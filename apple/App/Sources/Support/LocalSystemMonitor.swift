#if os(macOS)
import Foundation
import Darwin
import AITerminalCore

/// macOS 本地系统信息采集（使用 mach / sysctl）。
enum LocalSystemMonitor {
    // 上一次 CPU ticks，用于计算占用率
    private static var prevTotal: Double = 0
    private static var prevIdle: Double = 0

    static func snapshot() -> SystemInfo {
        var info = SystemInfo()
        info.hostname = ProcessInfo.processInfo.hostName
        info.cpuCores = ProcessInfo.processInfo.processorCount
        info.memTotal = ProcessInfo.processInfo.physicalMemory
        info.memUsed = usedMemory()
        info.cpuUsage = cpuUsage()
        info.loadavg = loadAverage()
        info.uptime = formatUptime(ProcessInfo.processInfo.systemUptime)
        return info
    }

    private static func usedMemory() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let pageSize = UInt64(vm_kernel_page_size)
        // 已用 = active + wired + compressed
        let used = (UInt64(stats.active_count)
                    + UInt64(stats.wire_count)
                    + UInt64(stats.compressor_page_count)) * pageSize
        return used
    }

    private static func cpuUsage() -> Double {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &cpuLoad) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = Double(cpuLoad.cpu_ticks.0)
        let system = Double(cpuLoad.cpu_ticks.1)
        let idle = Double(cpuLoad.cpu_ticks.2)
        let nice = Double(cpuLoad.cpu_ticks.3)
        let total = user + system + idle + nice

        defer {
            prevTotal = total
            prevIdle = idle
        }

        let totalDelta = total - prevTotal
        let idleDelta = idle - prevIdle
        guard totalDelta > 0 else { return 0 }
        return max(0, min(100, (1 - idleDelta / totalDelta) * 100))
    }

    private static func loadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        let count = getloadavg(&loads, 3)
        guard count == 3 else { return [] }
        return loads
    }

    private static func formatUptime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let days = s / 86400
        let hours = (s % 86400) / 3600
        let mins = (s % 3600) / 60
        if days > 0 { return "\(days)天\(hours)时" }
        if hours > 0 { return "\(hours)时\(mins)分" }
        return "\(mins)分钟"
    }
}
#endif
