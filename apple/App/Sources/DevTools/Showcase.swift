#if os(macOS)
import SwiftUI
import AITerminalCore

// 截图用的高保真预览（纯布局，避开 List/Form/ScrollView/TextField —— 它们无法离屏渲染）。
// 与真实视图共用 Theme / 字体 / 图标，用于视觉检视与设计打磨。

// MARK: 通用 mock 控件

private struct MockField: View {
    let label: String
    let value: String
    var secure = false
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            HStack {
                Text(secure ? String(repeating: "•", count: max(6, value.count)) : value)
                    .font(.system(size: 13))
                    .foregroundStyle(value.isEmpty ? Theme.textSecondary : Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.surfaceLight, lineWidth: 1))
        }
    }
}

private struct MockSegmented: View {
    let options: [String]
    let selected: Int
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, opt in
                Text(opt)
                    .font(.system(size: 12, weight: i == selected ? .semibold : .regular))
                    .foregroundStyle(i == selected ? Theme.textPrimary : Theme.textSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(i == selected ? Theme.surfaceLight : Color.clear)
            }
        }
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MockToggle: View {
    let label: String
    let on: Bool
    var body: some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
            Spacer()
            Capsule().fill(on ? Theme.success : Theme.surfaceLight)
                .frame(width: 38, height: 22)
                .overlay(Circle().fill(.white).padding(2), alignment: on ? .trailing : .leading)
        }
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: 侧边栏

struct SidebarShowcase: View {
    let connections: [Connection]
    let statuses: [SessionStatus]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("AI Terminal").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.textPrimary)
                .padding(16)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Text("搜索连接").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Theme.background).clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 10).padding(.bottom, 8)

            Text("本地").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 16).padding(.bottom, 6)
            HStack(spacing: 10) {
                Image(systemName: "laptopcomputer").foregroundStyle(Theme.accent)
                Text("新建本地终端").font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                Spacer()
            }.padding(.horizontal, 16).padding(.vertical, 8)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("SSH 连接").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                    Text("(\(connections.count))").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.arrow.down").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Image(systemName: "arrow.clockwise").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
            }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)

            // 未分组（按最近使用排序）
            ForEach(SidebarView.sortedByRecent(connections.filter { $0.groupName.isEmpty })) { conn in
                connRow(conn, active: false)
            }
            // 分组（组内按最近使用排序）
            ForEach(groupNames, id: \.self) { g in
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down").font(.system(size: 9)).foregroundStyle(Theme.textSecondary)
                    Image(systemName: "folder").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                    Text(g).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
                ForEach(SidebarView.sortedByRecent(connections.filter { $0.groupName == g })) { conn in
                    connRow(conn, active: conn.lastUsedAt != nil)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.surface)
    }

    private var groupNames: [String] {
        Array(Set(connections.compactMap { $0.groupName.isEmpty ? nil : $0.groupName })).sorted()
    }

    private func connRow(_ conn: Connection, active: Bool) -> some View {
        HStack(spacing: 10) {
            // 连接颜色标签色条
            if let hex = conn.colorTag?.hex {
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: hex)).frame(width: 3, height: 30)
            }
            Circle().fill(active ? Theme.success : Theme.textSecondary).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(conn.title).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textPrimary)
                Text(conn.subtitle).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                if !conn.noteText.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "note.text").font(.system(size: 9))
                        Text(conn.noteText).lineLimit(1)
                    }.font(.system(size: 10)).foregroundStyle(Theme.textSecondary.opacity(0.85))
                }
                if conn.lastUsedAt != nil {
                    Text("上次使用 · 5 分钟前").font(.system(size: 10)).foregroundStyle(Theme.textSecondary.opacity(0.8))
                }
            }
            Spacer()
            // 可达性指示（mock：数据库主机可达、生产服务器不可达）
            if conn.title.contains("数据库") {
                Image(systemName: "wifi").font(.system(size: 11)).foregroundStyle(Theme.success)
            } else if conn.title.contains("生产服务器") {
                Image(systemName: "wifi.slash").font(.system(size: 11)).foregroundStyle(Theme.danger)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(active ? Theme.surfaceLight.opacity(0.5) : Color.clear)
    }
}

// MARK: 状态栏

