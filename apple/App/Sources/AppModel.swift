import Foundation
import SwiftUI
import AITerminalCore

/// AI 三模式（安全梯度，对齐 windows/linux）：Chat 纯聊天 / Agent 每条确认 / Auto 自主闭环
enum AIMode: String, CaseIterable, Identifiable {
    case chat, agent, autoAgent
    var id: String { rawValue }
    var label: String {
        switch self {
        case .chat: return "聊天"
        case .agent: return "代理"
        case .autoAgent: return "全自动"
        }
    }
    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .agent: return "checkmark.shield"
        case .autoAgent: return "bolt.badge.automatic"
        }
    }
    var hint: String {
        switch self {
        case .chat: return "只对话建议，不执行命令"
        case .agent: return "AI 生成命令，每条需你确认放行"
        case .autoAgent: return "AI 自主执行闭环（高危仍需确认）"
        }
    }
}

/// 应用主状态。
@MainActor
final class AppModel: ObservableObject {
    // 保存的连接（模板）
    @Published var connections: [Connection] = []

    /// 连接可达性（TCP 探测结果）。缺省=未知。
    enum ReachState { case checking, reachable, unreachable }
    @Published var reachability: [UUID: ReachState] = [:]

    /// 并发探测全部保存连接的可达性（连接数通常不多，直接全发；如需可加并发上限）
    func checkAllReachability() {
        for conn in connections {
            checkReachability(conn)
        }
    }

    /// 异步探测某连接 host:port 的 TCP 可达性（不做 SSH 握手）
    func checkReachability(_ connection: Connection) {
        let id = connection.id
        let host = connection.host
        let port = connection.port
        guard !host.isEmpty else { return }
        reachability[id] = .checking
        Task {
            let ok = await ReachabilityChecker.probe(host: host, port: port)
            self.reachability[id] = ok ? .reachable : .unreachable
        }
    }
    // 打开的会话
    @Published var sessions: [TerminalSessionVM] = []
    @Published var activeSessionID: UUID? {
        didSet { persistOpenSessions() }
    }

    // 分屏（第二个并排面板）
    @Published var splitEnabled = false
    @Published var secondaryID: UUID?

    // 会话恢复
    private var didRestore = false
    private static let openSessionsKey = "open_session_connection_ids"
    private static let activeConnectionKey = "active_session_connection_id"

    // AI
    @Published var aiConfig: AIConfig
    @Published var aiProcessing = false
    /// Z3 环境感知：当前活动服务器的环境画像（探测得到后注入 AI 上下文）
    @Published var serverProfile: ServerProfile?

    // 多对话：会话列表 + 当前激活会话
    @Published var conversations: [AIConversation] = []
    @Published var activeConversationID: UUID?

    /// 当前会话的消息（计算属性指向激活会话，现有流式逻辑读写它即可）
    var aiMessages: [ChatMessage] {
        get { conversations.first(where: { $0.id == activeConversationID })?.messages ?? [] }
        set {
            guard let idx = conversations.firstIndex(where: { $0.id == activeConversationID }) else { return }
            conversations[idx].messages = newValue
            if !conversations[idx].isCustomTitle {
                conversations[idx].title = conversations[idx].derivedTitle
            }
            conversations[idx].updatedAt = Date()
        }
    }

