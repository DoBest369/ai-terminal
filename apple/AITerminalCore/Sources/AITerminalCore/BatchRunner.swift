import Foundation

/// 单台服务器的群发结果（N-Multi）。
public struct BatchOutcome: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let output: String
    public let ok: Bool
    public init(id: UUID = UUID(), name: String, output: String, ok: Bool) {
        self.id = id; self.name = name; self.output = output; self.ok = ok
    }
}

/// 批量群发命令（N-Multi）：对多台服务器并发执行同一命令、聚合结果。
/// 执行闭包 runner 注入，便于自测（无需真实 SSH）；真实接入时传入走 SSHTerminalSession.runCommand 的闭包。
public enum BatchRunner {

    /// 并发对每个目标执行 runner，返回与输入同序的结果。
    public static func run<T: Sendable>(
        _ targets: [T],
        name: @Sendable (T) -> String,
        runner: @Sendable @escaping (T) async -> (output: String, ok: Bool)
    ) async -> [BatchOutcome] {
        await withTaskGroup(of: (Int, BatchOutcome).self) { group in
            for (i, t) in targets.enumerated() {
                let nm = name(t)   // 在任务外取名，避免逃逸闭包捕获 name
                group.addTask {
                    let r = await runner(t)
                    return (i, BatchOutcome(name: nm, output: r.output, ok: r.ok))
                }
            }
            var collected: [(Int, BatchOutcome)] = []
            for await item in group { collected.append(item) }
            return collected.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    /// 统计成功/失败台数。
    public static func summary(_ outcomes: [BatchOutcome]) -> (ok: Int, fail: Int) {
        let ok = outcomes.filter { $0.ok }.count
        return (ok, outcomes.count - ok)
    }

    /// 把群发结果拼成给 AI 汇总的素材（N-Multi-AI）。
    public static func composeForAI(command: String, _ outcomes: [BatchOutcome]) -> String {
        var s = "对 \(outcomes.count) 台服务器执行了同一命令：`\(command)`\n各自结果如下：\n"
        for o in outcomes {
            s += "\n【\(o.name)】\(o.ok ? "成功" : "失败")\n\(o.output.prefix(500))\n"
        }
        return s
    }
}
