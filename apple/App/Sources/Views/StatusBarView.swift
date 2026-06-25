import SwiftUI
import AITerminalCore

struct StatusBarView: View {
    @ObservedObject var session: TerminalSessionVM
    @State private var localInfo: SystemInfo?
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            compactBar
            if expanded, let info = displayInfo {
                Divider().overlay(Theme.surfaceLight)
                expandedDetail(info)
            }
        }
        .glassPanel(Theme.surface, opacity: 0.5)
        .task(id: session.id) {
            #if os(macOS)
            if session.isLocal {
                while !Task.isCancelled {
                    localInfo = LocalSystemMonitor.snapshot()
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
            #endif
        }
    }

    private var compactBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                statusItem(icon: "circle.fill", label: "状态",
                           value: session.status.label,
                           tint: statusColor(session.status))

                if let note = session.connection?.noteText, !note.isEmpty {
                    statusItem(icon: "note.text", label: "备注", value: note)
                }

                if let info = displayInfo {
                    statusItem(icon: "desktopcomputer", label: "主机", value: info.hostname.isEmpty ? "—" : info.hostname)
                    metricItem(icon: "bolt.fill", label: "CPU",
                               value: String(format: "%.0f%%", info.cpuUsage),
                               percent: info.cpuUsage,
                               warn: info.cpuUsage > 80)
                    metricItem(icon: "memorychip", label: "内存",
                               value: "\(formatBytes(info.memUsed)) / \(formatBytes(info.memTotal))",
                               percent: info.memPercent,
                               warn: info.memPercent > 80)
                    if !info.loadavg.isEmpty {
                        statusItem(icon: "chart.bar.fill", label: "负载",
                                   value: info.loadavg.map { String(format: "%.2f", $0) }.joined(separator: " "))
                    }
                    if !info.uptime.isEmpty {
                        statusItem(icon: "clock", label: "运行", value: info.uptime)
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
                } else if !session.statusMessage.isEmpty {
                    statusItem(icon: "info.circle", label: "信息", value: session.statusMessage)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard displayInfo != nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
        }
    }

    /// 展开的详细系统信息（只用 SystemInfo 已有字段）
    private func expandedDetail(_ info: SystemInfo) -> some View {
        let load = info.loadavg
        return LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
            spacing: 10
        ) {
            detailCell("主机", info.hostname.isEmpty ? "—" : info.hostname)
            detailCell("运行时长", info.uptime.isEmpty ? "—" : info.uptime)
            detailCell("CPU", String(format: "%.1f%% · %d 核", info.cpuUsage, info.cpuCores))
            detailCell("内存", String(format: "%@ / %@ (%.0f%%)", formatBytes(info.memUsed), formatBytes(info.memTotal), info.memPercent))
            if load.count >= 3 {
                detailCell("负载 1 / 5 / 15 分钟", String(format: "%.2f / %.2f / %.2f", load[0], load[1], load[2]))
            } else if !load.isEmpty {
                detailCell("负载", load.map { String(format: "%.2f", $0) }.joined(separator: " / "))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func detailCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textPrimary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayInfo: SystemInfo? {
        session.isLocal ? localInfo : session.systemInfo
    }

    private func statusItem(icon: String, label: String, value: String, tint: Color = Theme.textSecondary) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func metricItem(icon: String, label: String, value: String, percent: Double, warn: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(warn ? Theme.danger : Theme.textSecondary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(warn ? Theme.danger : Theme.textPrimary)
            ProgressView(value: min(percent, 100), total: 100)
                .frame(width: 50)
                .tint(warn ? Theme.danger : Theme.accent)
        }
    }
}
