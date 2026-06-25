# AI Terminal — Android / iOS（Capacitor）

用 [Capacitor](https://capacitorjs.com/) 把 Web UI 包装成原生 Android / iOS App。

> 现状：本目录是**脚手架 + 移动 Web 壳**。Capacitor 依赖与 Android SDK 未随仓库提供，需在本地安装后再生成原生工程。Apple 平台推荐用 `apple/` 的 **SwiftUI 原生版**（体验最佳）；这里主要面向 **Android**。

## 结构

```
mobile/
├── capacitor.config.json   # appId / appName / webDir=www
├── package.json            # Capacitor 依赖与脚本
├── www/                    # Web 资源（webDir）
│   ├── index.html          # 应用框架 UI（顶栏/连接列表/底栏）
│   ├── styles.css          # 5 套配色主题（与原生/Electron 一致）
│   ├── app.js              # 主题切换 + 示例数据 + 跳转 SSH 终端页
│   ├── terminal.html       # SSH 终端页（xterm.js，经中继连 SSH）
│   ├── terminal.js         # WebSocket→relay 桥接 + 终端输入/输出/resize
│   └── vendor/             # xterm.js / xterm-addon-fit / xterm.css（本地内置）
└── README.md
```

## 本地生成与运行（需联网 + 工具链）

```bash
cd mobile
npm install                 # 安装 @capacitor/core /cli /android /ios

# Android（需 Android Studio + Android SDK，设置 ANDROID_HOME）
npx cap add android
npx cap sync
npx cap open android        # 在 Android Studio 里运行/打包

# iOS（需 Xcode）
npx cap add ios
npx cap sync
npx cap open ios
```

## 重要限制（移动端 SSH）

桌面/Electron 版的 SSH 走 Node 的 `ssh2` + `node-pty`，**在移动 WebView 中不可用**。移动端 SSH 计划（路线图 R17）：

1. **WebSocket 中继**：自建/复用一个轻量中继服务，App 经 WSS 连到中继，中继再 SSH 到目标主机（类似 Termius/Web SSH 方案）。
2. **Capacitor 原生插件**：用 Android（JSch / sshj）与 iOS（NMSSH / Citadel）原生 SSH 库写插件，JS 侧通过插件桥调用。

当前 Web 壳已统一全端配色，并已落地**方案 1**：`www/terminal.html`（xterm.js）经 WebSocket 连到 [`relay/`](../relay/README.md) 中继实现 SSH 终端（自托管/可信网络）。方案 2（原生插件）仍在路线图。

## 与其它版本的关系

- `apple/` — SwiftUI 原生 macOS / iOS（推荐 Apple 平台）
- `src/` — Electron 桌面版（Windows / Linux / macOS）
- `mobile/` — Capacitor Android（+ iOS 兜底）
