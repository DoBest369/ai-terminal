import Foundation

/// 部署/初始化模板的一个步骤（Z8）。
public struct SetupStep: Codable, Sendable, Equatable, Identifiable {
    public var id: String { title }
    public var title: String
    public var commands: [String]
    public init(_ title: String, _ commands: [String]) {
        self.title = title; self.commands = commands
    }
    /// 该步骤的最高风险等级（复用 Z7 CommandRisk）
    public var risk: CommandRisk {
        commands.map { CommandRisk.riskLevel($0) }.max() ?? .low
    }
}

/// 一键服务器初始化 / 部署模板（Z8）。
public struct SetupTemplate: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var icon: String
    public var description: String
    public var steps: [SetupStep]

    public init(id: String, name: String, icon: String, description: String, steps: [SetupStep]) {
        self.id = id; self.name = name; self.icon = icon; self.description = description; self.steps = steps
    }

    /// 全部命令（按步骤顺序展开）
    public var allCommands: [String] { steps.flatMap { $0.commands } }
    /// 模板最高风险
    public var risk: CommandRisk { steps.map { $0.risk }.max() ?? .low }

    /// 执行前预览文本（对齐 PRODUCT.md §16.3）。
    public func previewText() -> String {
        var s = "即将执行模板「\(name)」，共 \(steps.count) 步：\n"
        for (i, step) in steps.enumerated() {
            let tag = step.risk.needsConfirm ? " [\(step.risk.label)]" : ""
            s += "\n\(i + 1). \(step.title)\(tag)\n"
            for c in step.commands { s += "   $ \(c)\n" }
        }
        s += "\n⚠️ 预计影响：可能修改系统配置 / 防火墙规则、安装软件、重启部分服务。"
        if risk.needsConfirm { s += " 含\(risk.label)操作，执行前请确认。" }
        return s
    }

    /// 内置模板（覆盖 PRODUCT.md §16.2 常见场景）。
    public static let builtins: [SetupTemplate] = [
        SetupTemplate(
            id: "ubuntu-web", name: "Ubuntu Web 服务器初始化", icon: "server.rack",
            description: "更新系统、装基础工具、创建普通用户、加固 SSH、装 Nginx/Docker、配防火墙",
            steps: [
                SetupStep("更新系统软件包", ["apt update", "apt -y upgrade"]),
                SetupStep("安装基础工具", ["apt install -y curl wget vim git ufw fail2ban"]),
                SetupStep("设置时区", ["timedatectl set-timezone Asia/Shanghai"]),
                SetupStep("创建普通用户 deploy", ["adduser --disabled-password --gecos '' deploy", "usermod -aG sudo deploy"]),
                SetupStep("配置 SSH 密钥登录（把公钥放入 deploy）", ["mkdir -p /home/deploy/.ssh && chmod 700 /home/deploy/.ssh", "# 将你的公钥写入 /home/deploy/.ssh/authorized_keys"]),
                SetupStep("加固 SSH：关闭 root 密码登录", ["sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config", "sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config", "systemctl restart sshd"]),
                SetupStep("安装 Nginx", ["apt install -y nginx", "systemctl enable --now nginx"]),
                SetupStep("安装 Docker", ["curl -fsSL https://get.docker.com | sh", "systemctl enable --now docker"]),
                SetupStep("配置 UFW 防火墙", ["ufw allow 22", "ufw allow 80", "ufw allow 443", "ufw --force enable"]),
                SetupStep("启用 Fail2Ban", ["systemctl enable --now fail2ban"])
            ]),
        SetupTemplate(
            id: "docker-host", name: "Docker 服务器初始化", icon: "shippingbox",
            description: "装 Docker + Compose，配防火墙，开机自启",
            steps: [
                SetupStep("更新系统", ["apt update", "apt -y upgrade"]),
                SetupStep("安装 Docker", ["curl -fsSL https://get.docker.com | sh"]),
                SetupStep("安装 Docker Compose 插件", ["apt install -y docker-compose-plugin"]),
                SetupStep("开机自启 + 验证", ["systemctl enable --now docker", "docker version", "docker compose version"]),
                SetupStep("配置防火墙", ["ufw allow 22", "ufw --force enable"])
            ]),
        SetupTemplate(
            id: "node-env", name: "Node.js 运行环境", icon: "cube",
            description: "装 Node 20 + PM2，准备运行 Node 项目",
            steps: [
                SetupStep("安装 Node.js 20", ["curl -fsSL https://deb.nodesource.com/setup_20.x | bash -", "apt install -y nodejs"]),
                SetupStep("全局安装 PM2", ["npm install -g pm2"]),
                SetupStep("设置 PM2 开机自启", ["pm2 startup systemd -u deploy --hp /home/deploy"]),
                SetupStep("验证", ["node -v", "npm -v", "pm2 -v"])
            ]),
        SetupTemplate(
            id: "static-site", name: "静态网站部署", icon: "globe",
            description: "用 Nginx 部署静态站点（dist 已上传）+ 反代占位",
            steps: [
                SetupStep("创建站点目录", ["mkdir -p /var/www/example.com", "# 把构建产物 dist/* 上传到 /var/www/example.com"]),
                SetupStep("写 Nginx 站点配置", ["# 在 /etc/nginx/sites-available/example.com 配置 server { root /var/www/example.com; }"]),
                SetupStep("启用站点并重载", ["ln -sf /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/", "nginx -t", "systemctl reload nginx"])
            ]),
        SetupTemplate(
            id: "lnmp", name: "LNMP 环境", icon: "cylinder.split.1x2",
            description: "Linux + Nginx + MySQL + PHP",
            steps: [
                SetupStep("更新系统", ["apt update"]),
                SetupStep("安装 Nginx", ["apt install -y nginx"]),
                SetupStep("安装 MySQL", ["apt install -y mysql-server", "systemctl enable --now mysql"]),
                SetupStep("安装 PHP-FPM", ["apt install -y php-fpm php-mysql", "systemctl enable --now php8.1-fpm"]),
                SetupStep("验证", ["nginx -v", "mysql --version", "php -v"])
            ])
    ]
}
