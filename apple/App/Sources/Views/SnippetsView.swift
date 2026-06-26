import SwiftUI
import AITerminalCore

/// 快捷命令片段面板：点选一键注入当前会话，可增删、恢复默认。
struct SnippetsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var newTitle = ""
    @State private var newCommand = ""
    @State private var newGroup = ""
    @State private var editingID: UUID?   // 正在编辑的片段 id（nil=新建）
    @State private var search = ""
    @State private var previewTemplate: SetupTemplate?  // U-Z8 初始化模板预览
    @State private var quickNoteCmd: String?            // 随手记：把命令存为知识卡片
    @State private var quickNoteText = ""
    @State private var quickNoteKind: ServerNote.Kind = .note
    @State private var favorites: [String] = CommandFavorites.load()   // 命令收藏夹

    /// 按名称/命令/分组过滤
    private var filtered: [CommandSnippet] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return model.snippets }
        return model.snippets.filter {
            $0.title.lowercased().contains(q)
            || $0.command.lowercased().contains(q)
            || $0.groupName.lowercased().contains(q)
        }
    }

    /// 未分组片段
    private var ungrouped: [CommandSnippet] {
        filtered.filter { $0.groupName.isEmpty }
    }

    /// 各分组（按组名排序）
    private var groups: [(name: String, snippets: [CommandSnippet])] {
        let dict = Dictionary(grouping: filtered.filter { !$0.groupName.isEmpty }) { $0.groupName }
        return dict.keys.sorted().map { (name: $0, snippets: dict[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        TextField("搜索片段", text: $search)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                        if !search.isEmpty {
                            Button {
                                search = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 命令收藏夹（⭐ 置顶常用命令）
                if !favorites.isEmpty {
                    Section("⭐ 收藏命令") {
                        ForEach(favorites, id: \.self) { cmd in
                            Button {
                                if let inject = model.activeSession?.injectCommand { inject(cmd); model.recordCommand(cmd); dismiss() }
                                else { model.toast = "请先打开一个终端会话" }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(Theme.warning)
                                    Text(cmd).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                                    Spacer()
                                    Image(systemName: "xmark.circle").foregroundStyle(Theme.textSecondary)
                                        .onTapGesture { favorites = CommandFavorites.toggle(cmd) }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                // N-History：命令历史（点击注入重用）
                if !model.commandHistory.isEmpty {
                    Section("命令历史") {
                        ForEach(model.commandHistory.prefix(10), id: \.self) { cmd in
                            Button {
                                if let inject = model.activeSession?.injectCommand {
                                    inject(cmd); model.recordCommand(cmd); dismiss()
                                } else { model.toast = "请先打开一个终端会话" }
                            } label: {
                                let risk = CommandRisk.riskLevel(cmd)
                                HStack(spacing: 10) {
                                    Circle().fill(Color(hex: risk.colorHex)).frame(width: 8, height: 8)
                                    Text(cmd).font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(Theme.textPrimary).lineLimit(1)
                                    Spacer()
                                    Image(systemName: "arrow.down.left.circle").foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    favorites = CommandFavorites.toggle(cmd)
                                } label: { Label(favorites.contains(cmd) ? "取消收藏" : "收藏命令", systemImage: favorites.contains(cmd) ? "star.slash" : "star") }
                                Button {
                                    quickNoteText = cmd; quickNoteKind = .note; quickNoteCmd = cmd
                                } label: { Label("存为知识卡片", systemImage: "book.closed") }
                            }
                        }
                    }
                }

                Section {
                    if model.snippets.isEmpty {
                        Text("暂无片段")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    } else if filtered.isEmpty {
                        Text("无匹配「\(search)」的片段")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        ForEach(ungrouped) { snippet in
                            snippetRow(snippet)
                        }
                    }
                } header: {
                    Text("点选注入当前终端")
                } footer: {
                    Text("注入到提示符但不自动回车，方便复核后再执行。")
                }

                // 分组
                ForEach(groups, id: \.name) { grp in
                    Section {
                        ForEach(grp.snippets) { snippet in
                            snippetRow(snippet)
                        }
                    } header: {
                        Label(grp.name, systemImage: "folder")
                    }
                }

                Section(editingID == nil ? "新建片段" : "编辑片段") {
                    TextField("名称", text: $newTitle)
                    TextField("分组（可选）", text: $newGroup)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("命令", text: $newCommand)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    Button {
                        addSnippet()
                    } label: {
                        Label(editingID == nil ? "添加" : "保存修改", systemImage: editingID == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty
                              || newCommand.trimmingCharacters(in: .whitespaces).isEmpty)
                    if editingID != nil {
                        Button(role: .cancel) {
                            editingID = nil; newTitle = ""; newCommand = ""; newGroup = ""
                        } label: { Label("取消编辑", systemImage: "xmark.circle") }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("快捷命令")
            .alert("存为知识卡片", isPresented: Binding(get: { quickNoteCmd != nil }, set: { if !$0 { quickNoteCmd = nil } })) {
                TextField("内容", text: $quickNoteText)
                Button("取消", role: .cancel) { quickNoteCmd = nil }
                Button("保存") {
                    let t = quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty, let connID = model.activeSession?.connection?.id.uuidString {
                        _ = ServerNotebook.add(ServerNote(kind: quickNoteKind, text: t), connectionID: connID)
                        model.toast = "已存入知识卡片"
                    } else if model.activeSession?.connection == nil { model.toast = "请先打开一个连接的会话" }
                    quickNoteCmd = nil
                }
            } message: { Text("把这条命令记入当前服务器的知识卡片（笔记）") }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    // U-Z8：一键初始化/部署模板
                    Menu {
                        ForEach(SetupTemplate.builtins) { tpl in
                            Button {
                                previewTemplate = tpl
                            } label: {
                                Label(tpl.name, systemImage: tpl.icon)
                            }
                        }
                    } label: {
                        Label("初始化模板", systemImage: "square.stack.3d.up")
                    }
                    Button { exportSnippets() } label: { Label("导出快捷命令", systemImage: "square.and.arrow.up") }
                    Button("恢复默认") { model.resetSnippets() }
                }
            }
            .sheet(item: $previewTemplate) { tpl in
                templatePreview(tpl)
            }
        }
        .frame(minWidth: 420, minHeight: 480)
    }

    /// U-Z8 模板预览 sheet：滚动展示步骤+命令+风险+预计影响，确认后注入
    private func templatePreview(_ tpl: SetupTemplate) -> some View {
        NavigationStack {
            ScrollView {
                Text(tpl.previewText())
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Theme.background)
            .navigationTitle(tpl.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { previewTemplate = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("注入到终端") {
                        if model.runSetupTemplate(tpl) { previewTemplate = nil; dismiss() }
                    }
                    .tint(Color(hex: tpl.risk.colorHex))
                }
            }
        }
        .frame(minWidth: 440, minHeight: 520)
    }

    private func snippetRow(_ snippet: CommandSnippet) -> some View {
        let risk = CommandRisk.riskLevel(snippet.command)
        let riskColor = Color(hex: risk.colorHex)
        return Button {
            if model.runSnippet(snippet) { dismiss() }
        } label: {
            HStack(spacing: 10) {
                // Z7：四级风险图标+颜色（低=代码图标 accent，中/高/极高=风险图标对应色）
                Image(systemName: risk == .low ? "chevron.left.forwardslash.chevron.right" : risk.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(risk == .low ? Theme.accent : riskColor)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(snippet.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        // 中风险以上显示风险标签徽章
                        if risk.rawValue >= CommandRisk.medium.rawValue {
                            Text(risk.label)
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(riskColor.opacity(0.22))
                                .foregroundStyle(riskColor)
                                .clipShape(Capsule())
                        }
                    }
                    Text(snippet.command)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.down.left.circle")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .help(snippet.isDangerous
              ? "⚠️ 高危命令，注入后请仔细复核再执行：\(snippet.command)"
              : snippet.command)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                model.deleteSnippet(snippet)
            } label: {
                Label("删除", systemImage: "trash")
            }
            Button {
                // 载入到表单编辑（保留 id，保存时 upsert 覆盖原片段）
                editingID = snippet.id
                newTitle = snippet.title
                newCommand = snippet.command
                newGroup = snippet.group ?? ""
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(Theme.accent)
        }
    }

    /// 把快捷命令（默认+自定义）按分组拼成 Markdown 复制（备份/共享）
    private func exportSnippets() {
        let all = CommandSnippet.defaults + model.snippets
        let grouped = Dictionary(grouping: all) { $0.groupName.isEmpty ? "其他" : $0.groupName }
        var md = "# Termind 快捷命令\n"
        for (group, items) in grouped.sorted(by: { $0.key < $1.key }) {
            md += "\n## \(group)\n"
            for s in items { md += "- **\(s.title)**：`\(s.command)`\n" }
        }
        Clipboard.copy(md)
        model.toast = "快捷命令已复制（Markdown）"
    }

    private func addSnippet() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        let command = newCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = newGroup.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, !command.isEmpty else { return }
        // 编辑时保留原 id（saveSnippet 按 id upsert）；新建则生成新 id
        let snippet = editingID.map { CommandSnippet(id: $0, title: title, command: command, group: group.isEmpty ? nil : group) }
            ?? CommandSnippet(title: title, command: command, group: group.isEmpty ? nil : group)
        model.saveSnippet(snippet)
        newTitle = ""
        newCommand = ""
        newGroup = ""
        editingID = nil
    }
}
