import SwiftUI
import AITerminalCore

/// 批量健康巡检面板（N-Cron）：选多台服务器并发采集 CPU/内存/磁盘，异常置顶，可让 AI 总结。
/// 对齐 android InspectScreen。
struct InspectView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if model.inspectionResults.isEmpty && !model.inspectionRunning {
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
            List {
                ForEach(model.inspectionResults) { r in
                    resultRow(r)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)

            if !model.inspectionRunning {
                Button {
                    model.summarizeInspection()
                    dismiss()
                } label: {
                    Label("让 AI 总结这批巡检", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .padding(12)
            }
        }
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
