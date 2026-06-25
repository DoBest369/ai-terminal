import SwiftUI

/// 主题预览缩略图：背景色块 + 几行前景色「文字」+ 一行强调色，模拟迷你终端。
/// 纯 Rectangle/Capsule 实现，可被 ImageRenderer 离屏渲染。
struct ThemeThumbnail: View {
    let background: String
    let foreground: String
    let accent: String
    let name: String
    var selected: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 5).fill(Color(hex: background))
                VStack(alignment: .leading, spacing: 3) {
                    Capsule().fill(Color(hex: foreground)).frame(width: 20, height: 2.5)
                    Capsule().fill(Color(hex: foreground).opacity(0.65)).frame(width: 13, height: 2.5)
                    Capsule().fill(Color(hex: accent)).frame(width: 9, height: 2.5)
                }
                .padding(6)
            }
            .frame(width: 40, height: 28)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(selected ? Theme.textPrimary : Theme.surfaceLight,
                            lineWidth: selected ? 2 : 1)
            )
            Text(name)
                .font(.system(size: 9))
                .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(1)
        }
    }
}
