import SwiftUI
import UniformTypeIdentifiers
import AITerminalCore

struct AIAgentView: View {
    @EnvironmentObject var model: AppModel
    @State private var input = ""
    @State private var promptGroupIdx = 0   // AI 提示词库分类
    @State private var showExporter = false
    @State private var exportDoc: TextFileDocument?
    @State private var exportFilename = "ai-conversation"
    @State private var showRename = false
    @State private var renameText = ""
    @State private var searchActive = false
    @State private var aiSearch = ""
    @State private var showClearConfirm = false
    @State private var showDeleteConvConfirm = false
    @State private var previewWorkflow: DiagnosticWorkflow?  // U-Z4 排障预览

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.surfaceLight)
            if searchActive {
                searchBar
                Divider().overlay(Theme.surfaceLight)
            }
            messages
            // 快捷追问（末条 assistant 且未处理中，对齐 android）
            if model.aiMessages.last?.role == .assistant && !model.aiProcessing {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // 知识沉淀闭环：把 AI 结论一键存为方案卡片（有关联连接时）
                        if let connID = model.activeSession?.connection?.id.uuidString {
                            Button {
                                let text = model.aiMessages.last?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                if !text.isEmpty {
                                    _ = ServerNotebook.add(ServerNote(kind: .solution, text: text), connectionID: connID)
                                    model.toast = "已存为方案到知识卡片"
                                }
                            } label: {
                                Label("存为方案", systemImage: "bookmark").font(.system(size: 12)).padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Theme.success.opacity(0.15)).foregroundStyle(Theme.success).clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(["给我具体命令", "换个思路", "解释原理", "有什么风险"], id: \.self) { q in
                            Button { input = q; send() } label: {
                                Text(q).font(.system(size: 12)).padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Theme.surfaceLight).foregroundStyle(Theme.textSecondary).clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                }
            }
            Divider().overlay(Theme.surfaceLight)
            inputBar
        }
        .glassPanel(Theme.surface, opacity: 0.45)
        .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .markdownDoc, defaultFilename: exportFilename) { _ in }
        .alert("重命名对话", isPresented: $showRename) {
            TextField("对话名称（留空恢复自动）", text: $renameText)
            Button("确定") {
                if let id = model.activeConversationID { model.renameConversation(id, to: renameText) }
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(item: $previewWorkflow) { wf in
            diagnosticPreview(wf)
        }
    }

    /// U-Z4 排障工作流预览 sheet：展示要跑的诊断命令，确认后注入
    private func diagnosticPreview(_ wf: DiagnosticWorkflow) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(wf.description)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    Text("将依次注入以下只读诊断命令：")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    ForEach(wf.commands, id: \.self) { c in
                        Text("$ \(c)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Theme.background)
            .navigationTitle(wf.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { previewWorkflow = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("注入诊断命令") {
                        model.runDiagnostic(wf)
                        previewWorkflow = nil
                    }
                }
            }
        }
        .frame(minWidth: 440, minHeight: 460)
    }

    private var activeTitle: String {
        model.conversations.first(where: { $0.id == model.activeConversationID })?.title ?? "AI 助手"
    }

    /// 会话菜单按 updatedAt 倒序（最近更新在前；nil 排后，保持稳定）
    private var sortedConversations: [AIConversation] {
        model.conversations.enumerated().sorted { a, b -> Bool in
            switch (a.element.updatedAt, b.element.updatedAt) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.offset < b.offset
            }
        }.map { $0.element }
    }

    /// 会话项标题：「标题 · 相对时间」
    private func conversationLabel(_ conv: AIConversation) -> String {
        let title = conv.title.isEmpty ? "新对话" : conv.title
        if let updated = conv.updatedAt {
            return "\(title) · \(RelativeTime.string(updated))"
        }
        return title
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(Theme.accent)
            Menu {
                ForEach(sortedConversations) { conv in
                    Button {
                        model.switchConversation(conv.id)
                    } label: {
                        Label(conversationLabel(conv),
                              systemImage: conv.id == model.activeConversationID ? "checkmark" : "bubble.left")
                    }
                }
                Divider()
                Button {
                    renameText = activeTitle
                    showRename = true
                } label: {
                    Label("重命名当前对话", systemImage: "pencil")
                }
                if !model.aiMessages.isEmpty {
                    Button {
                        Clipboard.copy(String(decoding: model.exportAIConversationMarkdown(), as: UTF8.self))
                        model.toast = "已复制当前对话"
                    } label: {
                        Label("复制当前对话", systemImage: "doc.on.clipboard")
                    }
                }
                if model.conversations.contains(where: { !$0.messages.isEmpty }) {
                    Button {
                        Clipboard.copy(String(decoding: model.exportAllConversationsMarkdown(), as: UTF8.self))
                        model.toast = "已复制全部对话"
                    } label: {
                        Label("复制全部对话", systemImage: "doc.on.clipboard.fill")
                    }
                }
                Button {
                    exportDoc = TextFileDocument(text: String(decoding: model.exportAllConversationsMarkdown(), as: UTF8.self))
                    exportFilename = "ai-all-conversations"
                    showExporter = true
                } label: {
                    Label("导出全部对话", systemImage: "square.and.arrow.up.on.square")
                }
                Button {
                    model.newConversation()
                } label: {
                    Label("新建对话", systemImage: "plus")
                }
                if model.conversations.count > 1 {
                    Button(role: .destructive) {
                        showDeleteConvConfirm = true
                    } label: {
                        Label("删除当前对话", systemImage: "trash")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(activeTitle).font(.headline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .confirmationDialog("删除当前对话？", isPresented: $showDeleteConvConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let id = model.activeConversationID { model.deleteConversation(id) }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将删除整个对话及其历史，不可恢复。")
            }
            Spacer()
            // Z4：一键排障工作流
            Menu {
                ForEach(DiagnosticWorkflow.builtins) { wf in
                    Button {
                        previewWorkflow = wf
                    } label: {
                        Label(wf.name, systemImage: wf.icon)
                    }
                }
            } label: {
                Image(systemName: "stethoscope")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .help("一键排障：预览诊断命令后注入")
            Button {
                searchActive.toggle()
                if !searchActive { aiSearch = "" }
            } label: {
                Image(systemName: searchActive ? "magnifyingglass.circle.fill" : "magnifyingglass")
            }
            .buttonStyle(.plain)
            .foregroundStyle(searchActive ? Theme.accent : Theme.textSecondary)
            .disabled(model.aiMessages.isEmpty)
            .help("搜索对话")
            if model.aiMessages.last?.role == .assistant && !model.aiProcessing {
                Button {
                    model.regenerateLast()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .help("重新生成上一条回复")
            }
            Button {
                exportDoc = TextFileDocument(text: String(decoding: model.exportAIConversationMarkdown(), as: UTF8.self))
                exportFilename = "ai-conversation"
                showExporter = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .disabled(model.aiMessages.isEmpty)
            .help("导出当前对话为 Markdown")
            Button {
                showClearConfirm = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .disabled(model.aiMessages.isEmpty)
            .help("清空对话")
            .confirmationDialog("清空当前对话？", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清空", role: .destructive) { model.clearAIMessages() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将删除当前会话的全部消息，不可恢复。")
            }
        }
        .padding(12)
    }

    /// 搜索栏（仿 SidebarView 样式）
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            TextField("搜索当前对话", text: $aiSearch)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            if !aiSearch.isEmpty {
                Button { aiSearch = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Theme.surface)
    }

    /// 搜索过滤后的消息（搜索空则全部）
    private var displayedMessages: [ChatMessage] {
        let q = aiSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return model.aiMessages }
        return model.aiMessages.filter { $0.content.lowercased().contains(q) }
    }

    private var isSearching: Bool {
        !aiSearch.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if model.aiMessages.isEmpty {
                        emptyHint
                    } else if isSearching && displayedMessages.isEmpty {
                        Text("无匹配「\(aiSearch)」的消息")
                            .font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(displayedMessages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                    if model.aiProcessing && !isSearching {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("思考中…")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .id("processing")
                    }
                }
                .padding(12)
            }
            .onChange(of: model.aiMessages.count) { _, _ in
                guard !isSearching, let last = model.aiMessages.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    // AI 运维提示词库（对齐 android A-Prompts）：分类常用运维提问
    private static let promptGroups: [(String, [String])] = [
        ("排障", ["帮我查看为什么网站打不开", "分析这段报错并给修复", "服务突然 502，怎么排查？", "数据库连接不上，帮我排查", "某个端口被占用，怎么定位是哪个进程？"]),
        ("部署", ["一键初始化 Ubuntu Web 服务器", "用 Docker 部署一个 Nginx + 静态站点", "配置 Let's Encrypt 免费 HTTPS 证书", "帮我写一个 Nginx 反向代理配置", "用 systemd 把我的程序配成开机自启服务"]),
        ("安全", ["检查这台服务器有哪些安全风险", "怎么加固 SSH 登录安全？", "查看最近的登录失败记录并判断是否被爆破", "配置防火墙只放行 22/80/443 端口", "排查是否有可疑的定时任务或异常进程"]),
        ("性能", ["服务器很卡，帮我找出占用资源最高的进程", "磁盘快满了，怎么安全清理？", "分析内存占用是否正常", "分析这个进程为什么 CPU 占用高", "磁盘 I/O 很高，帮我定位原因"]),
        ("日志", ["怎么查看 Nginx 最近的错误日志？", "用一条命令统计访问量 Top 10 IP", "解释这条命令：docker system prune -a", "从日志里找出最近的报错并归类", "实时跟踪某个服务的日志输出"])
    ]

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("用自然语言操作终端")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textPrimary)
            // 分类提示词
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(Self.promptGroups.enumerated()), id: \.offset) { idx, group in
                        Button { promptGroupIdx = idx } label: {
                            Text(group.0)
                                .font(.system(size: 12))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(promptGroupIdx == idx ? Theme.accent.opacity(0.3) : Theme.surfaceLight)
                                .foregroundStyle(promptGroupIdx == idx ? Theme.accent : Theme.textSecondary)
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }
            ForEach(Self.promptGroups[promptGroupIdx].1, id: \.self) { ex in
                Button {
                    guard !model.aiProcessing else { return }
                    input = ex
                    send()
                } label: {
                    Text("· \(ex)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }
            Button {
                model.showSettings = true
            } label: {
                if model.aiConfig.apiKey.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9))
                        Text("未配置 \(model.aiConfig.provider.displayName) API Key，点此设置")
                        Image(systemName: "chevron.right").font(.system(size: 8))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.warning)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu").font(.system(size: 9))
                        Text("当前：\(model.aiConfig.provider.displayName) · \(model.aiConfig.model)")
                        Image(systemName: "chevron.right").font(.system(size: 8))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
            .help(model.aiConfig.apiKey.isEmpty ? "未配置 API Key，点击打开设置" : "打开设置更改 AI 服务商 / 模型")
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("输入指令…", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(8)
                .background(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(Theme.textPrimary)
                .onSubmitShim { send() }
            if model.aiProcessing {
                Button {
                    model.cancelAIStreaming()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
                .help("停止生成")
            } else {
                // Z1：解释当前输入的命令（不执行，讲解作用/参数/风险/安全等级）
                Button {
                    let cmd = input
                    input = ""
                    model.explainCommand(cmd)
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(canSend ? Theme.warning : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help("解释这条命令（不执行）")
                // Z2：把当前输入当报错/日志分析（含义+原因+修复）
                Button {
                    let err = input
                    input = ""
                    model.analyzeError(err)
                } label: {
                    Image(systemName: "exclamationmark.magnifyingglass")
                        .font(.system(size: 21))
                        .foregroundStyle(canSend ? Theme.danger : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help("分析这段报错并给修复")
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(canSend ? Theme.accent : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding(10)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.aiProcessing
    }

    private func send() {
        guard canSend else { return }
        let text = input
        input = ""
        model.sendAIMessage(text)
    }
}

extension UTType {
    /// Markdown 文档类型（.md，符合纯文本）
    static var markdownDoc: UTType {
        UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
    }
}

/// 文本文件（用于导出 Markdown 等）
struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdownDoc, .plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private struct MessageBubble: View {
    @EnvironmentObject var model: AppModel
    let message: ChatMessage

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        let isUser = message.role == .user
        HStack {
            if isUser { Spacer(minLength: 24) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // 角色标签（AI 带小头像图标，对齐 android A-Avatar）
                HStack(spacing: 4) {
                    if !isUser {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.accent)
                    }
                    Text(isUser ? "你" : "AI")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                    // 发送时间（有 createdAt 时显 HH:mm）
                    if let t = message.createdAt {
                        Text(Self.timeFormatter.string(from: t))
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textSecondary.opacity(0.7))
                    }
                }
                bubbleContent
                    .padding(10)
                    .background(isUser ? Theme.surfaceLight : Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .contextMenu {
                        Button {
                            Self.copyToClipboard(message.content)
                            model.toast = "已复制"
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        // 用户消息：重发该问题
                        if message.role == .user && !model.aiProcessing {
                            Button {
                                model.sendAIMessage(message.content)
                            } label: { Label("重发", systemImage: "paperplane") }
                        }
                        if message.role == .assistant {
                            Button {
                                Self.copyToClipboard(displayText)
                                model.toast = "已复制纯文本"
                            } label: {
                                Label("复制纯文本", systemImage: "doc.plaintext")
                            }
                            // 知识沉淀：把这条 AI 回复存为知识卡片（有关联连接时）
                            if let connID = model.activeSession?.connection?.id.uuidString {
                                Button {
                                    _ = ServerNotebook.add(ServerNote(kind: .note, text: displayText), connectionID: connID)
                                    model.toast = "已存为知识卡片（笔记）"
                                } label: { Label("存为知识卡片", systemImage: "book.closed") }
                                Button {
                                    _ = ServerNotebook.add(ServerNote(kind: .solution, text: displayText), connectionID: connID)
                                    model.toast = "已存为方案"
                                } label: { Label("存为方案", systemImage: "bookmark") }
                            }
                        }
                    }
            }
            if !isUser { Spacer(minLength: 24) }
        }
    }

    private var displayText: String {
        message.role == .assistant
            ? AIService.strippedDisplayText(from: message.content)
            : message.content
    }

    /// 气泡正文：助手消息按 ``` 围栏拆出代码块，单独等宽深色框渲染（对齐 android A-Md）；用户消息纯文本。
    @ViewBuilder
    private var bubbleContent: some View {
        if message.role == .assistant && displayText.contains("```") {
            let parts = displayText.components(separatedBy: "```")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { idx, part in
                    if idx % 2 == 1 {
                        // 代码块：去掉可能的语言行
                        let code = Self.stripLangLine(part)
                        Text(code)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.success)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.black.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        let t = part.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !t.isEmpty {
                            Text(t).font(.system(size: 13)).foregroundStyle(Theme.textPrimary).textSelection(.enabled)
                        }
                    }
                }
            }
        } else {
            Text(displayText)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .textSelection(.enabled)
        }
    }

    /// 代码块去掉首行可能的语言标识（如 ```bash），返回纯代码。
    private static func stripLangLine(_ raw: String) -> String {
        let trimmed = raw.hasPrefix("\n") ? String(raw.dropFirst()) : raw
        if let nl = trimmed.firstIndex(of: "\n") {
            let first = trimmed[trimmed.startIndex..<nl].trimmingCharacters(in: .whitespaces)
            // 首行是单个词（语言名）→ 去掉
            if !first.isEmpty && !first.contains(" ") && first.count < 16 {
                return String(trimmed[trimmed.index(after: nl)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 复制文本到系统剪贴板（跨平台，共用 Clipboard）
    static func copyToClipboard(_ text: String) {
        Clipboard.copy(text)
    }
}

/// 跨平台 onSubmit（macOS 回车提交）封装
private extension View {
    @ViewBuilder
    func onSubmitShim(_ action: @escaping () -> Void) -> some View {
        self.onSubmit(of: .text, action)
    }
}
