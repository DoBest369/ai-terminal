import Foundation
import os

/// AI 子系统日志（流式解析诊断用）
let aiLog = Logger(subsystem: "com.aiterminal", category: "ai")

/// 聊天角色
public enum ChatRole: String, Codable, Sendable {
    case system, user, assistant
}

/// 一条聊天消息
public struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var role: ChatRole
    public var content: String

    public init(id: UUID = UUID(), role: ChatRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

/// AI 服务提供方
public enum AIProvider: String, Codable, Sendable, CaseIterable {
    case anthropic
    case openai

    public var displayName: String {
        switch self {
        case .anthropic: return "Anthropic Claude"
        case .openai: return "OpenAI"
        }
    }

    public var defaultModel: String {
        switch self {
        case .anthropic: return "claude-opus-4-8"
        case .openai: return "gpt-4o"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .anthropic: return "https://api.anthropic.com/v1"
        case .openai: return "https://api.openai.com/v1"
        }
    }

    /// 该 provider 的常用模型，用于设置界面快速选择
    public var commonModels: [String] {
        switch self {
        case .anthropic: return ["claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5"]
        case .openai: return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo"]
        }
    }
}

/// AI Agent 的默认系统提示词（用户可在设置里自定义；与原 Electron 版行为一致）
public let defaultAgentSystemPrompt = """
你是一个终端AI助手，可以帮助用户执行命令和管理系统。

当用户请求执行某些任务时，你应该：
1. 分析用户需求
2. 生成需要执行的命令
3. 使用 [EXECUTE] 标记来执行命令

命令格式：
[EXECUTE]命令内容[/EXECUTE]

注意：
- 危险命令（如 rm -rf /）需要先警告用户
- 一次可以执行多个命令
- 执行完命令后分析结果并给出建议
"""

/// 命令解释模式的系统提示词（Z1：只讲解，不执行）。
public let commandExplainPrompt = """
你是 Termind 智能 SSH 运维助手的「命令解释」模块。用户给你一条命令，你只负责讲解、绝不执行，也不要输出 [EXECUTE] 标记。

请用简洁中文按以下结构解释：
1. 作用：这条命令做什么（一句话）。
2. 关键参数：逐个解释重要参数/选项的含义。
3. 风险：是否会修改/删除文件、影响服务、需要 root；执行前要注意什么。
4. 安全等级：明确标注【安全】（只读/查看类）或【高危】（删除/格式化/重启/改防火墙/停 SSH 等），高危务必用 ⚠️ 强调并说明可能后果。

保持精炼，不要长篇大论。
"""

/// 系统提示词预设模板（一键套用）
public struct PromptPreset: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let text: String
    public init(id: String, name: String, text: String) {
        self.id = id; self.name = name; self.text = text
    }

    public static let all: [PromptPreset] = [
        PromptPreset(id: "default", name: "默认", text: defaultAgentSystemPrompt),
        PromptPreset(id: "readonly", name: "只读模式", text: """
        你是一个终端AI助手，仅协助用户查看与诊断系统，绝不执行任何会修改/删除/写入的操作。

        - 只生成只读类命令（如 ls/cat/df/top/ps/grep 等查看类）。
        - 涉及修改、删除、安装、重启等写操作时，只解释应如何手动操作，不要用 [EXECUTE] 自动执行。
        - 需要执行只读命令时用：[EXECUTE]命令内容[/EXECUTE]
        - 执行后分析结果。
        """),
        PromptPreset(id: "verbose", name: "详细解释", text: """
        你是一个终端AI助手，帮助用户执行命令并管理系统。

        每生成一条命令，都要在执行前用中文解释它的作用、关键参数含义、以及可能的风险。
        命令格式：[EXECUTE]命令内容[/EXECUTE]
        - 危险命令（如 rm -rf /）必须先明确警告。
        - 执行完命令后详细分析结果并给出后续建议。
        """),
        PromptPreset(id: "concise", name: "精简", text: """
        你是一个终端AI助手。直接给出完成任务所需的命令，少说废话。

        命令格式：[EXECUTE]命令内容[/EXECUTE]
        - 危险命令先一句话警告。
        - 可一次给多条命令。
        """)
    ]
}

