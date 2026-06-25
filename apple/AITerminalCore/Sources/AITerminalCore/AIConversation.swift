import Foundation

/// 一组独立的 AI 对话（多对话切换用）。
public struct AIConversation: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var title: String
    public var messages: [ChatMessage]
    /// 是否用户手动重命名过（true 时不再用 derivedTitle 自动覆盖）。Optional 向后兼容。
    public var titleIsCustom: Bool?
    /// 最后更新时间（消息变更时刷新）。Optional 向后兼容。
    public var updatedAt: Date?

    public init(id: UUID = UUID(), title: String = "新对话", messages: [ChatMessage] = [],
                titleIsCustom: Bool? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.messages = messages
        self.titleIsCustom = titleIsCustom
        self.updatedAt = updatedAt
    }

    /// 是否手动命名过
    public var isCustomTitle: Bool { titleIsCustom == true }

    /// 根据首条用户消息自动生成标题（前 20 字），无则「新对话」。
    public var derivedTitle: String {
        if let first = messages.first(where: { $0.role == .user })?.content
            .trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty {
            return String(first.prefix(20))
        }
        return "新对话"
    }
}
