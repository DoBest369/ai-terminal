package com.termind.app

/**
 * 排障工作流 + 初始化模板（A3b）。
 * Kotlin 移植 apple DiagnosticWorkflow.swift + SetupTemplate.swift，内容保持一致。
 */

/** 场景化排障工作流：一键跑一串只读诊断命令 → AI 总结。 */
data class DiagnosticWorkflow(
    val id: String,
    val name: String,
    val description: String,
    val commands: List<String>,
    val summaryPrompt: String
) {
    /** 用分隔符把各命令串成一条 shell，便于一次执行后按分隔符拆回各命令输出 */
    fun joinedCommand(sep: String): String =
        commands.joinToString("; echo '$sep'; ")

    /** 把「工作流名 + 各命令及输出」拼成给 AI 的分析素材（对齐 apple composeForAI） */
    fun composeForAI(outputs: List<String>): String = buildString {
        append("【排障工作流：$name】\n以下是依次执行的诊断命令及输出，请据此分析：\n")
        commands.forEachIndexed { i, cmd ->
            append("\n$ $cmd\n${outputs.getOrNull(i)?.trim().orEmpty().ifBlank { "(无输出)" }}\n")
        }
    }

    companion object {
        const val SEP = "===TERMIND-DIAG-SEP==="
        val builtins = listOf(
            DiagnosticWorkflow(
                "web-down", "网站打不开排查",
                "依次检查 Nginx/端口/本地访问/磁盘/配置/日志，定位网站无法访问原因",
                listOf(
                    "systemctl status nginx --no-pager",
                    "ss -tlnp",
                    "curl -I -s -m 5 localhost",
                    "df -h",
                    "nginx -t",
                    "journalctl -u nginx -n 50 --no-pager"
                ),
                "你是运维排障助手。根据上述「网站打不开排查」各命令输出，给出：① 结论 ② 最可能的根因及定位 ③ 具体可执行的修复建议。精炼中文。"
            ),
            DiagnosticWorkflow(
                "disk-clean", "磁盘清理分析",
                "分析磁盘占用大头（系统/Docker/日志），给出可清理项",
                listOf(
                    "df -h",
                    "du -sh /* 2>/dev/null | sort -rh | head -15",
                    "docker system df 2>/dev/null",
                    "journalctl --disk-usage 2>/dev/null"
                ),
                "你是运维排障助手。根据上述磁盘占用输出，给出：① 占用大头排序 ② 哪些可安全清理及预计释放量 ③ 清理命令（删除类用 ⚠️ 并建议先确认）。精炼中文。"
            ),
            DiagnosticWorkflow(
                "ssl-check", "SSL 证书检查",
                "检查站点 SSL 证书有效期、Nginx SSL 配置",
                listOf(
                    "nginx -t",
                    "ls -l /etc/letsencrypt/live/ 2>/dev/null",
                    "for d in \$(ls /etc/letsencrypt/live/ 2>/dev/null); do echo \"== \$d ==\"; echo | openssl s_client -servername \$d -connect localhost:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null; done"
                ),
                "你是运维排障助手。根据上述 SSL 检查输出，给出：① 各证书到期时间与剩余天数 ② 是否有即将过期（<15 天）或配置问题 ③ 续期/修复建议。精炼中文。"
            ),
            DiagnosticWorkflow(
                "nginx-status", "Nginx 状态检查",
                "检查 Nginx 运行状态、配置语法、站点与错误日志",
                listOf(
                    "systemctl status nginx --no-pager",
                    "nginx -t",
                    "nginx -T 2>/dev/null | grep -E 'server_name|listen|root' | head -30",
                    "journalctl -u nginx -n 30 --no-pager"
                ),
                "你是运维排障助手。根据上述 Nginx 检查输出，给出：① 运行/配置是否正常 ② 发现的问题 ③ 修复建议。精炼中文。"
            ),
            DiagnosticWorkflow(
                "docker-logs", "Docker 容器排查",
                "查看容器状态、资源、最近异常日志",
                listOf(
                    "docker ps -a",
                    "docker stats --no-stream 2>/dev/null",
                    "for c in \$(docker ps -q); do echo \"== \$(docker inspect --format '{{.Name}}' \$c) ==\"; docker logs --tail 20 \$c 2>&1; done"
                ),
                "你是运维排障助手。根据上述 Docker 输出，给出：① 各容器运行状态 ② 异常容器及日志线索 ③ 处理建议。精炼中文。"
            ),
            DiagnosticWorkflow(
                "mem-pressure", "内存占用排查",
                "查看内存/交换分区、占用最高的进程、OOM 记录",
                listOf(
                    "free -m",
                    "ps aux --sort=-%mem | head -12",
                    "cat /proc/meminfo | head -5",
                    "dmesg 2>/dev/null | grep -i -E 'oom|out of memory' | tail -10"
                ),
                "你是运维排障助手。根据上述内存输出，给出：① 内存/交换使用是否紧张 ② 占用最高的进程是否异常（内存泄漏迹象）③ 有无 OOM 记录 ④ 优化/排查建议。精炼中文。"
            ),
            DiagnosticWorkflow(
                "port-usage", "端口占用排查",
                "查看监听端口、占用进程、连接数，定位端口冲突",
                listOf(
                    "ss -tlnp",
                    "ss -s",
                    "netstat -tlnp 2>/dev/null | head -20"
                ),
                "你是运维排障助手。根据上述端口输出，给出：① 各监听端口及对应进程 ② 有无端口冲突或异常监听 ③ 连接数概况 ④ 如需释放某端口的处理建议（标注风险）。精炼中文。"
            ),
            DiagnosticWorkflow(
                "service-failed", "服务启动失败排查",
                "列出启动失败的 systemd 服务及其状态与日志",
                listOf(
                    "systemctl --failed --no-pager",
                    "systemctl list-units --state=failed --no-pager",
                    "for s in \$(systemctl --failed --no-legend --plain | awk '{print \$1}'); do echo \"== \$s ==\"; systemctl status \$s --no-pager -l | tail -15; done"
                ),
                "你是运维排障助手。根据上述失败服务输出，给出：① 哪些服务启动失败 ② 各自失败原因线索 ③ 具体修复建议（配置/依赖/权限）。精炼中文。"
            ),
            DiagnosticWorkflow(
                "cron-check", "定时任务排查",
                "查看 crontab、systemd timer、最近定时任务执行情况",
                listOf(
                    "crontab -l 2>/dev/null",
                    "ls -l /etc/cron.d/ /etc/cron.daily/ 2>/dev/null",
                    "systemctl list-timers --all --no-pager 2>/dev/null | head -20",
                    "grep -i cron /var/log/syslog 2>/dev/null | tail -15 || journalctl -u cron -n 15 --no-pager 2>/dev/null"
                ),
                "你是运维排障助手。根据上述定时任务输出，给出：① 配置了哪些 cron/timer 任务 ② 有无异常或未按时执行 ③ 可疑/失败任务的排查建议。精炼中文。"
            ),
            DiagnosticWorkflow(
                "log-scan", "日志异常扫描",
                "扫描系统日志中的错误/警告，快速定位异常",
                listOf(
                    "journalctl -p err -n 40 --no-pager 2>/dev/null",
                    "dmesg --level=err,warn 2>/dev/null | tail -20",
                    "tail -30 /var/log/syslog 2>/dev/null | grep -iE 'error|fail|warn' || true"
                ),
                "你是运维排障助手。根据上述日志输出，给出：① 出现了哪些错误/警告 ② 按严重程度归类 ③ 最值得关注的异常及排查方向。精炼中文。"
            ),
            DiagnosticWorkflow(
                "firewall-check", "防火墙规则检查",
                "查看 iptables/ufw/firewalld 规则与放行端口",
                listOf(
                    "ufw status verbose 2>/dev/null || echo 'ufw 未安装/未启用'",
                    "iptables -L -n --line-numbers 2>/dev/null | head -40",
                    "firewall-cmd --list-all 2>/dev/null || true"
                ),
                "你是运维排障助手。根据上述防火墙输出，给出：① 当前放行/拦截的端口与规则 ② 有无安全隐患（如过度放行）③ 加固或调整建议（标注风险）。精炼中文。"
            )
        )
    }
}

