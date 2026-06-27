// Termind — 智能 SSH 服务器运维工作台（Linux 原生端骨架）
// Rust + egui/eframe。与 apple(Swift)/android(Kotlin) 端统一定位与配色。
//
// ⚠️ 本骨架在 macOS 开发机上未编译验证（无 Rust toolchain）。需在 Linux + Rust 环境
//    `cargo run` 构建。后续接 ssh2 实现真实 SSH/SFTP、ureq 接 AI。

use eframe::egui;

// U3 主题切换（用户要求「配色可调像 VSCode」）：4 套主题，全局 THEME_IDX 切换
// 颜色访问改为大写函数 BG()/ACCENT() 等（调用处不变，只加括号），读当前主题
const fn rgb(r: u8, g: u8, b: u8) -> egui::Color32 { egui::Color32::from_rgb(r, g, b) }
struct Theme { bg: egui::Color32, surface: egui::Color32, accent: egui::Color32, text_primary: egui::Color32, text_secondary: egui::Color32, success: egui::Color32, warning: egui::Color32 }
static THEMES: [Theme; 4] = [
    // 午夜（默认，呼应 apple/android：深蓝 + 珊瑚红）
    Theme { bg: rgb(0x1A,0x1A,0x2E), surface: rgb(0x16,0x21,0x3E), accent: rgb(0xE9,0x45,0x60), text_primary: rgb(0xEE,0xEE,0xEE), text_secondary: rgb(0xA0,0xA0,0xA0), success: rgb(0x2E,0xCC,0x71), warning: rgb(0xF5,0x9E,0x0B) },
    // Dracula
    Theme { bg: rgb(0x28,0x2A,0x36), surface: rgb(0x44,0x47,0x5A), accent: rgb(0xFF,0x79,0xC6), text_primary: rgb(0xF8,0xF8,0xF2), text_secondary: rgb(0x62,0x72,0xA4), success: rgb(0x50,0xFA,0x7B), warning: rgb(0xFF,0xB8,0x6C) },
    // Nord
    Theme { bg: rgb(0x2E,0x34,0x40), surface: rgb(0x3B,0x42,0x52), accent: rgb(0x88,0xC0,0xD0), text_primary: rgb(0xEC,0xEF,0xF4), text_secondary: rgb(0x81,0xA1,0xC1), success: rgb(0xA3,0xBE,0x8C), warning: rgb(0xEB,0xCB,0x8B) },
    // Solarized Dark
    Theme { bg: rgb(0x00,0x2B,0x36), surface: rgb(0x07,0x36,0x42), accent: rgb(0xD3,0x36,0x82), text_primary: rgb(0xEE,0xE8,0xD5), text_secondary: rgb(0x83,0x94,0x96), success: rgb(0x85,0x99,0x00), warning: rgb(0xB5,0x89,0x00) },
];
static THEME_IDX: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
const THEME_NAMES: [&str; 4] = ["午夜", "Dracula", "Nord", "Solarized"];
fn cur_theme() -> &'static Theme { &THEMES[THEME_IDX.load(std::sync::atomic::Ordering::Relaxed).min(THEMES.len() - 1)] }
#[allow(non_snake_case)] fn BG() -> egui::Color32 { cur_theme().bg }
#[allow(non_snake_case)] fn SURFACE() -> egui::Color32 { cur_theme().surface }
#[allow(non_snake_case)] fn ACCENT() -> egui::Color32 { cur_theme().accent }
#[allow(non_snake_case)] fn TEXT_PRIMARY() -> egui::Color32 { cur_theme().text_primary }
#[allow(non_snake_case)] fn TEXT_SECONDARY() -> egui::Color32 { cur_theme().text_secondary }
#[allow(non_snake_case)] fn SUCCESS() -> egui::Color32 { cur_theme().success }
#[allow(non_snake_case)] fn WARNING() -> egui::Color32 { cur_theme().warning }

/// 占用率着色：绿<60 / 橙60-80 / 红>80（对齐 apple/android 状态面板进度条）
fn usage_color(pct: u8) -> egui::Color32 {
    if pct > 80 { ACCENT() } else if pct > 60 { WARNING() } else { SUCCESS() }
}

/// AI 三模式（安全梯度，对齐 windows）：Chat 纯聊天 / Agent 每条确认 / Auto 全自动闭环
#[derive(PartialEq, Clone, Copy)]
enum AiMode { Chat, Agent, Auto }

/// 命令风险四级分级（对照 apple CommandRisk Z7 / windows）：0安全 1注意 2高风险 3极高危
#[derive(PartialEq, PartialOrd, Clone, Copy)]
enum RiskLevel { Safe = 0, Notice = 1, High = 2, Critical = 3 }

fn risk_level(cmd: &str) -> RiskLevel {
    let c = cmd.to_lowercase();
    // 极高危：删除/格式化/关 SSH/清防火墙/关机等不可逆或致命
    if c.contains("rm -rf") || c.contains("rm -fr") || c.contains(":(){") || c.contains("mkfs")
        || c.contains("dd if=") || c.contains("> /dev/") || c.contains("shutdown") || c.contains("reboot")
        || c.contains("halt") || c.contains("init 0") || c.contains("systemctl stop ssh") || c.contains("iptables -f")
        || c.contains("ufw disable") || c.contains("wipefs") || c.contains("drop database") || c.contains("> /etc/") {
        return RiskLevel::Critical;
    }
    // 高风险：重启/重载服务、改权限递归、改防火墙、kill、删容器/卸载
    if c.contains("systemctl restart") || c.contains("systemctl reload") || c.contains("systemctl stop")
        || c.contains("systemctl start") || c.starts_with("service ") || c.contains("nginx -s")
        || c.contains("ufw ") || c.contains("iptables ") || c.contains("firewall-cmd") || c.contains("chown -r")
        || c.contains("chmod -r") || c.contains("chmod 777") || c.starts_with("kill ") || c.contains("killall")
        || c.contains("pkill") || c.contains("docker rm") || c.contains("docker stop") || c.contains("apt remove")
        || c.contains("apt purge") || c.contains("yum remove") || c.contains("userdel") {
        return RiskLevel::High;
    }
    // 注意：改单文件/编辑/移动/安装
    if c.starts_with("vim ") || c.starts_with("vi ") || c.starts_with("nano ") || c.contains("sed -i")
        || c.starts_with("cp ") || c.starts_with("mv ") || c.contains("chmod ") || c.contains("chown ")
        || c.starts_with("mkdir ") || c.starts_with("touch ") || c.contains("apt install") || c.contains("yum install")
        || c.contains("pip install") || c.contains("npm install") || c.contains("git push") || c.contains("git reset")
        || c.contains("docker run") {
        return RiskLevel::Notice;
    }
    RiskLevel::Safe
}

/// 风险级别标签 + 颜色（绿/橙/深橙/红，对照 apple）
fn risk_style(r: RiskLevel) -> (&'static str, egui::Color32) {
    match r {
        RiskLevel::Critical => ("极高危", egui::Color32::from_rgb(0xE7, 0x4C, 0x3C)),
        RiskLevel::High => ("高风险", egui::Color32::from_rgb(0xE6, 0x7E, 0x22)),
        RiskLevel::Notice => ("注意", egui::Color32::from_rgb(0xF3, 0x9C, 0x12)),
        RiskLevel::Safe => ("", SUCCESS()),
    }
}

/// 危险命令检测：高/极高即危险（Auto 不自动执行，强制确认；委托四级分级，对照 windows）
fn is_dangerous(cmd: &str) -> bool {
    risk_level(cmd) >= RiskLevel::High
}

/// ANSI SGR 前景色码 → egui 颜色（30-37 标准 / 90-97 亮色，对照 windows AnsiFg）
fn ansi_color(code: u8) -> Option<egui::Color32> {
    use egui::Color32 as C;
    Some(match code {
        30 => C::from_rgb(0x6B, 0x72, 0x80), 31 => C::from_rgb(0xF8, 0x71, 0x71), 32 => C::from_rgb(0x3F, 0xB9, 0x50),
        33 => C::from_rgb(0xF5, 0x9E, 0x0B), 34 => C::from_rgb(0x60, 0xA5, 0xFA), 35 => C::from_rgb(0xC0, 0x84, 0xFC),
        36 => C::from_rgb(0x22, 0xD3, 0xEE), 37 => C::from_rgb(0xC9, 0xD1, 0xD9),
        90 => C::from_rgb(0x8B, 0x92, 0xA8), 91 => C::from_rgb(0xFC, 0xA5, 0xA5), 92 => C::from_rgb(0x86, 0xEF, 0xAC),
        93 => C::from_rgb(0xFC, 0xD3, 0x4D), 94 => C::from_rgb(0x93, 0xC5, 0xFD), 95 => C::from_rgb(0xD8, 0xB4, 0xFE),
        96 => C::from_rgb(0x67, 0xE8, 0xF9), 97 => C::from_rgb(0xFF, 0xFF, 0xFF),
        _ => return None,
    })
}

/// 解析 ANSI 转义 → egui LayoutJob 彩色等宽文本（手动解析，无 regex 依赖，对照 windows AppendTerm）
fn ansi_to_job(text: &str, default: egui::Color32, size: f32) -> egui::text::LayoutJob {
    let mut job = egui::text::LayoutJob::default();
    let fmt = |c: egui::Color32| egui::TextFormat { font_id: egui::FontId::monospace(size), color: c, ..Default::default() };
    let mut cur = default;
    let mut rest = text;
    while let Some(esc) = rest.find('\u{1b}') {
        if esc > 0 { job.append(&rest[..esc], 0.0, fmt(cur)); }
        rest = &rest[esc..];
        // 形如 \x1b[..m
        if rest.starts_with("\u{1b}[") {
            if let Some(mpos) = rest.find('m') {
                for code in rest[2..mpos].split(';') {
                    match code.parse::<u8>() {
                        Ok(0) => cur = default,
                        Ok(n) => { if let Some(c) = ansi_color(n) { cur = c; } }
                        Err(_) => {}
                    }
                }
                rest = &rest[mpos + 1..];
                continue;
            }
        }
        // 非标准转义：跳过单字符避免死循环
        job.append(&rest[..1], 0.0, fmt(cur));
        rest = &rest[1..];
    }
    if !rest.is_empty() { job.append(rest, 0.0, fmt(cur)); }
    job
}

/// 渲染 AI 回复：```代码块→等宽代码框，正文→普通文本（对照 windows RenderAiReply）
fn render_ai_reply(ui: &mut egui::Ui, text: &str, size: f32) {
    for (i, seg) in text.split("```").enumerate() {
        if i % 2 == 1 {
            // 代码块：去首行语言标识
            let code = match seg.split_once('\n') {
                Some((lang, rest)) if lang.trim().len() < 12 && !lang.contains(' ') => rest,
                _ => seg,
            }.trim();
            if !code.is_empty() {
                egui::Frame::default().fill(egui::Color32::from_rgb(0x05, 0x06, 0x0C)).rounding(6.0).inner_margin(8.0)
                    .show(ui, |ui| { ui.colored_label(SUCCESS(), egui::RichText::new(code).monospace().size(size)); });
            }
        } else {
            let body = seg.trim();
            if !body.is_empty() { ui.colored_label(TEXT_PRIMARY(), egui::RichText::new(body).size(size)); }
        }
    }
}

