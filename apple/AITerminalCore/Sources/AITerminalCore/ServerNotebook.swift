import Foundation

/// 服务器知识卡片的一条记录（差异化护城河：每台机沉淀历史问题/解决方案/运维笔记）。
public struct ServerNote: Identifiable, Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case issue      // 历史问题（出过的故障）
        case solution   // 解决方案
        case note       // 一般笔记/备忘

        public var label: String {
            switch self {
            case .issue: return "问题"
            case .solution: return "方案"
            case .note: return "笔记"
            }
        }
    }

    public var id: UUID
    public var kind: Kind
    public var text: String
    public var createdAt: Date

    public init(id: UUID = UUID(), kind: Kind = .note, text: String, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.text = text
        self.createdAt = createdAt
    }
}

/// 服务器知识卡片：按连接 id 关联一组 ServerNote，持久化于 UserDefaults。
/// 让运维经验沉淀到每台机器上（PRODUCT MVP 差异化项）。对齐双端逻辑。
public enum ServerNotebook {
    private static func key(_ connectionID: String) -> String { "termind.notebook.\(connectionID)" }

    /// 纯逻辑：新增一条（置顶最新）。便于自测。
    public static func adding(_ notes: [ServerNote], _ note: ServerNote) -> [ServerNote] {
        let t = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return notes }
        return [note] + notes
    }

    /// 纯逻辑：删除一条。
    public static func removing(_ notes: [ServerNote], id: UUID) -> [ServerNote] {
        notes.filter { $0.id != id }
    }

    // MARK: 持久化

    public static func load(connectionID: String, defaults: UserDefaults = .standard) -> [ServerNote] {
        guard let data = defaults.data(forKey: key(connectionID)),
              let notes = try? JSONDecoder().decode([ServerNote].self, from: data) else { return [] }
        return notes
    }

    public static func save(_ notes: [ServerNote], connectionID: String, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(notes) {
            defaults.set(data, forKey: key(connectionID))
        }
    }

    @discardableResult
    public static func add(_ note: ServerNote, connectionID: String, defaults: UserDefaults = .standard) -> [ServerNote] {
        let next = adding(load(connectionID: connectionID, defaults: defaults), note)
        save(next, connectionID: connectionID, defaults: defaults)
        return next
    }

    @discardableResult
    public static func remove(id: UUID, connectionID: String, defaults: UserDefaults = .standard) -> [ServerNote] {
        let next = removing(load(connectionID: connectionID, defaults: defaults), id: id)
        save(next, connectionID: connectionID, defaults: defaults)
        return next
    }

    /// 拼接成给 AI 的上下文素材（让 AI 排障时参考这台机的历史）。
    public static func composeForAI(_ notes: [ServerNote]) -> String {
        guard !notes.isEmpty else { return "" }
        let lines = notes.map { "· [\($0.kind.label)] \($0.text)" }
        return "这台服务器的历史运维记录：\n" + lines.joined(separator: "\n")
    }

    /// 导出为 Markdown（按 问题/方案/笔记 三类分组），便于团队共享运维经验。
    public static func exportMarkdown(_ notes: [ServerNote], serverName: String = "") -> String {
        let title = serverName.isEmpty ? "服务器知识卡片" : "知识卡片 · \(serverName)"
        var md = "# \(title)\n"
        for kind in ServerNote.Kind.allCases {
            let group = notes.filter { $0.kind == kind }
            guard !group.isEmpty else { continue }
            md += "\n## \(kind.label)\n"
            for n in group { md += "- \(n.text)\n" }
        }
        return md
    }
}
