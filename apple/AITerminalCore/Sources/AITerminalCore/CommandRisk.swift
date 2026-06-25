import Foundation

/// 命令风险四级分级（Z7）。
public enum CommandRisk: Int, Codable, Sendable, Comparable {
    case low = 0       // 只读/查看类
    case medium = 1    // 改普通文件/单文件权限
    case high = 2      // 重启服务/改配置/重载
    case critical = 3  // 删除/格式化/关 SSH/清防火墙

    public static func < (lhs: CommandRisk, rhs: CommandRisk) -> Bool { lhs.rawValue < rhs.rawValue }

    /// 中文标签
    public var label: String {
        switch self {
        case .low: return "安全"
        case .medium: return "注意"
        case .high: return "高风险"
        case .critical: return "极高危"
        }
    }

    /// 颜色建议（hex，供 UI 用）
    public var colorHex: String {
        switch self {
        case .low: return "#2ecc71"      // 绿
        case .medium: return "#f39c12"   // 橙
        case .high: return "#e67e22"     // 深橙
        case .critical: return "#e74c3c" // 红
        }
    }

    /// 是否需要二次确认（高/极高）
    public var needsConfirm: Bool { self >= .high }

    /// SF Symbol 建议
    public var icon: String {
        switch self {
        case .low: return "checkmark.shield"
        case .medium: return "exclamationmark.circle"
        case .high: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    // MARK: 规则

    /// 极高危：删除/格式化/关 SSH/清防火墙/关机等不可逆或致命操作。
    static let criticalPatterns = [
        "rm -rf", "rm -fr", ":(){", "mkfs", "dd if=", "> /dev/", "chmod -r 000",
        "shutdown", "reboot", "halt", "init 0", "forkbomb",
        "iptables -f", "ufw disable", "systemctl stop ssh", "systemctl stop sshd",
        "drop database", "truncate table", "> /etc/", "wipefs"
    ]

    /// 高风险：重启/重载服务、改配置、改权限递归、改防火墙、kill。
    static let highPatterns = [
        "systemctl restart", "systemctl reload", "systemctl stop", "systemctl start",
        "service ", "nginx -s reload", "nginx -s reS", "nginx -s stop",
        "ufw ", "iptables ", "firewall-cmd", "chown -r", "chmod -r", "chmod 777",
        "kill ", "killall", "pkill", "docker rm", "docker rmi", "docker stop",
        "apt remove", "apt purge", "yum remove", "dnf remove", "userdel", "passwd "
    ]

    /// 中风险：改单个文件/编辑/移动/安装。
    static let mediumPatterns = [
        "vim ", "vi ", "nano ", "sed -i", "tee ", "cp ", "mv ", "chmod ", "chown ",
        "mkdir ", "touch ", "ln -s", "apt install", "yum install", "dnf install",
        "npm install", "pip install", "git push", "git reset", "docker run"
    ]

    /// 判定一条命令的风险等级。匹配优先级 critical > high > medium > low。
    public static func riskLevel(_ command: String) -> CommandRisk {
        let c = command.lowercased()
        if criticalPatterns.contains(where: { c.contains($0) }) { return .critical }
        if highPatterns.contains(where: { c.contains($0) }) { return .high }
        if mediumPatterns.contains(where: { c.contains($0) }) { return .medium }
        return .low
    }
}

/// 敏感输出脱敏（Z7）：把密钥/密码/Token 等打码后再展示或发给 AI。
public enum Redactor {
    /// key=value 形式的敏感键（不区分大小写匹配键名）
    private static let sensitiveKeys = [
        "password", "passwd", "pwd", "secret", "secret_key", "api_key", "apikey",
        "api_token", "token", "access_key", "access_token", "private_key",
        "db_password", "database_password", "mysql_pwd", "redis_password", "auth"
    ]

    public static func redact(_ text: String) -> String {
        var s = text

        func replace(_ pattern: String, _ template: String, options: NSRegularExpression.Options = [.caseInsensitive]) {
            guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            let range = NSRange(s.startIndex..<s.endIndex, in: s)
            s = re.stringByReplacingMatches(in: s, range: range, withTemplate: template)
        }

        // key=value / key: value（保留键名，值打码）
        let keysAlt = sensitiveKeys.joined(separator: "|")
        replace("(?i)\\b(\(keysAlt))(\\s*[=:]\\s*)([^\\s\"']+)", "$1$2******")
        // OpenAI 风格 key、Bearer、AWS AKIA
        replace("sk-[A-Za-z0-9]{12,}", "sk-******", options: [])
        replace("(?i)Bearer\\s+[A-Za-z0-9._-]{8,}", "Bearer ******")
        replace("AKIA[0-9A-Z]{12,}", "AKIA******", options: [])
        // 私钥块
        replace("-----BEGIN [A-Z ]*PRIVATE KEY-----[\\s\\S]*?-----END [A-Z ]*PRIVATE KEY-----",
                "-----BEGIN PRIVATE KEY-----\n******（已脱敏）\n-----END PRIVATE KEY-----")
        return s
    }
}