/// 解析 AI 回复里的 [EXECUTE]cmd[/EXECUTE]，返回命令列表
fn parse_execute(reply: &str) -> Vec<String> {
    let mut cmds = Vec::new();
    let mut rest = reply;
    while let Some(start) = rest.find("[EXECUTE]") {
        if let Some(end) = rest[start..].find("[/EXECUTE]") {
            let cmd = rest[start + 9..start + end].trim().to_string();
            if !cmd.is_empty() { cmds.push(cmd); }
            rest = &rest[start + end + 10..];
        } else { break; }
    }
    cmds
}

/// SSH 连接（占位；后续接 ssh2 + 本地持久化）
struct ServerConn {
    name: &'static str,
    host: &'static str,
    user: &'static str,
    port: u16,
    group: &'static str,
    online: bool,
    probed: bool,          // 是否已完成 TCP 可达性探测（false=探测中）
    note: &'static str,
    last_used: &'static str,
}

fn demo_conns() -> Vec<ServerConn> {
    vec![
        ServerConn { name: "测试服务器", host: "47.85.19.31", user: "root", port: 22, group: "生产环境", online: true, probed: false, note: "Ubuntu 测试机", last_used: "5 分钟前" },
        ServerConn { name: "数据库主机", host: "db.internal.net", user: "admin", port: 22, group: "生产环境", online: true, probed: false, note: "MySQL 主库", last_used: "1 小时前" },
        ServerConn { name: "开发机", host: "dev.example.com", user: "deploy", port: 2222, group: "开发环境", online: false, probed: false, note: "", last_used: "" },
    ]
}

struct TermindApp {
    conns: Vec<ServerConn>,
    selected: Option<usize>,
    search: String,
    ai_input: String,
    show_settings: bool,
    api_key: String,
    base_url: String,
    sys_prompt: String,
    show_sftp: bool,
    cmd_input: String,
    term_lines: Vec<String>,   // 用户输入回车后追加的终端历史行
    ai_msgs: Vec<(bool, String)>,  // AI 对话（true=用户提问 / false=AI 真实回复）
    cmd_history: Vec<String>,  // 命令历史（去重最近优先），供上下键回溯
    hist_idx: Option<usize>,   // 当前回溯位置（None=未回溯）
    reach_rx: std::sync::mpsc::Receiver<(usize, bool)>,  // 后台 TCP 可达性探测结果
    ai_tx: std::sync::mpsc::Sender<String>,    // AI 真实回复回传（后台线程→UI）
    ai_rx: std::sync::mpsc::Receiver<String>,
    ai_busy: bool,                             // AI 请求进行中
    term_tx: std::sync::mpsc::Sender<String>,  // SSH 执行结果回传（后台线程→UI）
    term_rx: std::sync::mpsc::Receiver<String>,
    ai_mode: AiMode,                           // AI 三模式（Chat/Agent/Auto）
    pending_cmds: Vec<String>,                 // AI 生成待执行命令（Agent 确认 / Auto 自动）
    sftp_files: Vec<(String, bool, String, String)>,  // SFTP 真实文件（name/是否目录/大小/时间）
    sftp_path: String,                         // SFTP 当前路径
    sftp_loading: bool,
    sftp_tx: std::sync::mpsc::Sender<String>,  // SFTP ls 原始输出回传
    sftp_rx: std::sync::mpsc::Receiver<String>,
    new_dir_name: String,                      // SFTP 新建目录 / 重命名输入（复用）
    sftp_renaming: Option<String>,             // 待重命名文件原路径（非空=重命名模式）
    term_font_size: f32,                       // 终端字号（U4 可调，对照 windows）
    ai_font_size: f32,                         // AI 对话字号（U4 可调，对照 windows）
    term_search: String,                       // 终端输出搜索（匹配行高亮，对照 windows）
    metrics: (u8, u8, String),                 // 状态条远程真实指标 (CPU%, 内存%, 负载)，对照 windows
    services: Vec<(String, bool)>,             // 关键服务真实状态 (名, 是否 active)，SSH systemctl 取
    metrics_target: String,                    // 上次取指标的主机（检测连接切换刷新）
    metrics_tx: std::sync::mpsc::Sender<(u8, u8, String, Vec<(String, bool)>)>,
    metrics_rx: std::sync::mpsc::Receiver<(u8, u8, String, Vec<(String, bool)>)>,
}

/// 全局复用的 SSH 会话缓存（对照 windows _sshClient；多后台线程经 Mutex 串行复用）
fn ssh_session_cache() -> &'static std::sync::Mutex<Option<ssh2::Session>> {
    static CACHE: std::sync::OnceLock<std::sync::Mutex<Option<ssh2::Session>>> = std::sync::OnceLock::new();
    CACHE.get_or_init(|| std::sync::Mutex::new(None))
}

/// 建立一个已认证的 ssh2 会话
fn ssh_connect(host: &str, port: u16, user: &str, pass: &str) -> Result<ssh2::Session, String> {
    let tcp = std::net::TcpStream::connect((host, port)).map_err(|e| format!("连接失败：{}", e))?;
    let mut sess = ssh2::Session::new().map_err(|e| format!("会话失败：{}", e))?;
    sess.set_tcp_stream(tcp);
    sess.handshake().map_err(|e| format!("握手失败：{}", e))?;
    sess.userauth_password(user, pass).map_err(|e| format!("认证失败：{}", e))?;
    Ok(sess)
}

/// 真实 SSH exec（S2：ssh2 连真实服务器，对照 windows SshExecAsync）
/// 复用持久会话：连接+握手+认证只在首次或断线后做（对照 windows Session 复用）
fn ssh_exec(host: &str, port: u16, user: &str, pass: &str, cmd: &str) -> String {
    use std::io::Read;
    let mut guard = match ssh_session_cache().lock() { Ok(g) => g, Err(p) => p.into_inner() };
    // 未连接或会话失效 → 建立/重建
    if guard.as_ref().map(|s| !s.authenticated()).unwrap_or(true) {
        match ssh_connect(host, port, user, pass) {
            Ok(s) => *guard = Some(s),
            Err(e) => { *guard = None; return format!("⚠️ {}", e); }
        }
    }
    let sess = guard.as_ref().unwrap();
    // 通道/执行失败 → 重置会话以便下次干净重连（断线重连）
    let mut ch = match sess.channel_session() {
        Ok(c) => c, Err(e) => { *guard = None; return format!("⚠️ 通道失败（已重置）：{}", e); }
    };
    if let Err(e) = ch.exec(cmd) { *guard = None; return format!("⚠️ 执行失败（已重置）：{}", e); }
    let mut out = String::new();
    let _ = ch.read_to_string(&mut out);
    let mut err = String::new();
    let _ = ch.stderr().read_to_string(&mut err);
    let _ = ch.wait_close();
    let combined = format!("{}{}", out, err);
    if combined.trim().is_empty() { "(无输出)".to_string() } else { combined.trim_end().to_string() }
}

/// Z3 环境感知：SSH 取服务器真实状态摘要（对照 windows FetchServerEnv）；失败返回空
fn fetch_server_env() -> String {
    let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
    if pass.is_empty() { return String::new(); }
    let host = std::env::var("TERMIND_SSH_HOST").unwrap_or_else(|_| "47.85.19.31".to_string());  // 独立函数：环境感知用 env/默认
    let user = std::env::var("TERMIND_SSH_USER").unwrap_or_else(|_| "root".to_string());
    let probe = "echo 系统:$(uname -sr); echo CPU核数:$(nproc); \
        echo 内存:$(free -m 2>/dev/null|awk '/Mem:/{print $3\"/\"$2\"MB\"}'); \
        echo 负载:$(cat /proc/loadavg|cut -d' ' -f1-3); \
        echo 磁盘:$(df -h / 2>/dev/null|awk 'NR==2{print $5}'); \
        echo 服务:$(for s in nginx docker mysql redis sshd; do systemctl is-active $s 2>/dev/null|grep -q active && echo -n \"$s \"; done)";
    let env = ssh_exec(&host, 22, &user, &pass, probe);
    if env.starts_with('⚠') { String::new() } else { env }
}

/// 真实 AI（S2：ureq 调 Anthropic 兼容接口 nexcores，对照 windows CallAiAsync）
/// key 从环境变量 TERMIND_AI_KEY（不硬编码）；返回 content[0].text 或错误
fn ai_chat(base_url: &str, api_key: &str, model: &str, sys: &str, user: &str) -> String {
    let body = serde_json::json!({
        "model": model, "max_tokens": 1024, "system": sys,
        "messages": [{ "role": "user", "content": user }]
    });
    match ureq::post(base_url)
        .set("x-api-key", api_key)
        .set("anthropic-version", "2023-06-01")
        .set("content-type", "application/json")
        .send_json(body)
    {
        Ok(resp) => match resp.into_json::<serde_json::Value>() {
            Ok(j) => j["content"][0]["text"].as_str().map(|s| s.to_string())
                .or_else(|| j["error"]["message"].as_str().map(|s| format!("⚠️ {}", s)))
                .unwrap_or_else(|| "(无回复)".to_string()),
            Err(e) => format!("⚠️ 解析失败：{}", e),
        },
        Err(e) => format!("⚠️ 请求失败：{}", e),
    }
}

// 注：本机 /proc 指标读取（read_loadavg/read_uptime/read_mem）已移除——状态条改取
// 选中远程服务器的真实指标（SSH /proc，update 异步），运维工具应反映被运维的服务器而非本机。

/// TCP 可达性探测（真实逻辑第一步，std::net 无需额外依赖）：connect_timeout 2s
fn probe_tcp(host: &str, port: u16) -> bool {
    use std::net::ToSocketAddrs;
    match (host, port).to_socket_addrs() {
        Ok(mut addrs) => addrs.next().map_or(false, |addr|
            std::net::TcpStream::connect_timeout(&addr, std::time::Duration::from_secs(2)).is_ok()),
        Err(_) => false,
    }
}

/// 配置文件路径（~/.config/termind/config.json，对照 windows AppData）
fn config_path() -> Option<String> {
    std::env::var("HOME").ok().map(|h| format!("{}/.config/termind/config.json", h))
}

/// 加载持久化配置（api_key/base_url）：返回 (api_key, base_url) 覆盖默认
fn load_config() -> (Option<String>, Option<String>) {
    let Some(path) = config_path() else { return (None, None); };
    let Ok(text) = std::fs::read_to_string(&path) else { return (None, None); };
    let Ok(json) = serde_json::from_str::<serde_json::Value>(&text) else { return (None, None); };
    (json["api_key"].as_str().map(|s| s.to_string()),
     json["base_url"].as_str().map(|s| s.to_string()))
}

