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

## 阶段 7 — 双端对齐达成 + 差异化深化

- **🎯 双端配对能力 100% 对齐**：连续数十轮 apple↔android 互补打磨，所有共有能力均 ✅✅——SSH/终端（控制键栏/搜索/字号/复制清屏/连接时长/自动滚动/命令补全/keepalive）· SFTP（浏览/查看/下载/上传/新建/删除/重命名/路径跳转/时间/排序/过滤，完全对齐）· AI（流式/停止/重生成/模型选择/代码块/消息复制/提示词库/角色头像/多对话）· 智能运维 Z1–Z8 · 阶段 N 批量运维（群发+巡检双端 UI）· 连接管理（颜色标签/搜索/排序/分组折叠/复制/启动命令/测试/校验）· 安全/跳板机。仅余各自独有特性（android 定时后台巡检 / apple 分屏录制）。
- **多轮源码核查纠正文档滞后**：发现 apple 实为 ✅ 的能力（终端控制键栏 18 键/终端搜索/连接测试/批量群发/连接复制等），PARITY 文档随之校正。
- **差异化深化 · 服务器知识卡片**：双端 Core（`ServerNotebook`：问题/方案/笔记按连接持久化）+ UI（apple NotebookView / android NotebookSheet）。每台机沉淀历史问题、解决方案、运维笔记。
- **🎯 知识沉淀闭环**：AI 排障时注入这台机的知识卡片历史（`composeForAI` → systemPrompt），让 AI 结合「这台机出过什么、怎么解决的」给针对性结论——AI 不再只给通用教程，而是「记得」每台服务器。这是护城河「AI + 真实环境 + 知识沉淀」的核心价值落地。
- 质量：apple 7 项自测（含 inspect/notebook）全过；android clean 零 deprecated warning。

## 阶段 8 — 差异化深化（知识沉淀闭环 + 护城河场景库）

从「双端对齐」转向深化护城河价值：

- **🎯 服务器知识卡片闭环（护城河核心，双端全链路）**：
  - **随手记**：命令历史一键存为知识卡片（apple 右键 / android 书签图标）
  - **记录**：每台机沉淀 历史问题 / 解决方案 / 运维笔记（按连接持久化）
  - **喂 AI**：排障与健康分析时自动注入这台机的历史记录 → AI 结合「这台机出过什么、怎么解决的」给针对性结论
  - **共享**：导出 Markdown（apple 复制 / android 分享），团队共享运维经验
  - 价值：AI 不再只给通用教程，而是「记得」每台服务器——「AI + 真实环境 + 知识沉淀」核心差异化落地
- **护城河场景库扩充**：Z4 排障 5→8（加 内存占用 / 端口占用 / 服务启动失败）；Z8 部署 5→8（加 Redis / PostgreSQL / Python 应用环境）。
- **批量运维高效**：双端批量群发 / 巡检 完整 UI + 全选 / 清空 / 按分组快速选目标。
- **实用能力**：SSH config 导入（apple 读 ~/.ssh/config 文件 / android 粘贴 config 文本）批量建连接。
- **质量稳健**：apple 7 项自测（含 inspect / notebook）全过；android clean 零 deprecated warning。

## 当前状态

- **双端原生可构建**：apple（Swift，swift build + 自测齐全 + 截图渲染验证）+ android（Kotlin，gradle 出 APK，零 deprecated warning）。
- **双端配对能力 100% 对齐**（PARITY 配对能力 🟡=0）：核心智能运维护城河 Z1–Z8 + SSH/终端/SFTP（完整）/AI（完整）/安全/跳板机/批量运维/连接管理 全 ✅✅。
- **差异化深化**：服务器知识卡片闭环全链路（随手记→记录→喂 AI[排障+健康]→导出共享）+ 护城河场景库扩充（Z4 8 场景 / Z8 8 模板）+ 批量运维分组全选 + SSH config 导入，双端落地。
- 仅余各自独有特性（非缺陷）：android 定时后台巡检（WorkManager）、apple 分屏/会话录制（移动端意义有限）。
- linux（Rust+egui）🟡 骨架（未本机编译验证）；windows（C#/.NET）⬜ 待建。
- 边界：本机无完整 Xcode → apple 未出 iOS/macOS 包、未真机实测；android 真实连接/AI 需真机 + 服务器 + API Key。
