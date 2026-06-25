import SwiftUI
import AITerminalCore

/// 快捷命令片段面板：点选一键注入当前会话，可增删、恢复默认。
struct SnippetsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var newTitle = ""
    @State private var newCommand = ""
    @State private var newGroup = ""
    @State private var search = ""
    @State private var previewTemplate: SetupTemplate?  // U-Z8 初始化模板预览

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

                Section("新建片段") {
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
                        Label("添加", systemImage: "plus.circle.fill")
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty
                              || newCommand.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("快捷命令")
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
        }
    }

    private func addSnippet() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        let command = newCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = newGroup.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, !command.isEmpty else { return }
        model.saveSnippet(CommandSnippet(title: title, command: command, group: group.isEmpty ? nil : group))
        newTitle = ""
        newCommand = ""
        newGroup = ""
    }
}