struct StatusBarShowcase: View {
    let info: SystemInfo
    var expanded: Bool = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                item("circle.fill", "状态", "已连接", Theme.success)
                item("note.text", "备注", "数据库主库")
                item("desktopcomputer", "主机", info.hostname)
                metric("bolt.fill", "CPU", "\(Int(info.cpuUsage))%", info.cpuUsage, info.cpuUsage > 80)
                metric("memorychip", "内存", "\(formatBytes(info.memUsed)) / \(formatBytes(info.memTotal))", info.memPercent, info.memPercent > 80)
                item("chart.bar.fill", "负载", info.loadavg.map { String(format: "%.2f", $0) }.joined(separator: " "))
                item("clock", "运行", info.uptime)
                Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            if expanded {
                Rectangle().fill(Theme.surfaceLight).frame(height: 0.5)
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 10) {
                    detail("主机", info.hostname)
                    detail("运行时长", info.uptime)
                    detail("CPU", String(format: "%.1f%% · %d 核", info.cpuUsage, info.cpuCores))
                    detail("内存", String(format: "%@ / %@ (%.0f%%)", formatBytes(info.memUsed), formatBytes(info.memTotal), info.memPercent))
                    detail("负载 1 / 5 / 15 分钟", info.loadavg.map { String(format: "%.2f", $0) }.joined(separator: " / "))
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .background(Theme.surface)
    }
    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func item(_ icon: String, _ label: String, _ value: String, _ tint: Color = Theme.textSecondary) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(tint)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            Text(value).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textPrimary)
        }
    }
    private func metric(_ icon: String, _ label: String, _ value: String, _ pct: Double, _ warn: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(warn ? Theme.danger : Theme.textSecondary)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            Text(value).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textPrimary)
            Capsule().fill(Theme.surfaceLight).frame(width: 50, height: 4)
                .overlay(alignment: .leading) {
                    Capsule().fill(warn ? Theme.danger : Theme.accent).frame(width: 50 * min(pct, 100) / 100, height: 4)
                }
        }
    }
}

// MARK: 服务器状态面板（Z6）

/// 富状态面板：健康摘要条 + CPU/内存/磁盘进度条 + 关键服务状态。
struct ServerStatusShowcase: View {
    let info: SystemInfo
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部健康摘要条（有告警整条警示色）
            HStack(spacing: 8) {
                Image(systemName: info.hasWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(info.hasWarning ? Theme.danger : Theme.success)
                Text(info.hasWarning ? "发现异常" : "运行正常")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(info.hasWarning ? Theme.danger : Theme.success)
                Spacer()
                Text(info.hostname).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.textSecondary)
            }
            .padding(10)
            .background((info.hasWarning ? Theme.danger : Theme.success).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // 三大资源进度条
            bar("cpu", "CPU", info.cpuSeen ? "\(Int(info.cpuUsage))%" : "—", info.cpuUsage, info.cpuUsage > 85)
            bar("memorychip", "内存", String(format: "%@ / %@", formatBytes(info.memUsed), formatBytes(info.memTotal)), info.memPercent, info.memPercent > 85)
            bar("internaldrive", "磁盘", String(format: "%@ / %@", formatBytes(info.diskUsed), formatBytes(info.diskTotal)), info.diskPercent, info.diskPercent > 85)

            // 关键服务
            Text("关键服务").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 14) {
                ForEach(info.services.keys.sorted(), id: \.self) { svc in
                    HStack(spacing: 5) {
                        Circle().fill(info.services[svc] == true ? Theme.success : Theme.danger).frame(width: 8, height: 8)
                        Text(svc).font(.system(size: 12)).foregroundStyle(Theme.textPrimary)
                    }
                }
            }
            // 负载 + 运行时长
            HStack(spacing: 18) {
                detailInline("负载", info.loadavg.map { String(format: "%.2f", $0) }.joined(separator: " / "))
                detailInline("运行", info.uptime)
            }
        }
        .padding(16)
        .background(Theme.surface)
    }
    private func bar(_ icon: String, _ label: String, _ value: String, _ pct: Double, _ warn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(warn ? Theme.danger : Theme.accent)
                Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(value).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textSecondary)
                Text("\(Int(pct))%").font(.system(size: 11, weight: .semibold)).foregroundStyle(warn ? Theme.danger : Theme.textPrimary)
            }
            Capsule().fill(Theme.surfaceLight).frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule().fill(warn ? Theme.danger : Theme.accent)
                            .frame(width: geo.size.width * min(pct, 100) / 100)
                    }
                }
        }
    }
    private func detailInline(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(Theme.textPrimary)
        }
    }
}

