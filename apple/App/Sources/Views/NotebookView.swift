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

    private var connID: String { connection.id.uuidString }

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
                            notes = ServerNotebook.add(ServerNote(kind: newKind, text: t), connectionID: connID)
                            newText = ""
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
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
                    List {
                        ForEach(notes) { note in
                            HStack(alignment: .top, spacing: 10) {
                                Text(note.kind.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(kindColor(note.kind))
                                    .padding(.top, 1)
                                Text(note.text).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                            }
                            .listRowBackground(Theme.surface.opacity(0.4))
                        }
                        .onDelete { idx in
                            for i in idx { notes = ServerNotebook.remove(id: notes[i].id, connectionID: connID) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Theme.background)
                }
            }
            .background(Theme.background)
            .navigationTitle("知识卡片 · \(connection.title)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
            }
            .onAppear { notes = ServerNotebook.load(connectionID: connID) }
        }
        .frame(minWidth: 460, minHeight: 520)
    }
}
