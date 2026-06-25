#if os(macOS)
import SwiftUI
import AppKit
import AITerminalCore

/// 离屏截图工具：用 ImageRenderer 把界面渲染成 PNG，便于在无 Xcode 环境下做视觉检视。
/// 注意：不渲染会触发真实 SSH/本地 shell 的终端表示层，改用合成的「假终端」预览。
@MainActor
public enum AppScreenshots {
    public static func renderAll(to dirPath: String) {
        let dir = URL(fileURLWithPath: dirPath)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let model = makeSampleModel()
        let session = makeSampleSession(model)
        let info = session.systemInfo ?? SystemInfo()
        let statuses: [SessionStatus] = [.connected, .disconnected, .error]

        render(SidebarShowcase(connections: model.connections, statuses: statuses)
            .frame(width: 280, height: 460), dir, "01-sidebar")
        render(StatusBarShowcase(info: info, expanded: true)
            .frame(width: 820, height: 130), dir, "02-statusbar")
        // Z6 富状态面板（含磁盘/服务/健康摘要告警）
        var richInfo = info
        richInfo.diskTotal = 85_899_345_920; richInfo.diskUsed = 78_000_000_000  // ~91% 触发告警
        richInfo.services = ["nginx": true, "docker": true, "mysql": false, "redis": true, "sshd": true]
        richInfo.cpuSeen = true
        render(ServerStatusShowcase(info: richInfo)
            .frame(width: 420, height: 360), dir, "21-server-status")
        // N-Multi 批量群发界面
        let batchOutcomes = [
            BatchOutcome(name: "生产 Web 01", output: "nginx restarted", ok: true),
            BatchOutcome(name: "生产 Web 02", output: "nginx restarted", ok: true),
            BatchOutcome(name: "数据库主机", output: "⚠️ unit not found", ok: false),
        ]
        render(BatchShowcase(connections: Array(model.connections.prefix(3)), outcomes: batchOutcomes)
            .frame(width: 440, height: 540), dir, "22-batch")
        render(AIPanelShowcase(messages: model.aiMessages)
            .frame(width: 380, height: 520), dir, "03-ai-panel")
        render(AIPanelShowcase(messages: Array(model.aiMessages.prefix(1)), processing: true)
            .frame(width: 380, height: 360), dir, "15-ai-stop")
        render(AIPanelShowcase(messages: model.aiMessages, searching: true)
            .frame(width: 380, height: 420), dir, "19-ai-search")
        render(AIPanelShowcase(messages: [])
            .frame(width: 380, height: 360), dir, "20-ai-empty")
        render(ConnectionEditShowcase(conn: model.connections[1])
            .frame(width: 480, height: 1140), dir, "04-connection-edit")
        render(SettingsShowcase()
            .frame(width: 480, height: 1220), dir, "05-settings")
        render(KeyBarShowcase()
            .frame(width: 820, height: 50), dir, "06-keybar")
        // 加几个不同风险等级的示例片段，展示 Z7 四级风险颜色徽章
        let riskDemo = CommandSnippet.defaults + [
            CommandSnippet(title: "编辑 Nginx 配置", command: "vim /etc/nginx/nginx.conf", group: "系统"),
            CommandSnippet(title: "重启 Nginx", command: "systemctl restart nginx", group: "系统"),
            CommandSnippet(title: "清理日志", command: "rm -rf /var/log/*.log", group: "系统")
        ]
        render(SnippetsShowcase(snippets: riskDemo)
            .frame(width: 480, height: 720), dir, "08-snippets")
        render(SFTPShowcase()
            .frame(width: 480, height: 560), dir, "09-sftp")
        render(SFTPShowcase(dropHint: true)
            .frame(width: 480, height: 560), dir, "17-sftp-drop")
        render(SearchBarShowcase()
            .frame(width: 720, height: 260), dir, "13-search")
        render(PortForwardShowcase()
            .frame(width: 480, height: 480), dir, "14-portforward")
        render(KnownHostsShowcase()
            .frame(width: 480, height: 360), dir, "16-known-hosts")
        render(QRShowcase(connection: model.connections[0])
            .frame(width: 380, height: 400), dir, "18-qr")
        render(ShowcaseMainView(model: model, session: session, info: info)
            .frame(width: 1180, height: 720), dir, "07-main-overview")
        render(SettingsShowcase()
            .frame(width: 480, height: 1220), dir, "05-settings")

        // 多主题对比（设置全局配色后渲染主界面）
        activeColorScheme = .dracula
        render(ShowcaseMainView(model: model, session: session, info: info)
            .frame(width: 1180, height: 720), dir, "10-theme-dracula")
        activeColorScheme = .nord
        render(ShowcaseMainView(model: model, session: session, info: info)
            .frame(width: 1180, height: 720), dir, "11-theme-nord")
        activeColorScheme = .midnight

        render(ShowcaseSplitView()
            .frame(width: 1180, height: 600), dir, "12-split")

        renderAppIcon()

        print("Rendered screenshots to \(dirPath)")
    }