/// 加载持久化的终端字号（U4，对照 windows）；默认 13
fn load_font_size() -> f32 {
    config_path()
        .and_then(|p| std::fs::read_to_string(&p).ok())
        .and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok())
        .and_then(|j| j["font_size"].as_f64())
        .map(|f| (f as f32).clamp(9.0, 22.0))
        .unwrap_or(13.0)
}

/// 加载持久化的 AI 字号（U4，对照 windows）；默认 13
fn load_ai_font_size() -> f32 {
    config_path()
        .and_then(|p| std::fs::read_to_string(&p).ok())
        .and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok())
        .and_then(|j| j["ai_font_size"].as_f64())
        .map(|f| (f as f32).clamp(10.0, 22.0))
        .unwrap_or(13.0)
}

/// 加载持久化的主题索引（U3）；默认 0（午夜）
fn load_theme_idx() -> usize {
    config_path()
        .and_then(|p| std::fs::read_to_string(&p).ok())
        .and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok())
        .and_then(|j| j["theme_idx"].as_u64())
        .map(|i| (i as usize).min(THEMES.len() - 1))
        .unwrap_or(0)
}

/// 保存配置（api_key/base_url + 终端/AI 字号 + 主题）到配置文件
fn save_config(api_key: &str, base_url: &str, font_size: f32, ai_font_size: f32) {
    let Some(path) = config_path() else { return; };
    if let Some(dir) = std::path::Path::new(&path).parent() { let _ = std::fs::create_dir_all(dir); }
    let theme_idx = THEME_IDX.load(std::sync::atomic::Ordering::Relaxed);
    let json = serde_json::json!({ "api_key": api_key, "base_url": base_url, "font_size": font_size, "ai_font_size": ai_font_size, "theme_idx": theme_idx });
    let _ = std::fs::write(&path, json.to_string());
}

impl Default for TermindApp {
    fn default() -> Self {
        let conns = demo_conns();
        // 启动后台线程对每个连接做真实 TCP 可达性探测，结果经 channel 回传
        let (tx, reach_rx) = std::sync::mpsc::channel();
        for (i, c) in conns.iter().enumerate() {
            let (host, port, tx) = (c.host, c.port, tx.clone());
            std::thread::spawn(move || { let _ = tx.send((i, probe_tcp(host, port))); });
        }
        let (ai_tx, ai_rx) = std::sync::mpsc::channel();
        let (term_tx, term_rx) = std::sync::mpsc::channel();
        let (metrics_tx, metrics_rx) = std::sync::mpsc::channel();
        let (sftp_tx, sftp_rx) = std::sync::mpsc::channel();
        // 持久化配置优先：配置文件 > 环境变量 > 默认（对照 windows LoadConfig）
        let (cfg_key, cfg_url) = load_config();
        THEME_IDX.store(load_theme_idx(), std::sync::atomic::Ordering::Relaxed);   // U3 恢复持久化主题
        Self { conns, selected: None, search: String::new(), ai_input: String::new(), show_settings: false, api_key: cfg_key.unwrap_or_else(|| std::env::var("TERMIND_AI_KEY").unwrap_or_default()), base_url: cfg_url.unwrap_or_else(|| "https://www.nexcores.net/v1/messages".to_string()), sys_prompt: "你是 Termind 的资深 Linux/SSH 服务器运维专家。结合真实环境给针对性建议；命令用代码块；危险操作（删除/格式化/重启服务/改防火墙）标注风险等级+建议先备份；排障先诊断后修复验证。回答精炼、用中文。需执行命令用 [EXECUTE]命令[/EXECUTE] 标记。".to_string(), show_sftp: false, cmd_input: String::new(), term_lines: Vec::new(), ai_msgs: Vec::new(), cmd_history: Vec::new(), hist_idx: None, reach_rx, ai_tx, ai_rx, ai_busy: false, term_tx, term_rx, ai_mode: AiMode::Chat, pending_cmds: Vec::new(), sftp_files: Vec::new(), sftp_path: String::new(), sftp_loading: false, sftp_tx, sftp_rx, new_dir_name: String::new(), sftp_renaming: None, term_font_size: load_font_size(), ai_font_size: load_ai_font_size(), term_search: String::new(), metrics: (0, 0, "--".to_string()), services: Vec::new(), metrics_target: String::new(), metrics_tx, metrics_rx }
    }
}

impl TermindApp {
    /// SFTP 真实文件列表（对照 windows LoadSftp）：后台 SSH ls 指定目录 → sftp_rx；目录可导航
    fn run_sftp_ls(&mut self, path: &str) {
        if self.sftp_loading { return; }
        self.sftp_loading = true;
        let (host, user) = self.ssh_target();
        let tx = self.sftp_tx.clone();
        let dir = path.replace('\'', "");   // 防注入
        std::thread::spawn(move || {
            let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
            let out = if pass.is_empty() { "⚠️ 未配置 SSH 密码".to_string() }
                else { ssh_exec(&host, 22, &user, &pass, &format!("cd '{}' 2>/dev/null && pwd && ls -la --time-style=long-iso", dir)) };
            let _ = tx.send(out);
        });
    }

    /// SFTP 文件上传（对照 windows OnSftpUpload / apple sftpUpload）：rfd 选本地文件→base64→ssh 写远程
    fn run_sftp_upload(&mut self) {
        let Some(local) = rfd::FileDialog::new().set_title("上传到当前目录").pick_file() else { return; };
        let fname = local.file_name().and_then(|n| n.to_str()).unwrap_or("upload").to_string();
        let bytes = match std::fs::read(&local) { Ok(b) => b, Err(e) => { self.term_lines.push(format!("⚠️ 读文件失败：{}", e)); return; } };
        if bytes.len() > 5_000_000 { self.term_lines.push(format!("# 上传 {}：文件 {}MB 过大（base64 经命令行限 5MB）", fname, bytes.len() / 1024 / 1024)); return; }
        use base64::Engine;
        let b64 = base64::engine::general_purpose::STANDARD.encode(&bytes);
        let cwd = if self.sftp_path.is_empty() { "~".to_string() } else { self.sftp_path.clone() };
        let remote = format!("{}/{}", cwd, fname).replace('\'', "");
        self.term_lines.push(format!("# 上传 {} → {} …", fname, cwd));
        let (host, user) = self.ssh_target();
        let (tx, len) = (self.term_tx.clone(), bytes.len());
        std::thread::spawn(move || {
            let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
            if pass.is_empty() { let _ = tx.send("⚠️ 未配置 SSH 密码".to_string()); return; }
            let r = ssh_exec(&host, 22, &user, &pass, &format!("printf '%s' '{}' | base64 -d > '{}' && echo TERMIND_UP_OK", b64, remote));
            let _ = tx.send(if r.contains("TERMIND_UP_OK") { format!("✓ 已上传（{} 字节）", len) } else { format!("✕ 上传失败：{}", r) });
        });
        self.run_sftp_ls(&cwd);
    }

    /// SFTP 文件重命名（对照 windows / apple sftpRename）：ssh mv 原→同目录新名 + 刷新
    fn run_sftp_rename(&mut self) {
        let new = self.new_dir_name.trim().to_string();
        let Some(src) = self.sftp_renaming.take() else { return; };
        if new.is_empty() { return; }
        let cwd = if self.sftp_path.is_empty() { "~".to_string() } else { self.sftp_path.clone() };
        let dst = format!("{}/{}", cwd, new).replace('\'', "");
        let s = src.replace('\'', "");
        self.term_lines.push(format!("# 重命名 → {} …", dst));
        self.new_dir_name.clear();
        let (host, user) = self.ssh_target();
        let tx = self.term_tx.clone();
        std::thread::spawn(move || {
            let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
            if pass.is_empty() { let _ = tx.send("⚠️ 未配置 SSH 密码".to_string()); return; }
            let r = ssh_exec(&host, 22, &user, &pass, &format!("mv '{}' '{}' && echo TERMIND_MV_OK", s, dst));
            let _ = tx.send(if r.contains("TERMIND_MV_OK") { "✓ 已重命名".to_string() } else { format!("✕ 重命名失败：{}", r) });
        });
        self.run_sftp_ls(&cwd);   // 刷新
    }

    /// SFTP 新建目录（对照 windows OnMkdir / apple sftpMakeDirectory）：ssh mkdir + 刷新
    fn run_sftp_mkdir(&mut self) {
        let name = self.new_dir_name.trim().to_string();
        if name.is_empty() { return; }
        let cwd = if self.sftp_path.is_empty() { "~".to_string() } else { self.sftp_path.clone() };
        let target = format!("{}/{}", cwd, name).replace('\'', "");
        self.term_lines.push(format!("# 新建目录 {} …", target));
        self.new_dir_name.clear();
        let (host, user) = self.ssh_target();
        let tx = self.term_tx.clone();
        std::thread::spawn(move || {
            let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
            if pass.is_empty() { let _ = tx.send("⚠️ 未配置 SSH 密码".to_string()); return; }
            let r = ssh_exec(&host, 22, &user, &pass, &format!("mkdir -p '{}' && echo TERMIND_MKDIR_OK", target));
            let _ = tx.send(if r.contains("TERMIND_MKDIR_OK") { "✓ 已创建".to_string() } else { format!("✕ 创建失败：{}", r) });
        });
        self.run_sftp_ls(&cwd);   // 刷新
    }

    /// SFTP 文件删除（对照 windows DeleteSftpFile / apple sftpRemove）：ssh rm + 刷新当前目录
    fn run_sftp_delete(&mut self, file: &str) {
        self.term_lines.push(format!("# 删除 {} …", file));
        let (host, user) = self.ssh_target();
        let tx = self.term_tx.clone();
        let f = file.replace('\'', "");
        let path = if self.sftp_path.is_empty() { "~".to_string() } else { self.sftp_path.clone() };
        std::thread::spawn(move || {
            let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
            if pass.is_empty() { let _ = tx.send("⚠️ 未配置 SSH 密码".to_string()); return; }
            let r = ssh_exec(&host, 22, &user, &pass, &format!("rm -f '{}' && echo TERMIND_RM_OK", f));
            let _ = tx.send(if r.contains("TERMIND_RM_OK") { "✓ 已删除".to_string() } else { format!("✕ 删除失败：{}", r) });
        });
        self.run_sftp_ls(&path);   // 刷新当前目录
    }

