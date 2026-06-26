import SwiftUI
import AITerminalCore

/// 服务器知识卡片（差异化护城河：每台机沉淀历史问题/解决方案/运维笔记，喂 AI 排障参考）。
/// 对齐 android NotebookSheet。
struct NotebookView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let connection: Connection

    @State private var notes: [ServerNote] = []
    @State private var newKind: ServerNote.Kind = .note
    @State private var newText = ""
    @State private var newTags = ""   // 逗号分隔标签
    @State private var filterKind: ServerNote.Kind?   // nil=全部
    @State private var search = ""                    // 关键词搜索
    @State private var filterTag: String?             // 按标签筛选
    @State private var showImport = false             // 知识卡片导入粘贴
    @State private var importText = ""

    private var connID: String { connection.id.uuidString }
    private var allTags: [String] { notes.flatMap { $0.tags }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } } }
    private var shownNotes: [ServerNote] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return notes.filter {
            (filterKind == nil || $0.kind == filterKind) &&
            (q.isEmpty || $0.text.localizedCaseInsensitiveContains(q)) &&
            (filterTag == nil || $0.tags.contains(filterTag!))
        }
    }

    private func kindColor(_ k: ServerNote.Kind) -> Color {
        switch k {
        case .issue: return Theme.danger
        case .solution: return Theme.success
        case .note: return Theme.accent
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 新增区
                VStack(spacing: 8) {
                    Picker("类型", selection: $newKind) {
                        ForEach(ServerNote.Kind.allCases, id: \.self) { k in Text(k.label).tag(k) }
                    }
                    .pickerStyle(.segmented)
                    HStack(spacing: 8) {
                        TextField("记录问题 / 解决方案 / 笔记…", text: $newText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...3)
                        Button {
                            let t = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            let tags = newTags.split(whereSeparator: { $0 == "," || $0 == "，" }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                            notes = ServerNotebook.add(ServerNote(kind: newKind, text: t, tags: tags), connectionID: connID)
                            newText = ""; newTags = ""
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    TextField("标签（逗号分隔，可选）", text: $newTags)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }
                .padding(12)
                .background(Theme.surface)

                if notes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed").font(.system(size: 32)).foregroundStyle(Theme.textSecondary)
                        Text("还没有记录").font(.subheadline).foregroundStyle(Theme.textPrimary)
                        Text("把这台机出过的问题、解决方案、注意事项记下来，\nAI 排障时可参考。")
                            .font(.caption).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 类型筛选（记录多时按类型找）
                    Picker("筛选", selection: $filterKind) {
                        Text("全部").tag(ServerNote.Kind?.none)
                        ForEach(ServerNote.Kind.allCases, id: \.self) { k in Text(k.label).tag(ServerNote.Kind?.some(k)) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 12).padding(.top, 8)
                    // 标签筛选（有标签时显可点 #标签 Chip）
                    if !allTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(allTags, id: \.self) { tag in
                                    Button { filterTag = (filterTag == tag) ? nil : tag } label: {
                                        Text("#\(tag)").font(.system(size: 11))
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background((filterTag == tag ? Theme.accent : Theme.surfaceLight).opacity(filterTag == tag ? 0.25 : 0.5))
                                            .foregroundStyle(filterTag == tag ? Theme.accent : Theme.textSecondary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12).padding(.top, 6)
                        }
                    }
                    List {
                        ForEach(shownNotes) { note in
                            HStack(alignment: .top, spacing: 10) {
                                Text(note.kind.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(kindColor(note.kind))
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.text).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                                    if !note.tags.isEmpty {
                                        HStack(spacing: 4) {
                                            ForEach(note.tags, id: \.self) { tag in
                                                Text("#\(tag)").font(.system(size: 10)).foregroundStyle(Theme.accent)
                                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                                    .background(Theme.accent.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                        }
                                    }
                                }
                            }
                            .listRowBackground(Theme.surface.opacity(0.4))
                        }
                        .onDelete { idx in
                            for i in idx { notes = ServerNotebook.remove(id: shownNotes[i].id, connectionID: connID) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Theme.background)
                }
            }
            .background(Theme.background)
            .searchable(text: $search, prompt: "搜索记录")
            .navigationTitle("知识卡片 · \(connection.title)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Clipboard.copy(ServerNotebook.exportMarkdown(notes, serverName: connection.title))
                        model.toast = "知识卡片已复制（Markdown）"
                    } label: { Label("导出", systemImage: "square.and.arrow.up") }
                    .disabled(notes.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { importText = ""; showImport = true } label: { Label("导入", systemImage: "square.and.arrow.down") }
                }
            }
            .alert("导入知识卡片", isPresented: $showImport) {
                TextField("粘贴导出的 Markdown", text: $importText, axis: .vertical)
                Button("取消", role: .cancel) {}
                Button("导入") {
                    let parsed = ServerNotebook.parseImport(importText)
                    let existing = Set(notes.map { $0.text })
                    var added = 0
                    for n in parsed where !existing.contains(n.text) { notes = ServerNotebook.add(n, connectionID: connID); added += 1 }
                    model.toast = added > 0 ? "已导入 \(added) 条知识卡片" : "无新卡片（已存在或解析为空）"
                }
            } message: { Text("支持导出的 Markdown 格式（## 类型 + - 内容）") }
            .onAppear { notes = ServerNotebook.load(connectionID: connID) }
        }
        .frame(minWidth: 460, minHeight: 520)
    }
}
