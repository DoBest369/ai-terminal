import Foundation

/// SSH 认证方式
public enum AuthType: String, Codable, Sendable, CaseIterable {
    case password
    case privateKey

    public var displayName: String {
        switch self {
        case .password: return "密码"
        case .privateKey: return "私钥"
        }
    }
}

/// 连接颜色标签（一眼区分环境）。rawValue 持久化，hex 供 UI。
public enum ColorTag: String, Codable, Sendable, CaseIterable {
    case none, red, orange, green, blue, purple

    /// 十六进制色（none 返回 nil）
    public var hex: String? {
        switch self {
        case .none: return nil
        case .red: return "#e74c3c"
        case .orange: return "#f39c12"
        case .green: return "#2ecc71"
        case .blue: return "#3498db"
        case .purple: return "#9b59b6"
        }
    }
}

/// 一条保存的 SSH 连接配置（会话模板）
public struct Connection: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var username: String
    public var authType: AuthType

    /// 密码（当 savePassword 为 true 时持久化）
    public var password: String
    /// 是否保存密码到磁盘
    public var savePassword: Bool

    /// 私钥文件路径（macOS）或导入的私钥内容（iOS）
    public var privateKeyPath: String
    /// 直接保存的私钥 PEM 文本（iOS 无文件系统访问时使用）
    public var privateKeyText: String
    /// 私钥口令
    public var passphrase: String

    /// 分组名（可选；nil/空表示未分组）。Optional 保证旧 JSON 缺失时解码为 nil，向后兼容。
    public var group: String?

    /// 跳板机（可选，密码认证）。配置后先连跳板再 jump 到目标。
    public var jumpHost: String?
    public var jumpPort: Int?
    public var jumpUsername: String?
    public var jumpPassword: String?

    /// 最近一次使用（打开会话）的时间。可选，旧数据/未用过为 nil；用于侧边栏排序。
    /// 设备相关，故不参与跨端导出（ConnectionPortability 不带此字段）。
    public var lastUsedAt: Date?

    /// 启动命令（多行，每行一条）。SSH shell 就绪后自动逐条执行。
    /// 属于连接配置的一部分，参与跨端导出。
    public var startupCommands: String?

    /// 该连接的终端字号覆盖（可选；nil 表示用全局字号）。属连接配置，参与跨端导出。
    public var fontSizeOverride: Double?

    /// 自由文本备注（可选）。属连接配置，参与跨端导出。
    public var note: String?

    /// 颜色标签（可选；Optional 保证旧 JSON 缺失时解码为 nil，向后兼容）。属连接配置，参与跨端导出。
    public var colorTag: ColorTag?

    public init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        port: Int = 22,
        username: String = "",
        authType: AuthType = .password,
        password: String = "",
        savePassword: Bool = false,
        privateKeyPath: String = "",
        privateKeyText: String = "",
        passphrase: String = "",
        group: String? = nil,
        jumpHost: String? = nil,
        jumpPort: Int? = nil,
        jumpUsername: String? = nil,
        jumpPassword: String? = nil,
        lastUsedAt: Date? = nil,
        startupCommands: String? = nil,
        fontSizeOverride: Double? = nil,
        note: String? = nil,
        colorTag: ColorTag? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authType = authType
        self.password = password
        self.savePassword = savePassword
        self.privateKeyPath = privateKeyPath
        self.privateKeyText = privateKeyText
        self.passphrase = passphrase
        self.group = group
        self.jumpHost = jumpHost
        self.jumpPort = jumpPort
        self.jumpUsername = jumpUsername
        self.jumpPassword = jumpPassword
        self.lastUsedAt = lastUsedAt
        self.startupCommands = startupCommands
        self.fontSizeOverride = fontSizeOverride
        self.note = note
        self.colorTag = colorTag
    }

    /// 归一化备注（去首尾空白；空则 ""）
    public var noteText: String {
        (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 启动命令按行拆分（去空行/首尾空白）
    public var startupCommandLines: [String] {
        (startupCommands ?? "")
            .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 归一化的分组名（去空白；空则视为未分组返回 ""）
    public var groupName: String {
        (group ?? "").trimmingCharacters(in: .whitespaces)
    }

    /// 是否配置了跳板机
    public var hasJump: Bool {
        !(jumpHost ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        && !(jumpUsername ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 展示用标题
    public var title: String {
        if !name.isEmpty { return name }
        if !username.isEmpty && !host.isEmpty { return "\(username)@\(host)" }
        return host.isEmpty ? "新连接" : host
    }

    public var subtitle: String {
        guard !host.isEmpty else { return "未配置" }
        return "\(username)@\(host):\(port)"
    }

    /// 校验配置是否可用于发起连接
    public var isValidForConnect: Bool {
        guard !host.isEmpty, !username.isEmpty else { return false }
        switch authType {
        case .password:
            return true // 密码可在连接时再输入
        case .privateKey:
            return !privateKeyPath.isEmpty || !privateKeyText.isEmpty
        }
    }

    /// 持久化前去除不应保存的敏感字段
    public func sanitizedForStorage() -> Connection {
        var copy = self
        if !savePassword {
            copy.password = ""
        }
        return copy
    }
}

/// 连接 / 会话状态
public enum SessionStatus: String, Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case error

    public var label: String {
        switch self {
        case .disconnected: return "未连接"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .error: return "错误"
        }
    }
}
