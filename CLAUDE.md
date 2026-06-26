# CLAUDE.md

本文件为 Claude Code 提供项目上下文与工作规范。每次自动迭代唤醒后先读它。

## 项目目标

做一个**全平台覆盖、好用的终端 + SSH + AI 工具**，覆盖 **macOS / iOS / Linux / Windows / Android**。
用户要求 **24 小时不间断自动迭代，每 10 分钟一轮**，自行创新/优化/打磨细节。

## 平台与代码分布

| 平台 | 技术栈 | 目录 | 状态 |
|------|--------|------|------|
| macOS | SwiftUI 原生 | `apple/` | ✅ 可编译，持续打磨 |
| iOS / iPadOS | SwiftUI 原生 | `apple/` | ✅ 可编译，持续打磨 |
| Windows / Linux / macOS | Electron + React | `src/` | ✅ 旧版，保留 |
| Android | Capacitor 包 Web UI | `mobile/` | 🟡 脚手架+Web壳+SSH终端页已建；需本地 npm install + cap add android（Android SDK） |
| 移动/网页 SSH 中继 | Node ws + ssh2 | `relay/` | 🟡 WebSocket→SSH 桥接；需本地 npm install；仅自托管/可信网络 |

## apple/ 目录结构

- `apple/AITerminalCore/` — 平台无关 SPM 包：SSH（Citadel）/ AI（AIService）/ 模型 / 持久化。`swift build` 可独立编译验证。
- `apple/App/` — SwiftUI App（macOS + iOS）。
  - `project.yml` → 用 `xcodegen generate` 生成 `AITerminal.xcodeproj`（两个 scheme：`AITerminal (macOS)` / `AITerminal (iOS)`）。
  - `Sources/` — App 源码（Views / 模型 / 终端桥接）。
  - `Sources/DevTools/` — 截图预览工具（**已排除出发布 App**，仅用于 SPM 编译校验与截图）。
  - `Package.swift` — 临时的 macOS 编译校验包（AppCheck 库 + Shots 可执行），**非打包用**。
- `apple/screenshots/` — 最新界面渲染 PNG。

## 关键依赖

- 终端模拟：[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)（AppKit/UIKit `TerminalView`、macOS 本地 PTY `LocalProcessTerminalView`）
- SSH：[Citadel](https://github.com/orlandos-nl/Citadel)（纯 Swift，基于 swift-nio-ssh；交互式 PTY `withPTY` 需 macOS 15+）
- AI：直接 URLSession 调 Anthropic Messages API（默认 `claude-opus-4-8`）/ OpenAI 兼容接口

## 构建与验证（本机无完整 Xcode，只能 swift build 校验）

```bash
# 核心逻辑
cd apple/AITerminalCore && swift build

# App 的 macOS 源码（AppCheck 包）
cd apple/App && swift build

# 界面截图（ImageRenderer 离屏渲染 PNG，再用 Read 看图）
cd apple/App && swift run Shots /tmp/aiterminal-shots

# 运行时自测（Shots 可执行的子命令；改了对应逻辑后跑相应自测核对输出）
cd apple/App && swift run Shots --ssh-config-test    # ~/.ssh/config 解析
swift run Shots --portability-test                   # 连接 JSON 导入导出往返（group/启动命令/字号/备注）
swift run Shots --ai-md-test                         # 当前对话导出 Markdown
swift run Shots --ai-md-all-test                     # 全部对话导出 Markdown
swift run Shots --ai-persist-test                    # AI 对话持久化往返
swift run Shots --ai-conv-test                       # AI 多对话 保存/加载/删除/迁移
swift run Shots --reach-test                         # 连接可达性探测（TCP）
swift run Shots --inspect-test                        # N-Cron 批量巡检（告警置顶排序 + AI 素材拼接）
swift run Shots --notebook-test                       # 服务器知识卡片（新增置顶/删除/AI 素材）

# Electron 版（src/，Windows/Linux/macOS）：webpack 打包 + 主进程语法
npm run build
node --check src/main/main.js

# 移动 Web 壳（mobile/www）截图验证（本机有 Chrome.app，可 headless 渲染网页为 PNG）
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu \
  --force-device-scale-factor=2 --window-size=420,860 --screenshot=/tmp/mobile.png \
  "file://$(pwd)/mobile/www/index.html"
```

> ⚠️ 本机仅 Command Line Tools（Swift 6.x），**没有完整 Xcode** → iOS 出包/模拟器需用户自行装完整 Xcode。
> ⚠️ `ImageRenderer` 渲染不了 `List`/`Form`/`ScrollView`/`TextField`（需 AppKit 宿主），故截图用 `Sources/DevTools/Showcase.swift` 的纯布局高保真预览（与真实视图共用 `Theme`）。改了 UI 要同步更新 Showcase 再渲染。

## 每轮迭代流程（务必全部执行）

1. 读 `ROADMAP.md`，取 Backlog 里下一个未完成项。
2. 实现该项。
3. 编译验证：`cd apple/AITerminalCore && swift build` 和 `cd apple/App && swift build`，必须 Build complete。
4. 若改了界面：更新 `apple/App/Sources/DevTools/Showcase.swift`，`swift run Shots` 渲染，用 Read 看图核对，必要时拷到 `apple/screenshots/`。
5. **更新 `ROADMAP.md`**（标记完成 + 迭代日志一行）。
6. **追加 `ITERATION_LOG.md` 详细条目**（轮次、做了什么、改了哪些文件、验证结果）。
7. 必要时更新本 `CLAUDE.md`。
8. 简短汇报，再用 `ScheduleWakeup` 排 600 秒后的下一轮，保持循环。

## 约定

- 代码注释、UI 文案用中文，与现有风格一致。
- 配色统一用 `Theme`（`Support/Platform.swift`，计算属性）+ 终端 `Support/TerminalTheme.swift`，二者都读全局 `activeColorScheme`（`Support/AppColorScheme.swift`，5 套主题，AppModel.themeID 持久化切换）。新增 UI 不要写死颜色，用 `Theme.*`。
- 旧 Electron 版（`src/`）保留作参考，不破坏。
- 提交需用户明确要求；当前在 `main` 分支，提交前先开分支。

## 文档索引

- `ROADMAP.md` — 平台策略 + 优先级 backlog + 迭代日志摘要
- `ITERATION_LOG.md` — 每轮详细日志
- `apple/README.md` — 原生版构建运行说明
- `README.md` — 仓库总览（顶部指向原生版）
