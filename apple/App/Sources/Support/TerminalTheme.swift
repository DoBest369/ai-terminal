import SwiftTerm
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 终端配色，读取当前 `activeColorScheme`，随主题切换生效。
enum TerminalTheme {
    static var background: String { activeColorScheme.termBackground }
    static var foreground: String { activeColorScheme.termForeground }
    static var caret: String { activeColorScheme.termCaret }

    /// 16 色 ANSI 调色板（来自当前方案）
    private static var ansiHex: [String] { activeColorScheme.ansi }

    /// SwiftTerm 使用 0–65535 的 16bit 颜色分量
    private static func swiftTermColor(_ hex: String) -> SwiftTerm.Color {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = UInt16((rgb >> 16) & 0xFF) * 257
        let g = UInt16((rgb >> 8) & 0xFF) * 257
        let b = UInt16(rgb & 0xFF) * 257
        return SwiftTerm.Color(red: r, green: g, blue: b)
    }

    /// 对终端视图应用配色与字体。
    static func apply(to view: TerminalView, fontSize: CGFloat = 13) {
        applyColors(to: view)
        view.font = monospacedFont(size: fontSize)
    }

    /// 仅应用当前方案的配色（主题切换时热更新）。
    static func applyColors(to view: TerminalView) {
        view.installColors(ansiHex.map(swiftTermColor))
        view.nativeForegroundColor = PlatformColor(hexString: foreground)
        view.nativeBackgroundColor = PlatformColor(hexString: background)
        view.caretColor = PlatformColor(hexString: caret)
    }

    /// 仅更新字号（缩放时调用）；尺寸不变则跳过避免重排。
    static func updateFontSize(_ view: TerminalView, size: CGFloat) {
        guard abs(view.font.pointSize - size) > 0.5 else { return }
        view.font = monospacedFont(size: size)
    }

    private static func monospacedFont(size: CGFloat) -> PlatformFont {
        #if os(macOS)
        return NSFont(name: "Menlo", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #else
        return UIFont(name: "Menlo", size: size) ?? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #endif
    }
}
