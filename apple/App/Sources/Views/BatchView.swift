import SwiftUI
import AITerminalCore

/// 批量群发面板（N-Multi）：选多台服务器并发执行同一命令，高危确认，可让 AI 汇总。
/// 对齐 android BatchScreen。
struct BatchView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<UUID> = []
    @State private var command = ""
    @State private var confirmHighRisk = false

    private var risk: CommandRisk { CommandRisk.riskLevel(command.trimmingCharacters(in: .whitespaces)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if model.batchResults.isEmpty && !model.batchRunning {
                    setupArea
                } else {
                    resultArea
                }
            }
            .background(Theme.background)
            .navigationTitle("批量群发")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if model.batchResults.isEmpty {
                        Button { runOrConfirm() } label: { Label("群发执行", systemImage: "paperplane") }
                            .disabled(selected.isEmpty || command.trimmingCharacters(in: .whitespaces).isEmpty || model.batchRunning)
                    } else {
                        Button { model.batchResults = [] } label: { Label("重来", systemImage: "arrow.counterclockwise") }
                    }
                }
                if !model.batchResults.isEmpty && !model.batchRunning {
                    ToolbarItem(placement: .primaryAction) {
                        Button { exportResults() } label: { Label("导出", systemImage: "square.and.arrow.up") }
                    }
                }
            }
            .alert("\(risk.label)命令", isPresented: $confirmHighRisk) {
                Button("取消", role: .cancel) {}
                Button("确认群发", role: .destructive) { doRun() }
            } message: {
                Text("即将对 \(selected.count) 台服务器执行：\n\(command)\n\n该命令为\(risk.label)操作，确认？")
            }
        }
        .frame(minWidth: 460, minHeight: 560)
    }

    private func runOrConfirm() {
        if risk.needsConfirm { confirmHighRisk = true } else { doRun() }
    }
    private func doRun() {
        let targets = model.connections.filter { selected.contains($0.id) }
        model.runBatch(targets, command: command)
    }

    /// 把群发结果拼成 Markdown 复制到剪贴板（运维记录留存，对齐 android 分享）
    private func exportResults() {
        let okN = model.batchResults.filter { $0.ok }.count
        var md = "# 批量群发结果\n\n命令：`\(command)`\n\n成功 \(okN) · 失败 \(model.batchResults.count - okN) · 共 \(model.batchResults.count) 台\n"
        for o in model.batchResults {
            md += "\n## \(o.ok ? "✅" : "❌") \(o.name)\n```\n\(o.output.trimmingCharacters(in: .whitespacesAndNewlines))\n```\n"
        }
        Clipboard.copy(md)
        model.toast = "群发结果已复制（Markdown）"
    }

    // MARK: 选择 + 命令

    /// 各分组名（去重排序）
    private var groupNames: [String] {
        Array(Set(model.connections.compactMap { $0.groupName.isEmpty ? nil : $0.groupName })).sorted()
    }

    private var setupArea: some View {
        VStack(spacing: 0) {
            // 快速选择：全选 / 清空 / 按分组
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button("全选") { selected = Set(model.connections.map { $0.id }) }.buttonStyle(.bordered).tint(Theme.accent)
                    Button("清空") { selected.removeAll() }.buttonStyle(.bordered)
                    ForEach(groupNames, id: \.self) { g in
                        Button {
                            selected.formUnion(model.connections.filter { $0.groupName == g }.map { $0.id })
                        } label: { Label(g, systemImage: "folder") }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
            }
            .background(Theme.surface)
            List {
                Section {
                    ForEach(model.connections) { conn in
                        Button {
                            if selected.contains(conn.id) { selected.remove(conn.id) } else { selected.insert(conn.id) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selected.contains(conn.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(conn.id) ? Theme.accent : Theme.textSecondary)
                                Text(conn.name.isEmpty ? conn.host : conn.name)
                                    .font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(conn.username)@\(conn.host)")
                                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("选择服务器（\(selected.count) 台）").foregroundStyle(Theme.textSecondary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)

            VStack(spacing: 6) {
                if !command.trimmingCharacters(in: .whitespaces).isEmpty {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: risk.colorHex)).frame(width: 8, height: 8)
                        Text("风险：\(risk.label)").font(.system(size: 11, weight: .medium)).foregroundStyle(Color(hex: risk.colorHex))
                        if risk.needsConfirm { Text("· 执行前需确认").font(.system(size: 11)).foregroundStyle(Theme.textSecondary) }
                        Spacer()
                    }
                }
                TextField("要群发的命令…", text: $command)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(10)
                    .background(Theme.surfaceLight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(12)
            .background(Theme.surface)
        }
    }

    // MARK: 结果

    private var resultArea: some View {
        VStack(spacing: 0) {
            if model.batchRunning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("群发执行中…").font(.footnote).foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                .padding(12).background(Theme.surface)
            }
            // 成功/失败统计（结果完成后显）
            if !model.batchResults.isEmpty && !model.batchRunning {
                let okN = model.batchResults.filter { $0.ok }.count
                HStack(spacing: 14) {
                    Text("✅ 成功 \(okN)").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.success)
                    if model.batchResults.count - okN > 0 {
                        Text("❌ 失败 \(model.batchResults.count - okN)").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.danger)
                    }
                    Text("共 \(model.batchResults.count) 台").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 6).background(Theme.surface)
            }
            List {
                ForEach(model.batchResults) { o in
                    HStack(spacing: 10) {
                        Image(systemName: o.ok ? "checkmark.circle.fill" : "exclamationmark.octagon.fill")
                            .foregroundStyle(o.ok ? Theme.success : Theme.danger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(o.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textPrimary)
                            Text(o.output).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textSecondary).lineLimit(3)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)

            if !model.batchRunning {
                Button {
                    model.summarizeBatch(command: command)
                    dismiss()
                } label: {
                    Label("让 AI 汇总这批结果", systemImage: "sparkles")
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .padding(12)
            }
        }
    }
}
