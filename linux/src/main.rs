// Termind — 智能 SSH 服务器运维工作台（Linux 原生端骨架）
// Rust + egui/eframe。与 apple(Swift)/android(Kotlin) 端统一定位与配色。
//
// ⚠️ 本骨架在 macOS 开发机上未编译验证（无 Rust toolchain）。需在 Linux + Rust 环境
//    `cargo run` 构建。后续接 ssh2 实现真实 SSH/SFTP、ureq 接 AI。

use eframe::egui;

// Termind 品牌配色（呼应 apple/android：午夜深蓝 + 珊瑚红）
const BG: egui::Color32 = egui::Color32::from_rgb(0x1A, 0x1A, 0x2E);
const SURFACE: egui::Color32 = egui::Color32::from_rgb(0x16, 0x21, 0x3E);
const ACCENT: egui::Color32 = egui::Color32::from_rgb(0xE9, 0x45, 0x60);
const TEXT_PRIMARY: egui::Color32 = egui::Color32::from_rgb(0xEE, 0xEE, 0xEE);
const TEXT_SECONDARY: egui::Color32 = egui::Color32::from_rgb(0xA0, 0xA0, 0xA0);
const SUCCESS: egui::Color32 = egui::Color32::from_rgb(0x2E, 0xCC, 0x71);
const WARNING: egui::Color32 = egui::Color32::from_rgb(0xF5, 0x9E, 0x0B);

/// 占用率着色：绿<60 / 橙60-80 / 红>80（对齐 apple/android 状态面板进度条）
fn usage_color(pct: u8) -> egui::Color32 {
    if pct > 80 { ACCENT } else if pct > 60 { WARNING } else { SUCCESS }
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
        ServerConn { name: "生产 Web 01", host: "web01.example.com", user: "deploy", port: 22, group: "生产环境", online: true, probed: false, note: "官网 + API", last_used: "5 分钟前" },
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
    ai_msgs: Vec<String>,      // AI 区用户输入回车后追加的提问气泡
    cmd_history: Vec<String>,  // 命令历史（去重最近优先），供上下键回溯
    hist_idx: Option<usize>,   // 当前回溯位置（None=未回溯）
    reach_rx: std::sync::mpsc::Receiver<(usize, bool)>,  // 后台 TCP 可达性探测结果
}

/// 读本机真实负载（/proc/loadavg，真实系统指标；非 Linux/读失败返回 None）
fn read_loadavg() -> Option<String> {
    let s = std::fs::read_to_string("/proc/loadavg").ok()?;
    let parts: Vec<&str> = s.split_whitespace().take(3).collect();
    if parts.len() == 3 { Some(parts.join(" ")) } else { None }
}

/// 读本机真实运行时长（/proc/uptime，格式化「X天Y时」；非 Linux/读失败返回 None）
fn read_uptime() -> Option<String> {
    let s = std::fs::read_to_string("/proc/uptime").ok()?;
    let secs = s.split_whitespace().next()?.parse::<f64>().ok()? as u64;
    let days = secs / 86400;
    let hours = (secs % 86400) / 3600;
    Some(if days > 0 { format!("{}天{}时", days, hours) } else { format!("{}时{}分", hours, (secs % 3600) / 60) })
}

/// 读本机真实内存占用（/proc/meminfo：(已用GB, 总GB, 占用%)；非 Linux/读失败返回 None）
fn read_mem() -> Option<(f64, f64, u8)> {
    let s = std::fs::read_to_string("/proc/meminfo").ok()?;
    let kb = |key: &str| -> Option<f64> {
        s.lines().find(|l| l.starts_with(key))?
            .split_whitespace().nth(1)?.parse::<f64>().ok()
    };
    let total = kb("MemTotal:")?;
    let avail = kb("MemAvailable:")?;
    if total <= 0.0 { return None; }
    let used = total - avail;
    let pct = ((used / total) * 100.0).round() as u8;
    Some((used / 1024.0 / 1024.0, total / 1024.0 / 1024.0, pct))
}

