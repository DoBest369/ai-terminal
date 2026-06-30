import SwiftUI
import AITerminalCore

/// 批量健康巡检面板（N-Cron）：选多台服务器并发采集 CPU/内存/磁盘，异常置顶，可让 AI 总结。
/// 对齐 android InspectScreen。
struct InspectView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<UUID> = []
    @State private var onlyAlerts = false   // 仅看告警结果

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if model.connections.isEmpty {
                    emptyConnectionsState
                } else if model.inspectionResults.isEmpty && !model.inspectionRunning {
                    selectionList
                } else {
                    resultList
                }
            }
            .background(Theme.background)
            .navigationTitle("批量巡检")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if model.inspectionResults.isEmpty {
                        Button {
                            let targets = model.connections.filter { selected.contains($0.id) }
                            model.runHealthInspection(targets)
                        } label: {
                            Label("开始巡检", systemImage: "stethoscope")
                        }
                        .disabled(selected.isEmpty || model.inspectionRunning)
                    } else {
                        Button {
                            model.inspectionResults = []
                        } label: {
                            Label("重选", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 540)
    }

    // MARK: 连接选择

    private var groupNames: [String] {
        Array(Set(model.connections.compactMap { $0.groupName.isEmpty ? nil : $0.groupName })).sorted()
    }

    /// 空状态：还没有任何 SSH 连接（无巡检对象）→ 友好引导
    private var emptyConnectionsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 44)).foregroundStyle(Theme.textSecondary)
            Text("还没有 SSH 连接").font(.headline).foregroundStyle(Theme.textPrimary)
            Text("批量巡检需要先添加服务器连接，\n在侧边栏「+」新建连接后再回来一键巡检。")
                .font(.caption).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var selectionList: some View {
        VStack(spacing: 0) {
        // 快速选择：全选 / 清空 / 按分组
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button("全选") { selected = Set(model.connections.map { $0.id }) }.buttonStyle(.bordered).tint(Theme.accent)
                Button("清空") { selected.removeAll() }.buttonStyle(.bordered)
                ForEach(groupNames, id: \.self) { g in
                    Button { selected.formUnion(model.connections.filter { $0.groupName == g }.map { $0.id }) } label: { Label(g, systemImage: "folder") }
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conn.name.isEmpty ? conn.host : conn.name)
                                    .font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                                Text("\(conn.username)@\(conn.host):\(conn.port)")
                                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("选择要巡检的服务器（\(selected.count) 台）").foregroundStyle(Theme.textSecondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        }
    }

    // MARK: 巡检结果

    private var resultList: some View {
        VStack(spacing: 0) {
            if model.inspectionRunning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("巡检中…").font(.footnote).foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                .padding(12).background(Theme.surface)
            }
            // 巡检统计（告警/正常/失败，对齐群发统计）
            if !model.inspectionResults.isEmpty && !model.inspectionRunning {
                let failN = model.inspectionResults.filter { $0.error != nil }.count
                let warnN = model.inspectionResults.filter { $0.error == nil && $0.hasWarning }.count
                let okN = model.inspectionResults.count - failN - warnN
                HStack(spacing: 14) {
                    if warnN > 0 {
                        // 点告警数→切换「仅看告警」
                        Button { onlyAlerts.toggle() } label: {
                            Label("告警 \(warnN)", systemImage: "exclamationmark.triangle.fill").font(.system(size: 12, weight: .medium))
                                .foregroundStyle(onlyAlerts ? Color.white : Theme.danger)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(onlyAlerts ? Theme.danger : Theme.danger.opacity(0.12))
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)
                    }
                    Label("正常 \(okN)", systemImage: "checkmark.circle.fill").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.success)
                    if failN > 0 { Label("失败 \(failN)", systemImage: "xmark.circle.fill").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textSecondary) }
                    Spacer()
                    if onlyAlerts { Text("仅看告警").font(.system(size: 11)).foregroundStyle(Theme.textSecondary) }
                }
                .padding(.horizontal, 12).padding(.vertical, 6).background(Theme.surface)
            }
            List {
                ForEach(model.inspectionResults.filter { !onlyAlerts || ($0.error == nil && $0.hasWarning) }) { r in
                    resultRow(r)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)

            if !model.inspectionRunning && !model.inspectionResults.isEmpty {
                HStack(spacing: 10) {
                    Button { exportInspection() } label: {
                        Label("导出", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered).tint(Theme.accent)
                    Button {
                        model.summarizeInspection()
                        dismiss()
                    } label: {
                        Label("AI 总结", systemImage: "sparkles").frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                }
                .padding(12)
            }
        }
    }

    /// 把巡检结果拼成 Markdown 复制到剪贴板（巡检报告留存，对齐 android 分享）
    private func exportInspection() {
        let failN = model.inspectionResults.filter { $0.error != nil }.count
        let warnN = model.inspectionResults.filter { $0.error == nil && $0.hasWarning }.count
        let okN = model.inspectionResults.count - failN - warnN
        var md = "# 批量巡检报告\n\n⚠️ 告警 \(warnN) · ✅ 正常 \(okN) · ❌ 失败 \(failN) · 共 \(model.inspectionResults.count) 台\n"
        for r in model.inspectionResults {
            md += "\n## \(r.name)\n"
            if let e = r.error { md += "❌ 巡检失败：\(e)\n" }
            else if let info = r.info { md += "\(r.hasWarning ? "⚠️" : "✅") \(info.healthSummary.replacingOccurrences(of: "服务器状态：", with: ""))\n" }
        }
        Clipboard.copy(md)
        model.toast = "巡检报告已复制（Markdown）"
    }

    private func resultRow(_ r: AppModel.InspectionResult) -> some View {
        HStack(spacing: 10) {
            Image(systemName: r.hasWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(r.hasWarning ? Theme.danger : Theme.success)
            VStack(alignment: .leading, spacing: 3) {
                Text(r.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textPrimary)
                if let info = r.info {
                    HStack(spacing: 12) {
                        metric("CPU", String(format: "%.0f%%", info.cpuUsage), info.cpuUsage > 85)
                        metric("内存", String(format: "%.0f%%", info.memPercent), info.memPercent > 85)
                        metric("磁盘", String(format: "%.0f%%", info.diskPercent), info.diskPercent > 85)
                        // 负载 1 分钟（有则显示，对齐 android 巡检卡片 + healthSummary）
                        if let load1 = info.loadavg.first {
                            metric("负载", String(format: "%.2f", load1), load1 > Double(info.cpuCores) * 0.8)
                        }
                    }
                } else {
                    Text("采集失败：\(r.error ?? "未知")").font(.system(size: 11)).foregroundStyle(Theme.danger)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func metric(_ label: String, _ value: String, _ warn: Bool) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
            Text(value).font(.system(size: 12, weight: .medium)).foregroundStyle(warn ? Theme.danger : Theme.textPrimary)
        }
    }
}
