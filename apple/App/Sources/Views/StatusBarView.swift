import SwiftUI
import AITerminalCore

struct StatusBarView: View {
    @EnvironmentObject var model: AppModel
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

                // 连接时长（已连接时每秒刷新，对齐 android A-Duration）
                if let start = session.connectedAt {
                    TimelineView(.periodic(from: start, by: 1)) { ctx in
                        statusItem(icon: "clock", label: "时长", value: Self.durationLabel(ctx.date.timeIntervalSince(start)))
                    }
                }

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
                    if info.diskTotal > 0 {
                        metricItem(icon: "internaldrive", label: "磁盘",
                                   value: "\(formatBytes(info.diskUsed)) / \(formatBytes(info.diskTotal))",
                                   percent: info.diskPercent,
                                   warn: info.diskPercent > 85)
                    }
                    if !info.loadavg.isEmpty {
                        statusItem(icon: "chart.bar.fill", label: "负载",
                                   value: info.loadavg.map { String(format: "%.2f", $0) }.joined(separator: " "))
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
                    // Z6b：状态↔AI 联动——远程会话且有状态时可一键让 AI 分析健康
                    if !session.isLocal, !info.healthSummary.isEmpty {
                        Button { model.diagnoseHealth() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: info.hasWarning ? "exclamationmark.triangle.fill" : "sparkles")
                                Text(info.hasWarning ? "异常·问 AI" : "问 AI")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(info.hasWarning ? Theme.danger : Theme.accent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background((info.hasWarning ? Theme.danger : Theme.accent).opacity(0.15))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("让 AI 分析当前服务器状态并给排查/优化建议")
                    }
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
            detailCellWithBar("CPU", String(format: "%.1f%% · %d 核", info.cpuUsage, info.cpuCores), percent: info.cpuUsage)
            detailCellWithBar("内存", String(format: "%@ / %@ (%.0f%%)", formatBytes(info.memUsed), formatBytes(info.memTotal), info.memPercent), percent: info.memPercent)
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

    /// CPU/内存详情：数值下加 mini 进度条（绿<60 / 橙60-80 / 红>80），一眼看占用
    private func detailCellWithBar(_ label: String, _ value: String, percent: Double) -> some View {
        let barColor: Color = percent > 80 ? Theme.danger : (percent > 60 ? .orange : Theme.success)
        return VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textPrimary).lineLimit(1)
            // 纯布局 mini 进度条（自适应宽度，按占用着色）
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(barColor)
                        .frame(width: g.size.width * min(max(percent, 0), 100) / 100)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayInfo: SystemInfo? {
        session.isLocal ? localInfo : session.systemInfo
    }

    /// 秒数 → mm:ss 或 HH:mm:ss
    static func durationLabel(_ interval: TimeInterval) -> String {
        let s = Int(max(0, interval))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
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
