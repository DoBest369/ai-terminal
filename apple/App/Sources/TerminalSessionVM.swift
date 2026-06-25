import Foundation
import SwiftUI
import SwiftTerm
import AITerminalCore

/// 一个打开的终端会话（本地或 SSH）的视图模型。
@MainActor
final class TerminalSessionVM: ObservableObject, Identifiable {
    let id = UUID()
    let isLocal: Bool
    let connection: Connection?

    @Published var status: SessionStatus
    @Published var statusMessage: String = ""
    @Published var systemInfo: SystemInfo?

    /// 由终端视图注入：SwiftTerm 终端视图引用（用于搜索）
    weak var terminalView: TerminalView?
    /// 由终端视图注入：把字节喂给 SwiftTerm（用于显示）
    var feed: (@MainActor (Data) -> Void)?
    /// 由终端视图注入：向会话写入一条命令（本地写子进程 stdin，SSH 写远端）
    var injectCommand: (@MainActor (String) -> Void)?

    private var sshSession: SSHTerminalSession?
    private var prevCPU: (idle: Double, total: Double)?
    private var monitorTask: Task<Void, Never>?
    private var connectTask: Task<Void, Never>?
    private var didStartShell = false
    private(set) var lastCols = 80
    private(set) var lastRows = 24

    // MARK: - 输出录制
    @Published var isRecording = false
    private var recordingBuffer = Data()
    /// 录制 buffer 上限（5MB），防止超长会话内存无限增长；超限保留最近输出。
    private let recordingMaxBytes = 5_000_000

    func startRecording() {
        recordingBuffer = Data()
        isRecording = true
    }

    func stopRecording() {
        isRecording = false
    }

    /// 录制中才追加，避免影响正常显示/性能；超过上限时丢弃最旧字节、保留最近输出。
    private func recordOutput(_ data: Data) {
        guard isRecording else { return }
        recordingBuffer.append(data)
        if recordingBuffer.count > recordingMaxBytes {
            recordingBuffer.removeFirst(recordingBuffer.count - recordingMaxBytes)
        }
    }

    /// 录制文本（UTF8 容错解码 + 去除常见 ANSI 转义，便于阅读）
    func recordedText() -> String {
        var s = String(decoding: recordingBuffer, as: UTF8.self)
        let patterns = [
            "\u{1b}\\[[0-9;?]*[ -/]*[@-~]",          // CSI 序列（含 SGR 颜色等）
            "\u{1b}\\][^\u{07}\u{1b}]*(\u{07}|\u{1b}\\\\)" // OSC 序列（标题等）
        ]
        for p in patterns {
            if let re = try? NSRegularExpression(pattern: p) {
                s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
            }
        }
        return s
    }

    var title: String {
        if isLocal { return "本地终端" }
        return connection?.title ?? "SSH"
    }

    init(local: Bool, connection: Connection?) {
        self.isLocal = local
        self.connection = connection
        self.status = local ? .connected : .disconnected
    }

    // MARK: - SSH 生命周期

    /// 建立 SSH 连接并开启 shell。由终端视图在拿到初始尺寸后调用。
    func startSSH(cols: Int, rows: Int) {
        guard !isLocal, let connection, !didStartShell else { return }
        didStartShell = true
        lastCols = cols
        lastRows = rows
        status = .connecting
        statusMessage = "正在连接 \(connection.host)…"

        let session = SSHTerminalSession(connection: connection)
        self.sshSession = session

        connectTask = Task { @MainActor in
            do {
                try await session.connect()
                // 若期间被 disconnect/reconnect 取消或换了会话，丢弃结果，避免覆盖状态
                guard !Task.isCancelled, self.sshSession === session else { return }
                self.status = .connected
                self.statusMessage = "已连接"
                self.feed?(Data("\u{1b}[32m✓ 连接成功\u{1b}[0m\r\n".utf8))
                await session.startShell(
                    cols: cols,
                    rows: rows,
                    onOutput: { [weak self] data in
                        Task { @MainActor in
                            self?.recordOutput(data)
                            self?.feed?(data)
                        }
                    },
                    onClose: { [weak self] msg in
                        Task { @MainActor in self?.handleClose(msg) }
                    }
                )
                guard !Task.isCancelled, self.sshSession === session else { return }
                self.startMonitoring()
                self.runStartupCommands()
            } catch {
                guard !Task.isCancelled, self.sshSession === session else { return }
                self.status = .error
                let message = (error as? SSHFriendlyError)?.message ?? error.localizedDescription
                self.statusMessage = message
                self.feed?(Data("\r\n\u{1b}[31m✗ \(message)\u{1b}[0m\r\n".utf8))
                self.didStartShell = false
            }
        }
    }

