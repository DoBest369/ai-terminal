import SwiftUI
import AITerminalCore

/// 终端面板：终端视图 + 连接状态遮罩（连接中 / 断开重连）。
struct TerminalPane: View {
    @ObservedObject var session: TerminalSessionVM
    @EnvironmentObject var model: AppModel

    /// 连接级字号覆盖优先，否则用全局（本地会话 connection 为 nil 自然回退）。
    /// 覆盖值夹到 8…32，防止导入的极端值（如 999）撑坏终端。
    private var fontSize: CGFloat {
        if let override = session.connection?.fontSizeOverride {
            return CGFloat(min(32, max(8, override)))
        }
        return model.terminalFontSize
    }

    var body: some View {
        TerminalContainer(session: session, fontSize: fontSize, themeID: "\(model.themeID)#\(model.themeRevision)")
            .overlay(alignment: .center) {
                if session.status == .connecting {
                    connectingOverlay
                }
            }
            .overlay(alignment: .bottom) {
                if !session.isLocal && (session.status == .error || session.status == .disconnected) {
                    reconnectBanner
                }
            }
    }

    private var connectingOverlay: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.accent)
            Text(session.statusMessage.isEmpty ? "正在连接…" : session.statusMessage)
                .font(.callout)
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 20)
        .transition(.opacity)
    }

    private var reconnectBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: session.status == .error ? "exclamationmark.triangle.fill" : "bolt.slash.fill")
                .foregroundStyle(session.status == .error ? Theme.danger : Theme.warning)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.status == .error ? "连接出错" : "连接已断开")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if !session.statusMessage.isEmpty {
                    Text(session.statusMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Button {
                session.reconnect()
            } label: {
                Label("重新连接", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .overlay(alignment: .top) { Rectangle().fill(Theme.surfaceLight).frame(height: 0.5) }
        .padding(.horizontal, 0)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