// MARK: AI 面板

struct AIPanelShowcase: View {
    let messages: [ChatMessage]
    var processing: Bool = false
    var searching: Bool = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").foregroundStyle(Theme.accent)
                HStack(spacing: 4) {
                    Text("列出当前目录文件…").font(.headline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: searching ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .foregroundStyle(searching ? Theme.accent : Theme.textSecondary)
                if !processing {
                    Image(systemName: "arrow.clockwise").foregroundStyle(Theme.textSecondary)
                }
                Image(systemName: "square.and.arrow.up").foregroundStyle(Theme.textSecondary)
                Image(systemName: "trash").foregroundStyle(Theme.textSecondary)
            }.padding(12)
            Rectangle().fill(Theme.surfaceLight).frame(height: 0.5)
            if searching {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    Text("内存").font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 8).background(Theme.surface)
                Rectangle().fill(Theme.surfaceLight).frame(height: 0.5)
            }

            VStack(alignment: .leading, spacing: 10) {
                if messages.isEmpty {
                    Text("用自然语言操作终端").font(.subheadline.bold()).foregroundStyle(Theme.textPrimary)
                    // AI 提示词库分类（对齐 android A-Prompts）
                    HStack(spacing: 6) {
                        ForEach(["排障", "部署", "安全", "性能", "日志"], id: \.self) { cat in
                            Text(cat).font(.system(size: 12))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(cat == "排障" ? Theme.accent.opacity(0.3) : Theme.surfaceLight)
                                .foregroundStyle(cat == "排障" ? Theme.accent : Theme.textSecondary)
                                .clipShape(Capsule())
                        }
                    }
                    ForEach(["帮我查看为什么网站打不开", "分析这段报错并给修复", "服务突然 502，怎么排查？"], id: \.self) { ex in
                        Text("· \(ex)").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "cpu").font(.system(size: 9))
                        Text("当前：Anthropic Claude · claude-opus-4-8")
                        Image(systemName: "chevron.right").font(.system(size: 8))
                    }
                    .font(.system(size: 10)).foregroundStyle(Theme.textSecondary.opacity(0.8)).padding(.top, 2)
                }
                ForEach(messages) { msg in bubble(msg) }
                if processing {
                    HStack(spacing: 6) {
                        Image(systemName: "ellipsis").foregroundStyle(Theme.accent)
                        Text("思考中…").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // 快捷追问 + 存为方案（末条 assistant 且非处理/搜索时，对齐真实视图）
            if !messages.isEmpty && !processing && !searching && messages.last?.role == .assistant {
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 10)); Text("重新生成").font(.system(size: 12))
                    }.padding(.horizontal, 10).padding(.vertical, 5).background(Theme.surfaceLight).foregroundStyle(Theme.textPrimary).clipShape(Capsule())
                    HStack(spacing: 3) {
                        Image(systemName: "bookmark").font(.system(size: 10)); Text("存为方案").font(.system(size: 12))
                    }.padding(.horizontal, 10).padding(.vertical, 5).background(Theme.success.opacity(0.15)).foregroundStyle(Theme.success).clipShape(Capsule())
                    ForEach(["给我具体命令", "换个思路"], id: \.self) { q in
                        Text(q).font(.system(size: 12)).padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.surfaceLight).foregroundStyle(Theme.textSecondary).clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
            }
            Rectangle().fill(Theme.surfaceLight).frame(height: 0.5)
            HStack(spacing: 8) {
                Text("输入指令…").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                Spacer()
                // 生成中显示红色「停止」，否则蓝色「发送」
                Image(systemName: processing ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(processing ? Theme.danger : Theme.accent)
            }
            .padding(10).background(Theme.background).clipShape(RoundedRectangle(cornerRadius: 8)).padding(10)
        }
        .background(Theme.surface)
    }
    private func bubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == .user
        let text = AIService.strippedDisplayText(from: msg.content)
        return HStack {
            if isUser { Spacer(minLength: 24) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if !isUser { Image(systemName: "sparkles").font(.system(size: 9)).foregroundStyle(Theme.accent) }
                    Text(isUser ? "你" : "AI").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textSecondary)
                }
                bubbleBody(text, isUser: isUser)
                    .padding(10).background(isUser ? Theme.surfaceLight : Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if !isUser { Spacer(minLength: 24) }
        }
    }
    // 与真实 MessageBubble 一致：助手含 ``` 时拆代码块为等宽深色框
    @ViewBuilder private func bubbleBody(_ text: String, isUser: Bool) -> some View {
        if !isUser && text.contains("```") {
            let parts = text.components(separatedBy: "```")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { idx, part in
                    if idx % 2 == 1 {
                        Text(part.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.success)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8).background(Color.black.opacity(0.35)).clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        let t = part.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !t.isEmpty { Text(t).font(.system(size: 13)).foregroundStyle(Theme.textPrimary) }
                    }
                }
            }
        } else {
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
        }
    }
}

