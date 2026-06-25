import Foundation

/// 一条可保存、可一键注入终端的快捷命令片段
public struct CommandSnippet: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var title: String
    public var command: String
    /// 分组名（可选；nil/空表示未分组）。Optional 保证旧 JSON 缺失时解码为 nil，向后兼容。
    public var group: String?

    public init(id: UUID = UUID(), title: String, command: String, group: String? = nil) {
        self.id = id
        self.title = title
        self.command = command
        self.group = group
    }

    /// 是否为高危命令（注入前提示）
    public var isDangerous: Bool {
        AIService.isDangerous(command)
    }

    /// 归一化的分组名（去空白；空则返回 ""）
    public var groupName: String {
        (group ?? "").trimmingCharacters(in: .whitespaces)
    }

    /// 首次使用时的默认片段（已分组）
    public static let defaults: [CommandSnippet] = [
        CommandSnippet(title: "列出文件", command: "ls -la", group: "文件"),
        CommandSnippet(title: "当前路径", command: "pwd", group: "文件"),
        CommandSnippet(title: "磁盘占用", command: "df -h", group: "系统"),
        CommandSnippet(title: "内存使用", command: "free -h || vm_stat", group: "系统"),
        CommandSnippet(title: "CPU/进程 Top", command: "top -b -n 1 | head -20 || top -l 1 | head -20", group: "系统"),
        CommandSnippet(title: "系统信息", command: "uname -a", group: "系统"),
        CommandSnippet(title: "占用端口", command: "ss -tlnp || netstat -tlnp", group: "网络"),
        CommandSnippet(title: "Git 状态", command: "git status", group: "Git")
    ]
}