/// TCP 可达性探测（真实逻辑第一步，std::net 无需额外依赖）：connect_timeout 2s
fn probe_tcp(host: &str, port: u16) -> bool {
    use std::net::ToSocketAddrs;
    match (host, port).to_socket_addrs() {
        Ok(mut addrs) => addrs.next().map_or(false, |addr|
            std::net::TcpStream::connect_timeout(&addr, std::time::Duration::from_secs(2)).is_ok()),
        Err(_) => false,
    }
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
        Self { conns, selected: None, search: String::new(), ai_input: String::new(), show_settings: false, api_key: String::new(), base_url: "https://api.anthropic.com/v1/messages".to_string(), sys_prompt: "你是 Termind 的 SSH 运维助手。请结合服务器环境，给出安全、可直接执行的运维建议。危险操作（删除/格式化/重启服务/改防火墙）必须警示风险并建议先备份。回答精炼、用中文，命令用代码块。".to_string(), show_sftp: false, cmd_input: String::new(), term_lines: Vec::new(), ai_msgs: Vec::new(), cmd_history: Vec::new(), hist_idx: None, reach_rx }
    }
}

/// SFTP 文件项（占位）：name/是否目录/大小/修改时间（对照 apple/android SFTP）
fn sftp_demo() -> Vec<(&'static str, bool, &'static str, &'static str)> {
    vec![
        ("..", true, "", ""),
        ("projects", true, "", "06-22 18:00"),
        (".ssh", true, "", "06-10 09:12"),
        ("logs", true, "", "06-22 17:30"),
        ("deploy.sh", false, "1.0 KB", "06-22 17:30"),
        (".bashrc", false, "220 B", "06-10 09:12"),
        ("backup.tar.gz", false, "48.2 MB", "06-21 02:00"),
        ("notes.md", false, "3.4 KB", "06-22 14:20"),
    ]
}

