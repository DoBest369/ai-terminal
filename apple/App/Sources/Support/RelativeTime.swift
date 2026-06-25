import Foundation

/// 相对时间短描述（侧边栏连接、AI 会话等共用）。纯函数，依赖当前时间。
enum RelativeTime {
    static func string(_ date: Date) -> String {
        let s = Date().timeIntervalSince(date)
        if s < 60 { return "刚刚" }
        if s < 3600 { return "\(Int(s / 60)) 分钟前" }
        if s < 86400 { return "\(Int(s / 3600)) 小时前" }
        if s < 86400 * 7 { return "\(Int(s / 86400)) 天前" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        return fmt.string(from: date)
    }
}