    /// 渲染 1024×1024 App 图标，写入 Assets.xcassets/AppIcon.appiconset/icon-1024.png（相对 CWD）。
    static func renderAppIcon() {
        let renderer = ImageRenderer(content: AppIconView().frame(width: 1024, height: 1024))
        renderer.scale = 1
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        let cwd = FileManager.default.currentDirectoryPath
        let iconDir = URL(fileURLWithPath: cwd)
            .appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
        if FileManager.default.fileExists(atPath: iconDir.path) {
            try? png.write(to: iconDir.appendingPathComponent("icon-1024.png"))
            print("Wrote app icon to \(iconDir.path)/icon-1024.png")
        }
    }

    /// SSH config 解析自测（运行时验证 SSHConfigParser 逻辑）
    public static func sshConfigTest() -> String {
        let sample = """
        # 注释行
        Host prod
            HostName 192.168.1.10
            User root
            Port 2222

        Host dev gh
            HostName dev.example.com
            User deploy
            IdentityFile ~/.ssh/id_ed25519

        Host *
            ServerAliveInterval 60
        """
        let conns = SSHConfigParser.parse(sample)
        var lines = ["解析出 \(conns.count) 个连接:"]
        for c in conns {
            lines.append("  \(c.name): \(c.username)@\(c.host):\(c.port) auth=\(c.authType.rawValue) key=\(c.privateKeyPath)")
        }
        return lines.joined(separator: "\n")
    }

