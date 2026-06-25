# AI Terminal — 苹果原生版（macOS + iOS）

使用 **SwiftUI** 重写的原生终端工具，同时支持 **macOS** 与 **iOS / iPadOS**。

- **终端模拟**：[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
- **SSH（纯 Swift）**：[Citadel](https://github.com/orlandos-nl/Citadel)（基于 SwiftNIO SSH）
- **AI Agent**：默认 Anthropic Claude（claude-opus-4-8），兼容 OpenAI 接口；自然语言生成并执行命令

## 功能

| 功能 | macOS | iOS |
|------|:----:|:---:|
| 本地终端（zsh/bash） | ✅ | ➖（系统沙盒不允许本地 shell） |
| SSH 连接（密码 / ed25519、RSA 私钥） | ✅ | ✅ |
| 多会话标签 | ✅ | ✅ |
| 保存连接配置 | ✅ | ✅ |
| 实时系统监控（CPU/内存/负载/运行时长） | ✅ | ✅ |
| AI 助手（自然语言执行命令） | ✅ | ✅ |

## 项目结构

```
apple/
├── AITerminalCore/            # 平台无关核心（SPM 包，可独立编译验证）
│   └── Sources/AITerminalCore/
│       ├── Connection.swift       # 连接模型
│       ├── SSHService.swift       # Citadel SSH 会话（PTY）
│       ├── AIService.swift        # Anthropic/OpenAI 调用 + [EXECUTE] 解析
│       ├── SystemMonitor.swift    # 远程系统信息采集
│       └── ConnectionStore.swift  # 本地持久化
└── App/                       # SwiftUI 应用（macOS + iOS）
    ├── project.yml            # XcodeGen 工程定义
    ├── AITerminal.xcodeproj   # 生成的 Xcode 工程
    └── Sources/
        ├── AITerminalApp.swift
        ├── AppModel.swift
        ├── TerminalSessionVM.swift
        ├── Support/           # 跨平台适配 + 本地系统监控
        └── Views/             # 侧边栏 / 终端 / 状态栏 / AI / 设置 / 连接编辑
```

## 构建运行

### 前置要求
- **完整 Xcode 16+**（不是 Command Line Tools）。iOS 出包/模拟器必须用完整 Xcode。
- macOS 部署目标 15.0，iOS 部署目标 17.0（Citadel 的交互式 PTY 需要 macOS 15+）。

### 步骤

```bash
# 1. 安装工程生成器（已生成 .xcodeproj 时可跳过）
brew install xcodegen

# 2. 生成 Xcode 工程（修改 project.yml 后重新生成）
cd apple/App
xcodegen generate

# 3. 打开
open AITerminal.xcodeproj
```

在 Xcode 中：
- 选择 **AITerminal (macOS)** 方案运行桌面版；
- 选择 **AITerminal (iOS)** 方案 + 模拟器/真机运行移动版；
- 真机需在 *Signing & Capabilities* 选择你的开发者团队。

### 仅验证核心逻辑（无需 Xcode）

```bash
cd apple/AITerminalCore
swift build      # 编译 SSH/AI/模型逻辑
```

### 界面截图（无需 Xcode / 模拟器）

用 SwiftUI `ImageRenderer` 把界面离屏渲染为 PNG，便于在无 Xcode 环境做视觉检视：

```bash
cd apple/App
swift run Shots /tmp/aiterminal-shots   # 生成 PNG 到指定目录
```

最新预览见 [`apple/screenshots/`](screenshots/)。
> 说明：`ImageRenderer` 无法离屏渲染 `List`/`Form`/`ScrollView`/`TextField`（需 AppKit 宿主），
> 故截图用 `Sources/DevTools/` 里的高保真预览（同款 Theme/字体/图标）呈现，真机像素级效果请在 Xcode 运行。

## 使用说明

1. **新建 SSH 连接**：侧边栏「SSH 连接」右侧 **+**，填写主机/端口/用户名，选择密码或私钥认证。
2. **连接**：点击连接项即可打开会话标签。
3. **AI 助手**：工具栏 ✨ 打开面板，在设置选择 AI 服务商（默认 Anthropic Claude，也支持 OpenAI）并填入对应 API Key 后，用中文描述需求即可自动在当前终端执行命令；高危命令（如 `rm -rf`）会被拦截。
4. **系统监控**：连接后状态栏实时显示远端/本地 CPU、内存、负载。

## 与旧 Electron 版的关系

仓库根目录的 Electron 版本（`src/`）保留作参考；本目录 `apple/` 为全新的原生实现，是 macOS/iOS 的推荐版本。