    /// SFTP 文件下载（对照 windows DownloadFile）：SSH base64 取内容→解码→存 $HOME/Downloads
    fn run_sftp_download(&mut self, file: &str, fname: &str) {
        self.term_lines.push(format!("# 下载 {} …", file));
        let (host, user) = self.ssh_target();
        let tx = self.term_tx.clone();
        let (f, name) = (file.replace('\'', ""), fname.to_string());
        std::thread::spawn(move || {
            let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
            if pass.is_empty() { let _ = tx.send("⚠️ 未配置 SSH 密码".to_string()); return; }
            // 大小守门 >10MB 跳过
            let sz = ssh_exec(&host, 22, &user, &pass, &format!("stat -c %s '{}' 2>/dev/null", f));
            if sz.trim().parse::<u64>().unwrap_or(0) > 10_000_000 { let _ = tx.send("（文件过大，跳过下载）".to_string()); return; }
            let b64 = ssh_exec(&host, 22, &user, &pass, &format!("base64 '{}' 2>/dev/null", f));
            if b64.starts_with('⚠') || b64.is_empty() { let _ = tx.send("下载失败".to_string()); return; }
            use base64::Engine;
            match base64::engine::general_purpose::STANDARD.decode(b64.replace(['\n', '\r'], "")) {
                Ok(bytes) => {
                    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
                    let dir = format!("{}/Downloads", home);
                    let _ = std::fs::create_dir_all(&dir);
                    let local = format!("{}/{}", dir, name);
                    match std::fs::write(&local, &bytes) {
                        Ok(_) => { let _ = tx.send(format!("✓ 已下载到 {}（{} 字节）", local, bytes.len())); }
                        Err(e) => { let _ = tx.send(format!("✕ 写入失败：{}", e)); }
                    }
                }
                Err(e) => { let _ = tx.send(format!("✕ 解码失败：{}", e)); }
            }
        });
    }

    /// SFTP 文件预览（对照 windows PreviewFile）：守门大小/二进制，文本 head 到终端
    fn run_sftp_preview(&mut self, file: &str) {
        self.term_lines.push(format!("# 预览 {}", file));
        let (host, user) = self.ssh_target();
        let tx = self.term_tx.clone();
        let f = file.replace('\'', "");
        std::thread::spawn(move || {
            let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
            if pass.is_empty() { let _ = tx.send("⚠️ 未配置 SSH 密码".to_string()); return; }
            // stat 大小 + file 类型守门：>1MB 或二进制不预览
            let meta = ssh_exec(&host, 22, &user, &pass, &format!("stat -c %s '{}' 2>/dev/null; file -b '{}' 2>/dev/null", f, f));
            let ml: Vec<&str> = meta.split('\n').collect();
            let size: u64 = ml.first().and_then(|s| s.trim().parse().ok()).unwrap_or(0);
            let ftype = ml.get(1).copied().unwrap_or("");
            if size > 1_000_000 { let _ = tx.send(format!("（文件 {}KB 过大，跳过预览）", size / 1024)); return; }
            if ftype.contains("executable") || ftype.contains("binary") || ftype.contains("data") {
                let _ = tx.send(format!("（{}，二进制不预览）", ftype.trim())); return;
            }
            let _ = tx.send(ssh_exec(&host, 22, &user, &pass, &format!("head -n 200 '{}'", f)));
        });
    }

    /// 解析 ls -la 输出 → (路径, 文件列表)
    fn parse_sftp(out: &str) -> (String, Vec<(String, bool, String, String)>) {
        let mut lines = out.split('\n');
        let path = lines.next().unwrap_or("~").trim().to_string();
        let mut files = Vec::new();
        for line in lines {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() < 8 || line.starts_with("total") || line.starts_with("合计") { continue; }
            let is_dir = parts[0].starts_with('d');
            let size = if is_dir { String::new() } else { parts[4].to_string() };
            let time = format!("{} {}", parts[5], parts[6]);
            let name = parts[7..].join(" ");
            if name == "." { continue; }
            files.push((name, is_dir, size, time));
        }
        (path, files)
    }

    /// 批量群发命令（护城河 batch，对照 windows OnBatchExec）：对所有连接并发 ssh_exec → 聚合终端
    fn run_batch_exec(&mut self) {
        let cmd = self.cmd_input.trim().to_string();
        if cmd.is_empty() || self.conns.is_empty() { return; }
        self.cmd_input.clear();
        self.term_lines.push(format!("⇶ 批量群发「{}」→ {} 台连接", cmd, self.conns.len()));
        let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
        if pass.is_empty() { self.term_lines.push("⚠️ 未配置 SSH 密码".to_string()); return; }
        // 各连接并发执行，结果带连接名经 term_tx 回传（聚合分段显示）
        for c in &self.conns {
            let (name, host, user) = (c.name.to_string(), c.host.to_string(), c.user.to_string());
            let (tx, cmd, pass) = (self.term_tx.clone(), cmd.clone(), pass.clone());
            std::thread::spawn(move || {
                let out = ssh_exec(&host, 22, &user, &pass, &cmd);
                let ok = !out.starts_with('⚠');
                let mut s = format!("── {} ({}) {} ──\n", name, host, if ok { "✓" } else { "✕" });
                for line in out.split('\n') { s.push_str(&format!("  {}\n", line)); }
                let _ = tx.send(s.trim_end().to_string());
            });
        }
    }

    /// 当前 SSH 执行目标（选中连接 > env > 默认测试机，对照 windows _activeHost）
    fn ssh_target(&self) -> (String, String) {
        if let Some(c) = self.selected.and_then(|i| self.conns.get(i)) {
            (c.host.to_string(), c.user.to_string())
        } else {
            (std::env::var("TERMIND_SSH_HOST").unwrap_or_else(|_| "47.85.19.31".to_string()),
             std::env::var("TERMIND_SSH_USER").unwrap_or_else(|_| "root".to_string()))
        }
    }

    /// 一键健康巡检（Z3，对照 windows RunHealthCheck）：后台线程 SSH 取真实指标 → AI 分析 → ai_rx 回
    fn run_health_check(&mut self) {
        if self.ai_busy { return; }
        self.ai_msgs.push((true, "一键健康巡检".to_string()));
        if self.api_key.is_empty() {
            self.ai_msgs.push((false, "⚠️ 未配置 API Key（环境变量 TERMIND_AI_KEY 或设置面板）".to_string()));
            return;
        }
        self.ai_busy = true;
        let (host, user) = self.ssh_target();   // 选中连接驱动 SSH 目标
        let (base, key, sys, tx) = (self.base_url.clone(), self.api_key.clone(), self.sys_prompt.clone(), self.ai_tx.clone());
        std::thread::spawn(move || {
            // SSH 取真实指标（负载/内存/磁盘/CPU Top5/服务状态）
            let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
            let metrics = if pass.is_empty() { String::new() } else {
                ssh_exec(&host, 22, &user, &pass,
                    "echo '== 负载 =='; uptime; echo '== 内存 =='; free -h; echo '== 磁盘 =='; df -h; \
                     echo '== CPU Top5 =='; ps -eo pid,%cpu,%mem,comm --sort=-%cpu | head -6; \
                     echo '== 服务 =='; for s in nginx docker mysql redis sshd; do printf '%s:' $s; systemctl is-active $s 2>/dev/null; done")
            };
            let user_msg = if metrics.is_empty() || metrics.starts_with('⚠') {
                "对这台服务器做健康巡检，但当前未取到真实指标（未配置 SSH），请给出通用巡检清单".to_string()
            } else {
                format!("以下是这台服务器的当前真实状态，请做健康巡检：按 资源水位 → 风险点 → 优化建议 给出诊断，异常用 ⚠️ 标注。\n\n{}", metrics)
            };
            let _ = tx.send(ai_chat(&base, &key, "claude-opus-4-8", &sys, &user_msg));
        });
    }

    /// 一键报错分析（Z2，对照 windows RunErrorAnalysis）：SSH 取错误日志 → AI 诊断 → ai_rx 回
    fn run_error_analysis(&mut self) {
        if self.ai_busy { return; }
        self.ai_msgs.push((true, "一键分析最近报错".to_string()));
        if self.api_key.is_empty() {
            self.ai_msgs.push((false, "⚠️ 未配置 API Key（环境变量 TERMIND_AI_KEY 或设置面板）".to_string()));
            return;
        }
        self.ai_busy = true;
        let (host, user) = self.ssh_target();   // 选中连接驱动 SSH 目标
        let (base, key, sys, tx) = (self.base_url.clone(), self.api_key.clone(), self.sys_prompt.clone(), self.ai_tx.clone());
        std::thread::spawn(move || {
            // SSH 取系统错误日志（journalctl 优先，回退 dmesg）+ 失败服务
            let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
            let logs = if pass.is_empty() { String::new() } else {
                ssh_exec(&host, 22, &user, &pass,
                    "echo '== 最近错误日志 =='; journalctl -p err -n 40 --no-pager 2>/dev/null | tail -40 || dmesg -l err,crit 2>/dev/null | tail -40; \
                     echo '== 失败的服务 =='; systemctl --failed --no-pager 2>/dev/null | head -15")
            };
            let user_msg = if logs.is_empty() || logs.starts_with('⚠') {
                "分析这台服务器的报错，但当前未取到真实日志（未配置 SSH），请给出常见错误排查清单".to_string()
            } else {
                format!("以下是这台服务器最近的系统错误日志和失败服务，请按 现象 → 可能原因 → 修复步骤 诊断，给出可执行修复命令（高危用 ⚠️ 标注）。若日志为空说明暂无明显错误。\n\n{}", logs)
            };
            let _ = tx.send(ai_chat(&base, &key, "claude-opus-4-8", &sys, &user_msg));
        });
    }

    /// 导出当前 AI 对话为 Markdown（对照 windows OnExportChat），写到 $HOME
    fn export_chat(&mut self) {
        if self.ai_msgs.is_empty() {
            self.ai_msgs.push((false, "⚠️ 暂无对话可导出".to_string()));
            return;
        }
        let mut md = String::from("# Termind AI 运维对话\n\n");
        for (is_user, text) in &self.ai_msgs {
            md.push_str(&format!("## {}\n\n{}\n\n", if *is_user { "🧑 你" } else { "✦ AI" }, text));
        }
        if let Ok(home) = std::env::var("HOME") {
            let path = format!("{}/termind-chat-{}.md", home, self.ai_msgs.len());
            match std::fs::write(&path, md) {
                Ok(_) => self.ai_msgs.push((false, format!("✓ 已导出对话：{}", path))),
                Err(e) => self.ai_msgs.push((false, format!("⚠️ 导出失败：{}", e))),
            }
        }
    }
}

