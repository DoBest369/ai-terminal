import SwiftUI

#if os(macOS)
import AppKit
public typealias PlatformViewRepresentable = NSViewRepresentable
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
#else
import UIKit
public typealias PlatformViewRepresentable = UIViewRepresentable
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
#endif

extension PlatformColor {
    /// 从 16 进制创建原生颜色
    convenience init(hexString: String) {
        let s = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8) & 0xFF) / 255
        let b = CGFloat(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    /// 从 16 进制创建颜色，如 "#1a1a2e"
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }

    /// 转回 16 进制字符串（用于把 ColorPicker 选的颜色存回）。
    func toHexString() -> String {
        let platform = PlatformColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if os(macOS)
        let rgb = platform.usingColorSpace(.sRGB) ?? platform
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        platform.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        func ch(_ x: CGFloat) -> Int { max(0, min(255, Int((x * 255).rounded()))) }
        return String(format: "#%02x%02x%02x", ch(r), ch(g), ch(b))
    }
}

extension View {
    /// iOS 26 液态玻璃面板：主题色半透明叠在原生 `.ultraThinMaterial`（毛玻璃）之上。
    /// 用于侧栏/AI 面板/设置/状态栏等容器；终端正文不要用（保持不透明可读）。
    func glassPanel(_ tint: Color = Theme.surface, opacity: Double = 0.5) -> some View {
        self
            .background(tint.opacity(opacity))
            .background(.ultraThinMaterial)
    }

    /// 浮层玻璃（弹窗/sheet）：更高不透明度 + 描边 + 阴影，保证内容可读。
    func glassOverlay(_ tint: Color = Theme.surface, opacity: Double = 0.62) -> some View {
        self
            .background(tint.opacity(opacity))
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.textPrimary.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 28, y: 14)
    }
}

/// 全局 UI 配色，读取当前 `activeColorScheme`，随主题切换生效
enum Theme {
    static var background: Color { Color(hex: activeColorScheme.background) }
    static var surface: Color { Color(hex: activeColorScheme.surface) }
    static var surfaceLight: Color { Color(hex: activeColorScheme.surfaceLight) }
    static var accent: Color { Color(hex: activeColorScheme.accent) }
    static var textPrimary: Color { Color(hex: activeColorScheme.textPrimary) }
    static var textSecondary: Color { Color(hex: activeColorScheme.textSecondary) }
    static var success: Color { Color(hex: activeColorScheme.success) }
    static var warning: Color { Color(hex: activeColorScheme.warning) }
    static var danger: Color { Color(hex: activeColorScheme.danger) }
}
