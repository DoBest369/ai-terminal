import Foundation

/// 操作回滚 / 可恢复操作链路（Z5）：改关键配置前自动备份、记录时间线、一键回滚。
public enum OpRollback {
    /// 关键配置文件路径前缀（命中即视为高价值、改前应备份）。
    public static let criticalPrefixes = [
        "/etc/nginx/nginx.conf",
        "/etc/nginx/sites-",
        "/etc/nginx/conf.d/",
        "/etc/ssh/sshd_config",
        "/etc/mysql/",
        "/etc/my.cnf",
        "/etc/redis/",
        "/etc/hosts",
        "/etc/fstab",
        "/etc/crontab",
        "/etc/sudoers"
    ]

    /// 判断一个路径是否关键配置。
    public static func isCriticalConfig(_ path: String) -> Bool {
        let p = path.trimmingCharacters(in: .whitespaces)
        return criticalPrefixes.contains { p.hasPrefix($0) }
    }

    /// 从一条命令里提取它会修改的关键配置路径（识别 vim/nano/编辑/重定向/cp 覆盖等写操作目标）。
    /// 仅做轻量启发式：扫描命令里出现的关键路径，且命令包含写意图关键字。
    public static func criticalTargets(in command: String) -> [String] {
        let writeVerbs = ["vim ", "vi ", "nano ", "tee ", "cp ", "mv ", "sed -i", ">", ">>", "echo "]
        let hasWrite = writeVerbs.contains { command.contains($0) }
        guard hasWrite else { return [] }
        // 找出命令中出现的关键路径（按前缀匹配 token）
        var hits: [String] = []
        for token in command.split(whereSeparator: { " \t\"'><|;&".contains($0) }) {
            let t = String(token)
            if isCriticalConfig(t) { hits.append(t) }
        }
        return Array(Set(hits)).sorted()
    }

    /// 生成备份命令：`cp <path> <path>.bak-<stamp>`。stamp 由调用方传入（避免 Date.now 在测试不可用）。
    public static func backupCommand(for path: String, stamp: String) -> String {
        "cp \(path) \(path).bak-\(stamp)"
    }

    /// 给一条会改关键配置的命令生成「先备份」前缀命令组（每个目标一条 cp）。
    public static func backupCommands(forCommand command: String, stamp: String) -> [String] {
        criticalTargets(in: command).map { backupCommand(for: $0, stamp: stamp) }
    }

    /// sshd 类危险操作（改 sshd_config / 重启 ssh）的自动回滚命令文本：
    /// 备份 + N 分钟后若未取消则自动还原并重启 sshd，防止改错配置把自己锁在门外。
    public static func sshAutoRollbackCommand(minutes: Int, stamp: String) -> String {
        let cfg = "/etc/ssh/sshd_config"
        let bak = "\(cfg).bak-\(stamp)"
        return "cp \(cfg) \(bak); echo \"cp \(bak) \(cfg) && systemctl restart sshd\" | at now + \(minutes) minutes"
    }
}

/// 操作时间线条目（Z5）：记录关键操作，便于复盘/回滚。
public struct OpTimelineEntry: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var time: Date
    public var action: String        // 人类可读动作描述
    public var command: String       // 实际命令
    public var rollbackable: Bool     // 是否可回滚
    public var backupPath: String?    // 备份文件路径（用于回滚）

    public init(id: UUID = UUID(), time: Date, action: String, command: String,
                rollbackable: Bool = false, backupPath: String? = nil) {
        self.id = id; self.time = time; self.action = action; self.command = command
        self.rollbackable = rollbackable; self.backupPath = backupPath
    }

    /// 回滚命令：把备份还原回原路径（需 backupPath 形如 <orig>.bak-<stamp>）。
    public var rollbackCommand: String? {
        guard rollbackable, let bak = backupPath else { return nil }
        // 从 .bak-<stamp> 还原原路径
        guard let range = bak.range(of: ".bak-") else { return nil }
        let orig = String(bak[bak.startIndex..<range.lowerBound])
        return "cp \(bak) \(orig)"
    }
}