impl eframe::App for TermindApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // 当前 SSH 执行目标（选中连接驱动，对照 windows _activeHost）；本帧各命令执行用
        let (active_host, active_user) = self.ssh_target();
        // 应用后台 TCP 探测结果（真实可达性）→ 更新连接 online 状态
        while let Ok((i, ok)) = self.reach_rx.try_recv() {
            if let Some(c) = self.conns.get_mut(i) { c.online = ok; c.probed = true; }
        }
        // 状态条远程真实指标 + 服务状态（对照 windows/apple Z6）：连接切换 → SSH 取选中服务器 /proc + systemctl
        while let Ok((cpu, mem, load, svcs)) = self.metrics_rx.try_recv() {
            self.metrics = (cpu, mem, load);
            self.services = svcs;
        }
        if active_host != self.metrics_target {
            self.metrics_target = active_host.clone();
            self.metrics = (0, 0, "…".to_string());
            self.services.clear();
            let (host, user, tx) = (active_host.clone(), active_user.clone(), self.metrics_tx.clone());
            std::thread::spawn(move || {
                let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
                if pass.is_empty() { return; }
                // 一条命令取齐：负载 + 内存(used total) + /proc/stat 两次采样算 CPU% + 关键服务 systemctl is-active
                let cmd = "cat /proc/loadavg|awk '{print $1}'; free -m|awk '/Mem:/{printf \"%d %d\\n\",$3,$2}'; \
                    awk '/^cpu /{print $2+$4\" \"$2+$4+$5}' /proc/stat; sleep 0.4; awk '/^cpu /{print $2+$4\" \"$2+$4+$5}' /proc/stat; \
                    for s in nginx docker mysql redis sshd; do echo $s:$(systemctl is-active $s 2>/dev/null); done";
                let out = ssh_exec(&host, 22, &user, &pass, cmd);
                let l: Vec<&str> = out.lines().filter(|s| !s.trim().is_empty()).collect();
                if l.len() < 4 { return; }
                let load = l[0].trim().to_string();
                let mem: Vec<f64> = l[1].split_whitespace().filter_map(|s| s.parse().ok()).collect();
                let c1: Vec<f64> = l[2].split_whitespace().filter_map(|s| s.parse().ok()).collect();
                let c2: Vec<f64> = l[3].split_whitespace().filter_map(|s| s.parse().ok()).collect();
                let mem_pct = if mem.len() == 2 && mem[1] > 0.0 { (mem[0] / mem[1] * 100.0).round() as u8 } else { 0 };
                let cpu_pct = if c1.len() == 2 && c2.len() == 2 && c2[1] > c1[1] { ((c2[0] - c1[0]) / (c2[1] - c1[1]) * 100.0).round() as u8 } else { 0 };
                // 解析服务状态行 svc:active/inactive/...
                let svcs: Vec<(String, bool)> = l.iter().filter(|s| s.contains(':') && !s.contains(' '))
                    .filter_map(|s| s.split_once(':').map(|(n, st)| (n.to_string(), st.trim() == "active"))).collect();
                let _ = tx.send((cpu_pct, mem_pct, load, svcs));
            });
        }
        // 接收 AI 真实回复（后台线程 ai_chat → ai_rx）+ 解析 [EXECUTE] 命令
        while let Ok(reply) = self.ai_rx.try_recv() {
            let cmds = parse_execute(&reply);
            self.ai_msgs.push((false, reply));
            self.ai_busy = false;
            // Chat 模式仅展示；Agent/Auto 收集待执行命令（Auto 非危险自动执行）
            if self.ai_mode != AiMode::Chat {
                for cmd in cmds {
                    if self.ai_mode == AiMode::Auto && !is_dangerous(&cmd) {
                        // Auto：非危险命令直接真实 SSH 执行
                        self.term_lines.push(format!("$ {}", cmd));
                        let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
                        if !pass.is_empty() {
                            let (host, user) = (active_host.clone(), active_user.clone());
                            let (tx, c) = (self.term_tx.clone(), cmd.clone());
                            std::thread::spawn(move || {
                                let start = std::time::Instant::now();
                                let out = ssh_exec(&host, 22, &user, &pass, &c);
                                let ok = !out.starts_with('⚠');
                                // 执行结果 + 耗时提示（运维参考，对照 windows）
                                let _ = tx.send(format!("{}\n{} 耗时 {}ms", out, if ok { "✓" } else { "✕" }, start.elapsed().as_millis()));
                            });
                        }
                    } else {
                        self.pending_cmds.push(cmd);   // Agent / Auto危险 → 待确认执行
                    }
                }
            }
        }
        // 接收 SSH 真实执行结果（后台线程 ssh_exec → term_rx）→ 追加终端
        while let Ok(out) = self.term_rx.try_recv() {
            for line in out.split('\n') { self.term_lines.push(line.to_string()); }
        }
        // 接收 SFTP ls 结果 → 解析填文件列表（对照 windows）
        while let Ok(out) = self.sftp_rx.try_recv() {
            self.sftp_loading = false;
            if out.starts_with('⚠') { self.sftp_path = out.clone(); self.sftp_files.clear(); }
            else { let (p, f) = Self::parse_sftp(&out); self.sftp_path = p; self.sftp_files = f; }
        }
        // 探测期间保持低频重绘以接收后台线程结果
        ctx.request_repaint_after(std::time::Duration::from_millis(500));

        // 顶栏
        egui::TopBottomPanel::top("topbar").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.add_space(6.0);
                ui.colored_label(ACCENT(), egui_phosphor::regular::LIGHTNING);
                ui.heading(egui::RichText::new("Termind").color(TEXT_PRIMARY()).strong());
                ui.colored_label(TEXT_SECONDARY(), "智能 SSH 运维");
                // 右侧工具栏：新建连接 / SFTP / 设置（对照 windows 顶部工具栏）
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if ui.add(egui::Button::new(egui::RichText::new(egui_phosphor::regular::GEAR).size(16.0).color(TEXT_SECONDARY())).frame(false)).clicked() {
                        self.show_settings = !self.show_settings;
                    }
                    if ui.add(egui::Button::new(egui::RichText::new(egui_phosphor::regular::FOLDER).size(16.0).color(TEXT_SECONDARY())).frame(false)).clicked() {
                        self.show_sftp = !self.show_sftp;
                        if self.show_sftp { self.run_sftp_ls("~"); }   // 打开时 SSH 取真实文件
                    }
                    let _ = ui.add(egui::Button::new(egui::RichText::new(egui_phosphor::regular::PLUS).size(16.0).color(ACCENT())).frame(false));
                });
            });
            ui.add_space(4.0);
        });

        // 设置窗口（对照 apple/windows SettingsView）
        let mut open = self.show_settings;
        egui::Window::new("设置")
            .open(&mut open)
            .resizable(false)
            .default_width(300.0)
            .show(ctx, |ui| {
                ui.colored_label(TEXT_SECONDARY(), "配色主题（U3：点击切换，像 VSCode）");
                ui.horizontal(|ui| {
                    let cur = THEME_IDX.load(std::sync::atomic::Ordering::Relaxed);
                    for (i, name) in THEME_NAMES.iter().enumerate() {
                        let sel = i == cur;
                        if ui.add(egui::Button::new(egui::RichText::new(*name).size(12.0)
                            .color(if sel { ACCENT() } else { TEXT_SECONDARY() }))
                            .fill(if sel { ACCENT().linear_multiply(0.15) } else { SURFACE() }).rounding(6.0)).clicked() {
                            THEME_IDX.store(i, std::sync::atomic::Ordering::Relaxed);   // 全窗主题实时切换
                            save_config(&self.api_key, &self.base_url, self.term_font_size, self.ai_font_size);   // 主题持久化
                        }
                    }
                });
                ui.add_space(8.0);
                ui.colored_label(TEXT_SECONDARY(), "AI 服务商");
                ui.horizontal(|ui| {
                    let _ = ui.add(egui::Button::new(egui::RichText::new("Anthropic Claude").size(12.0).color(ACCENT()))
                        .fill(ACCENT().linear_multiply(0.15)).rounding(6.0));
                    let _ = ui.add(egui::Button::new(egui::RichText::new("OpenAI").size(12.0).color(TEXT_SECONDARY()))
                        .fill(SURFACE()).rounding(6.0));
                });
                ui.add_space(8.0);
                ui.colored_label(TEXT_SECONDARY(), "API Key");
                // 失焦后持久化（对照 windows LostFocus 保存）
                if ui.add(egui::TextEdit::singleline(&mut self.api_key).password(true)
                    .hint_text("sk-ant-…").desired_width(f32::INFINITY)).lost_focus() {
                    save_config(&self.api_key, &self.base_url, self.term_font_size, self.ai_font_size);
                }
                ui.add_space(8.0);
                ui.colored_label(TEXT_SECONDARY(), "模型");
                ui.colored_label(TEXT_PRIMARY(), egui::RichText::new("claude-opus-4-8").monospace());
                ui.add_space(8.0);
                // API 地址（Base URL，对齐 apple/android/windows；OpenAI 兼容/代理/自托管）
                ui.colored_label(TEXT_SECONDARY(), "API 地址");
                if ui.add(egui::TextEdit::singleline(&mut self.base_url)
                    .hint_text("https://api.anthropic.com/v1/messages").desired_width(f32::INFINITY)
                    .font(egui::TextStyle::Monospace)).lost_focus() {
                    save_config(&self.api_key, &self.base_url, self.term_font_size, self.ai_font_size);
                }
                ui.add_space(8.0);
                // AI 系统提示词（可自定义，对齐 apple/android）
                ui.colored_label(TEXT_SECONDARY(), "AI 系统提示词");
                ui.add(egui::TextEdit::multiline(&mut self.sys_prompt)
                    .desired_width(f32::INFINITY).desired_rows(4));
            });
        self.show_settings = open;

        // SFTP 文件浏览窗口（占位，对照 apple/android SFTP）
        let mut sftp_open = self.show_sftp;
        let mut sftp_nav: Option<String> = None;   // 待导航目标目录（点击后循环外执行）
        let mut sftp_preview: Option<String> = None;   // 待预览文件（点击后循环外执行）
        let mut sftp_download: Option<(String, String)> = None;   // 待下载 (远程路径, 文件名)
        let mut sftp_delete: Option<String> = None;   // 待删除文件（嵌套确认后）
        let mut sftp_start_rename: Option<(String, String)> = None;   // 开始重命名 (原路径, 原名)
        egui::Window::new("SFTP 文件")
            .open(&mut sftp_open)
            .resizable(true)
            .default_width(420.0)
            .show(ctx, |ui| {
                let path = if self.sftp_path.is_empty() { "~".to_string() } else { self.sftp_path.clone() };
                ui.colored_label(TEXT_SECONDARY(), egui::RichText::new(&path).monospace());
                // 新建目录 / 重命名（输入框复用）+ 上传（rfd 选本地文件，对照 windows）
                let mut trigger_mkdir = false;
                let mut trigger_upload = false;
                let renaming = self.sftp_renaming.is_some();
                ui.horizontal(|ui| {
                    let hint = if renaming { "输入新名…" } else { "新建目录名…" };
                    ui.add(egui::TextEdit::singleline(&mut self.new_dir_name).hint_text(hint).desired_width(150.0).font(egui::TextStyle::Monospace));
                    let label = if renaming { "重命名" } else { "新建" };
                    if ui.add(egui::Button::new(egui::RichText::new(label).size(11.0).color(SUCCESS()))
                        .fill(SUCCESS().linear_multiply(0.12)).rounding(6.0)).clicked() {
                        trigger_mkdir = true;
                    }
                    let blue = egui::Color32::from_rgb(0x60, 0xA5, 0xFA);
                    if ui.add(egui::Button::new(egui::RichText::new("上传").size(11.0).color(blue))
                        .fill(blue.linear_multiply(0.12)).rounding(6.0)).on_hover_text("上传本地文件到当前目录").clicked() {
                        trigger_upload = true;
                    }
                });
                if trigger_mkdir { if renaming { self.run_sftp_rename(); } else { self.run_sftp_mkdir(); } }
                if trigger_upload { self.run_sftp_upload(); }
                ui.separator();
                if self.sftp_loading { ui.colored_label(TEXT_SECONDARY(), "加载中…"); }
                else if self.sftp_files.is_empty() { ui.colored_label(TEXT_SECONDARY(), "(空目录或未配置 SSH)"); }
                let cwd = path.clone();
                for (name, is_dir, size, time) in &self.sftp_files {
                    let (name, is_dir, size, time) = (name.as_str(), *is_dir, size.as_str(), time.as_str());
                    ui.horizontal(|ui| {
                        // 类型图标（对照 apple/android 文件类型图标）
                        use egui_phosphor::regular as ph;
                        let icon = if is_dir { ph::FOLDER } else if name.ends_with(".sh") { ph::TERMINAL_WINDOW }
                            else if name.ends_with(".gz") || name.ends_with(".zip") { ph::FILE_ZIP }
                            else if name.ends_with(".md") || name.ends_with(".txt") { ph::FILE_TEXT }
                            else { ph::GEAR };
                        ui.colored_label(if is_dir { ACCENT() } else { TEXT_SECONDARY() }, icon);
                        // 目录可点击导航（cd 进入 / .. 返回上级，对照 windows）
                        if is_dir {
                            if ui.add(egui::Label::new(egui::RichText::new(name).color(TEXT_PRIMARY()))
                                .sense(egui::Sense::click())).on_hover_cursor(egui::CursorIcon::PointingHand).clicked() {
                                sftp_nav = Some(format!("{}/{}", cwd, name));
                            }
                        } else {
                            // 文件：左键预览(head 到终端) / 右键菜单下载（对照 windows）
                            let resp = ui.add(egui::Label::new(egui::RichText::new(name).color(TEXT_PRIMARY()))
                                .sense(egui::Sense::click())).on_hover_cursor(egui::CursorIcon::PointingHand);
                            if resp.clicked() { sftp_preview = Some(format!("{}/{}", cwd, name)); }
                            resp.context_menu(|ui| {
                                if ui.button("下载到本地").clicked() {
                                    sftp_download = Some((format!("{}/{}", cwd, name), name.to_string()));
                                    ui.close_menu();
                                }
                                // 重命名：复用 new_dir_name 输入框 + sftp_renaming 标志（对照 windows/apple sftpRename）
                                if ui.button("重命名").clicked() {
                                    sftp_start_rename = Some((format!("{}/{}", cwd, name), name.to_string()));
                                    ui.close_menu();
                                }
                                // 删除：嵌套子菜单确认防误删（对照 windows/apple sftpRemove）
                                ui.menu_button(egui::RichText::new("删除").color(ACCENT()), |ui| {
                                    if ui.button(format!("⚠ 确认删除 {}", name)).clicked() {
                                        sftp_delete = Some(format!("{}/{}", cwd, name));
                                        ui.close_menu();
                                    }
                                });
                            });
                        }
                        // 右侧：大小 + 修改时间（对照 apple/android SFTP）
                        ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                            if !size.is_empty() {
                                ui.colored_label(TEXT_SECONDARY(), size);
                            }
                            if !time.is_empty() {
                                ui.colored_label(TEXT_SECONDARY().linear_multiply(0.7), egui::RichText::new(time).size(10.0));
                            }
                        });
                    });
                }
            });
        self.show_sftp = sftp_open;
        if let Some(target) = sftp_nav { self.run_sftp_ls(&target); }   // 导航到子目录/上级
        if let Some(file) = sftp_preview { self.run_sftp_preview(&file); }   // 预览文件到终端
        if let Some((path, fname)) = sftp_download { self.run_sftp_download(&path, &fname); }   // 下载到本地
        if let Some(path) = sftp_delete { self.run_sftp_delete(&path); }   // 删除文件（确认后）
        if let Some((path, name)) = sftp_start_rename { self.sftp_renaming = Some(path); self.new_dir_name = name; }   // 进入重命名模式

        // ① 左侧栏：连接列表（按分组）—— 三栏工作台对齐 apple/windows
        egui::SidePanel::left("connections")
            .resizable(false)
            .exact_width(280.0)
            .frame(egui::Frame::default().fill(SURFACE()).inner_margin(10.0))
            .show(ctx, |ui| {
                // 搜索框（对照 windows/apple 侧边栏，按名称/host 过滤）
                ui.add(egui::TextEdit::singleline(&mut self.search)
                    .hint_text(format!("{} 搜索连接", egui_phosphor::regular::MAGNIFYING_GLASS)).desired_width(f32::INFINITY));
                ui.add_space(6.0);
                ui.colored_label(TEXT_SECONDARY(), "SSH 连接");
                ui.add_space(6.0);
                let q = self.search.trim().to_lowercase();
                // 按分组聚合（过滤后），分组用 CollapsingHeader 可折叠（对照 apple/android）
                let mut groups: Vec<(String, Vec<usize>)> = vec![];
                for (i, c) in self.conns.iter().enumerate() {
                    if !q.is_empty()
                        && !c.name.to_lowercase().contains(&q)
                        && !c.host.to_lowercase().contains(&q)
                        && !c.user.to_lowercase().contains(&q) {
                        continue;
                    }
                    if let Some(g) = groups.iter_mut().find(|(name, _)| name == c.group) {
                        g.1.push(i);
                    } else {
                        groups.push((c.group.to_string(), vec![i]));
                    }
                }
                let mut clicked: Option<usize> = None;
                for (group, indices) in &groups {
                    egui::CollapsingHeader::new(egui::RichText::new(group).color(TEXT_SECONDARY()))
                        .default_open(true)
                        .show(ui, |ui| {
                            for &i in indices {
                                let resp = server_card(ui, &self.conns[i], self.selected == Some(i));
                                if resp.clicked() { clicked = Some(i); }
                            }
                        });
                }
                if let Some(i) = clicked { self.selected = Some(i); }
            });

        // ③ 右侧栏：AI 助手面板
        egui::SidePanel::right("ai")
            .resizable(false)
            .exact_width(320.0)
            .frame(egui::Frame::default().fill(SURFACE()).inner_margin(12.0))
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.colored_label(ACCENT(), egui::RichText::new("✦ AI 助手").strong());
                    // AI 字号 A-/A+（U4，对照 windows）
                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        if ui.add(egui::Button::new(egui::RichText::new("A+").size(11.0).color(TEXT_SECONDARY())).frame(false)).on_hover_text("放大 AI 字号").clicked() {
                            self.ai_font_size = (self.ai_font_size + 1.0).min(22.0);
                            save_config(&self.api_key, &self.base_url, self.term_font_size, self.ai_font_size);
                        }
                        if ui.add(egui::Button::new(egui::RichText::new("A-").size(11.0).color(TEXT_SECONDARY())).frame(false)).on_hover_text("缩小 AI 字号").clicked() {
                            self.ai_font_size = (self.ai_font_size - 1.0).max(10.0);
                            save_config(&self.api_key, &self.base_url, self.term_font_size, self.ai_font_size);
                        }
                    });
                });
                ui.add_space(6.0);
                // AI 三模式切换器（Chat/Agent/Auto，安全梯度，对照 windows）
                ui.horizontal(|ui| {
                    for (mode, label) in [(AiMode::Chat, "聊天"), (AiMode::Agent, "代理"), (AiMode::Auto, "全自动")] {
                        let on = self.ai_mode == mode;
                        if ui.add(egui::Button::new(egui::RichText::new(label).size(11.0)
                            .color(if on { TEXT_PRIMARY() } else { TEXT_SECONDARY() }))
                            .fill(if on { ACCENT() } else { SURFACE() }).rounding(6.0)).clicked() {
                            self.ai_mode = mode;
                        }
                    }
                    // 清空 / 导出对话（对照 windows）
                    let mut trigger_export = false;
                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        if ui.add(egui::Button::new(egui::RichText::new(egui_phosphor::regular::TRASH).size(13.0).color(TEXT_SECONDARY()))
                            .fill(egui::Color32::TRANSPARENT)).on_hover_text("清空对话").clicked() {
                            self.ai_msgs.clear();
                            self.pending_cmds.clear();
                        }
                        if ui.add(egui::Button::new(egui::RichText::new(egui_phosphor::regular::EXPORT).size(13.0).color(TEXT_SECONDARY()))
                            .fill(egui::Color32::TRANSPARENT)).on_hover_text("导出对话为 Markdown").clicked() {
                            trigger_export = true;
                        }
                    });
                    if trigger_export { self.export_chat(); }
                });
                // 待执行命令卡片（Agent 确认放行 / Auto 危险命令确认）
                let mut run_idx: Option<usize> = None;
                let mut fill_cmd: Option<String> = None;
                for (i, cmd) in self.pending_cmds.iter().enumerate() {
                    let (rlabel, rcolor) = risk_style(risk_level(cmd));   // 四级风险配色+标签（对照 apple/windows）
                    ui.horizontal(|ui| {
                        ui.colored_label(rcolor,
                            egui::RichText::new(format!("{}{}", if rlabel.is_empty() { String::new() } else { format!("[{}] ", rlabel) }, cmd)).monospace().size(11.0));
                        if ui.add(egui::Button::new(egui::RichText::new("▶ 执行").size(10.0).color(TEXT_PRIMARY()))
                            .fill(ACCENT()).rounding(6.0)).clicked() {
                            run_idx = Some(i);
                        }
                        // 填入终端（命令填入输入框可编辑后执行，对照 windows）
                        if ui.add(egui::Button::new(egui::RichText::new("填入").size(10.0).color(TEXT_SECONDARY()))
                            .fill(SURFACE()).rounding(6.0)).clicked() {
                            fill_cmd = Some(cmd.clone());
                        }
                    });
                }
                if let Some(c) = fill_cmd { self.cmd_input = c; }
                if let Some(i) = run_idx {
                    let cmd = self.pending_cmds.remove(i);
                    self.term_lines.push(format!("$ {}", cmd));
                    let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
                    if !pass.is_empty() {
                        let (host, user) = (active_host.clone(), active_user.clone());
                        let (tx, c) = (self.term_tx.clone(), cmd);
                        std::thread::spawn(move || { let _ = tx.send(ssh_exec(&host, 22, &user, &pass, &c)); });
                    }
                }
                ui.add_space(10.0);
                // 第一轮对话（展示连续性 + AI 结合真实环境）
                ui.colored_label(TEXT_SECONDARY(), egui::RichText::new("你").size(10.0).strong());
                egui::Frame::default().fill(egui::Color32::from_rgb(0x3B, 0x82, 0xF6)).rounding(10.0).inner_margin(10.0)
                    .show(ui, |ui| { ui.colored_label(TEXT_PRIMARY(), "这台机器装了什么服务？"); });
                ui.add_space(6.0);
                ui.horizontal(|ui| {
                    ui.colored_label(ACCENT(), egui::RichText::new(egui_phosphor::regular::SPARKLE).size(10.0));
                    ui.colored_label(TEXT_SECONDARY(), egui::RichText::new("AI").size(10.0).strong());
                });
                egui::Frame::default().fill(BG()).rounding(10.0).inner_margin(10.0)
                    .show(ui, |ui| { ui.colored_label(TEXT_PRIMARY(), "检测到 nginx(运行)、docker(运行)、mysql(运行)、redis(未运行)。需要我帮你启动 redis 吗？"); });
                ui.add_space(8.0);
                // 第二轮对话：角色标签 + 气泡（对照 apple/android）
                ui.colored_label(TEXT_SECONDARY(), egui::RichText::new("你").size(10.0).strong());
                egui::Frame::default().fill(egui::Color32::from_rgb(0x3B, 0x82, 0xF6)).rounding(10.0).inner_margin(10.0)
                    .show(ui, |ui| { ui.colored_label(TEXT_PRIMARY(), "怎么查看 Nginx 错误日志？"); });
                ui.add_space(6.0);
                // AI 消息：角色标签 + 气泡
                ui.horizontal(|ui| {
                    ui.colored_label(ACCENT(), egui::RichText::new(egui_phosphor::regular::SPARKLE).size(10.0));
                    ui.colored_label(TEXT_SECONDARY(), egui::RichText::new("AI").size(10.0).strong());
                });
                egui::Frame::default().fill(BG()).rounding(10.0).inner_margin(10.0).show(ui, |ui| {
                    ui.colored_label(TEXT_PRIMARY(), "用下面的命令查看最近的错误日志：");
                    ui.add_space(4.0);
                    egui::Frame::default().fill(egui::Color32::BLACK).rounding(6.0).inner_margin(8.0).show(ui, |ui| {
                        ui.colored_label(SUCCESS(), egui::RichText::new("tail -n 50 /var/log/nginx/error.log").monospace());
                    });
                });
                // AI 真实对话（true=用户提问蓝气泡 / false=AI 真实回复气泡）；字号 U4 可调
                let aifs = self.ai_font_size;
                for (is_user, text) in &self.ai_msgs {
                    ui.add_space(6.0);
                    if *is_user {
                        ui.colored_label(TEXT_SECONDARY(), egui::RichText::new("你").size(10.0).strong());
                        egui::Frame::default().fill(egui::Color32::from_rgb(0x3B, 0x82, 0xF6)).rounding(10.0).inner_margin(10.0)
                            .show(ui, |ui| { ui.colored_label(TEXT_PRIMARY(), egui::RichText::new(text).size(aifs)); });
                    } else {
                        ui.horizontal(|ui| {
                            ui.colored_label(ACCENT(), egui::RichText::new(egui_phosphor::regular::SPARKLE).size(10.0));
                            ui.colored_label(TEXT_SECONDARY(), egui::RichText::new("AI").size(10.0).strong());
                        });
                        egui::Frame::default().fill(BG()).rounding(10.0).inner_margin(10.0)
                            .show(ui, |ui| { render_ai_reply(ui, text, aifs); });
                    }
                }
                if self.ai_busy {
                    ui.add_space(6.0);
                    ui.colored_label(TEXT_SECONDARY(), "✦ AI 思考中…");
                }
                ui.add_space(10.0);
                // 运维快捷入口（对照 apple 护城河 Z1命令解释/Z2报错分析/Z3健康巡检 + windows）
                // 解释/报错 → 预填提问；健康巡检 → 一键真闭环（标记触发，循环外执行避免借用冲突）
                let mut trigger_health = false;
                let mut trigger_error = false;
                ui.horizontal(|ui| {
                    // 解释命令：预填提问
                    if ui.add(egui::Button::new(egui::RichText::new("解释命令").size(11.0).color(ACCENT()))
                        .fill(ACCENT().linear_multiply(0.12)).rounding(14.0)).clicked() {
                        self.ai_input = "解释这条命令的作用、参数含义和潜在风险：".to_string();
                    }
                    // 分析报错：一键触发（SSH 取错误日志 → AI 诊断）
                    if ui.add(egui::Button::new(egui::RichText::new("分析报错").size(11.0).color(SUCCESS()))
                        .fill(SUCCESS().linear_multiply(0.12)).rounding(14.0)).clicked() {
                        trigger_error = true;
                    }
                    // 健康巡检：一键触发（SSH 取真实指标 → AI 分析）
                    if ui.add(egui::Button::new(egui::RichText::new("健康巡检").size(11.0).color(SUCCESS()))
                        .fill(SUCCESS().linear_multiply(0.12)).rounding(14.0)).clicked() {
                        trigger_health = true;
                    }
                });
                if trigger_health { self.run_health_check(); }
                if trigger_error { self.run_error_analysis(); }
                ui.add_space(6.0);
                // 快捷追问 chips（点击填入 AI 输入框，对照 apple/windows AI 面板 + 快捷命令交互）
                ui.horizontal(|ui| {
                    let blue = egui::Color32::from_rgb(0x3B, 0x82, 0xF6);
                    for q in ["如何排查？", "给我具体命令", "有什么风险？"] {
                        if ui.add(egui::Button::new(egui::RichText::new(q).size(11.0).color(blue))
                            .fill(blue.linear_multiply(0.12)).rounding(14.0)).clicked() {
                            self.ai_input = q.to_string();
                        }
                    }
                });
                ui.add_space(8.0);
                // AI 输入框 + 发送按钮（对照 apple/windows）
                ui.horizontal(|ui| {
                    let send = ui.add_sized(
                        [28.0, 28.0],
                        egui::Button::new(egui::RichText::new(egui_phosphor::regular::PAPER_PLANE_TILT).size(15.0).color(TEXT_PRIMARY()))
                            .fill(ACCENT()).rounding(14.0));
                    let resp = ui.add_sized(
                        [ui.available_width(), 28.0],
                        egui::TextEdit::singleline(&mut self.ai_input).hint_text("输入指令…"));
                    // 发送按钮点击 或 回车 → 追加提问气泡（后续接 AI 回复）
                    let enter = resp.lost_focus() && ui.input(|i| i.key_pressed(egui::Key::Enter));
                    if (send.clicked() || enter) && !self.ai_input.trim().is_empty() && !self.ai_busy {
                        let user_msg = self.ai_input.trim().to_string();
                        self.ai_msgs.push((true, user_msg.clone()));
                        self.ai_input.clear();
                        // 后台线程真实调 AI（对照 reach_rx 模式），结果经 ai_tx 回传
                        if self.api_key.is_empty() {
                            self.ai_msgs.push((false, "⚠️ 未配置 API Key（环境变量 TERMIND_AI_KEY 或设置面板）".to_string()));
                        } else {
                            self.ai_busy = true;
                            let (base, key, model, sys_base, tx) =
                                (self.base_url.clone(), self.api_key.clone(), "claude-opus-4-8".to_string(), self.sys_prompt.clone(), self.ai_tx.clone());
                            // Z3 环境感知：后台先 SSH 取真实环境注入系统提示（对照 windows）
                            std::thread::spawn(move || {
                                let env = fetch_server_env();
                                let sys = if env.is_empty() { sys_base }
                                    else { format!("{}\n\n【当前服务器真实环境】\n{}\n请结合以上真实环境给针对性建议。", sys_base, env) };
                                let _ = tx.send(ai_chat(&base, &key, &model, &sys, &user_msg));
                            });
                        }
                    }
                });
            });

        // ② 中间：终端区（状态条 + 输出）—— 状态条反映选中的连接
        let (sel_user, sel_host, sel_online) = self.selected.and_then(|i| self.conns.get(i))
            .map(|c| (c.user, c.host, c.online)).unwrap_or(("root", "prod-01", true));
        // 终端提示符联动选中连接（user@host:~$）
        let prompt = format!("{}@{}:~$", sel_user, sel_host);
        egui::CentralPanel::default()
            .frame(egui::Frame::default().fill(BG()).inner_margin(12.0))
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.colored_label(if sel_online { SUCCESS() } else { TEXT_SECONDARY() },
                        if sel_online { "● 已连接" } else { "○ 离线" });
                    ui.colored_label(TEXT_SECONDARY(), sel_host);
                    // CPU/内存 mini 进度条：远程选中服务器真实指标（SSH 取 /proc，对照 windows）
                    let (cpu_pct, mem_pct, load) = (self.metrics.0, self.metrics.1, self.metrics.2.clone());
                    ui.colored_label(TEXT_SECONDARY(), "CPU");
                    ui.add(egui::ProgressBar::new(cpu_pct as f32 / 100.0).desired_width(54.0)
                        .text(format!("{}%", cpu_pct)).fill(usage_color(cpu_pct)))
                        .on_hover_text("选中服务器真实 CPU 占用（/proc/stat 采样）");
                    ui.colored_label(TEXT_SECONDARY(), "内存");
                    ui.add(egui::ProgressBar::new(mem_pct as f32 / 100.0).desired_width(54.0)
                        .text(format!("{}%", mem_pct)).fill(usage_color(mem_pct)))
                        .on_hover_text("选中服务器真实内存占用（free）");
                    ui.colored_label(TEXT_SECONDARY(), format!("负载 {}", load));
                    // 关键服务真实运行状态点（SSH systemctl is-active 取，对照 apple/android Z6）
                    if !self.services.is_empty() {
                        ui.separator();
                        for (svc, running) in &self.services {
                            ui.colored_label(if *running { SUCCESS() } else { TEXT_SECONDARY() }, "●");
                            ui.colored_label(if *running { TEXT_PRIMARY() } else { TEXT_SECONDARY() }, svc);
                        }
                    }
                    // 终端字号调整（U4，对照 windows A-/A+）
                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        if ui.add(egui::Button::new(egui::RichText::new("A+").size(11.0).color(TEXT_SECONDARY())).frame(false)).on_hover_text("放大终端字号").clicked() {
                            self.term_font_size = (self.term_font_size + 1.0).min(22.0);
                            save_config(&self.api_key, &self.base_url, self.term_font_size, self.ai_font_size);   // 字号持久化
                        }
                        if ui.add(egui::Button::new(egui::RichText::new("A-").size(11.0).color(TEXT_SECONDARY())).frame(false)).on_hover_text("缩小终端字号").clicked() {
                            self.term_font_size = (self.term_font_size - 1.0).max(9.0);
                            save_config(&self.api_key, &self.base_url, self.term_font_size, self.ai_font_size);
                        }
                        // 终端输出搜索（匹配行高亮，对照 windows）
                        ui.add(egui::TextEdit::singleline(&mut self.term_search).hint_text("搜索输出…").desired_width(120.0).font(egui::TextStyle::Small));
                    });
                });
                ui.add_space(8.0);
                egui::Frame::default().fill(egui::Color32::from_rgb(0x0A, 0x0B, 0x14)).rounding(6.0).inner_margin(12.0)
                    .show(ui, |ui| {
                        // 终端输出可滚动（对照 windows，输出多时查看历史）
                        egui::ScrollArea::vertical().auto_shrink([false, false]).max_height(360.0).show(ui, |ui| {
                            ui.colored_label(TEXT_SECONDARY(), egui::RichText::new("Last login: Sun Jun 22 19:00 on ttys001").monospace());
                            ui.colored_label(TEXT_PRIMARY(), egui::RichText::new(format!("{} ls -la", prompt)).monospace());
                            ui.colored_label(TEXT_PRIMARY(), egui::RichText::new("total 32").monospace());
                            ui.colored_label(TEXT_PRIMARY(), egui::RichText::new("drwxr-xr-x  6 root root 4096 Jun 22 18:00 .").monospace());
                            ui.colored_label(TEXT_PRIMARY(), egui::RichText::new("-rw-r--r--  1 root root  220 Jun 10 09:12 .bashrc").monospace());
                            ui.colored_label(SUCCESS(), egui::RichText::new("-rwxr-xr-x  1 root root 1024 Jun 22 17:30 deploy.sh").monospace());
                            ui.colored_label(ACCENT(), egui::RichText::new("drwxr-xr-x  4 root root 4096 Jun 22 18:00 projects").monospace());
                            ui.colored_label(TEXT_PRIMARY(), egui::RichText::new(format!("{} systemctl status nginx", prompt)).monospace());
                            ui.colored_label(SUCCESS(), egui::RichText::new("● nginx.service - A high performance web server").monospace());
                            ui.colored_label(TEXT_PRIMARY(), egui::RichText::new("   Active: active (running) since Mon 2026-06-22").monospace());
                            // 用户输入回车后追加的历史命令行（ANSI 转义→彩色，对照 windows）
                            let fsz = self.term_font_size;   // U4 可调字号
                            let q = self.term_search.trim().to_lowercase();   // 终端搜索
                            for line in &self.term_lines {
                                // 搜索命中行：橙色半透明高亮背景（对照 windows）
                                let hit = !q.is_empty() && line.to_lowercase().contains(&q);
                                if hit {
                                    egui::Frame::default().fill(egui::Color32::from_rgba_unmultiplied(0xF5, 0x9E, 0x0B, 0x33))
                                        .show(ui, |ui| {
                                            if line.contains('\u{1b}') { ui.label(ansi_to_job(line, TEXT_PRIMARY(), fsz)); }
                                            else { ui.colored_label(TEXT_PRIMARY(), egui::RichText::new(line).monospace().size(fsz)); }
                                        });
                                } else if line.contains('\u{1b}') { ui.label(ansi_to_job(line, TEXT_PRIMARY(), fsz)); }
                                else { ui.colored_label(TEXT_PRIMARY(), egui::RichText::new(line).monospace().size(fsz)); }
                            }
                            ui.colored_label(TEXT_PRIMARY(), egui::RichText::new(format!("{} \u{2588}", prompt)).monospace());
                        });
                    });
                ui.add_space(8.0);
                // 快捷命令栏（对照 windows/apple/android 终端区；横滚容纳更多运维命令）
                egui::ScrollArea::horizontal().max_height(28.0).show(ui, |ui| {
                    ui.horizontal(|ui| {
                        for cmd in ["ls -la", "df -h", "free -h", "ps aux --sort=-%cpu | head", "ss -tlnp", "uptime", "top"] {
                            if ui.add(egui::Button::new(
                                egui::RichText::new(cmd).monospace().size(11.0).color(ACCENT()))
                                .fill(ACCENT().linear_multiply(0.12)).rounding(14.0)).clicked() {
                                self.cmd_input = cmd.to_string();
                            }
                        }
                        // 高风险/需谨慎命令橙色
                        for cmd in ["journalctl -xe -n 50", "systemctl status nginx"] {
                            if ui.add(egui::Button::new(
                                egui::RichText::new(cmd).monospace().size(11.0).color(WARNING()))
                                .fill(WARNING().linear_multiply(0.12)).rounding(14.0)).clicked() {
                                self.cmd_input = cmd.to_string();
                            }
                        }
                    });
                });
                ui.add_space(8.0);
                // 命令输入框（提示符 + 输入 + 批量群发按钮；快捷命令点击填入；回车追加终端）
                let mut trigger_batch = false;
                ui.horizontal(|ui| {
                    ui.colored_label(SUCCESS(), egui::RichText::new(format!("{} ", prompt)).monospace());
                    // 批量群发按钮（护城河 batch，对照 windows）：对所有连接群发命令
                    if ui.add(egui::Button::new(egui::RichText::new(egui_phosphor::regular::USERS_THREE).size(15.0).color(WARNING())).frame(false))
                        .on_hover_text("批量群发：对所有连接执行此命令").clicked() {
                        trigger_batch = true;
                    }
                    let resp = ui.add_sized([ui.available_width(), 24.0],
                        egui::TextEdit::singleline(&mut self.cmd_input).hint_text("输入命令…").font(egui::TextStyle::Monospace));
                    // ↑/↓ 键回溯命令历史（终端常用交互）
                    if resp.has_focus() && !self.cmd_history.is_empty() {
                        if ui.input(|i| i.key_pressed(egui::Key::ArrowUp)) {
                            let idx = self.hist_idx.map_or(0, |i| (i + 1).min(self.cmd_history.len() - 1));
                            self.hist_idx = Some(idx);
                            self.cmd_input = self.cmd_history[idx].clone();
                        } else if ui.input(|i| i.key_pressed(egui::Key::ArrowDown)) {
                            match self.hist_idx {
                                Some(0) | None => { self.hist_idx = None; self.cmd_input.clear(); }
                                Some(i) => { let n = i - 1; self.hist_idx = Some(n); self.cmd_input = self.cmd_history[n].clone(); }
                            }
                        }
                    }
                    if resp.lost_focus() && ui.input(|i| i.key_pressed(egui::Key::Enter)) && !self.cmd_input.trim().is_empty() {
                        let cmd = self.cmd_input.trim().to_string();
                        // 入历史（最近优先，去重）
                        self.cmd_history.retain(|c| c != &cmd);
                        self.cmd_history.insert(0, cmd.clone());
                        self.hist_idx = None;
                        if cmd == "clear" {
                            self.term_lines.clear();   // clear 清屏（终端常用命令）
                        } else {
                            // 命令行回显 + 真实 SSH 在服务器执行（后台线程，结果经 term_tx 回传）
                            self.term_lines.push(format!("{} {}", prompt, cmd));
                            let pass = std::env::var("TERMIND_SSH_PASS").unwrap_or_default();
                            if pass.is_empty() {
                                self.term_lines.push("⚠️ 未配置 SSH 密码（环境变量 TERMIND_SSH_PASS）".to_string());
                            } else {
                                let (host, user) = (active_host.clone(), active_user.clone());
                                let (tx, c) = (self.term_tx.clone(), cmd.clone());
                                std::thread::spawn(move || {
                                let start = std::time::Instant::now();
                                let out = ssh_exec(&host, 22, &user, &pass, &c);
                                let ok = !out.starts_with('⚠');
                                // 执行结果 + 耗时提示（运维参考，对照 windows）
                                let _ = tx.send(format!("{}\n{} 耗时 {}ms", out, if ok { "✓" } else { "✕" }, start.elapsed().as_millis()));
                            });
                            }
                        }
                        self.cmd_input.clear();
                        resp.request_focus();   // 保持焦点便于连续输入
                    }
                });
                if trigger_batch { self.run_batch_exec(); }   // 批量群发（循环外执行避免借用冲突）
            });
    }
}