/** 初始化/部署模板的一个步骤。 */
data class SetupStep(val title: String, val commands: List<String>) {
    /** 该步骤最高风险（复用 CommandRisk） */
    val risk: CommandRisk get() = commands.map { CommandRisk.riskLevel(it) }.maxByOrNull { it.level } ?: CommandRisk.LOW
}

/** 一键服务器初始化 / 部署模板。 */
data class SetupTemplate(
    val id: String,
    val name: String,
    val description: String,
    val steps: List<SetupStep>
) {
    val allCommands: List<String> get() = steps.flatMap { it.commands }
    val risk: CommandRisk get() = steps.map { it.risk }.maxByOrNull { it.level } ?: CommandRisk.LOW

    /** 执行前预览文本（对齐 apple previewText） */
    fun previewText(): String = buildString {
        append("即将执行模板「$name」，共 ${steps.size} 步：\n")
        steps.forEachIndexed { i, step ->
            val tag = if (step.risk.needsConfirm) " [${step.risk.label}]" else ""
            append("\n${i + 1}. ${step.title}$tag\n")
            step.commands.forEach { append("   $ $it\n") }
        }
        append("\n⚠️ 预计影响：可能修改系统配置/防火墙规则、安装软件、重启部分服务。")
        if (risk.needsConfirm) append(" 含${risk.label}操作，执行前请确认。")
    }

    companion object {
        val builtins = listOf(
            SetupTemplate(
                "ubuntu-web", "Ubuntu Web 服务器初始化",
                "更新系统、装基础工具、创建普通用户、加固 SSH、装 Nginx/Docker、配防火墙",
                listOf(
                    SetupStep("更新系统软件包", listOf("apt update", "apt -y upgrade")),
                    SetupStep("安装基础工具", listOf("apt install -y curl wget vim git ufw fail2ban")),
                    SetupStep("设置时区", listOf("timedatectl set-timezone Asia/Shanghai")),
                    SetupStep("创建普通用户 deploy", listOf("adduser --disabled-password --gecos '' deploy", "usermod -aG sudo deploy")),
                    SetupStep("配置 SSH 密钥登录", listOf("mkdir -p /home/deploy/.ssh && chmod 700 /home/deploy/.ssh", "# 将你的公钥写入 /home/deploy/.ssh/authorized_keys")),
                    SetupStep("加固 SSH：关闭 root 密码登录", listOf("sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config", "sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config", "systemctl restart sshd")),
                    SetupStep("安装 Nginx", listOf("apt install -y nginx", "systemctl enable --now nginx")),
                    SetupStep("安装 Docker", listOf("curl -fsSL https://get.docker.com | sh", "systemctl enable --now docker")),
                    SetupStep("配置 UFW 防火墙", listOf("ufw allow 22", "ufw allow 80", "ufw allow 443", "ufw --force enable")),
                    SetupStep("启用 Fail2Ban", listOf("systemctl enable --now fail2ban"))
                )
            ),
            SetupTemplate(
                "docker-host", "Docker 服务器初始化",
                "装 Docker + Compose，配防火墙，开机自启",
                listOf(
                    SetupStep("更新系统", listOf("apt update", "apt -y upgrade")),
                    SetupStep("安装 Docker", listOf("curl -fsSL https://get.docker.com | sh")),
                    SetupStep("安装 Docker Compose 插件", listOf("apt install -y docker-compose-plugin")),
                    SetupStep("开机自启 + 验证", listOf("systemctl enable --now docker", "docker version", "docker compose version")),
                    SetupStep("配置防火墙", listOf("ufw allow 22", "ufw --force enable"))
                )
            ),
            SetupTemplate(
                "node-env", "Node.js 运行环境",
                "装 Node 20 + PM2，准备运行 Node 项目",
                listOf(
                    SetupStep("安装 Node.js 20", listOf("curl -fsSL https://deb.nodesource.com/setup_20.x | bash -", "apt install -y nodejs")),
                    SetupStep("全局安装 PM2", listOf("npm install -g pm2")),
                    SetupStep("设置 PM2 开机自启", listOf("pm2 startup systemd -u deploy --hp /home/deploy")),
                    SetupStep("验证", listOf("node -v", "npm -v", "pm2 -v"))
                )
            ),
            SetupTemplate(
                "static-site", "静态网站部署",
                "用 Nginx 部署静态站点（dist 已上传）",
                listOf(
                    SetupStep("创建站点目录", listOf("mkdir -p /var/www/example.com", "# 把构建产物 dist/* 上传到 /var/www/example.com")),
                    SetupStep("写 Nginx 站点配置", listOf("# 在 /etc/nginx/sites-available/example.com 配置 server { root /var/www/example.com; }")),
                    SetupStep("启用站点并重载", listOf("ln -sf /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/", "nginx -t", "systemctl reload nginx"))
                )
            ),
            SetupTemplate(
                "lnmp", "LNMP 环境",
                "Linux + Nginx + MySQL + PHP",
                listOf(
                    SetupStep("更新系统", listOf("apt update")),
                    SetupStep("安装 Nginx", listOf("apt install -y nginx")),
                    SetupStep("安装 MySQL", listOf("apt install -y mysql-server", "systemctl enable --now mysql")),
                    SetupStep("安装 PHP-FPM", listOf("apt install -y php-fpm php-mysql", "systemctl enable --now php8.1-fpm")),
                    SetupStep("验证", listOf("nginx -v", "mysql --version", "php -v"))
                )
            ),
            SetupTemplate(
                "redis", "Redis 缓存",
                "安装 Redis、设密码、仅本地监听、开机自启",
                listOf(
                    SetupStep("安装 Redis", listOf("apt update", "apt install -y redis-server")),
                    SetupStep("仅本地监听 + 设访问密码（请改 YOUR_PASSWORD）", listOf("sed -i 's/^bind .*/bind 127.0.0.1/' /etc/redis/redis.conf", "sed -i 's/^# *requirepass .*/requirepass YOUR_PASSWORD/' /etc/redis/redis.conf")),
                    SetupStep("启用并重启", listOf("systemctl enable --now redis-server", "systemctl restart redis-server")),
                    SetupStep("验证", listOf("redis-cli ping || true", "systemctl status redis-server --no-pager | head -5"))
                )
            ),
            SetupTemplate(
                "postgres", "PostgreSQL 数据库",
                "安装 PostgreSQL、创建库与用户、开机自启",
                listOf(
                    SetupStep("安装 PostgreSQL", listOf("apt update", "apt install -y postgresql postgresql-contrib")),
                    SetupStep("启用并自启", listOf("systemctl enable --now postgresql")),
                    SetupStep("创建数据库与用户（请改名称/密码）", listOf("sudo -u postgres psql -c \"CREATE USER appuser WITH PASSWORD 'YOUR_PASSWORD';\"", "sudo -u postgres psql -c \"CREATE DATABASE appdb OWNER appuser;\"")),
                    SetupStep("验证", listOf("sudo -u postgres psql -c '\\l' | head -10", "psql --version"))
                )
            ),
            SetupTemplate(
                "python-app", "Python 应用环境",
                "装 Python3/venv、创建虚拟环境、装 gunicorn",
                listOf(
                    SetupStep("安装 Python3 与工具", listOf("apt update", "apt install -y python3 python3-venv python3-pip")),
                    SetupStep("创建应用目录与虚拟环境", listOf("mkdir -p /opt/app && cd /opt/app", "python3 -m venv /opt/app/venv")),
                    SetupStep("装常用依赖（按需改）", listOf("/opt/app/venv/bin/pip install --upgrade pip", "/opt/app/venv/bin/pip install gunicorn")),
                    SetupStep("验证", listOf("python3 --version", "/opt/app/venv/bin/pip --version"))
                )
            ),
            SetupTemplate(
                "mongodb", "MongoDB 数据库",
                "安装 MongoDB、启用自启、创建管理员（请改密码）",
                listOf(
                    SetupStep("安装 MongoDB", listOf("apt update", "apt install -y mongodb || apt install -y mongodb-org")),
                    SetupStep("启用并自启", listOf("systemctl enable --now mongod || systemctl enable --now mongodb")),
                    SetupStep("创建管理员（请改 YOUR_PASSWORD）", listOf("mongosh --eval \"db.getSiblingDB('admin').createUser({user:'admin',pwd:'YOUR_PASSWORD',roles:['root']})\" || mongo --eval \"db.getSiblingDB('admin').createUser({user:'admin',pwd:'YOUR_PASSWORD',roles:['root']})\"")),
                    SetupStep("验证", listOf("mongod --version | head -1"))
                )
            ),
            SetupTemplate(
                "caddy", "Caddy 反代（自动 HTTPS）",
                "安装 Caddy、写反代站点、自动申请 Let's Encrypt 证书",
                listOf(
                    SetupStep("安装 Caddy", listOf("apt install -y debian-keyring debian-archive-keyring apt-transport-https", "curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg", "curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list", "apt update && apt install -y caddy")),
                    SetupStep("写反代站点（请改域名/后端）", listOf("# 编辑 /etc/caddy/Caddyfile：\n# example.com {\n#   reverse_proxy 127.0.0.1:8080\n# }")),
                    SetupStep("重载并自启", listOf("systemctl enable --now caddy", "systemctl reload caddy")),
                    SetupStep("验证", listOf("caddy version", "systemctl status caddy --no-pager | head -5"))
                )
            ),
            SetupTemplate(
                "monitoring", "Prometheus + Grafana 监控",
                "Docker 起 Prometheus + Grafana 监控栈（请改 Grafana 密码）",
                listOf(
                    SetupStep("确保 Docker 就绪", listOf("docker --version || curl -fsSL https://get.docker.com | sh")),
                    SetupStep("启动 Prometheus", listOf("docker run -d --name prometheus -p 9090:9090 --restart unless-stopped prom/prometheus")),
                    SetupStep("启动 Grafana（请改 YOUR_PASSWORD）", listOf("docker run -d --name grafana -p 3000:3000 --restart unless-stopped -e GF_SECURITY_ADMIN_PASSWORD=YOUR_PASSWORD grafana/grafana")),
                    SetupStep("验证", listOf("docker ps --filter name=prometheus --filter name=grafana"))
                )
            )
        )
    }
}