impl eframe::App for TermindApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // 应用后台 TCP 探测结果（真实可达性）→ 更新连接 online 状态
        while let Ok((i, ok)) = self.reach_rx.try_recv() {
            if let Some(c) = self.conns.get_mut(i) { c.online = ok; c.probed = true; }
        }
        // 探测期间保持低频重绘以接收后台线程结果
        ctx.request_repaint_after(std::time::Duration::from_millis(500));

        // 顶栏
        egui::TopBottomPanel::top("topbar").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.add_space(6.0);
                ui.colored_label(ACCENT, egui_phosphor::regular::LIGHTNING);
                ui.heading(egui::RichText::new("Termind").color(TEXT_PRIMARY).strong());
                ui.colored_label(TEXT_SECONDARY, "智能 SSH 运维");
                // 右侧工具栏：新建连接 / SFTP / 设置（对照 windows 顶部工具栏）
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if ui.add(egui::Button::new(egui::RichText::new(egui_phosphor::regular::GEAR).size(16.0).color(TEXT_SECONDARY)).frame(false)).clicked() {
                        self.show_settings = !self.show_settings;
                    }
                    if ui.add(egui::Button::new(egui::RichText::new(egui_phosphor::regular::FOLDER).size(16.0).color(TEXT_SECONDARY)).frame(false)).clicked() {
                        self.show_sftp = !self.show_sftp;
                    }
                    let _ = ui.add(egui::Button::new(egui::RichText::new(egui_phosphor::regular::PLUS).size(16.0).color(ACCENT)).frame(false));
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
                ui.colored_label(TEXT_SECONDARY, "配色主题");
                ui.horizontal(|ui| {
                    for (name, sel) in [("午夜", true), ("Dracula", false), ("Nord", false)] {
                        let _ = ui.add(egui::Button::new(egui::RichText::new(name).size(12.0)
                            .color(if sel { ACCENT } else { TEXT_SECONDARY }))
                            .fill(if sel { ACCENT.linear_multiply(0.15) } else { SURFACE }).rounding(6.0));
                    }
                });
                ui.add_space(8.0);
                ui.colored_label(TEXT_SECONDARY, "AI 服务商");
                ui.horizontal(|ui| {
                    let _ = ui.add(egui::Button::new(egui::RichText::new("Anthropic Claude").size(12.0).color(ACCENT))
                        .fill(ACCENT.linear_multiply(0.15)).rounding(6.0));
                    let _ = ui.add(egui::Button::new(egui::RichText::new("OpenAI").size(12.0).color(TEXT_SECONDARY))
                        .fill(SURFACE).rounding(6.0));
                });
                ui.add_space(8.0);
                ui.colored_label(TEXT_SECONDARY, "API Key");
                ui.add(egui::TextEdit::singleline(&mut self.api_key).password(true)
                    .hint_text("sk-ant-…").desired_width(f32::INFINITY));
                ui.add_space(8.0);
                ui.colored_label(TEXT_SECONDARY, "模型");
                ui.colored_label(TEXT_PRIMARY, egui::RichText::new("claude-opus-4-8").monospace());
                ui.add_space(8.0);
                // API 地址（Base URL，对齐 apple/android/windows；OpenAI 兼容/代理/自托管）
                ui.colored_label(TEXT_SECONDARY, "API 地址");
                ui.add(egui::TextEdit::singleline(&mut self.base_url)
                    .hint_text("https://api.anthropic.com/v1/messages").desired_width(f32::INFINITY)
                    .font(egui::TextStyle::Monospace));
                ui.add_space(8.0);
                // AI 系统提示词（可自定义，对齐 apple/android）
                ui.colored_label(TEXT_SECONDARY, "AI 系统提示词");
                ui.add(egui::TextEdit::multiline(&mut self.sys_prompt)
                    .desired_width(f32::INFINITY).desired_rows(4));
            });
        self.show_settings = open;

        // SFTP 文件浏览窗口（占位，对照 apple/android SFTP）
        let mut sftp_open = self.show_sftp;
        egui::Window::new("SFTP 文件")
            .open(&mut sftp_open)
            .resizable(true)
            .default_width(420.0)
            .show(ctx, |ui| {
                ui.colored_label(TEXT_SECONDARY, egui::RichText::new("↑ /home/deploy").monospace());
                ui.separator();
                for (name, is_dir, size, time) in sftp_demo() {
                    ui.horizontal(|ui| {
                        // 类型图标（对照 apple/android 文件类型图标）
                        let icon = if is_dir { "📁" } else if name.ends_with(".sh") { "⌨" }
                            else if name.ends_with(".gz") || name.ends_with(".zip") { "🗜" }
                            else if name.ends_with(".md") || name.ends_with(".txt") { "📄" }
                            else { "⚙" };
                        ui.colored_label(if is_dir { ACCENT } else { TEXT_SECONDARY }, icon);
                        ui.colored_label(TEXT_PRIMARY, name);
                        // 右侧：大小 + 修改时间（对照 apple/android SFTP）
                        ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                            if !size.is_empty() {
                                ui.colored_label(TEXT_SECONDARY, size);
                            }
                            if !time.is_empty() {
                                ui.colored_label(TEXT_SECONDARY.linear_multiply(0.7), egui::RichText::new(time).size(10.0));
                            }
                        });
                    });
                }
            });
        self.show_sftp = sftp_open;

        // ① 左侧栏：连接列表（按分组）—— 三栏工作台对齐 apple/windows
        egui::SidePanel::left("connections")
            .resizable(false)
            .exact_width(280.0)
            .frame(egui::Frame::default().fill(SURFACE).inner_margin(10.0))
            .show(ctx, |ui| {
                // 搜索框（对照 windows/apple 侧边栏，按名称/host 过滤）
                ui.add(egui::TextEdit::singleline(&mut self.search)
                    .hint_text("🔍 搜索连接").desired_width(f32::INFINITY));
                ui.add_space(6.0);
                ui.colored_label(TEXT_SECONDARY, "SSH 连接");
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
                    egui::CollapsingHeader::new(egui::RichText::new(group).color(TEXT_SECONDARY))
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
            .frame(egui::Frame::default().fill(SURFACE).inner_margin(12.0))
            .show(ctx, |ui| {
                ui.colored_label(ACCENT, egui::RichText::new("✦ AI 助手").strong());
                ui.add_space(10.0);
                // 第一轮对话（展示连续性 + AI 结合真实环境）
                ui.colored_label(TEXT_SECONDARY, egui::RichText::new("你").size(10.0).strong());
                egui::Frame::default().fill(egui::Color32::from_rgb(0x3B, 0x82, 0xF6)).rounding(10.0).inner_margin(10.0)
                    .show(ui, |ui| { ui.colored_label(TEXT_PRIMARY, "这台机器装了什么服务？"); });
                ui.add_space(6.0);
                ui.horizontal(|ui| {
                    ui.colored_label(ACCENT, egui::RichText::new("✦").size(10.0));
                    ui.colored_label(TEXT_SECONDARY, egui::RichText::new("AI").size(10.0).strong());
                });
                egui::Frame::default().fill(BG).rounding(10.0).inner_margin(10.0)
                    .show(ui, |ui| { ui.colored_label(TEXT_PRIMARY, "检测到 nginx(运行)、docker(运行)、mysql(运行)、redis(未运行)。需要我帮你启动 redis 吗？"); });
                ui.add_space(8.0);
                // 第二轮对话：角色标签 + 气泡（对照 apple/android）
                ui.colored_label(TEXT_SECONDARY, egui::RichText::new("你").size(10.0).strong());
                egui::Frame::default().fill(egui::Color32::from_rgb(0x3B, 0x82, 0xF6)).rounding(10.0).inner_margin(10.0)
                    .show(ui, |ui| { ui.colored_label(TEXT_PRIMARY, "怎么查看 Nginx 错误日志？"); });
                ui.add_space(6.0);
                // AI 消息：角色标签 + 气泡
                ui.horizontal(|ui| {
                    ui.colored_label(ACCENT, egui::RichText::new("✦").size(10.0));
                    ui.colored_label(TEXT_SECONDARY, egui::RichText::new("AI").size(10.0).strong());
                });
                egui::Frame::default().fill(BG).rounding(10.0).inner_margin(10.0).show(ui, |ui| {
                    ui.colored_label(TEXT_PRIMARY, "用下面的命令查看最近的错误日志：");
                    ui.add_space(4.0);
                    egui::Frame::default().fill(egui::Color32::BLACK).rounding(6.0).inner_margin(8.0).show(ui, |ui| {
                        ui.colored_label(SUCCESS, egui::RichText::new("tail -n 50 /var/log/nginx/error.log").monospace());
                    });
                });
                // 用户回车追加的提问气泡 + 占位 AI 回复（对照终端命令回车交互）
                for msg in &self.ai_msgs {
                    ui.add_space(6.0);
                    ui.colored_label(TEXT_SECONDARY, egui::RichText::new("你").size(10.0).strong());
                    egui::Frame::default().fill(egui::Color32::from_rgb(0x3B, 0x82, 0xF6)).rounding(10.0).inner_margin(10.0)
                        .show(ui, |ui| { ui.colored_label(TEXT_PRIMARY, msg); });
                    ui.add_space(4.0);
                    // 占位 AI 回复（后续接真实 AI 流式回复）
                    ui.horizontal(|ui| {
                        ui.colored_label(ACCENT, egui::RichText::new("✦").size(10.0));
                        ui.colored_label(TEXT_SECONDARY, egui::RichText::new("AI").size(10.0).strong());
                    });
                    egui::Frame::default().fill(BG).rounding(10.0).inner_margin(10.0)
                        .show(ui, |ui| { ui.colored_label(TEXT_SECONDARY, "已收到，正在结合服务器环境分析…（接入 API Key 后回复）"); });
                }
                ui.add_space(10.0);
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
                        egui::Button::new(egui::RichText::new("↑").size(15.0).color(TEXT_PRIMARY))
                            .fill(ACCENT).rounding(14.0));
                    let resp = ui.add_sized(
                        [ui.available_width(), 28.0],
                        egui::TextEdit::singleline(&mut self.ai_input).hint_text("输入指令…"));
                    // 发送按钮点击 或 回车 → 追加提问气泡（后续接 AI 回复）
                    let enter = resp.lost_focus() && ui.input(|i| i.key_pressed(egui::Key::Enter));
                    if (send.clicked() || enter) && !self.ai_input.trim().is_empty() {
                        self.ai_msgs.push(self.ai_input.trim().to_string());
                        self.ai_input.clear();
                    }
                });
            });

        // ② 中间：终端区（状态条 + 输出）—— 状态条反映选中的连接
        let (sel_user, sel_host, sel_online) = self.selected.and_then(|i| self.conns.get(i))
            .map(|c| (c.user, c.host, c.online)).unwrap_or(("root", "prod-01", true));
        // 终端提示符联动选中连接（user@host:~$）
        let prompt = format!("{}@{}:~$", sel_user, sel_host);
        egui::CentralPanel::default()
            .frame(egui::Frame::default().fill(BG).inner_margin(12.0))
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.colored_label(if sel_online { SUCCESS } else { TEXT_SECONDARY },
                        if sel_online { "● 已连接" } else { "○ 离线" });
                    ui.colored_label(TEXT_SECONDARY, sel_host);
                    // CPU/内存 mini 进度条（绿<60/橙60-80/红>80 三档，对齐 apple/android）
                    ui.colored_label(TEXT_SECONDARY, "CPU");
                    // 真实逻辑核数（available_parallelism）；CPU% 瞬时占用需 /proc/stat 采样留后续
                    let cores = std::thread::available_parallelism().map(|n| n.get()).unwrap_or(8);
                    ui.add(egui::ProgressBar::new(0.47).desired_width(54.0).text("47%").fill(usage_color(47)))
                        .on_hover_text(format!("{} 核", cores));
                    ui.colored_label(TEXT_SECONDARY, "内存");
                    // 真实本机内存（/proc/meminfo）；非 Linux/读失败回退占位
                    let (mem_used, mem_total, mem_pct) = read_mem().unwrap_or((9.0, 16.0, 56));
                    ui.add(egui::ProgressBar::new(mem_pct as f32 / 100.0).desired_width(54.0)
                        .text(format!("{}%", mem_pct)).fill(usage_color(mem_pct)))
                        .on_hover_text(format!("{:.1} / {:.1} GB", mem_used, mem_total));
                    // 真实本机负载（/proc/loadavg）；非 Linux/读失败回退占位
                    let load = read_loadavg().unwrap_or_else(|| "0.82 0.45 0.30".to_string());
                    ui.colored_label(TEXT_SECONDARY, format!("负载 {}", load));
                    // 真实本机运行时长（/proc/uptime）；真 Linux 显示，非 Linux 跳过
                    if let Some(up) = read_uptime() {
                        ui.colored_label(TEXT_SECONDARY, format!("· 运行 {}", up));
                    }
                    ui.separator();
                    // 关键服务运行状态点（对照 apple/android Z6：nginx/docker/mysql/redis/sshd）
                    for (svc, running) in [("nginx", true), ("docker", true), ("mysql", true), ("redis", false), ("sshd", true)] {
                        ui.colored_label(if running { SUCCESS } else { TEXT_SECONDARY }, "●");
                        ui.colored_label(if running { TEXT_PRIMARY } else { TEXT_SECONDARY }, svc);
                    }
                });
                ui.add_space(8.0);
                egui::Frame::default().fill(egui::Color32::from_rgb(0x0A, 0x0B, 0x14)).rounding(6.0).inner_margin(12.0)
                    .show(ui, |ui| {
                        // 终端输出可滚动（对照 windows，输出多时查看历史）
                        egui::ScrollArea::vertical().auto_shrink([false, false]).max_height(360.0).show(ui, |ui| {
                            ui.colored_label(TEXT_SECONDARY, egui::RichText::new("Last login: Sun Jun 22 19:00 on ttys001").monospace());
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new(format!("{} ls -la", prompt)).monospace());
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new("total 32").monospace());
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new("drwxr-xr-x  6 root root 4096 Jun 22 18:00 .").monospace());
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new("-rw-r--r--  1 root root  220 Jun 10 09:12 .bashrc").monospace());
                            ui.colored_label(SUCCESS, egui::RichText::new("-rwxr-xr-x  1 root root 1024 Jun 22 17:30 deploy.sh").monospace());
                            ui.colored_label(ACCENT, egui::RichText::new("drwxr-xr-x  4 root root 4096 Jun 22 18:00 projects").monospace());
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new(format!("{} systemctl status nginx", prompt)).monospace());
                            ui.colored_label(SUCCESS, egui::RichText::new("● nginx.service - A high performance web server").monospace());
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new("   Active: active (running) since Mon 2026-06-22").monospace());
                            // 用户输入回车后追加的历史命令行
                            for line in &self.term_lines {
                                ui.colored_label(TEXT_PRIMARY, egui::RichText::new(line).monospace());
                            }
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new(format!("{} \u{2588}", prompt)).monospace());
                        });
                    });
                ui.add_space(8.0);
                // 快捷命令栏（对照 windows/apple/android 终端区，点击填入命令输入框）
                ui.horizontal(|ui| {
                    for cmd in ["ls -la", "df -h", "free -h", "top"] {
                        if ui.add(egui::Button::new(
                            egui::RichText::new(cmd).monospace().size(11.0).color(ACCENT))
                            .fill(ACCENT.linear_multiply(0.12)).rounding(14.0)).clicked() {
                            self.cmd_input = cmd.to_string();
                        }
                    }
                    // 高风险命令橙色
                    if ui.add(egui::Button::new(
                        egui::RichText::new("systemctl status nginx").monospace().size(11.0).color(WARNING))
                        .fill(WARNING.linear_multiply(0.12)).rounding(14.0)).clicked() {
                        self.cmd_input = "systemctl status nginx".to_string();
                    }
                });
                ui.add_space(8.0);
                // 命令输入框（提示符 + 输入，快捷命令点击填入；回车追加到终端输出）
                ui.horizontal(|ui| {
                    ui.colored_label(SUCCESS, egui::RichText::new(format!("{} ", prompt)).monospace());
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
                            self.term_lines.push(format!("{} {}", prompt, cmd));
                        }
                        self.cmd_input.clear();
                        resp.request_focus();   // 保持焦点便于连续输入
                    }
                });
            });
    }
}