    /// shell 就绪后逐条注入连接配置里的启动命令（每行一条，补回车执行）
    private func runStartupCommands() {
        guard let connection else { return }
        let lines = connection.startupCommandLines
        guard !lines.isEmpty, let sshSession else { return }
        Task {
            for line in lines {
                await sshSession.send(Data((line + "\n").utf8))
            }
        }
    }

    private func handleClose(_ message: String?) {
        status = .disconnected
        statusMessage = message ?? "连接已断开"
        if let message {
            feed?(Data("\r\n\u{1b}[33m\(message)\u{1b}[0m\r\n".utf8))
        }
        monitorTask?.cancel()
        monitorTask = nil
        didStartShell = false
    }

    /// 用户在终端输入
    func sendInput(_ data: ArraySlice<UInt8>) {
        guard let sshSession else { return }
        let bytes = Data(data)
        Task { await sshSession.send(bytes) }
    }

    /// 清屏：向 shell 发 Ctrl-L（SSH 经 delegate 回到 sendInput，本地直达进程）
    func clearScreen() {
        terminalView?.send(txt: "\u{0c}")
    }

    func resize(cols: Int, rows: Int) {
        lastCols = cols
        lastRows = rows
        guard let sshSession else { return }
        Task { await sshSession.resize(cols: cols, rows: rows) }
    }

    func disconnect() {
        connectTask?.cancel()
        connectTask = nil
        monitorTask?.cancel()
        monitorTask = nil
        let session = sshSession
        Task { await session?.close() }
        sshSession = nil
        status = .disconnected
        didStartShell = false
    }

    /// 重新连接（用于断开/出错后重试），沿用上次的终端尺寸
    func reconnect() {
        guard !isLocal else { return }
        disconnect()
        startSSH(cols: lastCols, rows: lastRows)
    }

    /// 直接向远端发送原始字节（终端辅助键栏用）
    func sendBytes(_ bytes: [UInt8]) {
        guard let sshSession else { return }
        Task { await sshSession.send(Data(bytes)) }
    }

    // MARK: - 终端搜索（SwiftTerm 内置）

    /// 向下查找；返回是否命中
    @discardableResult
    func searchNext(_ term: String) -> Bool {
        guard let tv = terminalView, !term.isEmpty else { return false }
        return tv.findNext(term)
    }

    /// 向上查找；返回是否命中
    @discardableResult
    func searchPrevious(_ term: String) -> Bool {
        guard let tv = terminalView, !term.isEmpty else { return false }
        return tv.findPrevious(term)
    }

    // MARK: - SFTP 代理

    var supportsSFTP: Bool { !isLocal && sshSession != nil }

    func sftpHome() async -> String {
        await sshSession?.sftpHome() ?? "/"
    }

    func sftpList(_ path: String) async throws -> [SFTPEntry] {
        guard let sshSession else { throw SSHFriendlyError("未连接") }
        return try await sshSession.sftpList(path)
    }

    func sftpDownload(_ path: String) async throws -> Data {
        guard let sshSession else { throw SSHFriendlyError("未连接") }
        return try await sshSession.sftpDownload(path)
    }

    func sftpUpload(_ data: Data, to path: String) async throws {
        guard let sshSession else { throw SSHFriendlyError("未连接") }
        try await sshSession.sftpUpload(data, to: path)
    }

    // MARK: - 端口转发

    @Published var portForwards: [PortForward] = []
    @Published var activeForwardIDs: Set<UUID> = []
    @Published var forwardError: String?

    func addForward(localPort: Int, remoteHost: String, remotePort: Int) {
        portForwards.append(PortForward(localPort: localPort, remoteHost: remoteHost, remotePort: remotePort))
    }

    func removeForward(_ pf: PortForward) {
        if activeForwardIDs.contains(pf.id) {
            Task { await stopForward(pf) }
        }
        portForwards.removeAll { $0.id == pf.id }
    }

    func toggleForward(_ pf: PortForward) {
        if activeForwardIDs.contains(pf.id) {
            Task { await stopForward(pf) }
        } else {
            Task { await startForward(pf) }
        }
    }

    private func startForward(_ pf: PortForward) async {
        guard let sshSession else { return }
        forwardError = nil
        do {
            try await sshSession.startForward(pf)
            activeForwardIDs.insert(pf.id)
        } catch {
            forwardError = (error as? SSHFriendlyError)?.message ?? error.localizedDescription
        }
    }

    private func stopForward(_ pf: PortForward) async {
        guard let sshSession else { return }
        await sshSession.stopForward(pf.id)
        activeForwardIDs.remove(pf.id)
    }

    // MARK: - 系统监控

    private func startMonitoring() {
        guard let sshSession else { return }
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                let result = await RemoteSystemMonitor.fetch(using: sshSession, previousCPU: self?.prevCPU)
                await MainActor.run {
                    self?.prevCPU = result.cpu
                    self?.systemInfo = result.info
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }
}
