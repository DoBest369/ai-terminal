package com.termind.app

/** 快捷命令片段（A-Snippets）：常用运维命令一键填入命令框，仿 apple SnippetsView。 */
data class CommandSnippet(val title: String, val command: String, val group: String = "") {
    val risk: CommandRisk get() = CommandRisk.riskLevel(command)

    companion object {
        val defaults = listOf(
            CommandSnippet("磁盘占用", "df -h", "系统"),
            CommandSnippet("内存使用", "free -m", "系统"),
            CommandSnippet("进程 Top", "top -bn1 | head -20", "系统"),
            CommandSnippet("系统信息", "uname -a", "系统"),
            CommandSnippet("占用端口", "ss -tlnp", "网络"),
            CommandSnippet("Nginx 状态", "systemctl status nginx --no-pager", "服务"),
            CommandSnippet("Nginx 配置检查", "nginx -t", "服务"),
            CommandSnippet("重载 Nginx", "systemctl reload nginx", "服务"),
            CommandSnippet("Docker 容器", "docker ps -a", "Docker"),
            CommandSnippet("Docker 占用", "docker system df", "Docker"),
            CommandSnippet("系统日志", "journalctl -n 50 --no-pager", "日志"),
            CommandSnippet("登录失败记录", "grep -i 'failed password' /var/log/auth.log | tail -20", "安全")
        )
    }
}