/// AI 配置：记住每个 provider 各自的 Key / 模型 / 地址，切换不丢失
public struct AIConfig: Codable, Sendable, Equatable {
    public var provider: AIProvider
    /// provider.rawValue -> API Key
    public var keys: [String: String]
    /// provider.rawValue -> 模型覆盖（为空则用 provider.defaultModel）
    public var modelOverrides: [String: String]
    /// provider.rawValue -> baseURL 覆盖（为空则用 provider.defaultBaseURL）
    public var baseURLOverrides: [String: String]

    public init(provider: AIProvider = .anthropic,
                keys: [String: String] = [:],
                modelOverrides: [String: String] = [:],
                baseURLOverrides: [String: String] = [:]) {
        self.provider = provider
        self.keys = keys
        self.modelOverrides = modelOverrides
        self.baseURLOverrides = baseURLOverrides
    }

    public var apiKey: String {
        get { keys[provider.rawValue] ?? "" }
        set { keys[provider.rawValue] = newValue }
    }

    public var model: String {
        get {
            let v = modelOverrides[provider.rawValue] ?? ""
            return v.isEmpty ? provider.defaultModel : v
        }
        set { modelOverrides[provider.rawValue] = newValue }
    }

    public var baseURL: String {
        get {
            let v = baseURLOverrides[provider.rawValue] ?? ""
            return v.isEmpty ? provider.defaultBaseURL : v
        }
        set { baseURLOverrides[provider.rawValue] = newValue }
    }

    public var isConfigured: Bool { !apiKey.isEmpty }
}

public enum AIServiceError: LocalizedError {
    case notConfigured
    case badResponse(String)
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "尚未配置 API Key，请在设置中填写"
        case .badResponse(let m): return "AI 响应异常: \(m)"
        case .network(let m): return "网络错误: \(m)"
        }
    }
}

/// 从 AI 回复中解析出的待执行命令
public struct ParsedCommand: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let command: String
    /// 是否被判定为高危命令
    public let isDangerous: Bool
}

/// 调用 AI 接口的服务，支持 Anthropic（默认）与 OpenAI 兼容接口
public struct AIService: Sendable {
    public let config: AIConfig
    private let session: URLSession