// MARK: 连接编辑

struct ConnectionEditShowcase: View {
    let conn: Connection
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("取消").foregroundStyle(Theme.accent)
                Spacer()
                Text("编辑连接").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("保存").font(.body.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            SectionCard(title: "基本信息") {
                MockField(label: "名称（可选）", value: conn.name)
                MockField(label: "分组（可选）", value: conn.groupName)
                MockField(label: "主机地址", value: conn.host)
                MockField(label: "端口", value: String(conn.port))
                MockField(label: "用户名", value: conn.username)
                HStack {
                    Label("测试连接", systemImage: "dot.radiowaves.left.and.right").foregroundStyle(Theme.accent)
                    Spacer()
                    Label("可达", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Theme.success)
                }
                .font(.system(size: 13))
            }
            SectionCard(title: "认证方式") {
                MockSegmented(options: ["密码", "私钥"], selected: conn.authType == .password ? 0 : 1)
                if conn.authType == .privateKey {
                    MockField(label: "私钥内容", value: "—— BEGIN OPENSSH PRIVATE KEY ——")
                    MockField(label: "私钥口令（可选）", value: "", secure: true)
                } else {
                    MockField(label: "密码", value: "secret", secure: true)
                    MockToggle(label: "保存密码", on: true)
                }
            }
            SectionCard(title: "跳板机 / Bastion（可选）") {
                MockField(label: "跳板主机", value: "bastion.example.com")
                MockField(label: "跳板用户名", value: "jump")
                MockField(label: "跳板密码", value: "secret", secure: true)
            }
            SectionCard(title: "启动命令（可选）") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("cd /var/www").font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.textPrimary)
                    Text("source venv/bin/activate").font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10).background(Theme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                Text("每行一条，SSH 连接就绪后自动依次执行。").font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
            }
            SectionCard(title: "终端字号（可选）") {
                MockField(label: "终端字号（留空用全局）", value: "15")
            }
            SectionCard(title: "备注（可选）") {
                MockField(label: "如：数据库主库 / 需先连 VPN", value: "数据库主库")
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }
}

// MARK: 设置

