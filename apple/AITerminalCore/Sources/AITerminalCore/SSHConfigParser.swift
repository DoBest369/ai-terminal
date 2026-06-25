import Foundation

/// 解析 OpenSSH `~/.ssh/config`，把每个具体 Host 块转成 Connection。
/// 支持 Host / HostName / Port / User / IdentityFile；忽略通配 Host（含 * ?）。
public enum SSHConfigParser {

    private struct Block {
        var alias: String
        var hostName: String?
        var port: Int?
        var user: String?
        var identity: String?
    }

    public static func parse(_ text: String) -> [Connection] {
        var result: [Connection] = []
        var current: Block?

        func flush() {
            guard let b = current else { return }
            let host = (b.hostName?.isEmpty == false) ? b.hostName! : b.alias
            let auth: AuthType = (b.identity != nil) ? .privateKey : .password
            var conn = Connection(
                name: b.alias,
                host: host,
                port: b.port ?? 22,
                username: b.user ?? "",
                authType: auth
            )
            if let id = b.identity { conn.privateKeyPath = expandTilde(id) }
            result.append(conn)
        }

        for rawLine in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            // 拆成 key 与 value（分隔符：空白或 =）
            guard let splitIndex = line.firstIndex(where: { $0 == " " || $0 == "\t" || $0 == "=" }) else { continue }
            let key = line[..<splitIndex].lowercased()
            var value = line[line.index(after: splitIndex)...].trimmingCharacters(in: CharacterSet(charactersIn: " \t="))
            value = stripQuotes(value)

            switch key {
            case "host":
                flush()
                let firstPattern = value.split(separator: " ").first.map(String.init) ?? value
                if firstPattern.isEmpty || firstPattern.contains("*") || firstPattern.contains("?") {
                    current = nil
                } else {
                    current = Block(alias: firstPattern)
                }
            case "hostname":
                current?.hostName = value
            case "port":
                current?.port = Int(value)
            case "user":
                current?.user = value
            case "identityfile":
                if current?.identity == nil { current?.identity = value }
            default:
                break
            }
        }
        flush()
        return result.filter { !$0.host.isEmpty }
    }

    static func expandTilde(_ path: String) -> String {
        guard path.hasPrefix("~") else { return path }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return home + path.dropFirst()
    }

    static func stripQuotes(_ s: String) -> String {
        if s.count >= 2, s.hasPrefix("\""), s.hasSuffix("\"") {
            return String(s.dropFirst().dropLast())
        }
        return s
    }
}
