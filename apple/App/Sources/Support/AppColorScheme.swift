import SwiftUI

/// 一套完整配色方案：UI 颜色 + 终端前景/背景/光标 + 16 色 ANSI 调色板。
struct AppColorScheme: Identifiable, Equatable {
    let id: String
    let name: String
    // UI
    let background: String
    let surface: String
    let surfaceLight: String
    let accent: String
    let textPrimary: String
    let textSecondary: String
    let success: String
    let warning: String
    let danger: String
    // 终端
    let termBackground: String
    let termForeground: String
    let termCaret: String
    let ansi: [String] // 16 色

    static let all: [AppColorScheme] = [midnight, oneDark, dracula, solarized, nord]

    static func by(id: String) -> AppColorScheme {
        all.first { $0.id == id } ?? midnight
    }

    /// 午夜（项目原配色，默认）
    static let midnight = AppColorScheme(
        id: "midnight", name: "午夜",
        background: "#1a1a2e", surface: "#16213e", surfaceLight: "#0f3460", accent: "#e94560",
        textPrimary: "#eeeeee", textSecondary: "#8b92a8", success: "#2ecc71", warning: "#f39c12", danger: "#e74c3c",
        termBackground: "#1a1a2e", termForeground: "#e6e6e6", termCaret: "#f39c12",
        ansi: ["#282c34", "#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2", "#abb2bf",
               "#5c6370", "#ff7b86", "#b5e890", "#ffd596", "#7cc5ff", "#dd9bf0", "#6fd6e2", "#ffffff"]
    )

    /// One Dark
    static let oneDark = AppColorScheme(
        id: "onedark", name: "One Dark",
        background: "#282c34", surface: "#21252b", surfaceLight: "#3e4451", accent: "#61afef",
        textPrimary: "#abb2bf", textSecondary: "#5c6370", success: "#98c379", warning: "#e5c07b", danger: "#e06c75",
        termBackground: "#282c34", termForeground: "#abb2bf", termCaret: "#61afef",
        ansi: ["#282c34", "#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2", "#abb2bf",
               "#5c6370", "#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2", "#ffffff"]
    )

    /// Dracula
    static let dracula = AppColorScheme(
        id: "dracula", name: "Dracula",
        background: "#282a36", surface: "#21222c", surfaceLight: "#44475a", accent: "#bd93f9",
        textPrimary: "#f8f8f2", textSecondary: "#6272a4", success: "#50fa7b", warning: "#f1fa8c", danger: "#ff5555",
        termBackground: "#282a36", termForeground: "#f8f8f2", termCaret: "#f1fa8c",
        ansi: ["#21222c", "#ff5555", "#50fa7b", "#f1fa8c", "#bd93f9", "#ff79c6", "#8be9fd", "#f8f8f2",
               "#6272a4", "#ff6e6e", "#69ff94", "#ffffa5", "#d6acff", "#ff92df", "#a4ffff", "#ffffff"]
    )

    /// Solarized Dark
    static let solarized = AppColorScheme(
        id: "solarized", name: "Solarized",
        background: "#002b36", surface: "#073642", surfaceLight: "#586e75", accent: "#268bd2",
        textPrimary: "#eee8d5", textSecondary: "#93a1a1", success: "#859900", warning: "#b58900", danger: "#dc322f",
        termBackground: "#002b36", termForeground: "#839496", termCaret: "#93a1a1",
        ansi: ["#073642", "#dc322f", "#859900", "#b58900", "#268bd2", "#d33682", "#2aa198", "#eee8d5",
               "#586e75", "#cb4b16", "#586e75", "#657b83", "#839496", "#6c71c4", "#93a1a1", "#fdf6e3"]
    )

    /// Nord
    static let nord = AppColorScheme(
        id: "nord", name: "Nord",
        background: "#2e3440", surface: "#3b4252", surfaceLight: "#434c5e", accent: "#88c0d0",
        textPrimary: "#eceff4", textSecondary: "#81a1c1", success: "#a3be8c", warning: "#ebcb8b", danger: "#bf616a",
        termBackground: "#2e3440", termForeground: "#d8dee9", termCaret: "#88c0d0",
        ansi: ["#3b4252", "#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#88c0d0", "#e5e9f0",
               "#4c566a", "#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#8fbcbb", "#eceff4"]
    )
}

// MARK: - 自定义主题

/// 用户可调的几个关键颜色（hex）；其余 UI 颜色由这几个派生。
struct CustomThemeColors: Codable, Equatable {
    var background: String
    var textPrimary: String
    var accent: String
    var caret: String

    static let `default` = CustomThemeColors(
        background: "#1e1e2e", textPrimary: "#e6e6e6", accent: "#89b4fa", caret: "#f5c2e7"
    )
}

extension AppColorScheme {
    static let customID = "custom"

    /// 由几个关键颜色派生一套完整「自定义」配色。
    static func makeCustom(_ c: CustomThemeColors) -> AppColorScheme {
        AppColorScheme(
            id: customID, name: "自定义",
            background: c.background,
            surface: mix(c.background, "#ffffff", 0.06),
            surfaceLight: mix(c.background, "#ffffff", 0.15),
            accent: c.accent,
            textPrimary: c.textPrimary,
            textSecondary: mix(c.textPrimary, c.background, 0.45),
            success: "#2ecc71", warning: "#f39c12", danger: "#e74c3c",
            termBackground: c.background, termForeground: c.textPrimary, termCaret: c.caret,
            ansi: midnight.ansi
        )
    }

    /// 在两个 hex 颜色之间线性插值（t=0 取 a，t=1 取 b）。
    static func mix(_ a: String, _ b: String, _ t: Double) -> String {
        let (ar, ag, ab) = hexRGB(a)
        let (br, bg, bb) = hexRGB(b)
        return rgbHex(ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t)
    }

    private static func hexRGB(_ hex: String) -> (Double, Double, Double) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return (0, 0, 0) }
        return (Double((v >> 16) & 0xff) / 255, Double((v >> 8) & 0xff) / 255, Double(v & 0xff) / 255)
    }

    private static func rgbHex(_ r: Double, _ g: Double, _ b: Double) -> String {
        func ch(_ x: Double) -> Int { max(0, min(255, Int((x * 255).rounded()))) }
        return String(format: "#%02x%02x%02x", ch(r), ch(g), ch(b))
    }
}

/// 当前生效的配色方案（全局）。AppModel 在启动与切换时更新它；
/// SwiftUI 视图通过 `Theme.*`（计算属性）读取，@Published 变更触发重渲染即生效。
var activeColorScheme: AppColorScheme = .midnight
