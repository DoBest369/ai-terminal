import Foundation
import Network

/// 轻量可达性探测：只测 host:port 的 TCP 能否在超时内建立连接，不做 SSH 握手
/// （故不触发认证 / 主机密钥校验）。
public enum ReachabilityChecker {

    /// 探测 TCP 连通性。能在 timeout 内进入 .ready 即视为可达。
    public static func probe(host: String, port: Int, timeout: TimeInterval = 5) async -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, port > 0, port <= 65535 else { return false }
        let nwHost = NWEndpoint.Host(trimmed)
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return false }

        let params = NWParameters.tcp
        let connection = NWConnection(host: nwHost, port: nwPort, using: params)
        let queue = DispatchQueue(label: "com.aiterminal.reachability")

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            // 用一个 box + 锁保证只 resume 一次（成功 / 失败 / 超时三路竞争）
            let finished = LockedFlag()
            @Sendable func finish(_ reachable: Bool) {
                guard finished.setIfUnset() else { return }
                connection.cancel()
                continuation.resume(returning: reachable)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(false)
            }
        }
    }

    /// 探测并返回 TCP 建连延迟毫秒（可达时为耗时，不可达返回 nil）。对照 linux/windows 连接延迟显示。
    public static func probeLatency(host: String, port: Int, timeout: TimeInterval = 5) async -> Int? {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, port > 0, port <= 65535 else { return nil }
        let nwHost = NWEndpoint.Host(trimmed)
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return nil }
        let connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        let queue = DispatchQueue(label: "com.aiterminal.reachability.lat")
        let start = Date()
        return await withCheckedContinuation { (continuation: CheckedContinuation<Int?, Never>) in
            let finished = LockedFlag()
            @Sendable func finish(_ ms: Int?) {
                guard finished.setIfUnset() else { return }
                connection.cancel()
                continuation.resume(returning: ms)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(Int(Date().timeIntervalSince(start) * 1000))
                case .failed, .cancelled: finish(nil)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }
}

/// 极简一次性标志（线程安全），保证 continuation 只 resume 一次。
private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var set = false
    func setIfUnset() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if set { return false }
        set = true
        return true
    }
}
