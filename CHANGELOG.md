# Termind 演进历程

> Termind — 智能 SSH 服务器运维工作台。本文档梳理项目从早期工具到双端原生智能运维工作台的演进里程碑。
> 详细每轮记录见 [`ITERATION_LOG.md`](ITERATION_LOG.md)，能力对照见 [`docs/PARITY.md`](docs/PARITY.md)。
>
> 边界声明（真实）：开发机为 macOS + Command Line Tools（无完整 Xcode），故 apple 端可 `swift build` 编译校验 + Showcase 渲染 + Shots 自测，但**未出 iOS/macOS 安装包、未真机实测**；android 端可 `gradle assembleDebug` 出 APK，但**真实连接/AI 对话需真机或模拟器 + 目标服务器 + API Key**。Linux/Windows 端为骨架/待建。

## 阶段 0 — 起点（Electron + 原生雏形）

- 最初为 Electron + React 的 AI 终端（本地终端 + SSH + AI 执行命令），并有 apple/ SwiftUI 原生雏形。

## 阶段 1 — 重大重定位（2026-06-25）

- **产品重定位**：从「又一个本地终端」改为 **智能 SSH 服务器运维工作台**——以 SSH 为入口、AI 为助手、服务器管理为核心，对标 Xshell/Termius/FinalShell，而非 iTerm/Warp。
- **护城河确立**：AI + 真实服务器状态 + 安全执行 + 可回滚。
- **全平台原生决策**：用户要求全部用原生语言。删除 Electron(`src/`) + Capacitor(`mobile/`) 等 Web 方案。架构定为 apple=Swift/SwiftUI、android=Kotlin/Compose、windows=C#/.NET、linux=Rust。
- 品牌：定名 **Termind**，重设计图标，iOS 26 液态玻璃 UI 方向。

## 阶段 2 — apple 智能运维护城河（Z1–Z8）

围绕「理解环境→规划→评估风险→确认→执行→验证→回滚」闭环，在 apple/AITerminalCore 落地 8 大差异化能力（每项含 `swift run Shots --xxx-test` 自测）：

- **Z1** AI 命令解释 · **Z2** AI 报错分析 · **Z3** 环境感知（ServerProfile/EnvDetector，喂 AI）
- **Z4** 场景化排障工作流（网站打不开/磁盘/SSL/Nginx/Docker，真跑+AI 总结）
- **Z5** 操作回滚（改关键配置前自动备份 + 时间线 + 一键还原 + sshd 自动回滚防锁门外）
- **Z6** 服务器状态面板（CPU/内存/磁盘/服务/健康摘要/告警）+ Z6b 面板↔AI 联动
- **Z7** 命令风险四级分级 + 敏感输出脱敏 · **Z8** 一键初始化/部署模板（Ubuntu/Docker/Node/LNMP）
- UI 接入：风险颜色、模板预览、排障预览确认（渲染验证）。

## 阶段 3 — android 从零到双端对齐

- **A0** Kotlin + Jetpack Compose 工程骨架 → 出 APK（gradle 8.13 + AGP 8.7.2）。
- 逐步建成：真实 SSH（sshj，密码+私钥）· 交互式 PTY 终端（ANSI 彩色）· 连接管理（持久化/增删改）· SFTP（浏览/查看/下载/上传）· 状态采集 · AI 助手（OkHttp 调 Anthropic，流式/多对话/持久化/搜索/导出）· 环境感知 · 排障工作流真执行 · 初始化模板真执行 · 风险分级/脱敏 · 操作回滚 · API Key 加密（EncryptedSharedPreferences）· TOFU 主机密钥校验 · 本地端口转发 · 可达性探测 · 多主题。
- **智能运维护城河 Z1–Z8 双端完全对齐**（见 PARITY.md）。

## 阶段 4 — 阶段 N 批量运维创新（运维工作台杀手级）

从「逐台 SSH」升级为「一批机器的批量操作 + AI 智能洞察」——单连接 SSH 工具做不到：

- **命令历史**（双端，去重/置顶/限长/调出）
- **批量群发命令**（选多服务器并发执行同一命令 + 高危二次确认）+ **群发结果 AI 汇总**
- **批量健康巡检**（并发查全部服务器 CPU/内存/磁盘，异常置顶）+ **巡检结果 AI 总结**
- **定时后台巡检 + 离线通知**（WorkManager，主动运维）

## 阶段 5 — 持续体验打磨

- 终端：控制键栏（Tab/Ctrl/方向键）· 字号调节 · 复制全部/清屏 · AI 代码块渲染+复制。
- 连接：颜色标签 · 搜索 · 排序（名称/最近/在线）· 启动命令 · 导出导入 · 私钥文件导入。
- AI：停止生成 · 命令解释/报错分析/健康分析快捷入口。
- 快捷命令自定义增删。质量：android 零 deprecated warning，apple 多项自测回归确认。

## 阶段 6 — 双端深度对齐 + 文档准确性

连续多轮 apple↔android 互补，把两端能力拉到实质完全对齐：

- **android 补强**：完整 SFTP 文件管理（新建/删除/重命名/路径跳转）· 跳板机 ProxyJump（sshj connectVia，覆盖全 SSH 操作）· 终端会话 keepalive · 终端输出搜索高亮 · AI（停止/重新生成/模型选择/代码块渲染/消息复制/运维提示词库）· 连接管理（颜色标签/搜索/排序/启动命令/测试连接/表单校验）· 设置（模型选择/开源仓库链接）· 全量零 deprecated warning。
- **apple 补齐 android 独有项**：AI 代码块渲染（``` 等宽深色框）· AI 运维提示词库（5 类分类）· SFTP 增删改 + 路径跳转（Citadel createDirectory/rmdir/remove/rename）· 批量健康巡检逻辑（runHealthInspection/summarizeInspection，UI 待接）。
- **文档准确性维护**：多轮源码核查纠正 PARITY 文档滞后——apple 实为 ✅ 的：终端控制键栏（18 键）· 终端搜索（SwiftTerm 内置）· 连接测试 · 批量群发（runBatch 真接 SSHTerminalSession）。
- **结果**：PARITY 配对能力 🟡 清零，双端 SSH/终端/SFTP/AI/智能运维 Z1–Z8/批量群发/安全全 ✅✅。

## 当前状态

- **双端原生可构建**：apple（Swift，swift build + 自测齐全 + 截图渲染验证）+ android（Kotlin，gradle 出 APK，零 deprecated warning）。
- **双端实质完全对齐**：核心智能运维护城河 Z1–Z8 + SSH/终端（含控制键栏/搜索）/SFTP（完整文件管理）/AI（含代码块/提示词库）/安全/跳板机/批量群发 全 ✅✅。
- 仅余单端独有：android 巡检 UI/定时后台巡检（apple 巡检逻辑已接、UI 待接）、apple 分屏/会话录制（移动端意义有限）。
- linux（Rust+egui）🟡 骨架（未本机编译验证）；windows（C#/.NET）⬜ 待建。
- 边界：本机无完整 Xcode → apple 未出 iOS/macOS 包、未真机实测；android 真实连接/AI 需真机 + 服务器 + API Key。
