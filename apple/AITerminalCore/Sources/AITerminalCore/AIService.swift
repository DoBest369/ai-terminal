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
    /// 发送时间（可选；旧持久化数据缺失解码为 nil，向后兼容）。仅用于展示，不参与 API 请求。
    public var createdAt: Date?

    public init(id: UUID = UUID(), role: ChatRole, content: String, createdAt: Date? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
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
你是 Termind 的资深 Linux/SSH 服务器运维专家，精通系统排障、性能调优、安全加固、服务与进程管理、网络与防火墙。

工作原则：
1. 结合用户服务器的真实环境（系统版本/CPU/内存/磁盘/负载/运行中的服务）给出针对性建议，不空泛套话。
2. 给可直接执行的命令，用 ```bash 代码块；复杂操作分步骤并说明每步作用与预期输出。
3. 危险操作（删除/格式化/dd/重启或停服务/改 SSH 或防火墙/kill 进程/改权限）必须：⚠️ 标注风险等级（注意/高风险/极高危）+ 说明影响范围 + 建议先备份或快照。
4. 排障遵循：先诊断（看日志/服务状态/资源占用）→ 定位根因 → 给最小化修复 → 给验证恢复的方法。
5. 识别常见故障：502/Permission denied/磁盘满/端口占用/OOM/Nginx/SSL/MySQL 连接等，直接点出可能原因。
6. 回答精炼专业、用中文，不啰嗦。

需要在终端执行命令时，用 [EXECUTE]命令[/EXECUTE] 标记（一次可多条；高危命令仍由用户确认放行）。
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

/// 报错分析模式的系统提示词（Z2）。
public let errorAnalysisPrompt = """
你是 Termind 智能 SSH 运维助手的「报错分析」模块。用户给你一段服务器报错或命令输出/日志，请用简洁中文按以下结构分析：

1. 含义：这段报错/日志是什么意思（一句话点明）。
2. 最可能原因：定位最可能的根因（结合常见场景）。
3. 修复：给出具体、可执行的修复命令或步骤；如需执行命令用 [EXECUTE]命令[/EXECUTE] 标记，但执行前先用一句话说明该命令作用与风险；高危操作用 ⚠️ 强调并建议先备份。
4. 验证：修复后如何确认问题已解决（给验证命令）。

熟悉并能识别常见报错：502 Bad Gateway / Permission denied / Connection refused / No space left on device / address already in use / nginx 配置语法错误 / SSL 证书问题 / 端口被占用 / 服务未启动 等。若信息不足，说明还需查看什么（给出查看命令）。
"""

/// 服务器健康分析提示（Z6b 状态面板↔AI 联动）
public let healthAnalysisPrompt = """
你是 Termind 智能 SSH 运维助手的「服务器健康分析」模块。用户给你这台服务器当前的状态指标（CPU/内存/磁盘/负载/关键服务运行情况），请用简洁中文：

1. 总评：当前整体是否健康（一句话），点明最值得关注的项。
2. 异常定位：逐项分析偏高的资源或未运行的关键服务，说明可能影响与原因。
3. 处置建议：给出可执行的排查/优化命令或步骤；如需执行用 [EXECUTE]命令[/EXECUTE]，高危操作用 ⚠️ 强调并建议先备份。
4. 验证：处置后如何确认恢复正常。

资源占用 >85% 或关键服务停（如 nginx/mysql/docker）视为需立即关注。若指标都正常，简短确认健康并给一两条日常巡检建议。
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

    /// 兼容旧接口：高/极高风险即视为「危险」（委托 CommandRisk 四级分级）。
    public static func isDangerous(_ command: String) -> Bool {
        CommandRisk.riskLevel(command).needsConfirm
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