    /// 连接交换格式 group 往返自测（export→parse 保留分组）
    public static func portabilityTest() -> String {
        let conns = [
            Connection(name: "生产", host: "10.0.0.1", port: 22, username: "root", authType: .password, group: "生产环境", startupCommands: "cd /var/www\nsource venv/bin/activate", fontSizeOverride: 15, note: "数据库主库"),
            Connection(name: "无组", host: "10.0.0.2", port: 2200, username: "dev", authType: .privateKey)
        ]
        let data = ConnectionPortability.export(conns)
        let json = String(data: data, encoding: .utf8) ?? ""
        let parsed = (try? ConnectionPortability.parse(data)) ?? []
        var lines = [
            "导出含 group: \(json.contains("\"group\"")) / startupCommands: \(json.contains("startupCommands"))"
        ]
        for c in parsed {
            lines.append("  \(c.name)@\(c.host) group=\(c.group ?? "<nil>") 启动命令行数=\(c.startupCommandLines.count) 字号=\(c.fontSizeOverride.map { String(Int($0)) } ?? "<nil>") 备注=\(c.noteText.isEmpty ? "<nil>" : c.noteText)")
        }
        return lines.joined(separator: "\n")
    }

    /// 可达性探测自测（本机闭合端口应返回不可达；空 host 也不可达）
    nonisolated public static func reachTest() async -> String {
        let closed = await ReachabilityChecker.probe(host: "127.0.0.1", port: 1, timeout: 2)
        let empty = await ReachabilityChecker.probe(host: "", port: 22, timeout: 2)
        return "127.0.0.1:1 可达=\(closed)（应为 false）\n空 host 可达=\(empty)（应为 false）"
    }

    /// AI 对话持久化自测（保存→新 store 加载→比对；清空验证）
    public static func aiPersistTest() -> String {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("aiterm-persist-test", isDirectory: true)
        try? FileManager.default.removeItem(at: tmp)
        let store1 = ConnectionStore(directory: tmp)
        let conv = AIConversation(messages: [
            ChatMessage(role: .user, content: "你好"),
            ChatMessage(role: .assistant, content: "世界 [EXECUTE]ls[/EXECUTE]")
        ])
        store1.saveConversations([conv])
        let loaded = ConnectionStore(directory: tmp).loadConversations().first?.messages ?? []
        let match = loaded.count == 2 && loaded.first?.content == "你好" && (loaded.last?.content.contains("世界") ?? false)
        store1.saveConversations([])
        let afterClear = ConnectionStore(directory: tmp).loadConversations()
        try? FileManager.default.removeItem(at: tmp)
        return "保存→加载 条数=\(loaded.count) 内容匹配=\(match)；清空后会话数=\(afterClear.count)（应为 0）"
    }

    /// AI 多对话自测（建两个会话→各加消息→保存→加载比对→删一个）
    public static func aiConvTest() -> String {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("aiterm-conv-test", isDirectory: true)
        try? FileManager.default.removeItem(at: tmp)
        let store = ConnectionStore(directory: tmp)
        var c1 = AIConversation(messages: [ChatMessage(role: .user, content: "会话一问题")])
        c1.title = c1.derivedTitle
        var c2 = AIConversation(messages: [ChatMessage(role: .user, content: "会话二问题")])
        c2.title = c2.derivedTitle
        store.saveConversations([c1, c2])
        let loaded = ConnectionStore(directory: tmp).loadConversations()
        let ok = loaded.count == 2 && loaded.first?.title == "会话一问题" && loaded.last?.title == "会话二问题"
        // 删一个
        store.saveConversations([c2])
        let afterDelete = ConnectionStore(directory: tmp).loadConversations()
        // 自定义标题：手动命名后加新用户消息，标题不应被 derivedTitle 覆盖
        var custom = AIConversation(messages: [ChatMessage(role: .user, content: "原问题")])
        custom.title = "我的项目"
        custom.titleIsCustom = true
        custom.updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        store.saveConversations([custom])
        let reloadedCustom = ConnectionStore(directory: tmp).loadConversations().first
        let customOK = reloadedCustom?.title == "我的项目" && reloadedCustom?.isCustomTitle == true && reloadedCustom?.updatedAt != nil
        // 旧 ai_messages.json 迁移测试
        try? FileManager.default.removeItem(at: tmp.appendingPathComponent("conversations.json"))
        if let data = try? JSONEncoder().encode([ChatMessage(role: .user, content: "旧单对话")]) {
            try? data.write(to: tmp.appendingPathComponent("ai_messages.json"))
        }
        let migrated = ConnectionStore(directory: tmp).loadConversations()
        try? FileManager.default.removeItem(at: tmp)
        return "保存→加载 会话数=\(loaded.count) 标题正确=\(ok)；删除后=\(afterDelete.count)（应为 1）；自定义标题保留+updatedAt=\(customOK)；旧版迁移会话数=\(migrated.count) 首条标题=\(migrated.first?.title ?? "<nil>")"
    }

    /// AI 对话 Markdown 导出自测
    public static func aiMarkdownTest() -> String {
        let model = makeSampleModel()
        return String(decoding: model.exportAIConversationMarkdown(), as: UTF8.self)
    }

    /// 部署模板自测（Z8）：内置模板 + 步骤 + 预览 + 风险标注
    public static func templateTest() -> String {
        let builtins = SetupTemplate.builtins
        guard let ubuntu = builtins.first(where: { $0.id == "ubuntu-web" }) else { return "缺 ubuntu-web 模板" }
        let preview = ubuntu.previewText()
        let ok = builtins.count >= 5
            && ubuntu.steps.count == 10
            && ubuntu.allCommands.contains("apt update")
            && ubuntu.risk == .high  // 含 systemctl restart sshd / ufw 等高风险（初始化模板不含极高危）
            && preview.contains("即将执行模板「Ubuntu Web 服务器初始化」")
            && preview.contains("$ apt update")
            && preview.contains("预计影响")
        return "内置模板数=\(builtins.count)；ubuntu 步骤=\(ubuntu.steps.count) 风险=\(ubuntu.risk.label)；预览格式正确=\(ok)"
    }

    /// 批量群发自测（N-Multi）：并发执行（mock runner）+ 顺序聚合 + 统计 + AI 素材
    public static func batchTest() async -> String {
        let targets = ["web-01", "web-02", "db-01"]
        let outcomes = await BatchRunner.run(targets, name: { $0 }) { t in
            // mock：db-01 失败，其余成功
            if t == "db-01" { return ("connection refused", false) }
            return ("ok on \(t)", true)
        }
        let orderOk = outcomes.map { $0.name } == targets   // 保持输入顺序
        let (ok, fail) = BatchRunner.summary(outcomes)
        let statOk = ok == 2 && fail == 1
        let material = BatchRunner.composeForAI(command: "uptime", outcomes)
        let materialOk = material.contains("3 台") && material.contains("【db-01】失败")
        return "顺序聚合=\(orderOk)；统计 成功\(ok)/失败\(fail)=\(statOk)；AI 素材正确=\(materialOk)"
    }

    /// 命令历史自测（N-History）：去重/置顶/限长
    public static func historyTest() -> String {
        var h: [String] = []
        h = CommandHistory.updated(h, adding: "ls")
        h = CommandHistory.updated(h, adding: "df -h")
        h = CommandHistory.updated(h, adding: "ls")          // 重复→去重置顶
        h = CommandHistory.updated(h, adding: "  ")          // 空→忽略
        let dedupOk = h == ["ls", "df -h"]
        // 限长
        var big: [String] = []
        for i in 0..<60 { big = CommandHistory.updated(big, adding: "cmd\(i)", limit: 50) }
        let capOk = big.count == 50 && big.first == "cmd59" && big.last == "cmd10"
        return "去重置顶=\(dedupOk)；限长=\(capOk)"
    }

    /// 服务器状态面板解析自测（Z6）：验证 RemoteSystemMonitor.parse 解析 disk/服务/健康摘要
    public static func metricsTest() -> String {
        let fake = """
        HOST@@web-01
        CORES@@4
        UPTIME@@10 days
        LOAD@@0.50 0.40 0.30
        MEM@@8000000 2000000
        CPU@@9000 10000
        DISK@@85899345920 36507222016
        SVC@@nginx:active
        SVC@@docker:active
        SVC@@mysql:inactive
        SVC@@redis:active
        SVC@@sshd:active
        """
        let info = RemoteSystemMonitor.parse(fake, previousCPU: (idle: 8000, total: 9000)).info
        let ok = info.hostname == "web-01"
            && info.diskTotal == 85_899_345_920 && info.diskUsed == 36_507_222_016
            && Int(info.diskPercent) == 42
            && info.services["nginx"] == true && info.services["mysql"] == false
            && info.stoppedServices == ["mysql"]
            && info.hasWarning
            && info.healthSummary.contains("未运行 mysql")
        return "解析正确=\(ok)；健康摘要=「\(info.healthSummary)」"
    }

    /// 命令风险分级 + 脱敏自测（Z7）
    public static func riskTest() -> String {
        func r(_ c: String) -> CommandRisk { CommandRisk.riskLevel(c) }
        let levels = r("ls -la") == .low
            && r("cat /etc/hosts") == .low
            && r("vim app.js") == .medium
            && r("cp a b") == .medium
            && r("systemctl restart nginx") == .high
            && r("ufw allow 80") == .high
            && r("rm -rf /") == .critical
            && r("mkfs.ext4 /dev/sdb") == .critical
            && r("iptables -F") == .critical
        // isDangerous 兼容（high/critical 才 true）
        let compat = AIService.isDangerous("rm -rf /") && AIService.isDangerous("systemctl restart nginx")
            && !AIService.isDangerous("ls -la")
        // 脱敏
        let red = Redactor.redact("DB_PASSWORD=supersecret123\nAPI_TOKEN: abcdEFGH1234\nnormal text\nuse sk-ABCDEFGHIJKL1234\nAuthorization: Bearer xyz12345678")
        let redacted = red.contains("DB_PASSWORD=******") && red.contains("API_TOKEN: ******")
            && red.contains("normal text") && red.contains("sk-******") && red.contains("Bearer ******")
            && !red.contains("supersecret123") && !red.contains("abcdEFGH1234")
        return "风险分级正确=\(levels)；isDangerous 兼容=\(compat)；脱敏正确=\(redacted)"
    }

    /// 操作回滚自测（Z5）：验证关键配置识别 + 备份命令 + 回滚命令 + sshd 自动回滚
    public static func rollbackTest() -> String {
        let critical = OpRollback.isCriticalConfig("/etc/nginx/nginx.conf")
        let notCritical = OpRollback.isCriticalConfig("/home/user/app.js")
        let targets = OpRollback.criticalTargets(in: "vim /etc/nginx/nginx.conf")
        let safeTargets = OpRollback.criticalTargets(in: "cat /etc/nginx/nginx.conf")  // 只读不该命中
        let backup = OpRollback.backupCommand(for: "/etc/ssh/sshd_config", stamp: "20260625-200000")
        let entry = OpTimelineEntry(time: Date(), action: "改 nginx", command: "vim /etc/nginx/nginx.conf",
                                    rollbackable: true, backupPath: "/etc/nginx/nginx.conf.bak-20260625-200000")
        let rb = entry.rollbackCommand
        let ssh = OpRollback.sshAutoRollbackCommand(minutes: 5, stamp: "20260625-200000")
        let ok = critical && !notCritical
            && targets == ["/etc/nginx/nginx.conf"] && safeTargets.isEmpty
            && backup == "cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak-20260625-200000"
            && rb == "cp /etc/nginx/nginx.conf.bak-20260625-200000 /etc/nginx/nginx.conf"
            && ssh.contains("at now + 5 minutes") && ssh.contains("systemctl restart sshd")
        return "关键配置识别+备份+回滚+sshd自动回滚 全部正确=\(ok)"
    }

    /// 排障工作流自测（Z4）：验证内置工作流 + composeForAI 拼装格式
    public static func diagTest() -> String {
        let builtins = DiagnosticWorkflow.builtins
        guard let web = builtins.first(where: { $0.id == "web-down" }) else { return "缺 web-down 工作流" }
        let composed = web.composeForAI(outputs: [
            "nginx -t": "nginx: configuration file test failed"
        ])
        let ok = builtins.count >= 5
            && web.commands.contains("nginx -t")
            && composed.contains("【排障工作流：网站打不开排查】")
            && composed.contains("$ nginx -t")
            && composed.contains("configuration file test failed")
            && composed.contains("(未获取到输出)")  // 未提供输出的命令占位
        return "内置工作流数=\(builtins.count)；composeForAI 格式正确=\(ok)"
    }

    /// 环境感知解析自测（Z3）：用假的探测输出验证 parse → ServerProfile
    public static func envDetectTest() -> String {
        let fake = """
        HOST:web-01
        UNAME:Linux 5.15.0-89-generic x86_64
        USER:deploy 1000
        OSREL:NAME="Ubuntu"
        OSREL:PRETTY_NAME="Ubuntu 22.04.3 LTS"
        OSREL:VERSION_ID="22.04"
        PM:apt
        SVC:nginx:1
        SVC:docker:1
        SVC:node:0
        SVC:mysql:1
        SVC:redis:0
        """
        let p = EnvDetector.parse(fake)
        let ok = p.hostname == "web-01" && p.os == "Linux" && p.arch == "x86_64"
            && p.distro == "Ubuntu 22.04.3 LTS" && p.currentUser == "deploy" && !p.isRoot
            && p.packageManager == "apt"
            && p.services["nginx"] == true && p.services["node"] == false
        return "解析正确=\(ok)；摘要=「\(p.aiSummary)」"
    }

    /// 导出全部会话 Markdown 自测（2 会话各有消息）
    public static func aiMarkdownAllTest() -> String {
        let model = AppModel()
        model.conversations = [
            AIConversation(title: "项目A", messages: [
                ChatMessage(role: .user, content: "问题A"),
                ChatMessage(role: .assistant, content: "答A [EXECUTE]ls[/EXECUTE]")
            ]),
            AIConversation(title: "项目B", messages: [
                ChatMessage(role: .user, content: "问题B"),
                ChatMessage(role: .assistant, content: "答B")
            ])
        ]
        let md = String(decoding: model.exportAllConversationsMarkdown(), as: UTF8.self)
        let hasA = md.contains("# 对话：项目A")
        let hasB = md.contains("# 对话：项目B")
        let hasBash = md.contains("```bash")
        let hasSep = md.contains("\n---\n")
        return "全部导出: 含项目A=\(hasA) 含项目B=\(hasB) 含bash块=\(hasBash) 含分隔=\(hasSep)"
    }

    // MARK: 样例数据

    static func makeSampleModel() -> AppModel {
        let model = AppModel()
        model.connections = [
            Connection(name: "生产服务器", host: "192.168.1.10", port: 22, username: "root", authType: .password, group: "生产"),
            Connection(name: "开发机", host: "dev.example.com", port: 2222, username: "deploy", authType: .privateKey),
            // 数据库主机「最近使用」→ 在「生产」分组内排到生产服务器之前 + 显示相对时间 + 备注
            Connection(name: "数据库主机", host: "db.internal.net", port: 22, username: "admin", authType: .password, group: "生产", lastUsedAt: Date().addingTimeInterval(-300), note: "数据库主库")
        ]
        model.aiMessages = [
            ChatMessage(role: .user, content: "列出当前目录文件并查看内存"),
            ChatMessage(role: .assistant, content: "好的，我来执行：\n[EXECUTE]ls -la[/EXECUTE]\n[EXECUTE]free -h[/EXECUTE]\n命令已在终端执行，请查看结果。")
        ]
        return model
    }

    static func makeSampleSession(_ model: AppModel) -> TerminalSessionVM {
        let session = TerminalSessionVM(local: false, connection: model.connections[0])
        session.status = .connected
        session.statusMessage = "已连接"
        var info = SystemInfo()
        info.hostname = "prod-01"
        info.cpuUsage = 47
        info.cpuCores = 8
        info.memTotal = 16 * 1024 * 1024 * 1024
        info.memUsed = 9 * 1024 * 1024 * 1024
        info.loadavg = [0.82, 0.65, 0.51]
        info.uptime = "12天3时"
        session.systemInfo = info
        return session
    }

    static func render<V: View>(_ view: V, _ dir: URL, _ name: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("FAILED: \(name)")
            return
        }
        try? png.write(to: dir.appendingPathComponent("\(name).png"))
    }
}