    public init(config: AIConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// 发送整段对话，返回助手回复文本（非流式）
    public func complete(messages: [ChatMessage]) async throws -> String {
        guard config.isConfigured else { throw AIServiceError.notConfigured }
        let request = try makeURLRequest(messages: messages, stream: false)
        let data = try await send(request)
        switch config.provider {
        case .anthropic:
            let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            let text = decoded.content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
            guard !text.isEmpty else { throw AIServiceError.badResponse("无内容返回") }
            return text
        case .openai:
            let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content else {
                throw AIServiceError.badResponse("无内容返回")
            }
            return content
        }
    }

    /// 流式发送，逐块返回文本增量（SSE）
    public func completeStreaming(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [self] in
                do {
                    guard config.isConfigured else { throw AIServiceError.notConfigured }
                    let request = try makeURLRequest(messages: messages, stream: true)
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw AIServiceError.badResponse("无 HTTP 响应")
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        throw AIServiceError.badResponse("HTTP \(http.statusCode) \(body)")
                    }
                    let isAnthropic = config.provider == .anthropic
                    let decoder = JSONDecoder()
                    streamLoop: for try await line in bytes.lines {
                        // SSE 只关心 data: 行；event:/id:/空行/注释跳过
                        guard line.hasPrefix("data:") else { continue }
                        let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if payload.isEmpty { continue }
                        if payload == "[DONE]" { break }            // OpenAI 结束标记
                        guard let data = payload.data(using: .utf8) else { continue }

                        if isAnthropic {
                            do {
                                let ev = try decoder.decode(AnthropicStreamEvent.self, from: data)
                                switch ev.type {
                                case "content_block_delta":
                                    if ev.delta?.type == "text_delta", let text = ev.delta?.text {
                                        continuation.yield(text)
                                    }
                                case "message_stop":
                                    break streamLoop                // 正常结束
                                case "error":
                                    aiLog.error("Anthropic 流式错误事件: \(String(payload.prefix(160)), privacy: .public)")
                                default:
                                    break                           // message_start/ping/content_block_start/stop 等，正常跳过
                                }
                            } catch {
                                // 真正的解码失败（字段变更/脏数据）才记日志，不静默吞
                                aiLog.debug("SSE 解析失败(anthropic): \(String(payload.prefix(120)), privacy: .public)")
                            }
                        } else {
                            do {
                                let chunk = try decoder.decode(OpenAIStreamChunk.self, from: data)
                                if let text = chunk.choices.first?.delta.content {
                                    continuation.yield(text)
                                }
                            } catch {
                                aiLog.debug("SSE 解析失败(openai): \(String(payload.prefix(120)), privacy: .public)")
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 构建请求（stream 决定是否流式）
    private func makeURLRequest(messages: [ChatMessage], stream: Bool) throws -> URLRequest {
        switch config.provider {
        case .anthropic:
            guard let url = URL(string: "\(config.baseURL)/messages") else {
                throw AIServiceError.network("无效的 baseURL")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.timeoutInterval = 120
            let systemText = messages.first(where: { $0.role == .system })?.content
            let turns = messages
                .filter { $0.role != .system }
                .map { AnthropicMessage(role: $0.role == .assistant ? "assistant" : "user", content: $0.content) }
            request.httpBody = try JSONEncoder().encode(
                AnthropicRequest(model: config.model, maxTokens: 16000, system: systemText, messages: turns, stream: stream ? true : nil)
            )
            return request
        case .openai:
            guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
                throw AIServiceError.network("无效的 baseURL")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 120
            request.httpBody = try JSONEncoder().encode(
                OpenAIRequest(model: config.model, messages: messages.map { .init(role: $0.role.rawValue, content: $0.content) }, stream: stream ? true : nil)
            )
            return request
        }
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIServiceError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.badResponse("无 HTTP 响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIServiceError.badResponse("HTTP \(http.statusCode) \(body)")
        }
        return data
    }

    // MARK: - 命令解析

    private static let dangerousPatterns = [
        "rm -rf", "rm -fr", ":(){", "mkfs", "dd if=", "> /dev/", "chmod -r 000",
        "shutdown", "reboot", "halt", "init 0", "forkbomb"
    ]

    /// 从 AI 回复中提取 [EXECUTE]...[/EXECUTE] 命令
    public static func parseCommands(from text: String) -> [ParsedCommand] {
        var result: [ParsedCommand] = []
        let pattern = "\\[EXECUTE\\]([\\s\\S]*?)\\[/EXECUTE\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match, match.numberOfRanges >= 2,
                  let r = Range(match.range(at: 1), in: text) else { return }
            let cmd = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cmd.isEmpty else { return }
            result.append(ParsedCommand(command: cmd, isDangerous: isDangerous(cmd)))
        }
        return result
    }

    /// 把回复中的 [EXECUTE] 标记替换为可读文本（用于展示）
    public static func strippedDisplayText(from text: String) -> String {
        let pattern = "\\[EXECUTE\\]([\\s\\S]*?)\\[/EXECUTE\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "▶ $1")
    }

    public static func isDangerous(_ command: String) -> Bool {
        let lower = command.lowercased()
        return dangerousPatterns.contains { lower.contains($0) }
    }
}

// MARK: - Anthropic 数据结构

private struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [AnthropicMessage]
    var stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case stream
    }
}

private struct AnthropicResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }
    let content: [Block]
}

/// Anthropic SSE 事件（content_block_delta → text_delta）
private struct AnthropicStreamEvent: Decodable {
    struct Delta: Decodable {
        let type: String?
        let text: String?
    }
    let type: String
    let delta: Delta?
}

// MARK: - OpenAI 数据结构

private struct OpenAIRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    let model: String
    let messages: [Message]
    var stream: Bool?
}

private struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}

/// OpenAI SSE chunk（choices[].delta.content）
private struct OpenAIStreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }
    let choices: [Choice]
}