struct SettingsShowcase: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("取消").foregroundStyle(Theme.accent)
                Spacer()
                Text("设置").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("保存").font(.body.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            SectionCard(title: "配色主题") {
                HStack(spacing: 12) {
                    ForEach(AppColorScheme.all) { scheme in
                        ThemeThumbnail(background: scheme.background, foreground: scheme.termForeground,
                                       accent: scheme.accent, name: scheme.name,
                                       selected: scheme.id == activeColorScheme.id)
                    }
                    ThemeThumbnail(background: "#1e1e2e", foreground: "#e6e6e6", accent: "#89b4fa",
                                   name: "自定义", selected: false)
                    Spacer()
                }
                // 自定义调色（ColorPicker 离屏不渲染，用色块 mock）
                VStack(spacing: 8) {
                    customRow("背景", "#1e1e2e")
                    customRow("主文字", "#e6e6e6")
                    customRow("强调色", "#89b4fa")
                    customRow("终端光标", "#f5c2e7")
                }
                .padding(.top, 8)
            }
            SectionCard(title: "AI 服务商") {
                MockSegmented(options: ["Anthropic Claude", "OpenAI"], selected: 0)
            }
            SectionCard(title: "Anthropic Claude API Key") {
                MockField(label: "API Key", value: "sk-ant-xxxxxxxxxxxx", secure: true)
            }
            SectionCard(title: "模型") {
                MockSegmented(options: ["claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5"], selected: 0)
            }
            SectionCard(title: "API 地址") {
                MockField(label: "Base URL", value: "https://api.anthropic.com/v1")
            }
            SectionCard(title: "AI 系统提示词") {
                Label("套用预设模板", systemImage: "text.badge.checkmark")
                    .font(.system(size: 13)).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("你是一个终端AI助手，可以帮助用户执行命令…").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.textPrimary)
                    Text("命令格式：[EXECUTE]命令内容[/EXECUTE]").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10).background(Theme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                Text("恢复默认提示词").font(.system(size: 11)).foregroundStyle(Theme.accent)
            }
            SectionCard(title: "连接备份") {
                HStack(spacing: 10) {
                    Label("导出连接", systemImage: "square.and.arrow.up").foregroundStyle(Theme.accent)
                    Spacer()
                    Label("导入连接", systemImage: "square.and.arrow.down").foregroundStyle(Theme.accent)
                }
                .font(.system(size: 13))
                Label("从 ~/.ssh/config 导入", systemImage: "doc.text")
                    .font(.system(size: 13)).foregroundStyle(Theme.accent)
            }
            SectionCard(title: "主机密钥（TOFU）") {
                Label("清除已知主机密钥", systemImage: "key.slash")
                    .font(.system(size: 13)).foregroundStyle(Theme.danger)
            }
            HStack {
                Text("AI Terminal v1.0.0 · 原生 macOS / iOS 终端工具")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }

    private func customRow(_ label: String, _ hex: String) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(hex).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textSecondary)
            RoundedRectangle(cornerRadius: 4).fill(Color(hex: hex)).frame(width: 28, height: 20)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.surfaceLight, lineWidth: 1))
        }
    }
}

// MARK: 批量群发（N-Multi）

struct BatchShowcase: View {
    let connections: [Connection]
    let outcomes: [BatchOutcome]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill").foregroundStyle(Theme.accent)
                Text("批量群发 · \(connections.count) 台").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            // 选择服务器
            Text("选择服务器").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            ForEach(connections.prefix(3)) { c in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    Text(c.name).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(c.username)@\(c.host)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textSecondary)
                }
                .padding(8).background(Theme.accent.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            // 命令
            HStack(spacing: 8) {
                Circle().fill(Theme.danger).frame(width: 8, height: 8)
                Text("systemctl restart nginx").font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("高风险").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.danger)
            }
            .padding(10).background(Theme.surfaceLight).clipShape(RoundedRectangle(cornerRadius: 8))
            // 结果
            Text("执行结果").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            ForEach(outcomes) { o in
                HStack(spacing: 8) {
                    Image(systemName: o.ok ? "checkmark.circle.fill" : "exclamationmark.octagon.fill")
                        .foregroundStyle(o.ok ? Theme.success : Theme.danger)
                    Text(o.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(o.output).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
                .padding(10).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            // AI 汇总入口
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Theme.accent)
                Text("AI 汇总这批结果").font(.system(size: 13)).foregroundStyle(Theme.accent)
            }
            .padding(10).frame(maxWidth: .infinity).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.4)))
        }
        .padding(16).background(Theme.background)
    }
}

// MARK: 服务器知识卡片

struct NotebookShowcase: View {
    // (kind, color, text)
    let rows: [(String, Color, String)]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.closed").foregroundStyle(Theme.accent)
                Text("知识卡片 · 生产服务器").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            // 新增区
            HStack(spacing: 8) {
                ForEach(["问题", "方案", "笔记"], id: \.self) { k in
                    Text(k).font(.system(size: 12))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(k == "笔记" ? Theme.accent.opacity(0.25) : Theme.surfaceLight)
                        .foregroundStyle(k == "笔记" ? Theme.accent : Theme.textSecondary)
                        .clipShape(Capsule())
                }
                Spacer()
                Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.accent)
            }
            Text("沉淀这台机的运维经验，AI 排障时可参考").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            // 记录列表
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(alignment: .top, spacing: 10) {
                    Text(r.0).font(.system(size: 11, weight: .medium)).foregroundStyle(r.1)
                    Text(r.2).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
                .padding(10).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16).background(Theme.background)
    }
}

