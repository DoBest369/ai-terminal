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

    /// 解析导出的 Markdown / 宽松文本为快捷命令（与 exportSnippets 对称）。
    /// 支持：`## 分组` 行设当前分组；`- **标题**：\`命令\`` 行；宽松 `标题|命令` / `标题=命令`。
    public static func parseImport(_ text: String) -> [CommandSnippet] {
        var result: [CommandSnippet] = []
        var currentGroup = ""
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") { currentGroup = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces); continue }
            if line.hasPrefix("# ") || line.isEmpty { continue }
            // - **标题**：`命令`
            if let r = line.range(of: #"^-\s*\*\*(.+?)\*\*\s*[:：]\s*`(.+)`\s*$"#, options: .regularExpression) {
                let m = String(line[r])
                if let t = m.range(of: #"\*\*(.+?)\*\*"#, options: .regularExpression),
                   let c = m.range(of: "`(.+)`", options: .regularExpression) {
                    let title = String(m[t].dropFirst(2).dropLast(2))
                    let cmd = String(m[c].dropFirst().dropLast())
                    result.append(CommandSnippet(title: title, command: cmd, group: currentGroup.isEmpty ? nil : currentGroup))
                }
                continue
            }
            // 宽松：标题|命令 或 标题=命令
            for sep in ["|", "="] where line.contains(sep) {
                let parts = line.split(separator: Character(sep), maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty {
                    result.append(CommandSnippet(title: parts[0], command: parts[1], group: currentGroup.isEmpty ? nil : currentGroup))
                }
                break
            }
        }
        return result
    }
}