/// 单个连接卡片
fn server_card(ui: &mut egui::Ui, c: &ServerConn, selected: bool) -> egui::Response {
    let frame = egui::Frame::default()
        .fill(if selected { ACCENT.linear_multiply(0.2) } else { SURFACE })
        .rounding(10.0)
        .inner_margin(12.0);
    frame
        .show(ui, |ui| {
            ui.horizontal(|ui| {
                let dot = if c.online { SUCCESS } else { TEXT_SECONDARY };
                ui.colored_label(dot, "●");
                ui.vertical(|ui| {
                    ui.colored_label(TEXT_PRIMARY, egui::RichText::new(c.name).strong());
                    ui.colored_label(TEXT_SECONDARY, format!("{}@{}:{}", c.user, c.host, c.port));
                    if !c.note.is_empty() {
                        ui.colored_label(TEXT_SECONDARY, format!("📝 {}", c.note));
                    }
                    if !c.last_used.is_empty() {
                        ui.colored_label(TEXT_SECONDARY.linear_multiply(0.8), format!("上次使用 · {}", c.last_used));
                    }
                });
                // 右侧可达指示（探测中 ⏳ / 可达 ✓ / 不可达 ✕，真实 TCP 探测）
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if !c.probed {
                        ui.colored_label(TEXT_SECONDARY.linear_multiply(0.7), "⏳");
                    } else if c.online {
                        ui.colored_label(SUCCESS, egui::RichText::new("✓").strong());
                    } else {
                        ui.colored_label(TEXT_SECONDARY, "✕");
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
