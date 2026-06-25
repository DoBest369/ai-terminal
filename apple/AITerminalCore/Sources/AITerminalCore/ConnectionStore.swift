import Foundation

/// 连接配置与设置的本地持久化（JSON 存于 Application Support）。
public final class ConnectionStore: @unchecked Sendable {
    public static let shared = ConnectionStore()

    private let fileURL: URL
    private let snippetsURL: URL
    private let aiMessagesURL: URL
    private let conversationsURL: URL
    private let defaults = UserDefaults.standard
    private let aiConfigKey = "ai_config"

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
        self.fileURL = base.appendingPathComponent("connections.json")
        self.snippetsURL = base.appendingPathComponent("snippets.json")
        self.aiMessagesURL = base.appendingPathComponent("ai_messages.json")
        self.conversationsURL = base.appendingPathComponent("conversations.json")
    }

    // MARK: - 连接

    // 敏感字段（不写入明文 JSON，改存 Keychain）
    private enum Secret: String, CaseIterable {
        case password, passphrase, privateKeyText, jumpPassword
    }
    private func account(_ id: UUID, _ secret: Secret) -> String {
        "\(id.uuidString).\(secret.rawValue)"
    }

    public func loadConnections() -> [Connection] {
        guard let data = try? Data(contentsOf: fileURL),
              var conns = try? JSONDecoder().decode([Connection].self, from: data) else { return [] }
        for i in conns.indices {
            let id = conns[i].id
            // 密码仅在 savePassword 时回填
            if conns[i].savePassword, let pw = KeychainStore.get(account: account(id, .password)) {
                conns[i].password = pw
            }
            // 口令 / 私钥内容：Keychain 优先，否则保留 JSON 里的旧值（下次保存时迁移）
            if let pp = KeychainStore.get(account: account(id, .passphrase)) {
                conns[i].passphrase = pp
            }
            if let key = KeychainStore.get(account: account(id, .privateKeyText)) {
                conns[i].privateKeyText = key
            }
            if let jp = KeychainStore.get(account: account(id, .jumpPassword)) {
                conns[i].jumpPassword = jp
            }
        }
        return conns
    }

    public func saveConnections(_ connections: [Connection]) {
        var jsonSafe: [Connection] = []
        for c in connections {
            let id = c.id
            // 写入 Keychain（空值会删除对应项）
            KeychainStore.set(c.savePassword ? c.password : "", account: account(id, .password))
            KeychainStore.set(c.passphrase, account: account(id, .passphrase))
            KeychainStore.set(c.privateKeyText, account: account(id, .privateKeyText))
            KeychainStore.set(c.jumpPassword ?? "", account: account(id, .jumpPassword))
            // JSON 只存非敏感字段
            var safe = c
            safe.password = ""
            safe.passphrase = ""
            safe.privateKeyText = ""
            safe.jumpPassword = nil
            jsonSafe.append(safe)
        }
        guard let data = try? JSONEncoder().encode(jsonSafe) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 删除某连接在 Keychain 中的所有敏感字段
    public func deleteConnectionSecrets(id: UUID) {
        for secret in Secret.allCases {
            KeychainStore.delete(account: account(id, secret))
        }
    }

    // MARK: - AI 配置

    public func loadAIConfig() -> AIConfig {
        guard let data = defaults.data(forKey: aiConfigKey),
              let cfg = try? JSONDecoder().decode(AIConfig.self, from: data) else {
            return AIConfig()
        }
        return cfg
    }

    public func saveAIConfig(_ config: AIConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: aiConfigKey)
    }

    // MARK: - 命令片段

    /// 加载片段；文件不存在时返回默认片段
    public func loadSnippets() -> [CommandSnippet] {
        guard let data = try? Data(contentsOf: snippetsURL) else {
            return CommandSnippet.defaults
        }
        return (try? JSONDecoder().decode([CommandSnippet].self, from: data)) ?? CommandSnippet.defaults
    }

    public func saveSnippets(_ snippets: [CommandSnippet]) {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        try? data.write(to: snippetsURL, options: .atomic)
    }

    // MARK: - AI 对话历史（多会话）

    /// 加载会话列表。向后兼容：若无 conversations.json 但有旧 ai_messages.json，迁移成一个默认会话。
    public func loadConversations() -> [AIConversation] {
        if let data = try? Data(contentsOf: conversationsURL),
           let convs = try? JSONDecoder().decode([AIConversation].self, from: data) {
            return convs
        }
        // 迁移旧的单一对话
        if let data = try? Data(contentsOf: aiMessagesURL),
           let msgs = try? JSONDecoder().decode([ChatMessage].self, from: data), !msgs.isEmpty {
            var conv = AIConversation(messages: msgs)
            conv.title = conv.derivedTitle
            return [conv]
        }
        return []
    }

    public func saveConversations(_ conversations: [AIConversation]) {
        // 清掉旧单一对话文件（已迁移）
        try? FileManager.default.removeItem(at: aiMessagesURL)
        if conversations.isEmpty {
            try? FileManager.default.removeItem(at: conversationsURL)
            return
        }
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: conversationsURL, options: .atomic)
    }
}
