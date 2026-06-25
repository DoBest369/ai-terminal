import Foundation
import NIOCore
import NIOSSH
import Crypto

/// 主机密钥变化错误（可能中间人攻击）
public struct HostKeyChangedError: LocalizedError {
    public let hostID: String
    public let expected: String
    public let got: String
    public var errorDescription: String? {
        "主机密钥已变化（可能存在中间人攻击）：\(hostID)\n记录指纹 \(expected)\n本次指纹 \(got)\n如确认服务器更换了密钥，可在设置中清除已知主机后重连。"
    }
}

/// 已知主机指纹的本地存储（host:port → SHA256 指纹），用于 TOFU 校验。
public final class KnownHostsStore: @unchecked Sendable {
    public static let shared = KnownHostsStore()

    private let fileURL: URL
    private let lock = NSLock()
    private var map: [String: String]

    public init(directory: URL? = nil) {
        let base: URL
        if let directory = directory {
            base = directory
        } else {
            let fm = FileManager.default
            let appSupport = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
                ?? fm.temporaryDirectory
            base = appSupport.appendingPathComponent("AITerminal", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("known_hosts.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.map = decoded
        } else {
            self.map = [:]
        }
    }

    public func fingerprint(for hostID: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return map[hostID]
    }

    public func record(_ fingerprint: String, for hostID: String) {
        lock.lock()
        map[hostID] = fingerprint
        let snapshot = map
        lock.unlock()
        persist(snapshot)
    }

    public func forget(_ hostID: String) {
        lock.lock()
        map.removeValue(forKey: hostID)
        let snapshot = map
        lock.unlock()
        persist(snapshot)
    }

    /// 清空所有已知主机
    public func clear() {
        lock.lock()
        map.removeAll()
        let snapshot = map
        lock.unlock()
        persist(snapshot)
    }

    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return map.count
    }

    /// 只读快照：所有已知主机（按 host 排序）
    public func all() -> [(host: String, fingerprint: String)] {
        lock.lock(); defer { lock.unlock() }
        return map.sorted { $0.key < $1.key }.map { (host: $0.key, fingerprint: $0.value) }
    }

    private func persist(_ snapshot: [String: String]) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 计算公钥的 SHA256 指纹（OpenSSH 风格 `SHA256:<base64>`）
    public static func fingerprint(of key: NIOSSHPublicKey) -> String {
        var buffer = ByteBufferAllocator().buffer(capacity: 256)
        _ = key.write(to: &buffer)
        let bytes = Data(buffer.readableBytesView)
        let digest = SHA256.hash(data: bytes)
        // OpenSSH 风格：base64 去掉结尾的 '='
        var b64 = Data(digest).base64EncodedString()
        while b64.hasSuffix("=") { b64.removeLast() }
        return "SHA256:" + b64
    }
}

/// TOFU（trust-on-first-use）主机密钥校验：首次记录指纹并接受，之后校验，不一致则失败。
public final class TOFUHostKeyValidator: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    private let hostID: String
    private let store: KnownHostsStore

    public init(hostID: String, store: KnownHostsStore = .shared) {
        self.hostID = hostID
        self.store = store
    }

    public func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        let fp = KnownHostsStore.fingerprint(of: hostKey)
        if let known = store.fingerprint(for: hostID) {
            if known == fp {
                validationCompletePromise.succeed(())
            } else {
                validationCompletePromise.fail(HostKeyChangedError(hostID: hostID, expected: known, got: fp))
            }
        } else {
            // 首次连接：信任并记录
            store.record(fp, for: hostID)
            validationCompletePromise.succeed(())
        }
    }
}
