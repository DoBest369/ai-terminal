import Foundation

/// 命令历史（N-History）：最近执行命令（去重、置顶、限长）。对齐 android CommandHistory。
public enum CommandHistory {
    public static let limit = 50
    private static let key = "termind.command.history"

    /// 纯逻辑：把 cmd 加入 list（去重→置顶→截断到 limit）。便于自测。
    public static func updated(_ list: [String], adding cmd: String, limit: Int = limit) -> [String] {
        let c = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return list }
        var result = list.filter { $0 != c }   // 去重
        result.insert(c, at: 0)                 // 置顶
        if result.count > limit { result = Array(result.prefix(limit)) }
        return result
    }

    // MARK: 持久化（UserDefaults）

    public static func load(defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    @discardableResult
    public static func add(_ cmd: String, defaults: UserDefaults = .standard) -> [String] {
        let next = updated(load(defaults: defaults), adding: cmd)
        defaults.set(next, forKey: key)
        return next
    }

    @discardableResult
    public static func remove(_ cmd: String, defaults: UserDefaults = .standard) -> [String] {
        let next = load(defaults: defaults).filter { $0 != cmd }
        defaults.set(next, forKey: key)
        return next
    }

    public static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