/// 单个连接卡片
fn server_card(ui: &mut egui::Ui, c: &ServerConn, selected: bool) -> egui::Response {
    let frame = egui::Frame::default()
        .fill(if selected { ACCENT().linear_multiply(0.2) } else { SURFACE() })
        .rounding(10.0)
        .inner_margin(12.0);
    frame
        .show(ui, |ui| {
            ui.horizontal(|ui| {
                let dot = if c.online { SUCCESS() } else { TEXT_SECONDARY() };
                ui.colored_label(dot, "●");
                ui.vertical(|ui| {
                    ui.colored_label(TEXT_PRIMARY(), egui::RichText::new(c.name).strong());
                    ui.colored_label(TEXT_SECONDARY(), format!("{}@{}:{}", c.user, c.host, c.port));
                    if !c.note.is_empty() {
                        ui.colored_label(TEXT_SECONDARY(), format!("{} {}", egui_phosphor::regular::NOTE_PENCIL, c.note));
                    }
                    if !c.last_used.is_empty() {
                        ui.colored_label(TEXT_SECONDARY().linear_multiply(0.8), format!("上次使用 · {}", c.last_used));
                    }
                });
                // 右侧可达指示（探测中 / 可达 / 不可达，真实 TCP 探测；phosphor 矢量图标）
                use egui_phosphor::regular as ph;
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if !c.probed {
                        ui.colored_label(TEXT_SECONDARY().linear_multiply(0.7), ph::CIRCLE_DASHED);
                    } else if c.online {
                        ui.colored_label(SUCCESS(), egui::RichText::new(ph::CHECK_CIRCLE).strong());
                    } else {
                        ui.colored_label(TEXT_SECONDARY(), ph::X_CIRCLE);
                    }
                });
            });
        })
        .response
        .interact(egui::Sense::click())
}

/// 加载 JetBrains Mono 等宽字体（U4：好看的字体库，对照 windows）
fn setup_fonts(ctx: &egui::Context) {
    let mut fonts = egui::FontDefinitions::default();
    fonts.font_data.insert(
        "jbmono".to_owned(),
        egui::FontData::from_static(include_bytes!("../assets/JetBrainsMono-Regular.ttf")),
    );
    // JetBrains Mono 作为等宽字体首选；也加到比例字体兜底（含 ASCII 更清晰）
    fonts.families.entry(egui::FontFamily::Monospace).or_default().insert(0, "jbmono".to_owned());
    fonts.families.entry(egui::FontFamily::Proportional).or_default().push("jbmono".to_owned());
    // Phosphor 图标字体（U1：禁 emoji，UI 图标用矢量图标字体）
    egui_phosphor::add_to_fonts(&mut fonts, egui_phosphor::Variant::Regular);
    ctx.set_fonts(fonts);
}

fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default().with_inner_size([1200.0, 760.0]),
        ..Default::default()
    };
    eframe::run_native(
        "Termind",
        options,
        Box::new(|cc| {
            setup_fonts(&cc.egui_ctx);
            Box::<TermindApp>::default()
        }),
    )
}
