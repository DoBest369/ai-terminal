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
}

fn demo_conns() -> Vec<ServerConn> {
    vec![
        ServerConn { name: "生产 Web 01", host: "web01.example.com", user: "deploy", port: 22, group: "生产环境", online: true, note: "官网 + API" },
        ServerConn { name: "数据库主机", host: "db.internal.net", user: "admin", port: 22, group: "生产环境", online: true, note: "MySQL 主库" },
        ServerConn { name: "开发机", host: "dev.example.com", user: "deploy", port: 2222, group: "开发环境", online: false, note: "" },
    ]
}

struct TermindApp {
    conns: Vec<ServerConn>,
    selected: Option<usize>,
}

impl Default for TermindApp {
    fn default() -> Self {
        Self { conns: demo_conns(), selected: None }
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
            });
            ui.add_space(4.0);
        });

        // ① 左侧栏：连接列表（按分组）—— 三栏工作台对齐 apple/windows
        egui::SidePanel::left("connections")
            .resizable(false)
            .exact_width(280.0)
            .frame(egui::Frame::default().fill(SURFACE).inner_margin(10.0))
            .show(ctx, |ui| {
                ui.colored_label(TEXT_SECONDARY, "SSH 连接");
                ui.add_space(6.0);
                let mut last_group = "";
                for (i, c) in self.conns.iter().enumerate() {
                    if c.group != last_group {
                        ui.add_space(8.0);
                        ui.colored_label(TEXT_SECONDARY, c.group);
                        last_group = c.group;
                    }
                    let resp = server_card(ui, c, self.selected == Some(i));
                    if resp.clicked() {
                        self.selected = Some(i);
                    }
                }
            });

        // ③ 右侧栏：AI 助手面板
        egui::SidePanel::right("ai")
            .resizable(false)
            .exact_width(320.0)
            .frame(egui::Frame::default().fill(SURFACE).inner_margin(12.0))
            .show(ctx, |ui| {
                ui.colored_label(ACCENT, egui::RichText::new("✦ AI 助手").strong());
                ui.add_space(10.0);
                egui::Frame::default().fill(egui::Color32::from_rgb(0x3B, 0x82, 0xF6)).rounding(10.0).inner_margin(10.0)
                    .show(ui, |ui| { ui.colored_label(TEXT_PRIMARY, "怎么查看 Nginx 错误日志？"); });
                ui.add_space(6.0);
                egui::Frame::default().fill(BG).rounding(10.0).inner_margin(10.0).show(ui, |ui| {
                    ui.colored_label(TEXT_PRIMARY, "用下面的命令查看最近的错误日志：");
                    ui.add_space(4.0);
                    egui::Frame::default().fill(egui::Color32::BLACK).rounding(6.0).inner_margin(8.0).show(ui, |ui| {
                        ui.colored_label(SUCCESS, egui::RichText::new("tail -n 50 /var/log/nginx/error.log").monospace());
                    });
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
                });
                ui.add_space(8.0);
                egui::Frame::default().fill(egui::Color32::from_rgb(0x0A, 0x0B, 0x14)).rounding(6.0).inner_margin(12.0)
                    .show(ui, |ui| {
                        ui.colored_label(TEXT_SECONDARY, egui::RichText::new("Last login: Sun Jun 22 19:00 on ttys001").monospace());
                        ui.colored_label(TEXT_PRIMARY, egui::RichText::new("root@prod-01:~$ ls -la").monospace());
                        ui.colored_label(SUCCESS, egui::RichText::new("-rwxr-xr-x 1 root root 1024 deploy.sh").monospace());
                        ui.colored_label(TEXT_PRIMARY, egui::RichText::new("root@prod-01:~$ \u{2588}").monospace());
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