// MARK: 批量健康巡检（N-Cron）

struct InspectShowcase: View {
    // (name, cpu, mem, disk, warn, error?)
    let rows: [(String, Int, Int, Int, Bool, String?)]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "stethoscope").foregroundStyle(Theme.accent)
                Text("批量巡检 · \(rows.count) 台").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            Text("巡检结果（告警置顶）").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 10) {
                    Image(systemName: r.4 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(r.4 ? Theme.danger : Theme.success)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.0).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textPrimary)
                        if let err = r.5 {
                            Text("采集失败：\(err)").font(.system(size: 11)).foregroundStyle(Theme.danger)
                        } else {
                            HStack(spacing: 12) {
                                metric("CPU", r.1)
                                metric("内存", r.2)
                                metric("磁盘", r.3)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(10).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Theme.accent)
                Text("让 AI 总结这批巡检").font(.system(size: 13)).foregroundStyle(Theme.accent)
            }
            .padding(10).frame(maxWidth: .infinity).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.4)))
        }
        .padding(16).background(Theme.background)
    }
    private func metric(_ label: String, _ v: Int) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
            Text("\(v)%").font(.system(size: 12, weight: .medium)).foregroundStyle(v > 85 ? Theme.danger : Theme.textPrimary)
        }
    }
}

// MARK: 快捷命令片段

struct SnippetsShowcase: View {
    let snippets: [CommandSnippet]
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("完成").foregroundStyle(Theme.accent)
                Spacer()
                Text("快捷命令").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("恢复默认").foregroundStyle(Theme.accent)
            }
            // 搜索框
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Text("搜索片段").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .padding(10).background(Theme.background).clipShape(RoundedRectangle(cornerRadius: 8))
            // 按分组渲染
            ForEach(groupNames, id: \.self) { g in
                SectionCard(title: "📁 \(g)") {
                    VStack(spacing: 0) {
                        let items = snippets.filter { $0.groupName == g }
                        ForEach(Array(items.enumerated()), id: \.offset) { i, s in
                            snipRow(s)
                            if i < items.count - 1 {
                                Rectangle().fill(Theme.surfaceLight.opacity(0.5)).frame(height: 0.5)
                            }
                        }
                    }
                }
            }
            SectionCard(title: "新建片段") {
                MockField(label: "名称", value: "")
                MockField(label: "分组（可选）", value: "")
                MockField(label: "命令", value: "")
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }

    private var groupNames: [String] {
        Array(Set(snippets.compactMap { $0.groupName.isEmpty ? nil : $0.groupName })).sorted()
    }

    private func snipRow(_ s: CommandSnippet) -> some View {
        let risk = CommandRisk.riskLevel(s.command)
        let riskColor = Color(hex: risk.colorHex)
        return HStack(spacing: 10) {
            Image(systemName: risk == .low ? "chevron.left.forwardslash.chevron.right" : risk.icon)
                .font(.system(size: 13))
                .foregroundStyle(risk == .low ? Theme.accent : riskColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(s.title).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textPrimary)
                    if risk.rawValue >= CommandRisk.medium.rawValue {
                        Text(risk.label)
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(riskColor.opacity(0.22)).foregroundStyle(riskColor)
                            .clipShape(Capsule())
                    }
                }
                Text(s.command).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "arrow.down.left.circle").foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 7)
    }
}

// MARK: 端口转发

