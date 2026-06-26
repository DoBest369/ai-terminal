import Foundation
import Citadel
import NIOCore
import NIOPosix
import NIOSSH
import Crypto

/// SSH 相关错误，附带中文友好提示
public struct SSHFriendlyError: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }

    /// 把底层错误翻译为中文提示
    public static func translate(_ error: Error) -> SSHFriendlyError {
        if let hk = error as? HostKeyChangedError {
            return SSHFriendlyError(hk.errorDescription ?? "主机密钥已变化（可能存在中间人攻击）")
        }
        let raw = String(describing: error).lowercased()
        if raw.contains("hostkeychanged") || raw.contains("主机密钥") {
            return SSHFriendlyError("主机密钥已变化（可能存在中间人攻击）。如确认服务器更换了密钥，可在设置中清除已知主机后重连。")
        }
        if raw.contains("timed out") || raw.contains("timeout") {
            return SSHFriendlyError("连接超时，请检查网络或服务器地址")
        } else if raw.contains("authentication") || raw.contains("auth") && raw.contains("fail") {
            return SSHFriendlyError("认证失败，请检查用户名和密码/私钥")
        } else if raw.contains("connection refused") || raw.contains("econnrefused") {
            return SSHFriendlyError("连接被拒绝，请检查服务器地址和端口")
        } else if raw.contains("reset") {
            return SSHFriendlyError("连接被重置，服务器可能断开了连接")
        } else if raw.contains("unreachable") {
            return SSHFriendlyError("无法访问主机，请检查网络连接")
        } else if raw.contains("privatekey") || raw.contains("invalidopenssh") || raw.contains("key") && raw.contains("invalid") {
            return SSHFriendlyError("私钥格式错误或口令不正确")
        }
        return SSHFriendlyError("连接失败: \(error.localizedDescription)")
    }
}

/// SFTP 目录条目
public struct SFTPEntry: Identifiable, Sendable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: UInt64
    /// 修改时间（可选，Citadel 提供时填充）
    public let modifiedAt: Date?

    public init(name: String, path: String, isDirectory: Bool, size: UInt64, modifiedAt: Date? = nil) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedAt = modifiedAt
    }
}