    /// 重命名某会话；空标题则回退自动标题（取消自定义）
    func renameConversation(_ id: UUID, to title: String) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            conversations[idx].titleIsCustom = false
            conversations[idx].title = conversations[idx].derivedTitle
        } else {
            conversations[idx].titleIsCustom = true
            conversations[idx].title = trimmed
        }
        persistAIMessages()
    }

    /// 新建对话并切换过去
    func newConversation() {
        if aiProcessing { cancelAIStreaming() }
        let conv = AIConversation()
        conversations.append(conv)
        activeConversationID = conv.id
        persistAIMessages()
    }

    /// 切换到指定会话（流式中先停掉）
    func switchConversation(_ id: UUID) {
        guard id != activeConversationID else { return }
        if aiProcessing { cancelAIStreaming() }
        activeConversationID = id
    }

    /// 删除指定会话；删完为空则建一个新的
    func deleteConversation(_ id: UUID) {
        if id == activeConversationID, aiProcessing { cancelAIStreaming() }
        conversations.removeAll { $0.id == id }
        if conversations.isEmpty {
            conversations = [AIConversation()]
        }
        if !conversations.contains(where: { $0.id == activeConversationID }) {
            activeConversationID = conversations.first?.id
        }
        persistAIMessages()
    }

    /// AI 系统提示词（可自定义，持久化）。空则视为用默认。
    @Published var agentSystemPrompt: String {
        didSet {
            UserDefaults.standard.set(agentSystemPrompt, forKey: Self.systemPromptKey)
        }
    }
    private static let systemPromptKey = "ai_system_prompt"

    /// AI 工作模式（chat/agent/autoAgent，持久化，对齐 windows/linux 三模式）
    @Published var aiMode: AIMode = AIMode(rawValue: UserDefaults.standard.string(forKey: "ai_mode") ?? "chat") ?? .chat {
        didSet { UserDefaults.standard.set(aiMode.rawValue, forKey: "ai_mode") }
    }
    /// Agent 模式待确认放行的命令（UI 显示「执行」按钮）
    @Published var pendingCommands: [String] = []

    /// 恢复默认系统提示词
    func resetAgentSystemPrompt() {
        agentSystemPrompt = defaultAgentSystemPrompt
    }
    /// 进行中的流式消费 Task（用于「停止」取消）
    private var aiStreamTask: Task<Void, Never>?

    // 命令片段
    @Published var snippets: [CommandSnippet] = []

    // N-History：命令历史（注入命令时记录，可调出重用）
    @Published var commandHistory: [String] = CommandHistory.load()

    // N-Multi：批量群发结果（对多连接并发执行同一命令，对齐 android）
    @Published var batchResults: [BatchOutcome] = []
    @Published var batchRunning: Bool = false

    /// 对选中的多个连接并发执行同一命令，聚合结果（N-Multi）。
    /// 各连接用自身 Connection 的凭据（savePassword/私钥）建临时会话；TODO: 未存密码的连接需运行时输入。
    func runBatch(_ targets: [Connection], command: String) {
        let cmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty, !targets.isEmpty, !batchRunning else { return }
        batchRunning = true
        batchResults = []
        Task { @MainActor in
            let outcomes = await BatchRunner.run(targets, name: { $0.name.isEmpty ? $0.host : $0.name }) { conn in
                let session = SSHTerminalSession(connection: conn)
                do {
                    try await session.connect()
                    let out = await session.runCommand(cmd)
                    await session.close()
                    return (output: Redactor.redact(out), ok: true)
                } catch {
                    await session.close()
                    return (output: "⚠️ \(error.localizedDescription)", ok: false)
                }
            }
            batchResults = outcomes
            batchRunning = false
        }
    }

    // N-Cron：批量健康巡检结果（对多连接并发采集系统状态，异常置顶，对齐 android InspectScreen）
    struct InspectionResult: Identifiable, Sendable {
        let id = UUID()
        let name: String
        let info: SystemInfo?
        let error: String?
        var hasWarning: Bool { info?.hasWarning ?? true }   // 采集失败也视为需关注
    }
    @Published var inspectionResults: [InspectionResult] = []
    @Published var inspectionRunning: Bool = false

    /// 对选中的多个连接并发巡检系统健康（CPU/内存/磁盘），异常置顶（N-Cron）。
    func runHealthInspection(_ targets: [Connection]) {
        guard !targets.isEmpty, !inspectionRunning else { return }
        inspectionRunning = true
        inspectionResults = []
        Task { @MainActor in
            let results: [InspectionResult] = await withTaskGroup(of: InspectionResult.self) { group in
                for conn in targets {
                    group.addTask {
                        let nm = conn.name.isEmpty ? conn.host : conn.name
                        let session = SSHTerminalSession(connection: conn)
                        do {
                            try await session.connect()
                            let (info, _) = await RemoteSystemMonitor.fetch(using: session, previousCPU: nil)
                            await session.close()
                            return InspectionResult(name: nm, info: info, error: nil)
                        } catch {
                            await session.close()
                            return InspectionResult(name: nm, info: nil, error: error.localizedDescription)
                        }
                    }
                }
                var acc: [InspectionResult] = []
                for await r in group { acc.append(r) }
                return acc
            }
            // 异常置顶，其余按名称（复用 Core 纯逻辑）
            let items = HealthInspection.sorted(results.map { HealthInspectionItem(name: $0.name, info: $0.info, error: $0.error) })
            inspectionResults = items.map { InspectionResult(name: $0.name, info: $0.info, error: $0.error) }
            inspectionRunning = false
        }
    }

    /// 让 AI 总结巡检结果（N-Cron-AI）。
    func summarizeInspection() {
        guard aiConfig.isConfigured, !inspectionResults.isEmpty else {
            toast = inspectionResults.isEmpty ? "请先巡检" : "请先配置 API Key"
            return
        }
        let material = HealthInspection.composeForAI(inspectionResults.map { HealthInspectionItem(name: $0.name, info: $0.info, error: $0.error) })
        aiMessages.append(ChatMessage(role: .user, content: material))
        runAICompletion(systemPrompt: "你是运维助手。这是一批服务器的健康巡检，请：① 总览(正常/告警台数) ② 需优先处理的机器及原因 ③ 共性风险 ④ 处理建议。精炼中文。")
    }

    /// 让 AI 汇总群发结果（N-Multi-AI）。
    func summarizeBatch(command: String) {
        guard aiConfig.isConfigured, !batchResults.isEmpty else {
            toast = batchResults.isEmpty ? "请先群发执行" : "请先配置 API Key"
            return
        }
        let material = BatchRunner.composeForAI(command: command, batchResults)
        aiMessages.append(ChatMessage(role: .user, content: material))
        runAICompletion(systemPrompt: "你是运维助手。这是一批服务器执行同一命令的结果，请：① 总览(成功/失败台数) ② 失败机器及原因 ③ 共性问题 ④ 后续建议。精炼中文。")
    }

    /// 记录一条注入的命令到历史
    func recordCommand(_ cmd: String) {
        commandHistory = CommandHistory.add(cmd)
    }

    // UI 状态
    @Published var showSettings = false
    @Published var showSnippets = false
    @Published var showFileBrowser = false
    @Published var showPortForward = false
    @Published var showInspect = false   // N-Cron 批量巡检面板
    @Published var showBatch = false     // N-Multi 批量群发面板
    @Published var multiSelectMode = false           // 连接批量编辑：多选模式
    @Published var selectedConnectionIDs: Set<UUID> = []
    @Published var notebookConnection: Connection?   // 服务器知识卡片：当前查看的连接
    @Published var searchActive = false
    @Published var editingConnection: Connection?
    /// 正在展示二维码分享的连接
    @Published var qrConnection: Connection?
    @Published var toast: String?

    // 终端字号（持久化）
    @Published var terminalFontSize: CGFloat {
        didSet { UserDefaults.standard.set(Double(terminalFontSize), forKey: Self.fontSizeKey) }
    }
    static let minFontSize: CGFloat = 8
    static let maxFontSize: CGFloat = 28
    private static let fontSizeKey = "terminal_font_size"

    // 配色方案（持久化）
    @Published var themeID: String {
        didSet {
            applyTheme()
            UserDefaults.standard.set(themeID, forKey: Self.themeKey)
        }
    }
    private static let themeKey = "color_scheme_id"

    /// 自定义主题的可调颜色（持久化）
    @Published var customColors: CustomThemeColors {
        didSet {
            if let data = try? JSONEncoder().encode(customColors) {
                UserDefaults.standard.set(data, forKey: Self.customKey)
            }
            if themeID == AppColorScheme.customID {
                applyTheme()
            }
        }
    }
    private static let customKey = "custom_scheme_json"

    /// 主题修订号：自定义颜色变化时自增，作为终端视图热更新的触发令牌。
    @Published var themeRevision = 0

    /// 根据 themeID 计算并应用全局配色（自定义走 makeCustom），并 bump 修订号。
    private func applyTheme() {
        activeColorScheme = themeID == AppColorScheme.customID
            ? AppColorScheme.makeCustom(customColors)
            : AppColorScheme.by(id: themeID)
        themeRevision &+= 1
    }

    /// 设置某个自定义颜色（ColorPicker 绑定用）。keyPath 指向 customColors 的字段。
    func setCustomColor(_ keyPath: WritableKeyPath<CustomThemeColors, String>, _ hex: String) {
        customColors[keyPath: keyPath] = hex
    }

    private let store = ConnectionStore.shared

    init() {
        self.aiConfig = store.loadAIConfig()
        var convs = store.loadConversations()
        if convs.isEmpty { convs = [AIConversation()] }
        self.conversations = convs
        self.activeConversationID = convs.first?.id
        let savedPrompt = UserDefaults.standard.string(forKey: Self.systemPromptKey)
        self.agentSystemPrompt = (savedPrompt?.isEmpty == false) ? savedPrompt! : defaultAgentSystemPrompt
        self.connections = store.loadConnections()
        let savedSize = UserDefaults.standard.double(forKey: Self.fontSizeKey)
        self.terminalFontSize = savedSize > 0 ? CGFloat(savedSize) : 13
        // 自定义配色（先于 themeID 应用）
        if let data = UserDefaults.standard.data(forKey: Self.customKey),
           let c = try? JSONDecoder().decode(CustomThemeColors.self, from: data) {
            self.customColors = c
        } else {
            self.customColors = .default
        }
        let savedTheme = UserDefaults.standard.string(forKey: Self.themeKey) ?? AppColorScheme.midnight.id
        self.themeID = savedTheme
        // init 中 didSet 不触发，手动应用
        activeColorScheme = savedTheme == AppColorScheme.customID
            ? AppColorScheme.makeCustom(self.customColors)
            : AppColorScheme.by(id: savedTheme)
        self.snippets = store.loadSnippets()

        #if os(macOS)
        // macOS 默认打开本地终端会话
        let local = TerminalSessionVM(local: true, connection: nil)
        sessions = [local]
        activeSessionID = local.id
        #endif

        restoreSessions()
    }

    // MARK: - 会话恢复

    /// 启动时按上次记录的连接 id 重新打开 SSH 会话标签
    private func restoreSessions() {
        let savedIDs = (UserDefaults.standard.array(forKey: Self.openSessionsKey) as? [String])?
            .compactMap { UUID(uuidString: $0) } ?? []
        for id in savedIDs {
            guard let conn = connections.first(where: { $0.id == id }),
                  !sessions.contains(where: { $0.connection?.id == id }) else { continue }
            sessions.append(TerminalSessionVM(local: false, connection: conn))
        }
        // 恢复上次激活的会话
        if let activeStr = UserDefaults.standard.string(forKey: Self.activeConnectionKey),
           let activeUUID = UUID(uuidString: activeStr),
           let vm = sessions.first(where: { $0.connection?.id == activeUUID }) {
            activeSessionID = vm.id
        } else if activeSessionID == nil {
            activeSessionID = sessions.first?.id
        }
        didRestore = true
    }

    /// 记录当前打开的 SSH 会话（连接 id）与激活会话，供下次启动恢复
    private func persistOpenSessions() {
        guard didRestore else { return }
        let ids = sessions.compactMap { $0.connection?.id.uuidString }
        UserDefaults.standard.set(ids, forKey: Self.openSessionsKey)
        if let activeConn = activeSession?.connection?.id.uuidString {
            UserDefaults.standard.set(activeConn, forKey: Self.activeConnectionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.activeConnectionKey)
        }
    }

    var activeSession: TerminalSessionVM? {
        sessions.first { $0.id == activeSessionID }
    }

    var secondarySession: TerminalSessionVM? {
        sessions.first { $0.id == secondaryID }
    }

    // MARK: - 分屏

    func toggleSplit() {
        if splitEnabled {
            splitEnabled = false
            return
        }
        guard let other = sessions.first(where: { $0.id != activeSessionID }) else {
            toast = "需要至少两个会话才能分屏"
            return
        }
        secondaryID = other.id
        splitEnabled = true
    }

    // MARK: - 终端字号

    func zoomIn() {
        terminalFontSize = min(Self.maxFontSize, terminalFontSize + 1)
    }

    func zoomOut() {
        terminalFontSize = max(Self.minFontSize, terminalFontSize - 1)
    }

    func resetZoom() {
        terminalFontSize = 13
    }

    // MARK: - 命令片段

    func saveSnippet(_ snippet: CommandSnippet) {
        if let idx = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[idx] = snippet
        } else {
            snippets.append(snippet)
        }
        store.saveSnippets(snippets)
    }

    func deleteSnippet(_ snippet: CommandSnippet) {
        snippets.removeAll { $0.id == snippet.id }
        store.saveSnippets(snippets)
    }

    func resetSnippets() {
        snippets = CommandSnippet.defaults
        store.saveSnippets(snippets)
    }

    /// 操作时间线（Z5）：记录改关键配置等关键操作，便于复盘/回滚
    @Published var opTimeline: [OpTimelineEntry] = []

    /// 当前时间戳（备份文件名用），格式 yyyyMMdd-HHmmss
    private func backupStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }

    /// 把片段命令注入当前活动会话的终端提示符（不自动回车，便于复核高危命令）。
    /// Z5：若命令会改关键配置，先注入备份命令并记录时间线。
    @discardableResult
    func runSnippet(_ snippet: CommandSnippet) -> Bool {
        guard let session = activeSession, let inject = session.injectCommand else {
            toast = "请先打开一个终端会话"
            return false
        }
        injectWithBackup(snippet.command, action: "快捷命令：\(snippet.title)", inject: inject)
        return true
    }

    /// 注入命令前，若会改关键配置则先注入 `cp 备份` 命令并记入时间线（Z5 可回滚）。
    private func injectWithBackup(_ command: String, action: String, inject: (String) -> Void) {
        let stamp = backupStamp()
        let backups = OpRollback.backupCommands(forCommand: command, stamp: stamp)
        if !backups.isEmpty {
            for b in backups { inject(b) }
            // 记录每个被备份的关键配置到时间线
            for target in OpRollback.criticalTargets(in: command) {
                opTimeline.append(OpTimelineEntry(
                    time: Date(), action: action, command: command,
                    rollbackable: true, backupPath: "\(target).bak-\(stamp)"))
            }
            toast = "⚠️ 检测到改动关键配置，已先注入备份命令（可在时间线回滚）"
        }
        inject(command)
        recordCommand(command)   // N-History
    }

    /// 运行一个初始化/部署模板（Z8）：把模板全部命令注入当前会话执行，关键配置自动备份。
    @discardableResult
    func runSetupTemplate(_ template: SetupTemplate) -> Bool {
        guard let session = activeSession, let inject = session.injectCommand else {
            toast = "请先打开一个终端会话"
            return false
        }
        injectWithBackup(template.allCommands.joined(separator: "\n"), action: "初始化模板：\(template.name)", inject: inject)
        toast = "已注入「\(template.name)」共 \(template.steps.count) 步命令"
        return true
    }

    /// 回滚一条时间线操作（注入还原命令到终端）。
    @discardableResult
    func rollback(_ entry: OpTimelineEntry) -> Bool {
        guard let cmd = entry.rollbackCommand else { toast = "该操作不可回滚"; return false }
        guard let session = activeSession, let inject = session.injectCommand else {
            toast = "请先打开一个终端会话"; return false
        }
        inject(cmd)
        toast = "已注入回滚命令：还原 \(entry.backupPath ?? "")"
        return true
    }

    // MARK: - Z4 场景化排障工作流

    /// 触发一个排障工作流：把诊断命令依次注入当前会话终端执行（用户可见输出）。
    @discardableResult
    func runDiagnostic(_ workflow: DiagnosticWorkflow) -> Bool {
        guard let session = activeSession, let inject = session.injectCommand else {
            toast = "请先打开一个终端会话"
            return false
        }
        // 用 `;` 串起来一次注入，便于复核后整体执行
        inject(workflow.commands.joined(separator: "\n"))
        toast = "已注入「\(workflow.name)」诊断命令"
        return true
    }

    /// 用命令输出让 AI 总结排障结论（outputs：命令→输出）。待 SSH exec 捕获接入后由 runDiagnostic 自动调用。
    func analyzeDiagnostic(_ workflow: DiagnosticWorkflow, outputs: [String: String]) {
        guard aiConfig.isConfigured else {
            toast = "请先在设置中配置 API Key"
            showSettings = true
            return
        }
        aiMessages.append(ChatMessage(role: .user, content: workflow.composeForAI(outputs: outputs), createdAt: Date()))
        // 知识卡片由 runAICompletion 中心化注入（覆盖所有 AI 路径）
        runAICompletion(systemPrompt: workflow.summaryPrompt)
    }

    // MARK: - 连接管理

    func saveConnection(_ connection: Connection) {
        if let idx = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[idx] = connection
        } else {
            connections.append(connection)
        }
        store.saveConnections(connections)
    }

    func deleteConnection(_ connection: Connection) {
        connections.removeAll { $0.id == connection.id }
        store.deleteConnectionSecrets(id: connection.id)
        store.saveConnections(connections)
    }

    // MARK: - 连接批量编辑（对齐 android）

    func exitMultiSelect() { multiSelectMode = false; selectedConnectionIDs.removeAll() }

    func batchSetGroup(_ group: String) {
        for i in connections.indices where selectedConnectionIDs.contains(connections[i].id) {
            connections[i].group = group.isEmpty ? nil : group
        }
        store.saveConnections(connections)
        toast = "已为 \(selectedConnectionIDs.count) 个连接改分组"
        exitMultiSelect()
    }

    func batchSetColor(_ tag: ColorTag) {
        for i in connections.indices where selectedConnectionIDs.contains(connections[i].id) {
            connections[i].colorTag = tag
        }
        store.saveConnections(connections)
        toast = "已为 \(selectedConnectionIDs.count) 个连接改颜色标签"
        exitMultiSelect()
    }

    func batchDelete() {
        let ids = selectedConnectionIDs
        for id in ids { store.deleteConnectionSecrets(id: id) }
        connections.removeAll { ids.contains($0.id) }
        store.saveConnections(connections)
        toast = "已删除 \(ids.count) 个连接"
        exitMultiSelect()
    }

    /// 把连接的非敏感配置 JSON 复制到剪贴板（不含密码）
    func copyConnectionConfig(_ connection: Connection) {
        let data = ConnectionPortability.export([connection], includeSecrets: false)
        Clipboard.copy(String(decoding: data, as: UTF8.self))
        toast = "已复制连接配置（不含密码）"
    }

    /// 复制 ssh 连接串到剪贴板（方便粘贴到其他终端/文档）。默认端口 22 省略 -p。
    func copyConnectionString(_ connection: Connection) {
        let base = "ssh \(connection.username)@\(connection.host)"
        Clipboard.copy(connection.port == 22 ? base : "\(base) -p \(connection.port)")
        toast = "已复制连接串"
    }

    /// 复制一条连接为副本。换新 UUID（Identifiable/Equatable 以 id 区分），name 加「副本」后缀。
    /// 敏感字段一并复制：内存里的 connection 已从 Keychain 回填了密码/口令/私钥/跳板密码，
    /// saveConnections 会按新 id 写入各自的 Keychain 项（同一设备，安全等价）。
    func cloneConnection(_ connection: Connection) {
        var copy = connection
        copy.id = UUID()
        let base = connection.name.isEmpty ? connection.title : connection.name
        copy.name = base + " 副本"
        // 插到原连接之后，便于查看
        if let idx = connections.firstIndex(where: { $0.id == connection.id }) {
            connections.insert(copy, at: connections.index(after: idx))
        } else {
            connections.append(copy)
        }
        store.saveConnections(connections)
        toast = "已复制「\(base)」"
    }

    // MARK: - 连接导入/导出（跨端交换格式）

    /// 导出所有连接为交换 JSON（默认不含密码）
    func exportConnectionsData(includeSecrets: Bool = false) -> Data {
        ConnectionPortability.export(connections, includeSecrets: includeSecrets)
    }

    /// 合并连接（按 host+username+port 去重），返回新增数量
    @discardableResult
    private func mergeConnections(_ incoming: [Connection]) -> Int {
        var added = 0
        for conn in incoming {
            let dup = connections.contains {
                $0.host == conn.host && $0.username == conn.username && $0.port == conn.port
            }
            if !dup {
                connections.append(conn)
                added += 1
            }
        }
        if added > 0 {
            store.saveConnections(connections)
        }
        return added
    }

    /// 从交换 JSON 导入并合并；返回新增数量
    @discardableResult
    func importConnections(from data: Data) -> Int {
        guard let incoming = try? ConnectionPortability.parse(data) else {
            toast = "导入失败：文件格式无效"
            return 0
        }
        let added = mergeConnections(incoming)
        toast = added > 0 ? "已导入 \(added) 个连接" : "无新连接（已存在或为空）"
        return added
    }

    /// 从 ~/.ssh/config 解析并导入（macOS）
    func importSSHConfig() {
        #if os(macOS)
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh/config")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            toast = "未找到或无法读取 ~/.ssh/config"
            return
        }
        let added = mergeConnections(SSHConfigParser.parse(text))
        toast = added > 0 ? "从 ~/.ssh/config 导入 \(added) 个连接" : "无新连接（已存在或 config 为空）"
        #endif
    }

    /// 打开（或激活）某个保存连接的会话
    func openSession(for connection: Connection) {
        // 记录「最近使用」时间，用于侧边栏排序
        markUsed(connection.id)
        if let existing = sessions.first(where: { $0.connection?.id == connection.id }) {
            activeSessionID = existing.id
            return
        }
        let vm = TerminalSessionVM(local: false, connection: connection)
        sessions.append(vm)
        activeSessionID = vm.id
    }

    /// 把某连接的 lastUsedAt 标记为现在并持久化
    private func markUsed(_ id: UUID) {
        guard let idx = connections.firstIndex(where: { $0.id == id }) else { return }
        connections[idx].lastUsedAt = Date()
        store.saveConnections(connections)
    }

    func openLocalSession() {
        let vm = TerminalSessionVM(local: true, connection: nil)
        sessions.append(vm)
        activeSessionID = vm.id
    }

    func closeSession(_ session: TerminalSessionVM) {
        session.disconnect()
        sessions.removeAll { $0.id == session.id }
        if activeSessionID == session.id {
            activeSessionID = sessions.last?.id
        }
        // 维护分屏：关掉的是副面板，或会话不足 2 个，则退出分屏并清空副面板引用
        if secondaryID == session.id || sessions.count < 2 {
            splitEnabled = false
            secondaryID = nil
        }
        persistOpenSessions()
    }

    func status(for connection: Connection) -> SessionStatus {
        sessions.first { $0.connection?.id == connection.id }?.status ?? .disconnected
    }

    /// 断开并关闭某连接对应的会话（若存在）
    func disconnectSession(for connection: Connection) {
        if let s = sessions.first(where: { $0.connection?.id == connection.id }) {
            closeSession(s)
        }
    }

    /// 仅断开当前活动会话（保留标签，TerminalPane 会显示「重新连接」遮罩）
    func disconnectActiveSession() {
        guard let s = activeSession, !s.isLocal else { return }
        s.disconnect()
    }

    // MARK: - AI 配置

    func saveAIConfig(_ config: AIConfig) {
        aiConfig = config
        store.saveAIConfig(config)
    }

    // MARK: - AI 对话

    func sendAIMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !aiProcessing else { return }
        guard aiConfig.isConfigured else {
            toast = "请先在设置中配置 API Key"
            showSettings = true
            return
        }

        aiMessages.append(ChatMessage(role: .user, content: trimmed, createdAt: Date()))
        runAICompletion()
    }

    /// 重新生成上一条回复：删除末尾 assistant 回复，按最近的用户消息重答
    func regenerateLast() {
        guard !aiProcessing, aiMessages.last?.role == .assistant else { return }
        guard aiConfig.isConfigured else {
            toast = "请先在设置中配置 API Key"
            showSettings = true
            return
        }
        guard let lastUserIdx = aiMessages.lastIndex(where: { $0.role == .user }) else { return }
        // 删除最近用户消息之后的所有消息（末条 assistant 回复及可能的命令提示）
        aiMessages.removeSubrange((lastUserIdx + 1)...)
        runAICompletion()
    }

    /// 解释一条命令（Z1）：不执行，仅讲解作用/参数/风险/安全等级。
    func explainCommand(_ command: String) {
        let cmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty, !aiProcessing else { return }
        guard aiConfig.isConfigured else {
            toast = "请先在设置中配置 API Key"
            showSettings = true
            return
        }
        // 本地规则先判一道安全等级（即使没网/AI 也有基础提示）
        let danger = AIService.isDangerous(cmd) ? "（本地规则判定：⚠️ 高危命令）" : ""
        aiMessages.append(ChatMessage(role: .user, content: "解释这条命令\(danger)：\n```\n\(cmd)\n```", createdAt: Date()))
        runAICompletion(systemPrompt: commandExplainPrompt)
    }

    /// 分析一段报错/日志（Z2）：解释含义+定位原因+给可执行修复。
    func analyzeError(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !aiProcessing else { return }
        guard aiConfig.isConfigured else {
            toast = "请先在设置中配置 API Key"
            showSettings = true
            return
        }
        aiMessages.append(ChatMessage(role: .user, content: "分析这段报错并给修复：\n```\n\(t)\n```", createdAt: Date()))
        runAICompletion(systemPrompt: errorAnalysisPrompt)
    }

    /// 服务器健康分析（Z6b）：取当前会话的 SystemInfo 状态摘要，让 AI 排查异常并给建议。
    /// 实现「状态面板发现异常 → 一键问 AI 怎么办」的面板↔AI 联动。
    func diagnoseHealth() {
        guard aiConfig.isConfigured else {
            toast = "请先在设置中配置 API Key"
            showSettings = true
            return
        }
        guard let info = activeSession?.systemInfo, !info.healthSummary.isEmpty else {
            toast = "暂无服务器状态数据（请连接服务器并等待状态采集）"
            return
        }
        guard !aiProcessing else { return }
        var detail = info.healthSummary
        if !info.uptime.isEmpty { detail += "\n运行时长：\(info.uptime)" }
        if info.cpuCores > 0 { detail += "\nCPU 核数：\(info.cpuCores)" }
        aiMessages.append(ChatMessage(role: .user, content: "这台服务器当前状态如下，请分析有无异常并给排查/优化建议：\n\(detail)", createdAt: Date()))
        // 知识卡片由 runAICompletion 中心化注入（覆盖所有 AI 路径）
        runAICompletion(systemPrompt: healthAnalysisPrompt)
    }

    /// 公共流式生成：假定用户消息已在 aiMessages 末尾，追加占位 assistant 并流式填充。
    /// systemPrompt 可覆盖（命令解释等专用模式）。
    private func runAICompletion(systemPrompt: String? = nil) {
        aiProcessing = true

        let service = AIService(config: aiConfig)
        // 多轮上下文：只取最近 N 条，避免无限增长
        let recent = Array(aiMessages.suffix(Self.contextWindow))
        // Z3：若已探测到服务器环境，把摘要并入系统提示，让 AI 基于真实环境回答
        var sys = systemPrompt ?? agentSystemPrompt
        if let summary = serverProfile?.aiSummary, !summary.isEmpty {
            sys += "\n\n\(summary)\n请结合以上真实服务器环境给出针对性、可直接执行的回答。"
        }
        // 知识卡片注入（中心化）：所有 AI 路径（对话/解释/报错/排障/健康）都结合这台机历史记录
        if let connID = activeSession?.connection?.id.uuidString {
            let notebook = ServerNotebook.composeForAI(ServerNotebook.load(connectionID: connID))
            if !notebook.isEmpty { sys += "\n\n\(notebook)\n如与本次问题相关，请结合上述历史运维记录。" }
        }
        let conversation: [ChatMessage] = [ChatMessage(role: .system, content: sys)] + recent

        // 流式输出：先放一条空的 assistant 占位，按 token 追加
        let assistant = ChatMessage(role: .assistant, content: "", createdAt: Date())
        aiMessages.append(assistant)
        let aid = assistant.id

        // 立即保存（含刚加入的用户消息 + 占位），收尾再保存最终内容
        persistAIMessages()

        aiStreamTask = Task { @MainActor in
            var errored = false
            // 任何退出路径（成功/取消/出错）都持久化最终消息
            defer { self.persistAIMessages() }
            do {
                for try await delta in service.completeStreaming(messages: conversation) {
                    if Task.isCancelled { break }
                    if let idx = self.aiMessages.firstIndex(where: { $0.id == aid }) {
                        self.aiMessages[idx].content += delta
                    }
                }
            } catch {
                // 取消引发的错误交给下方统一处理；真正的错误才显示 ⚠️
                if !(error is CancellationError) {
                    errored = true
                    if let idx = self.aiMessages.firstIndex(where: { $0.id == aid }) {
                        let nl = self.aiMessages[idx].content.isEmpty ? "" : "\n"
                        self.aiMessages[idx].content += "\(nl)⚠️ \(error.localizedDescription)"
                    }
                }
            }

            self.aiProcessing = false
            self.aiStreamTask = nil

            // 被用户停止：补标记，不解析/注入命令
            if Task.isCancelled {
                if let idx = self.aiMessages.firstIndex(where: { $0.id == aid }) {
                    let nl = self.aiMessages[idx].content.isEmpty ? "" : "\n"
                    self.aiMessages[idx].content += "\(nl)⏹ 已停止"
                }
                return
            }
            if errored { return }

            let full = self.aiMessages.first(where: { $0.id == aid })?.content ?? ""
            if full.isEmpty, let idx = self.aiMessages.firstIndex(where: { $0.id == aid }) {
                self.aiMessages[idx].content = "（无回复）"
            }
            self.runParsedCommands(from: full)
        }
    }

    /// 停止进行中的 AI 流式生成
    func cancelAIStreaming() {
        guard aiProcessing else { return }
        aiStreamTask?.cancel()   // 触发 AsyncThrowingStream.onTermination → 取消底层网络
        aiProcessing = false     // 即时反馈；Task 收尾会补「⏹ 已停止」
    }

    /// AI 多轮上下文窗口：发送时携带的最近消息条数
    static let contextWindow = 20

    private var autoLoopDepth = 0          // Auto 自主闭环轮数（防失控）
    private let autoLoopMax = 5

    /// 把 AI 回复里的 [EXECUTE] 命令按 AI 模式处理（chat 不执行 / agent 待确认 / auto 自动+闭环）
    private func runParsedCommands(from reply: String) {
        let commands = AIService.parseCommands(from: reply)
        guard !commands.isEmpty else { autoLoopDepth = 0; return }
        // Chat 模式：纯聊天，不碰终端
        if aiMode == .chat { return }
        var autoExecuted = false
        for cmd in commands {
            // 危险命令：即使 Auto 也不自动执行，进待确认（安全铁律）
            if cmd.isDangerous || aiMode == .agent {
                pendingCommands.append(cmd.command)
                continue
            }
            // Auto 模式非危险命令：自动注入终端执行（首条前开始录制输出）
            if !autoExecuted { activeSession?.startRecording() }
            activeSession?.injectCommand?(cmd.command + "\n")
            recordCommand(cmd.command)   // N-History
            autoExecuted = true
        }
        // S5 Auto 自主闭环：等命令输出 → 回喂 AI 决策下一步（限轮+危险中断防失控）
        if aiMode == .autoAgent && autoExecuted && autoLoopDepth < autoLoopMax {
            autoLoopDepth += 1
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_500_000_000)   // 等命令执行产生输出
                let output = activeSession?.recordedText() ?? ""
                activeSession?.stopRecording()
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sendAIMessage("已执行命令，终端输出如下：\n\(trimmed)\n\n请判断是否需要下一步操作：需要则用 [EXECUTE]命令[/EXECUTE]，已完成则直接给结论不再给命令。")
                }
            }
        } else {
            autoLoopDepth = 0   // 非 Auto / 未执行 / 到顶 → 重置轮数
        }
    }

    /// 确认放行待执行命令（Agent 模式「执行」按钮 / 危险命令二次确认）
    func runPendingCommand(_ cmd: String) {
        activeSession?.injectCommand?(cmd + "\n")
        recordCommand(cmd)
        pendingCommands.removeAll { $0 == cmd }
    }

    func clearAIMessages() {
        aiMessages.removeAll()
        persistAIMessages()
    }

    /// 持久化 AI 对话历史（多会话，重启可恢复）
    private func persistAIMessages() {
        store.saveConversations(conversations)
    }

    /// 把当前 AI 对话导出为 Markdown
    func exportAIConversationMarkdown() -> Data {
        Data(markdown(for: aiMessages, heading: "# AI 对话").utf8)
    }

    /// 把全部会话导出为 Markdown（每会话一节）
    func exportAllConversationsMarkdown() -> Data {
        let nonEmpty = conversations.filter { !$0.messages.isEmpty }
        guard !nonEmpty.isEmpty else { return Data("# AI 对话（无内容）\n".utf8) }
        let sections = nonEmpty.map { conv in
            markdown(for: conv.messages, heading: "# 对话：\(conv.title.isEmpty ? "新对话" : conv.title)")
        }
        return Data(sections.joined(separator: "\n---\n\n").utf8)
    }

    /// 把一组消息拼装成 Markdown（你/AI 分段 + [EXECUTE]→bash 块），供单会话/全部共用
    private func markdown(for messages: [ChatMessage], heading: String) -> String {
        var md = heading + "\n\n"
        for msg in messages where msg.role != .system {
            md += (msg.role == .user ? "## 你\n\n" : "## AI\n\n")
            md += markdownBody(for: msg) + "\n\n"
        }
        return md
    }

    /// 助手消息里的 [EXECUTE]cmd[/EXECUTE] 转成 ```bash 代码块；其余原样
    private func markdownBody(for msg: ChatMessage) -> String {
        guard msg.role == .assistant else { return msg.content }
        let pattern = "\\[EXECUTE\\]([\\s\\S]*?)\\[/EXECUTE\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return msg.content }
        let ns = msg.content as NSString
        let result = NSMutableString(string: msg.content)
        let matches = regex.matches(in: msg.content, range: NSRange(location: 0, length: ns.length))
        for m in matches.reversed() where m.numberOfRanges >= 2 {
            let cmd = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            result.replaceCharacters(in: m.range(at: 0), with: "\n```bash\n\(cmd)\n```\n")
        }
        return result as String
    }
}
