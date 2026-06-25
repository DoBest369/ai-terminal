import SwiftUI

/// 终端辅助键栏：为缺少 Esc/Tab/Ctrl/方向键的触屏键盘补齐常用按键。
/// 主要用于 iOS / iPadOS（SSH 会话）。
struct TerminalKeyBar: View {
    @ObservedObject var session: TerminalSessionVM

    /// 一个辅助键定义
    private struct Key: Identifiable {
        let id = UUID()
        let label: String
        let bytes: [UInt8]
        var wide: Bool = false
    }

    private let keys: [Key] = [
        Key(label: "Esc", bytes: [0x1b], wide: true),
        Key(label: "Tab", bytes: [0x09], wide: true),
        Key(label: "^C", bytes: [0x03]),
        Key(label: "^D", bytes: [0x04]),
        Key(label: "^Z", bytes: [0x1a]),
        Key(label: "^L", bytes: [0x0c]),
        Key(label: "^R", bytes: [0x12]),
        Key(label: "^U", bytes: [0x15]),
        Key(label: "↑", bytes: [0x1b, 0x5b, 0x41]),
        Key(label: "↓", bytes: [0x1b, 0x5b, 0x42]),
        Key(label: "←", bytes: [0x1b, 0x5b, 0x44]),
        Key(label: "→", bytes: [0x1b, 0x5b, 0x43]),
        Key(label: "|", bytes: Array("|".utf8)),
        Key(label: "~", bytes: Array("~".utf8)),
        Key(label: "/", bytes: Array("/".utf8)),
        Key(label: "-", bytes: Array("-".utf8)),
        Key(label: "*", bytes: Array("*".utf8)),
        Key(label: "$", bytes: Array("$".utf8))
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(keys) { key in
                    Button {
                        session.sendBytes(key.bytes)
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                    } label: {
                        Text(key.label)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(minWidth: key.wide ? 46 : 34, minHeight: 34)
                            .background(Theme.surfaceLight)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(Theme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.surfaceLight).frame(height: 0.5)
        }
    }
}
