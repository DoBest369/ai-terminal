import Foundation

/// 主机系统信息快照（本地或远程通用）
public struct SystemInfo: Sendable, Equatable {
    public var hostname: String = ""
    public var cpuUsage: Double = 0      // 0-100
    public var cpuCores: Int = 0
    public var memUsed: UInt64 = 0       // bytes
    public var memTotal: UInt64 = 0      // bytes
    public var loadavg: [Double] = []
    public var uptime: String = ""
    public var diskUsed: UInt64 = 0      // bytes（根分区 /）
    public var diskTotal: UInt64 = 0     // bytes
    /// 关键服务运行状态：服务名 -> 是否 active（Z6）
    public var services: [String: Bool] = [:]
    /// CPU 是否已采到有效占用率（避免首帧 0% 误显）
    public var cpuSeen: Bool = false

    public init() {}

    public var memPercent: Double {
        guard memTotal > 0 else { return 0 }
        return Double(memUsed) / Double(memTotal) * 100
    }

    public var diskPercent: Double {
        guard diskTotal > 0 else { return 0 }
        return Double(diskUsed) / Double(diskTotal) * 100
    }

    /// 运行中 / 已停的关键服务（排序）
    public var runningServices: [String] { services.filter { $0.value }.keys.sorted() }
    public var stoppedServices: [String] { services.filter { !$0.value }.keys.sorted() }

    /// 健康摘要（供面板顶部 + 喂给 AI 排障，Z6 面板↔AI 联动）
    public var healthSummary: String {
        var parts: [String] = []
        if cpuSeen { parts.append("CPU \(Int(cpuUsage))%") }
        if memTotal > 0 { parts.append("内存 \(Int(memPercent))%") }
        if diskTotal > 0 { parts.append("磁盘 \(Int(diskPercent))%") }
        if !loadavg.isEmpty { parts.append("负载 \(loadavg.map { String(format: "%.2f", $0) }.joined(separator: "/"))") }
        let stopped = stoppedServices
        if !stopped.isEmpty { parts.append("⚠️ 未运行 \(stopped.joined(separator: ","))") }
        return parts.isEmpty ? "" : "服务器状态：" + parts.joined(separator: " · ")
    }

    /// 是否存在告警项（CPU/内存/磁盘 >85% 或有关键服务停了）
    public var hasWarning: Bool {
        (cpuSeen && cpuUsage > 85) || memPercent > 85 || diskPercent > 85 || !stoppedServices.isEmpty
    }
}

/// 远程系统信息采集：通过 SSH 执行命令并解析（兼容 Linux）。
public enum RemoteSystemMonitor {

    /// 一条聚合命令，便于一次性抓取。各字段以 `@@` 分隔行。
    private static let probe = """
    echo "HOST@@$(hostname)"; \
    echo "CORES@@$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null)"; \
    echo "UPTIME@@$(uptime | sed 's/.*up //' | sed 's/,.*user.*//')"; \
    echo "LOAD@@$(cat /proc/loadavg 2>/dev/null | awk '{print $1,$2,$3}')"; \
    echo "MEM@@$(cat /proc/meminfo 2>/dev/null | awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print t,a}')"; \
    echo "CPU@@$(grep 'cpu ' /proc/stat 2>/dev/null | awk '{idle=$5; total=0; for(i=2;i<=NF;i++) total+=$i; print idle,total}')"; \
    echo "DISK@@$(df -B1 / 2>/dev/null | tail -1 | awk '{print $2,$3}')"; \
    for s in nginx docker mysql redis sshd; do echo "SVC@@$s:$(systemctl is-active $s 2>/dev/null || echo unknown)"; done
    """

    /// 探测的关键服务（与 probe 一致）
    public static let probedServices = ["nginx", "docker", "mysql", "redis", "sshd"]

    public static func fetch(using session: SSHTerminalSession, previousCPU: (idle: Double, total: Double)?) async -> (info: SystemInfo, cpu: (idle: Double, total: Double)?) {
        let output = await session.runCommand(probe)
        return parse(output, previousCPU: previousCPU)
    }

    public static func parse(_ output: String, previousCPU: (idle: Double, total: Double)?) -> (info: SystemInfo, cpu: (idle: Double, total: Double)?) {
        var info = SystemInfo()
        var cpuSample: (idle: Double, total: Double)?

        for line in output.split(separator: "\n") {
            let parts = line.components(separatedBy: "@@")
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "HOST":
                info.hostname = value
            case "CORES":
                info.cpuCores = Int(value) ?? 0
            case "UPTIME":
                info.uptime = value
            case "LOAD":
                info.loadavg = value.split(separator: " ").compactMap { Double($0) }
            case "MEM":
                let nums = value.split(separator: " ").compactMap { UInt64($0) }
                if nums.count == 2 {
                    let totalKB = nums[0]
                    let availKB = nums[1]
                    info.memTotal = totalKB * 1024
                    info.memUsed = (totalKB > availKB ? totalKB - availKB : 0) * 1024
                }
            case "CPU":
                let nums = value.split(separator: " ").compactMap { Double($0) }
                if nums.count == 2 {
                    cpuSample = (idle: nums[0], total: nums[1])
                }
            case "DISK":
                let nums = value.split(separator: " ").compactMap { UInt64($0) }
                if nums.count == 2 { info.diskTotal = nums[0]; info.diskUsed = nums[1] }
            case "SVC":
                // 形如 nginx:active / docker:inactive / mysql:unknown
                let kv = value.split(separator: ":", maxSplits: 1).map(String.init)
                if kv.count == 2 && kv[1] != "unknown" { info.services[kv[0]] = (kv[1] == "active") }
            default:
                break
            }
        }

        // 用两次采样差值计算 CPU 占用率
        if let cur = cpuSample, let prev = previousCPU {
            let idleDelta = cur.idle - prev.idle
            let totalDelta = cur.total - prev.total
            if totalDelta > 0 {
                info.cpuUsage = max(0, min(100, (1 - idleDelta / totalDelta) * 100))
                info.cpuSeen = true
            }
        }

        return (info, cpuSample)
    }
}

/// 字节数格式化
public func formatBytes(_ bytes: UInt64) -> String {
    guard bytes > 0 else { return "0 B" }
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = Double(bytes)
    var idx = 0
    while value >= 1024 && idx < units.count - 1 {
        value /= 1024
        idx += 1
    }
    return String(format: "%.1f %@", value, units[idx])
}
