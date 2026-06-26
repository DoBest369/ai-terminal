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
    note: &'static str,
    last_used: &'static str,
}

fn demo_conns() -> Vec<ServerConn> {
    vec![
        ServerConn { name: "生产 Web 01", host: "web01.example.com", user: "deploy", port: 22, group: "生产环境", online: true, note: "官网 + API", last_used: "5 分钟前" },
        ServerConn { name: "数据库主机", host: "db.internal.net", user: "admin", port: 22, group: "生产环境", online: true, note: "MySQL 主库", last_used: "1 小时前" },
        ServerConn { name: "开发机", host: "dev.example.com", user: "deploy", port: 2222, group: "开发环境", online: false, note: "", last_used: "" },
    ]
}

struct TermindApp {
    conns: Vec<ServerConn>,
    selected: Option<usize>,
    search: String,
    ai_input: String,
}

impl Default for TermindApp {
    fn default() -> Self {
        Self { conns: demo_conns(), selected: None, search: String::new(), ai_input: String::new() }
    }
}

impl eframe::App for TermindApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // 顶栏
        egui::TopBottomPanel::top("topbar").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.add_space(6.0);
                ui.colored_label(ACCENT, "⚡");
                ui.heading(egui::RichText::new("Termind").color(TEXT_PRIMARY).strong());
                ui.colored_label(TEXT_SECONDARY, "智能 SSH 运维");
                // 右侧工具栏：新建连接 / 设置（对照 windows 顶部工具栏）
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    let _ = ui.add(egui::Button::new(egui::RichText::new("⚙").size(15.0).color(TEXT_SECONDARY)).frame(false));
                    let _ = ui.add(egui::Button::new(egui::RichText::new("＋").size(16.0).color(ACCENT)).frame(false));
                });
            });
            ui.add_space(4.0);
        });

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
                ui.add_space(10.0);
                // 快捷追问 chips（对照 apple/windows AI 面板）
                ui.horizontal(|ui| {
                    let blue = egui::Color32::from_rgb(0x3B, 0x82, 0xF6);
                    let _ = ui.add(egui::Button::new(egui::RichText::new("重新生成").size(11.0).color(blue))
                        .fill(blue.linear_multiply(0.12)).rounding(14.0));
                    let _ = ui.add(egui::Button::new(egui::RichText::new("存为方案").size(11.0).color(SUCCESS))
                        .fill(SUCCESS.linear_multiply(0.12)).rounding(14.0));
                });
                ui.add_space(8.0);
                // AI 输入框 + 发送按钮（对照 apple/windows）
                ui.horizontal(|ui| {
                    let send = ui.add_sized(
                        [28.0, 28.0],
                        egui::Button::new(egui::RichText::new("↑").size(15.0).color(TEXT_PRIMARY))
                            .fill(ACCENT).rounding(14.0));
                    let _ = ui.add_sized(
                        [ui.available_width(), 28.0],
                        egui::TextEdit::singleline(&mut self.ai_input).hint_text("输入指令…"));
                    if send.clicked() {
                        // 发送逻辑占位（后续接 AI）：清空输入
                        self.ai_input.clear();
                    }
                });
            });

        // ② 中间：终端区（状态条 + 输出）
        egui::CentralPanel::default()
            .frame(egui::Frame::default().fill(BG).inner_margin(12.0))
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    ui.colored_label(SUCCESS, "● 已连接");
                    ui.colored_label(TEXT_SECONDARY, "prod-01");
                    // CPU/内存 mini 进度条（绿<60/橙60-80/红>80 三档，对齐 apple/android）
                    ui.colored_label(TEXT_SECONDARY, "CPU");
                    ui.add(egui::ProgressBar::new(0.47).desired_width(54.0).text("47%").fill(usage_color(47)));
                    ui.colored_label(TEXT_SECONDARY, "内存");
                    ui.add(egui::ProgressBar::new(0.56).desired_width(54.0).text("56%").fill(usage_color(56)));
                    ui.colored_label(TEXT_SECONDARY, "负载 0.82");
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
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new("root@prod-01:~$ ls -la").monospace());
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new("total 32").monospace());
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new("drwxr-xr-x  6 root root 4096 Jun 22 18:00 .").monospace());
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new("-rw-r--r--  1 root root  220 Jun 10 09:12 .bashrc").monospace());
                            ui.colored_label(SUCCESS, egui::RichText::new("-rwxr-xr-x  1 root root 1024 Jun 22 17:30 deploy.sh").monospace());
                            ui.colored_label(ACCENT, egui::RichText::new("drwxr-xr-x  4 root root 4096 Jun 22 18:00 projects").monospace());
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new("root@prod-01:~$ systemctl status nginx").monospace());
                            ui.colored_label(SUCCESS, egui::RichText::new("● nginx.service - A high performance web server").monospace());
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new("   Active: active (running) since Mon 2026-06-22").monospace());
                            ui.colored_label(TEXT_PRIMARY, egui::RichText::new("root@prod-01:~$ \u{2588}").monospace());
                        });
                    });
                ui.add_space(8.0);
                // 快捷命令栏（对照 windows/apple/android 终端区，点击填入命令）
                ui.horizontal(|ui| {
                    for cmd in ["ls -la", "df -h", "free -h", "top"] {
                        let _ = ui.add(egui::Button::new(
                            egui::RichText::new(cmd).monospace().size(11.0).color(ACCENT))
                            .fill(ACCENT.linear_multiply(0.12)).rounding(14.0));
                    }
                    // 高风险命令橙色
                    let _ = ui.add(egui::Button::new(
                        egui::RichText::new("systemctl status nginx").monospace().size(11.0).color(WARNING))
                        .fill(WARNING.linear_multiply(0.12)).rounding(14.0));
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
                // 右侧可达指示（对照 apple/android wifi/wifi.slash）
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if c.online {
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

fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default().with_inner_size([1200.0, 760.0]),
        ..Default::default()
    };
    eframe::run_native(
        "Termind",
        options,
        Box::new(|_cc| Box::<TermindApp>::default()),
    )
}
