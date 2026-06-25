import Foundation

/// 连接配置的跨端交换格式（见 docs/connection-format.md）。
public enum ConnectionPortability {
    static let formatTag = "ai-terminal-connections"
    static let currentVersion = 1

    struct Envelope: Codable {
        var format: String
        var version: Int
        var connections: [Item]
    }

    struct Item: Codable {
        var name: String
        var host: String
        var port: Int
        var username: String
        var authType: String
        var group: String?
        var startupCommands: String?
        var fontSizeOverride: Double?
        var note: String?
        var colorTag: String?
        var password: String?
        var passphrase: String?
    }

    /// 导出为交换 JSON。`includeSecrets` 为 true 时才写入密码/口令（默认不含）。
    public static func export(_ connections: [Connection], includeSecrets: Bool = false) -> Data {
        let items = connections.map { c -> Item in
            Item(
                name: c.name,
                host: c.host,
                port: c.port,
                username: c.username,
                authType: c.authType.rawValue,
                group: c.groupName.isEmpty ? nil : c.groupName,
                startupCommands: (c.startupCommands?.isEmpty == false) ? c.startupCommands : nil,
                fontSizeOverride: c.fontSizeOverride,
                note: c.noteText.isEmpty ? nil : c.noteText,
                colorTag: (c.colorTag != nil && c.colorTag != .none) ? c.colorTag?.rawValue : nil,
                password: (includeSecrets && c.savePassword && !c.password.isEmpty) ? c.password : nil,
                passphrase: (includeSecrets && !c.passphrase.isEmpty) ? c.passphrase : nil
            )
        }
        let envelope = Envelope(format: formatTag, version: currentVersion, connections: items)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(envelope)) ?? Data()
    }

    public enum ImportError: LocalizedError {
        case invalidFormat
        public var errorDescription: String? { "文件格式无效，不是连接配置 JSON" }
    }

    /// 从交换 JSON 解析为新的 Connection 列表（各自新 id）。
    public static func parse(_ data: Data) throws -> [Connection] {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.format == formatTag else {
            throw ImportError.invalidFormat
        }
        return envelope.connections.map { item in
            let auth = AuthType(rawValue: item.authType) ?? .password
            let pw = item.password ?? ""
            let grp = item.group?.trimmingCharacters(in: .whitespaces)
            return Connection(
                name: item.name,
                host: item.host,
                port: item.port == 0 ? 22 : item.port,
                username: item.username,
                authType: auth,
                password: pw,
                savePassword: !pw.isEmpty,
                privateKeyPath: "",
                privateKeyText: "",
                passphrase: item.passphrase ?? "",
                group: (grp?.isEmpty == false) ? grp : nil,
                startupCommands: (item.startupCommands?.isEmpty == false) ? item.startupCommands : nil,
                fontSizeOverride: item.fontSizeOverride,
                note: (item.note?.isEmpty == false) ? item.note : nil,
                colorTag: item.colorTag.flatMap { ColorTag(rawValue: $0) }
            )
        }
    }
}
