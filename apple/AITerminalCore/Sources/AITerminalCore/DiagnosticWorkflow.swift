import Foundation

/// 场景化排障工作流（Z4）：一键跑一串诊断命令 → AI 总结结论。
public struct DiagnosticWorkflow: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var icon: String          // SF Symbol
    public var description: String
    public var commands: [String]    // 依次执行的只读诊断命令
    public var summaryPrompt: String // 让 AI 据输出总结的提示

    public init(id: String, name: String, icon: String, description: String,
                commands: [String], summaryPrompt: String) {
        self.id = id; self.name = name; self.icon = icon; self.description = description
        self.commands = commands; self.summaryPrompt = summaryPrompt
    }

    /// 把「工作流名 + 各命令及其输出」拼成给 AI 的分析素材。
    /// outputs 与 commands 一一对应（未跑到的可缺省）。
    public func composeForAI(outputs: [String: String]) -> String {
        var s = "【排障工作流：\(name)】\n以下是依次执行的诊断命令及输出，请据此分析：\n"
        for cmd in commands {
            let out = outputs[cmd] ?? "(未获取到输出)"
            s += "\n$ \(cmd)\n\(out)\n"
        }
        return s
    }

    /// 内置排障工作流（覆盖 PRODUCT.md 重点场景）。命令均为只读诊断类。
    public static let builtins: [DiagnosticWorkflow] = [
        DiagnosticWorkflow(
            id: "web-down", name: "网站打不开排查", icon: "globe.badge.chevron.backward",
            description: "依次检查 Nginx/端口/本地访问/磁盘/配置/日志，定位网站无法访问原因",
            commands: [
                "systemctl status nginx --no-pager",
                "ss -tlnp",
                "curl -I -s -m 5 localhost",
                "df -h",
                "nginx -t",
                "journalctl -u nginx -n 50 --no-pager"
            ],
            summaryPrompt: "你是运维排障助手。根据上述「网站打不开排查」各命令输出，给出：① 结论（网站为何打不开）② 最可能的根因及定位（指明哪条命令的哪个迹象）③ 具体可执行的修复建议。精炼中文。"
        ),
        DiagnosticWorkflow(
            id: "disk-clean", name: "磁盘清理分析", icon: "internaldrive",
            description: "分析磁盘占用大头（系统/Docker/日志），给出可清理项",
            commands: [
                "df -h",
                "du -sh /* 2>/dev/null | sort -rh | head -15",
                "docker system df 2>/dev/null",
                "journalctl --disk-usage 2>/dev/null"
            ],
            summaryPrompt: "你是运维排障助手。根据上述磁盘占用输出，给出：① 占用大头排序 ② 哪些可安全清理及预计释放量 ③ 清理命令（标注风险，删除类用 ⚠️ 并建议先确认）。精炼中文。"
        ),
        DiagnosticWorkflow(
            id: "ssl-check", name: "SSL 证书检查", icon: "lock.shield",
            description: "检查站点 SSL 证书有效期、Nginx SSL 配置",
            commands: [
                "nginx -t",
                "ls -l /etc/letsencrypt/live/ 2>/dev/null",
                "for d in $(ls /etc/letsencrypt/live/ 2>/dev/null); do echo \"== $d ==\"; echo | openssl s_client -servername $d -connect localhost:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null; done"
            ],
            summaryPrompt: "你是运维排障助手。根据上述 SSL 检查输出，给出：① 各证书的到期时间与剩余天数 ② 是否有即将过期（<15 天）或配置问题 ③ 续期/修复建议（如 certbot renew）。精炼中文。"
        ),
        DiagnosticWorkflow(
            id: "nginx-status", name: "Nginx 状态检查", icon: "server.rack",
            description: "检查 Nginx 运行状态、配置语法、站点与错误日志",
            commands: [
                "systemctl status nginx --no-pager",
                "nginx -t",
                "nginx -T 2>/dev/null | grep -E 'server_name|listen|root' | head -30",
                "journalctl -u nginx -n 30 --no-pager"
            ],
            summaryPrompt: "你是运维排障助手。根据上述 Nginx 检查输出，给出：① 运行/配置是否正常 ② 发现的问题（语法/站点/错误日志）③ 修复建议。精炼中文。"
        ),
        DiagnosticWorkflow(
            id: "docker-logs", name: "Docker 容器排查", icon: "shippingbox",
            description: "查看容器状态、资源、最近异常日志",
            commands: [
                "docker ps -a",
                "docker stats --no-stream 2>/dev/null",
                "for c in $(docker ps -q); do echo \"== $(docker inspect --format '{{.Name}}' $c) ==\"; docker logs --tail 20 $c 2>&1; done"
            ],
            summaryPrompt: "你是运维排障助手。根据上述 Docker 输出，给出：① 各容器运行状态（有无退出/重启）② 异常容器及日志线索 ③ 处理建议。精炼中文。"
        )
    ]
}