/// 一个交互式 SSH 终端会话（基于 Citadel 的 PTY）。
///
/// 用法：
/// ```swift
/// let session = SSHTerminalSession(connection: conn)
/// try await session.connect()
/// await session.startShell(cols: 80, rows: 24,
///     onOutput: { data in /* 写入终端视图 */ },
///     onClose: { msg in /* 处理断开 */ })
/// await session.send(Data("ls\n".utf8))
/// ```
public actor SSHTerminalSession {
    public let connection: Connection

    private var client: SSHClient?
    private var jumpClient: SSHClient?
    private var sftp: SFTPClient?
    private var stdin: TTYStdinWriter?
    private var forwardChannels: [UUID: Channel] = [:]
    private var shellTask: Task<Void, Never>?
    private var pendingCols: Int = 80
    private var pendingRows: Int = 24

    public private(set) var status: SessionStatus = .disconnected

    public init(connection: Connection) {
        self.connection = connection
    }

    /// 建立底层 SSH 连接（完成认证）。
    public func connect() async throws {
        // 重入保护：关闭任何已有连接，避免覆盖导致泄漏
        if let existing = client { try? await existing.close(); client = nil }
        if let existingJump = jumpClient { try? await existingJump.close(); jumpClient = nil }
        status = .connecting
        do {
            let auth = try Self.makeAuthMethod(for: connection)
            let hostID = "\(connection.host):\(connection.port)"

            if connection.hasJump {
                // 先连跳板机（密码认证），再 jump 到目标
                let jHost = (connection.jumpHost ?? "").trimmingCharacters(in: .whitespaces)
                let jPort = connection.jumpPort ?? 22
                let jUser = (connection.jumpUsername ?? "").trimmingCharacters(in: .whitespaces)
                let jPass = connection.jumpPassword ?? ""
                let jump = try await SSHClient.connect(
                    host: jHost,
                    port: jPort,
                    authenticationMethod: .passwordBased(username: jUser, password: jPass),
                    hostKeyValidator: .custom(TOFUHostKeyValidator(hostID: "\(jHost):\(jPort)")),
                    reconnect: .never
                )
                self.jumpClient = jump
                let settings = SSHClientSettings(
                    host: connection.host,
                    port: connection.port,
                    authenticationMethod: { auth },
                    hostKeyValidator: .custom(TOFUHostKeyValidator(hostID: hostID))
                )
                self.client = try await jump.jump(to: settings)
            } else {
                self.client = try await SSHClient.connect(
                    host: connection.host,
                    port: connection.port,
                    authenticationMethod: auth,
                    hostKeyValidator: .custom(TOFUHostKeyValidator(hostID: hostID)),
                    reconnect: .never
                )
            }
            status = .connected
        } catch {
            // 失败时清理可能已建立的跳板连接，避免残留
            if let jc = jumpClient { try? await jc.close() }
            jumpClient = nil
            client = nil
            status = .error
            throw SSHFriendlyError.translate(error)
        }
    }

    /// 在已建立的连接上开启一个交互式 shell（PTY），持续把输出回调出去。
    public func startShell(
        cols: Int,
        rows: Int,
        onOutput: @escaping @Sendable (Data) -> Void,
        onClose: @escaping @Sendable (String?) -> Void
    ) {
        guard let client = client else {
            onClose("尚未建立连接")
            return
        }
        pendingCols = cols
        pendingRows = rows

        let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )

        shellTask = Task { [weak self] in
            do {
                try await client.withPTY(ptyRequest) { inbound, outbound in
                    await self?.setStdin(outbound)
                    for try await chunk in inbound {
                        switch chunk {
                        case .stdout(let buffer):
                            onOutput(Data(buffer.readableBytesView))
                        case .stderr(let buffer):
                            onOutput(Data(buffer.readableBytesView))
                        }
                    }
                }
                await self?.markClosed()
                onClose(nil)
            } catch {
                await self?.markClosed()
                onClose(SSHFriendlyError.translate(error).message)
            }
        }
    }

    private func setStdin(_ writer: TTYStdinWriter) {
        self.stdin = writer
    }

    private func markClosed() {
        status = .disconnected
        stdin = nil
    }

    /// 向远端写入用户输入。
    public func send(_ data: Data) async {
        guard let stdin = stdin else { return }
        try? await stdin.write(ByteBuffer(bytes: data))
    }

    /// 调整 PTY 窗口大小。
    public func resize(cols: Int, rows: Int) async {
        pendingCols = cols
        pendingRows = rows
        guard let stdin = stdin else { return }
        try? await stdin.changeSize(cols: cols, rows: rows, pixelWidth: 0, pixelHeight: 0)
    }

    /// 执行一次性命令并返回输出（用于抓取系统信息）。
    public func runCommand(_ command: String) async -> String {
        guard let client = client else { return "" }
        do {
            let buffer = try await client.executeCommand(command)
            return String(buffer: buffer)
        } catch {
            return ""
        }
    }

    // MARK: - 本地端口转发

    /// 开启本地端口转发：监听 127.0.0.1:localPort，每个连接经 SSH 桥接到 remoteHost:remotePort
    public func startForward(_ pf: PortForward) async throws {
        guard let client = client else { throw SSHFriendlyError("尚未建立连接") }
        guard forwardChannels[pf.id] == nil else { return }

        let group = MultiThreadedEventLoopGroup.singleton
        let originator = try SocketAddress(ipAddress: "127.0.0.1", port: 0)
        let remoteHost = pf.remoteHost
        let remotePort = pf.remotePort

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 16)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { localChannel in
                let promise = localChannel.eventLoop.makePromise(of: Void.self)
                Task {
                    var remoteChannel: Channel?
                    do {
                        let remote = try await client.createDirectTCPIPChannel(
                            using: SSHChannelType.DirectTCPIP(
                                targetHost: remoteHost,
                                targetPort: remotePort,
                                originatorAddress: originator
                            )
                        ) { channel in channel.eventLoop.makeSucceededFuture(()) }
                        remoteChannel = remote

                        let (glueLocal, glueRemote) = GlueHandler.matchedPair()
                        try await localChannel.pipeline.addHandler(glueLocal)
                        try await remote.pipeline.addHandler(glueRemote)
                        promise.succeed(())
                    } catch {
                        localChannel.close(promise: nil)
                        remoteChannel?.close(promise: nil)  // 半开的远端通道也要关，防泄漏
                        promise.fail(error)
                    }
                }
                return promise.futureResult
            }

        do {
            let serverChannel = try await bootstrap.bind(host: "127.0.0.1", port: pf.localPort).get()
            forwardChannels[pf.id] = serverChannel
        } catch {
            throw SSHFriendlyError("本地端口 \(pf.localPort) 监听失败: \(error.localizedDescription)")
        }
    }

    /// 停止某条端口转发
    public func stopForward(_ id: UUID) async {
        if let channel = forwardChannels.removeValue(forKey: id) {
            try? await channel.close()
        }
    }

    /// 断开会话。
    public func close() async {
        shellTask?.cancel()
        shellTask = nil
        stdin = nil
        for (_, channel) in forwardChannels {
            try? await channel.close()
        }
        forwardChannels.removeAll()
        if let sftp = sftp {
            try? await sftp.close()
        }
        sftp = nil
        if let client = client {
            try? await client.close()
        }
        client = nil
        if let jumpClient = jumpClient {
            try? await jumpClient.close()
        }
        jumpClient = nil
        status = .disconnected
    }

    // MARK: - SFTP 文件传输（复用同一 SSH 连接）

    private func ensureSFTP() async throws -> SFTPClient {
        if let sftp = sftp { return sftp }
        guard let client = client else { throw SSHFriendlyError("尚未建立连接") }
        do {
            let s = try await client.openSFTP()
            sftp = s
            return s
        } catch {
            throw SSHFriendlyError.translate(error)
        }
    }

    /// 解析远端家目录（用于初始路径）
    public func sftpHome() async -> String {
        guard let sftp = try? await ensureSFTP() else { return "/" }
        return (try? await sftp.getRealPath(atPath: ".")) ?? "/"
    }

    /// 列目录（已排序：目录在前，按名称）
    public func sftpList(_ path: String) async throws -> [SFTPEntry] {
        let sftp = try await ensureSFTP()
        let names: [SFTPMessage.Name]
        do {
            names = try await sftp.listDirectory(atPath: path)
        } catch {
            throw SSHFriendlyError.translate(error)
        }
        var entries: [SFTPEntry] = []
        for name in names {
            for c in name.components {
                if c.filename == "." || c.filename == ".." { continue }
                let isDir = c.longname.hasPrefix("d")
                let full = path.hasSuffix("/") ? path + c.filename : path + "/" + c.filename
                let mtime = c.attributes.accessModificationTime?.modificationTime
                entries.append(SFTPEntry(name: c.filename, path: full, isDirectory: isDir, size: c.attributes.size ?? 0, modifiedAt: mtime))
            }
        }
        return entries.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.lowercased() < b.name.lowercased()
        }
    }

    /// 下载文件内容
    public func sftpDownload(_ path: String) async throws -> Data {
        let sftp = try await ensureSFTP()
        do {
            let file = try await sftp.openFile(filePath: path, flags: .read)
            let buffer = try await file.readAll()
            try await file.close()
            return Data(buffer.readableBytesView)
        } catch {
            throw SSHFriendlyError.translate(error)
        }
    }

    /// 上传文件内容（覆盖写）
    public func sftpUpload(_ data: Data, to path: String) async throws {
        let sftp = try await ensureSFTP()
        do {
            let file = try await sftp.openFile(filePath: path, flags: [.write, .create, .truncate])
            try await file.write(ByteBuffer(bytes: data))
            try await file.close()
        } catch {
            throw SSHFriendlyError.translate(error)
        }
    }

    /// 新建远程目录（SFTP-Edit，对齐 android A-SftpEdit）。
    public func sftpMakeDirectory(_ path: String) async throws {
        let sftp = try await ensureSFTP()
        do { try await sftp.createDirectory(atPath: path) }
        catch { throw SSHFriendlyError.translate(error) }
    }

    /// 删除远程文件或目录（目录用 rmdir，文件用 remove）。
    public func sftpRemove(_ path: String, isDirectory: Bool) async throws {
        let sftp = try await ensureSFTP()
        do {
            if isDirectory { try await sftp.rmdir(at: path) }
            else { try await sftp.remove(at: path) }
        } catch { throw SSHFriendlyError.translate(error) }
    }

    /// 重命名/移动远程文件或目录（对齐 android A-SftpRename）。
    public func sftpRename(_ oldPath: String, to newPath: String) async throws {
        let sftp = try await ensureSFTP()
        do { try await sftp.rename(at: oldPath, to: newPath) }
        catch { throw SSHFriendlyError.translate(error) }
    }

    // MARK: - 认证方式构建

    static func makeAuthMethod(for connection: Connection) throws -> SSHAuthenticationMethod {
        switch connection.authType {
        case .password:
            return .passwordBased(username: connection.username, password: connection.password)
        case .privateKey:
            let keyText = try loadPrivateKeyText(for: connection)
            let passphraseData: Data? = connection.passphrase.isEmpty
                ? nil
                : Data(connection.passphrase.utf8)
            let keyType = try SSHKeyDetection.detectPrivateKeyType(from: keyText)
            switch keyType {
            case .ed25519:
                let key = try Curve25519.Signing.PrivateKey(sshEd25519: keyText, decryptionKey: passphraseData)
                return .ed25519(username: connection.username, privateKey: key)
            case .rsa:
                let key = try Insecure.RSA.PrivateKey(sshRsa: keyText, decryptionKey: passphraseData)
                return .rsa(username: connection.username, privateKey: key)
            default:
                throw SSHFriendlyError("暂不支持该私钥类型（\(keyType.description)），请使用 ed25519 或 RSA 私钥")
            }
        }
    }

    private static func loadPrivateKeyText(for connection: Connection) throws -> String {
        if !connection.privateKeyText.isEmpty {
            return connection.privateKeyText
        }
        guard !connection.privateKeyPath.isEmpty else {
            throw SSHFriendlyError("未提供私钥")
        }
        do {
            return try String(contentsOfFile: connection.privateKeyPath, encoding: .utf8)
        } catch {
            throw SSHFriendlyError("无法读取私钥文件: \(error.localizedDescription)")
        }
    }
}
