# Termind — Linux 原生端

**智能 SSH 服务器运维工作台**的 Linux 原生客户端，用 **Rust + egui/eframe** 构建。与 `apple/`（Swift）、`android/`（Kotlin）端共享统一定位、配色（午夜深蓝 + 珊瑚红）与产品愿景。

## 现状

🟡 **骨架阶段** —— 连接列表占位 UI 已搭，真实 SSH/SFTP/AI 待接。

> ⚠️ 该端**尚未在开发机（macOS，无 Rust toolchain）上编译验证**。需在装有 Rust 的环境构建。源码按 eframe 0.27 API 编写。

## 构建

需 [Rust toolchain](https://rustup.rs/)（`rustc` + `cargo`）。Linux 下还需 SSH 库的系统依赖：

```bash
# Debian/Ubuntu 系统依赖（ssh2 crate 需要）
sudo apt install -y build-essential pkg-config libssl-dev

cd linux
cargo run            # 开发运行
cargo build --release  # 发布构建 → target/release/termind
```

> egui/eframe 跨平台，理论上 macOS/Windows 亦可 `cargo run`，但本端定位 Linux。

## 路线（对齐双端能力）

- [x] 骨架：窗口 + 连接列表占位 UI（Termind 顶栏 + 分组 ServerCard）
- [ ] 真实 SSH：`ssh2` crate 连接 + exec + 交互式 PTY 终端
- [ ] 连接管理：本地持久化（serde_json）+ 增删改
- [ ] AI 助手：`ureq` 调 Anthropic / OpenAI（流式）
- [ ] 智能运维：命令风险分级 / 脱敏 / 排障工作流 / 初始化模板 / 操作回滚 / 环境感知（移植 apple Core 逻辑）
- [ ] SFTP 文件浏览 / 服务器状态面板 + AI 联动

## 依赖（Cargo.toml）

- `eframe` / `egui` — 原生 GUI
- `ssh2` — SSH / SFTP（需系统 libssh2 + openssl）
- `ureq` + `serde` / `serde_json` — AI HTTP + JSON
