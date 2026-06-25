import Foundation

/// 服务器环境画像（Z3 环境感知）。连接后探测真实环境，做成「服务器卡片」喂给 AI。
public struct ServerProfile: Codable, Sendable, Equatable {
    public var hostname: String
    public var os: String          // 如 "Linux"
    public var distro: String      // 如 "Ubuntu 22.04.3 LTS"
    public var kernel: String      // uname -r
    public var arch: String        // uname -m
    public var currentUser: String
    public var isRoot: Bool
    public var packageManager: String   // apt / yum / dnf / apk / 空
    /// 服务名 -> 是否已安装（nginx/docker/node/...）
    public var services: [String: Bool]
    public var detectedAt: Date?

    public init(hostname: String = "", os: String = "", distro: String = "", kernel: String = "",
                arch: String = "", currentUser: String = "", isRoot: Bool = false,
                packageManager: String = "", services: [String: Bool] = [:], detectedAt: Date? = nil) {
        self.hostname = hostname; self.os = os; self.distro = distro; self.kernel = kernel
        self.arch = arch; self.currentUser = currentUser; self.isRoot = isRoot
        self.packageManager = packageManager; self.services = services; self.detectedAt = detectedAt
    }

    /// 已安装的服务列表（排序）
    public var installedServices: [String] { services.filter { $0.value }.keys.sorted() }
    /// 未安装的服务列表（排序）
    public var missingServices: [String] { services.filter { !$0.value }.keys.sorted() }

    /// 给 AI 的一行环境摘要（用作上下文）
    public var aiSummary: String {
        guard !distro.isEmpty || !os.isEmpty else { return "" }
        var parts: [String] = []
        parts.append("系统 \(distro.isEmpty ? os : distro)\(arch.isEmpty ? "" : " (\(arch))")")
        if !currentUser.isEmpty { parts.append("用户 \(currentUser)\(isRoot ? "(root)" : "")") }
        if !packageManager.isEmpty { parts.append("包管理器 \(packageManager)") }
        let inst = installedServices, miss = missingServices
        if !inst.isEmpty { parts.append("已装 \(inst.joined(separator: ","))") }
        if !miss.isEmpty { parts.append("未装 \(miss.joined(separator: ","))") }
        return "当前服务器环境：" + parts.joined(separator: " · ")
    }
}

/// 环境探测命令与解析（Z3）。
public enum EnvDetector {
    /// 待检测的服务（which 判断）
    public static let probedServices = ["nginx", "docker", "node", "npm", "python3", "mysql", "redis", "pm2", "git", "java"]

    /// 一条复合探测命令：用唯一分隔符把各段输出拼起来，便于解析。
    /// 远端跑这条，把结果整段传回 parse(_:)。
    public static var detectCommand: String {
        let whichLines = probedServices.map { "echo \"SVC:\($0):$(command -v \($0) >/dev/null 2>&1 && echo 1 || echo 0)\"" }.joined(separator: "; ")
        return [
            "echo \"HOST:$(hostname 2>/dev/null)\"",
            "echo \"UNAME:$(uname -s) $(uname -r) $(uname -m)\"",
            "echo \"USER:$(id -un 2>/dev/null) $(id -u 2>/dev/null)\"",
            "( cat /etc/os-release 2>/dev/null | sed 's/^/OSREL:/' )",
            "for pm in apt dnf yum apk pacman; do command -v $pm >/dev/null 2>&1 && echo \"PM:$pm\" && break; done",
            whichLines
        ].joined(separator: "; ")
    }

    /// 解析 detectCommand 的整段输出为 ServerProfile。
    public static func parse(_ output: String, now: Date? = nil) -> ServerProfile {
        var p = ServerProfile()
        var services: [String: Bool] = [:]
        for raw in output.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("HOST:") {
                p.hostname = String(line.dropFirst(5))
            } else if line.hasPrefix("UNAME:") {
                let parts = String(line.dropFirst(6)).split(separator: " ")
                if parts.count >= 1 { p.os = String(parts[0]) }
                if parts.count >= 2 { p.kernel = String(parts[1]) }
                if parts.count >= 3 { p.arch = String(parts[2]) }
            } else if line.hasPrefix("USER:") {
                let parts = String(line.dropFirst(5)).split(separator: " ")
                if parts.count >= 1 { p.currentUser = String(parts[0]) }
                if parts.count >= 2 { p.isRoot = (parts[1] == "0") }
            } else if line.hasPrefix("OSREL:") {
                let kv = String(line.dropFirst(6))
                if kv.hasPrefix("PRETTY_NAME=") {
                    p.distro = kv.dropFirst("PRETTY_NAME=".count)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
            } else if line.hasPrefix("PM:") {
                p.packageManager = String(line.dropFirst(3))
            } else if line.hasPrefix("SVC:") {
                let kv = String(line.dropFirst(4)).split(separator: ":")
                if kv.count == 2 { services[String(kv[0])] = (kv[1] == "1") }
            }
        }
        p.services = services
        p.detectedAt = now
        return p
    }
}
