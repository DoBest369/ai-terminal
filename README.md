<div align="center">

<img src="apple/App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png" width="120" alt="Termind" />

# Termind

**智能 SSH 服务器运维工作台** —— 不是又一个本地终端，而是以 SSH 为入口、AI 为助手、服务器管理为核心的运维工作台。对标 Xshell / Termius / FinalShell，护城河是 **AI + 真实服务器状态 + 安全执行 + 可回滚**。

[![Platform](https://img.shields.io/badge/原生-macOS%20·%20iOS%20·%20Android-blue)](#平台矩阵)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

## 定位

传统 SSH 工具只是「连上去敲命令」。Termind 让 AI 真正理解你这台服务器——装了什么、什么系统、当前状态——再给出**针对性、可直接执行、出问题能回滚**的运维建议。围绕一条闭环：

> 理解环境 → 规划 → 评估风险 → 确认 → 执行 → 验证 → 回滚

详见产品构想 [`docs/PRODUCT.md`](docs/PRODUCT.md)。

## 平台矩阵（全平台原生）

按平台用各自最佳原生技术，无 Electron / WebView 中间层。

| 平台 | 原生技术 | 目录 | 状态 |
|------|---------|------|------|
| **macOS / iOS / iPadOS** | Swift + SwiftUI（Citadel SSH + SwiftTerm） | [`apple/`](apple/README.md) | ✅ 旗舰，智能运维 Z1–Z8 大部完成 |
| **Android** | Kotlin + Jetpack Compose（sshj + OkHttp） | [`android/`](android/) | ✅ 能力全齐，可构建 APK（~30 MB） |
| **Windows** | C# + WinUI 3 / .NET | `windows/` | ⬜ 待起（需 Windows 环境） |
| **Linux** | Rust + GTK4 / C++ Qt | `linux/` | ⬜ 待起（需 Linux 环境） |

> 早期 Electron / Capacitor Web 方案已按「全平台原生」决策删除，git 历史保留。

## 智能运维能力（双端已落地）

围绕护城河闭环的差异化能力，**apple 与 android 双端均已实现**：

| 能力 | 说明 | apple | android |
|------|------|:---:|:---:|
| 连接管理 | 分组 / 备注 / 持久化 / 增删改 | ✅ | ✅ |
| 真实 SSH | 密码 / 密钥认证，交互式 PTY 终端 | ✅ | ✅ |
| SFTP 文件 | 远程目录浏览 + 查看文件内容 | ✅ | ✅ |
| 服务器状态 | CPU / 内存 / 磁盘实时采集 | ✅ | ✅ |
| **环境感知** | 探测系统/发行版/已装服务 → 喂给 AI | ✅ | ✅ |
| **AI 助手** | 对话 / 命令解释 / 报错分析，流式输出 | ✅ | ✅ |
| **排障工作流** | 网站打不开/磁盘/SSL/Nginx/Docker 一键诊断 + AI 总结 | ✅ | ✅ |
| **初始化模板** | Ubuntu Web / Docker / Node / LNMP 一键部署 | ✅ | ✅ |
| **风险分级** | 命令四级风险（安全/注意/高/极高）+ 高危二次确认 | ✅ | ✅ |
| **敏感脱敏** | 终端输出里的密码/密钥/Token 自动打码 | ✅ | ✅ |
| **操作回滚** | 改关键配置前自动备份 + 时间线 + 一键还原 | ✅ | ✅ |
| SFTP 下载 / 上传 | 文件下载到本地 / 选本地文件上传 | ✅ | ✅ |
| 终端 ANSI 彩色 | 保留颜色高亮渲染 | ✅ | ✅ |
| 连接可达性探测 | TCP 探测真实在线状态 | ✅ | ✅ |
| 本地端口转发 | 本机端口经 SSH 转发到远端 | ✅ | ✅ |
| 凭据安全存储 | Keychain（apple）/ EncryptedSharedPreferences（android） | ✅ | ✅ |
| TOFU 主机密钥校验 | 首次信任 + 指纹比对防 MITM | ✅ | ✅ |
| 多主题配色 | 午夜 / One Dark / Dracula / Solarized / Nord | ✅ | ✅ |
| AI 多对话 | 新建 / 切换 / 删除 | ✅ | ✅ |

> 这套能力让 AI 不再只会给通用教程，而是结合**这台机器的真实环境与状态**给出可执行、可回滚的运维方案。
> 完整双端能力对照见 [`docs/PARITY.md`](docs/PARITY.md)——**核心智能运维护城河（Z1–Z8）与 SSH/SFTP/AI/安全主线双端完全对齐**。

### 🚀 批量运维（单连接 SSH 工具做不到）

- **批量群发命令**：选多台服务器，并发执行同一命令、汇总各自输出，高危命令二次确认
- **群发结果 AI 汇总**：一键让 AI 分析这批结果——哪些成功/失败、共性问题、处理建议
- **批量健康巡检**：并发查全部服务器 CPU/内存/磁盘，异常红色置顶 + AI 总结处理优先级
- **命令历史**：执行过的命令去重记录、一键调出重用

> 这是从「逐台 SSH」到「**一批机器的批量操作 + AI 智能洞察**」的运维工作台升级（android 完整落地，apple 框架就绪）。

## 快速开始

### 🍎 Apple 原生（macOS / iOS）

```bash
brew install xcodegen
cd apple/App && xcodegen generate && open AITerminal.xcodeproj
```
选 `AITerminal (macOS)` 或 `AITerminal (iOS)` scheme 运行（需完整 Xcode 16+）。
无 Xcode 时可只校验核心逻辑与自测：

```bash
cd apple/AITerminalCore && swift build       # 平台无关核心
cd apple/App && swift build                  # App 源码（AppCheck 包）
swift run Shots --risk-test                  # 风险分级/脱敏自测（另有 env-detect/diag/rollback/template 等）
```

### 🤖 Android 原生

```bash
cd android
ANDROID_HOME=~/Library/Android/sdk ./gradlew assembleDebug
# 产物：android/app/build/outputs/apk/debug/app-debug.apk
```
需 Android SDK（android-34）+ JDK 17。安装到设备/模拟器后，新建连接（密码或私钥）即可连真实服务器，支持交互式彩色终端、SFTP 文件管理、端口转发、5 套主题；AI 功能需在「设置」配置 Anthropic API Key（加密存储）。

## 项目结构

```
ai-terminal/
├── apple/            # Swift + SwiftUI（macOS + iOS）—— 旗舰
│   ├── AITerminalCore/   # 平台无关核心（SSH/AI/环境感知/风险/回滚/模板）
│   └── App/              # SwiftUI App + xcodegen 工程 + Shots 自测
├── android/          # Kotlin + Jetpack Compose（sshj + OkHttp）
├── relay/            # 可选 WebSocket → SSH 中继（自托管/可信网络）
├── docs/PRODUCT.md   # 产品构想（定位/护城河/MVP）
├── ROADMAP.md        # 路线图 + 阶段进度
└── ITERATION_LOG.md  # 每轮详细迭代日志
```

## 现状与边界（真实说明）

- apple 端：核心逻辑 + UI 均 `swift build` 通过、自测齐全；**出 iOS/macOS 安装包需完整 Xcode**（开发机仅 Command Line Tools，未出包）。
- android 端：`gradle assembleDebug` 通过、产出可安装 APK；**真实连接/AI 对话需真机或模拟器 + 目标服务器 + API Key** 实测。
- Windows / Linux 原生端：架构已定，待在对应平台环境起步。

## 路线图

迭代进展见 [`ROADMAP.md`](ROADMAP.md) 与 [`ITERATION_LOG.md`](ITERATION_LOG.md)。

## 许可证

MIT，详见 [LICENSE](LICENSE)。