struct PortForwardShowcase: View {
    struct Rule { let summary: String; let active: Bool }
    let rules = [
        Rule(summary: "127.0.0.1:8080 → 10.0.0.5:80", active: true),
        Rule(summary: "127.0.0.1:5432 → db.internal:5432", active: true),
        Rule(summary: "127.0.0.1:6006 → 127.0.0.1:6006", active: false),
    ]
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Spacer()
                Text("端口转发").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("完成").foregroundStyle(Theme.accent)
            }
            SectionCard(title: "转发规则") {
                VStack(spacing: 0) {
                    ForEach(Array(rules.enumerated()), id: \.offset) { i, r in
                        HStack(spacing: 10) {
                            Circle().fill(r.active ? Theme.success : Theme.textSecondary).frame(width: 8, height: 8)
                            Text(r.summary).font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Capsule().fill(r.active ? Theme.success : Theme.surfaceLight)
                                .frame(width: 38, height: 22)
                                .overlay(Circle().fill(.white).padding(2), alignment: r.active ? .trailing : .leading)
                        }
                        .padding(.vertical, 8)
                        if i < rules.count - 1 { Rectangle().fill(Theme.surfaceLight.opacity(0.4)).frame(height: 0.5) }
                    }
                }
            }
            SectionCard(title: "新建转发") {
                HStack(spacing: 8) {
                    Text("本地端口").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    Image(systemName: "arrow.right").foregroundStyle(Theme.textSecondary)
                    Text("远端 host").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    Text(":").foregroundStyle(Theme.textSecondary)
                    Text("端口").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                .padding(10).background(Theme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                HStack { Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent); Text("添加").foregroundStyle(Theme.accent) }
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }
}

// MARK: 已知主机（TOFU）

struct KnownHostsShowcase: View {
    let hosts: [(String, String)] = [
        ("192.168.1.10:22", "SHA256:9kR2x7Lp8vQwE3nT5yU1mZaB6cD0fG4hJkL2pN8qR"),
        ("db.internal.net:22", "SHA256:Aa1Bb2Cc3Dd4Ee5Ff6Gg7Hh8Ii9Jj0Kk1Ll2Mm3"),
        ("dev.example.com:2222", "SHA256:Zz9Yy8Xx7Ww6Vv5Uu4Tt3Ss2Rr1Qq0Pp9Oo8Nn7"),
    ]
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("完成").foregroundStyle(Theme.accent)
                Spacer()
                Text("已知主机").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("全部清除").foregroundStyle(Theme.danger)
            }
            SectionCard(title: "TOFU 指纹记录") {
                VStack(spacing: 0) {
                    ForEach(Array(hosts.enumerated()), id: \.offset) { i, h in
                        HStack(spacing: 10) {
                            Image(systemName: "key.fill").font(.system(size: 12)).foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(h.0).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textPrimary)
                                Text(h.1).font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Theme.textSecondary).lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Theme.danger)
                        }
                        .padding(.vertical, 8)
                        if i < hosts.count - 1 { Rectangle().fill(Theme.surfaceLight.opacity(0.4)).frame(height: 0.5) }
                    }
                }
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }
}

// MARK: 连接二维码分享

struct QRShowcase: View {
    let connection: Connection
    private var payload: String {
        String(decoding: ConnectionPortability.export([connection], includeSecrets: false), as: UTF8.self)
    }
    var body: some View {
        VStack(spacing: 16) {
            Text(connection.title).font(.headline).foregroundStyle(Theme.textPrimary)
            if let qr = QRCode.image(from: payload) {
                qr.interpolation(.none).resizable().scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding(10).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Text("用另一台设备扫码即可导入此连接（不含密码）。")
                .font(.footnote).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }
}

// MARK: App 图标

struct AppIconView: View {
    var body: some View {
        ZStack {
            // macOS 风格 squircle（留白），珊瑚红品牌渐变 + 顶部高光
            RoundedRectangle(cornerRadius: 232, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#ff6f8d"), Color(hex: "#e94560"), Color(hex: "#8f1330")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 232, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.20), .clear],
                                             startPoint: .top, endPoint: .center))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 232, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 3)
                )
                .frame(width: 836, height: 836)
                .shadow(color: .black.opacity(0.28), radius: 34, x: 0, y: 18)
            // 终端提示符
            Text(">_")
                .font(.system(size: 372, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
                .offset(x: -14, y: 24)
            // AI 火花（右上角，呼应全 App 的 sparkles 标识）
            Image(systemName: "sparkles")
                .font(.system(size: 196, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.20), radius: 12, x: 0, y: 6)
                .offset(x: 250, y: -232)
        }
        .frame(width: 1024, height: 1024)
    }
}

// MARK: 终端搜索栏

struct SearchBarShowcase: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Text("error").font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("已定位").font(.system(size: 11)).foregroundStyle(Theme.success)
                Image(systemName: "chevron.up").foregroundStyle(Theme.textPrimary)
                Image(systemName: "chevron.down").foregroundStyle(Theme.textPrimary)
                Image(systemName: "xmark").foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.surface)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.surfaceLight).frame(height: 0.5) }
            FakeTerminalLines()
        }
        .background(Theme.background)
    }
}

