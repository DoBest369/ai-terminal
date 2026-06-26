import Foundation

/// 命令收藏夹：常用命令加星标，跨连接快捷复用（对齐 android CommandFavorites）。
public enum CommandFavorites {
    private static let key = "termind.command.favorites"

    public static func load(defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    public static func isFavorite(_ cmd: String, defaults: UserDefaults = .standard) -> Bool {
        load(defaults: defaults).contains(cmd.trimmingCharacters(in: .whitespaces))
    }

    /// 纯逻辑：切换收藏（已收藏则取消，否则置顶加入）。便于自测。
    public static func toggled(_ list: [String], _ cmd: String) -> [String] {
        let c = cmd.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty else { return list }
        if list.contains(c) { return list.filter { $0 != c } }
        return [c] + list
    }

    @discardableResult
    public static func toggle(_ cmd: String, defaults: UserDefaults = .standard) -> [String] {
        let next = toggled(load(defaults: defaults), cmd)
        defaults.set(next, forKey: key)
        return next
    }
}