/// 合成的主界面预览（侧边栏 + 假终端 + 状态栏 + AI 面板），避免真实终端副作用。
private struct ShowcaseMainView: View {
    let model: AppModel
    let session: TerminalSessionVM
    let info: SystemInfo

    var body: some View {
        HStack(spacing: 0) {
            SidebarShowcase(connections: model.connections, statuses: [.connected, .disconnected, .error])
                .frame(width: 260)
            Divider().overlay(Theme.surfaceLight)
            VStack(spacing: 0) {
                tabBar
                StatusBarShowcase(info: info)
                Divider().overlay(Theme.surfaceLight)
                FakeTerminal()
            }
            Divider().overlay(Theme.surfaceLight)
            AIPanelShowcase(messages: model.aiMessages)
                .frame(width: 340)
        }
        .background(Theme.background)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(Theme.success).frame(width: 7, height: 7)
                Text("生产服务器").font(.caption).foregroundStyle(Theme.textPrimary)
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Theme.surfaceLight)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.surface)
    }
}

/// 分屏预览：两个会话并排，各带小标题。
private struct ShowcaseSplitView: View {
    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            HStack(spacing: 6) {
                tab("生产服务器", active: true)
                tab("开发机", active: false)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 6).background(Theme.surface)
            GeometryReader { geo in
                let leftW = (geo.size.width - 6) * 0.62   // 拖拽后非等分示意
                HStack(spacing: 0) {
                    pane("root@prod-01", Theme.success).frame(width: leftW)
                    // 可拖拽分隔条 + 把手
                    Rectangle().fill(Theme.surfaceLight)
                        .frame(width: 6)
                        .overlay(Capsule().fill(Theme.textSecondary.opacity(0.6)).frame(width: 2, height: 26))
                    pane("deploy@dev", Theme.warning)
                }
            }
        }
        .background(Theme.background)
    }
    private func tab(_ t: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(active ? Theme.success : Theme.textSecondary).frame(width: 7, height: 7)
            Text(t).font(.caption).foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
            Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(active ? Theme.surfaceLight : Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(active ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1))
    }
    private func pane(_ host: String, _ dot: Color) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(dot).frame(width: 6, height: 6)
                Text(host).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 4).background(Theme.surface)
            FakeTerminal()
        }
    }
}

/// 假终端：展示配色与提示符，不启动真实进程。
private struct FakeTerminal: View {
    private let lines: [(String, Color)] = [
        ("Last login: Sun Jun 22 19:00 on ttys001", Theme.textSecondary),
        ("root@prod-01:~$ ls -la", Theme.textPrimary),
        ("total 32", Theme.textSecondary),
        ("drwxr-xr-x  6 root root 4096 Jun 22 18:00 .", Color(hex: "#61afef")),
        ("drwxr-xr-x 18 root root 4096 Jun 10 09:12 ..", Color(hex: "#61afef")),
        ("-rw-r--r--  1 root root  220 Jun 10 09:12 .bashrc", Theme.textPrimary),
        ("-rwxr-xr-x  1 root root 1024 Jun 22 17:30 deploy.sh", Color(hex: "#98c379")),
        ("root@prod-01:~$ ▎", Theme.success)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line.0)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(line.1)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color(hex: "#1a1a2e"))
    }
}
#endif