/// 复用：带高亮的假终端几行（搜索预览用）
private struct FakeTerminalLines: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("root@prod-01:~$ tail -f app.log").font(.system(size: 12.5, design: .monospaced)).foregroundStyle(Theme.textPrimary)
            Text("[INFO] started worker").font(.system(size: 12.5, design: .monospaced)).foregroundStyle(Theme.textSecondary)
            (Text("[").foregroundColor(Theme.textSecondary)
             + Text("ERROR").foregroundColor(Color.black).bold()
             + Text("] connection refused").foregroundColor(Theme.textSecondary))
                .font(.system(size: 12.5, design: .monospaced))
                .padding(.horizontal, 2)
                .background(Theme.warning.opacity(0.9))
                .fixedSize()
            Text("[INFO] retrying in 3s").font(.system(size: 12.5, design: .monospaced)).foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color(hex: "#1a1a2e"))
    }
}

// MARK: SFTP 文件浏览器

struct SFTPShowcase: View {
    var dropHint: Bool = false
    struct Item { let name: String; let dir: Bool; let size: String }
    let items: [Item] = [
        Item(name: "..", dir: true, size: ""),
        Item(name: "projects", dir: true, size: ""),
        Item(name: ".ssh", dir: true, size: ""),
        Item(name: "logs", dir: true, size: ""),
        Item(name: "deploy.sh", dir: false, size: "1.0 KB"),
        Item(name: ".bashrc", dir: false, size: "220 B"),
        Item(name: "backup.tar.gz", dir: false, size: "48.2 MB"),
        Item(name: "notes.md", dir: false, size: "3.4 KB")
    ]
    var body: some View {
        VStack(spacing: 0) {
            // 顶栏
            HStack {
                Text("完成").foregroundStyle(Theme.accent)
                Spacer()
                Text("SFTP 文件").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.arrow.down").foregroundStyle(Theme.accent)
                Image(systemName: "folder.badge.plus").foregroundStyle(Theme.accent)
                Image(systemName: "square.and.arrow.up").foregroundStyle(Theme.accent)
            }
            .padding(14)
            // 路径栏
            HStack(spacing: 8) {
                Image(systemName: "arrow.up").foregroundStyle(Theme.textSecondary)
                Text("/home/deploy").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.surface)
            Rectangle().fill(Theme.surfaceLight).frame(height: 0.5)
            // 列表
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                    HStack(spacing: 10) {
                        Image(systemName: it.dir ? "folder.fill" : "doc")
                            .foregroundStyle(it.dir ? Theme.accent : Theme.textSecondary)
                            .frame(width: 20)
                        Text(it.name).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if it.dir {
                            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                        } else {
                            Text(it.size).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                            Image(systemName: "arrow.down.circle").foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    Rectangle().fill(Theme.surfaceLight.opacity(0.4)).frame(height: 0.5)
                }
                Spacer()
            }
            .background(Theme.background)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .overlay {
            if dropHint {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    Label("松开上传到当前目录", systemImage: "arrow.down.doc")
                        .font(.headline).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Theme.surface).clipShape(Capsule())
                }
                .padding(6)
            }
        }
    }
}

// MARK: 终端辅助键栏

struct KeyBarShowcase: View {
    let keys = ["Esc", "Tab", "^C", "^D", "^Z", "^L", "^R", "^U", "↑", "↓", "←", "→", "|", "~", "/", "-", "*", "$"]
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, k in
                Text(k)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(minWidth: k.count > 1 ? 44 : 34, minHeight: 34)
                    .background(Theme.surfaceLight)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Theme.surface)
    }
}
#endif
