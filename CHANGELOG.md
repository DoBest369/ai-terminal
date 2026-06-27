# Termind 演进历程

> Termind — 智能 SSH 服务器运维工作台。本文档梳理项目从早期工具到**五端原生**智能运维工作台的演进里程碑。
> 详细每轮记录见 [`ITERATION_LOG.md`](ITERATION_LOG.md)，能力对照见 [`docs/PARITY.md`](docs/PARITY.md)。
>
> 边界声明（真实，2026-06-27 更新）：开发机有完整 **Xcode 26.4 + Rust + .NET 9**（靠系统代理 1082 + 国外官方源装齐），**五端本机编译全打通**（macOS/iOS xcodebuild、Linux cargo、Android gradle、Windows Avalonia dotnet）。功能完整度：apple/android 最高（护城河 Z1-Z8 + 批量运维 + 知识沉淀**真实接 SSH/AI**）；windows/linux 为**全功能区 UI + 真实交互（mock 数据）**，真实 SSH/AI 逻辑待接入。iOS 真机/上架需开发者签名；linux 真机运行验证留 CI/真 Linux（mac 上 egui icrate 兼容 bug，仅影响 mac 运行不影响编译）。

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

## 阶段 9 — 细节打磨与双端一致性

差异化护城河成型后，转向把每个高频操作打磨到位、双端交互严格一致：

- **知识沉淀入口全覆盖**：随手记（命令历史一键）· AI 结论存为方案（末条）· 任意 AI 消息存知识卡片（右键/长按选 笔记/方案）· 手动记录。
- **知识卡片检索**：类型筛选（全部/问题/方案/笔记）+ 关键词搜索，组合过滤快速定位。
- **AI 对话体验**：快捷追问（给我命令/换思路/解释/风险）· 单条 user 消息重发 · 单条消息存卡片 · 重新生成 · 停止 · 模型选择。
- **命令体验**：命令收藏夹（星标置顶跨连接）· 快捷命令增删改 + 分组显示 · 命令历史去重/补全/随手记。
- **连接管理**：连接批量编辑（改分组/颜色/删除）· 最近使用快速访问 · 端口范围校验（1–65535）· SSH config 导入。
- **防误操作（双端一致）**：删除连接 / 删除对话 / 清空对话 / SFTP 删除 / 批量删除 均二次确认。
- **方法论**：多项经「系统性审计发现单端落后 → 补齐」（端口校验补 apple、清空/删除确认补 android），保证 PARITY 配对能力持续 🟡=0。
- **linux 端**：Rust+egui 骨架评估——本机无 Rust 工具链，无法编译验证，保留为明确 backlog（需 Linux+Rust 环境推进）。
- **自测**：apple 8 项自测（history/batch/risk/metrics/env-detect/inspect/notebook/favorites）回归保护。

## 阶段 10 — 功能完整化与平台差异处理

细节打磨延续，把各功能区补到完整、把平台差异处理得当：

- **SFTP 批量操作**：批量删除（双端多选 + 二次确认）+ 批量下载（android → app Downloads 目录；apple macOS NSOpenPanel 选目录批量存、iOS 单文件经系统导出器）——桌面/移动各用平台惯例。
- **AI 提示词库扩充**：5 类（排障/部署/安全/性能/日志）每类 3→5 条，共 25 条，覆盖更多常见运维场景。
- **连接编辑完整化**：颜色标签色选器接入（apple 补 6 色圆点）+ 主机/用户名必填标识 + 端口范围校验（1–65535）。
- **危险操作二次确认审计**：删除连接 / 删除对话 / 清空对话 / SFTP 删除 / 批量删除 全双端二次确认。
- **快捷命令完整化**：增删改（编辑名称/命令/分组）+ 分组显示 + 命令收藏夹。
- **完整度评估**：终端区逐项审计（控制键栏/搜索/复制/清屏/字号/自动滚动/ANSI/快捷命令历史）——双端齐平无缺口。
- **文档审查**：README 平台矩阵（Linux 行改为 Rust+egui 骨架🟡）、能力清单、边界全面核对修正。
- **方法论延续**：系统性审计发现单端落后 → 补齐，PARITY 配对能力维持 🟡=0（中途 apple 批量下载短暂 🟡，当轮补齐归零）。
- **linux 端**：如实评估——本机无 Rust 工具链，骨架未编译验证，明确 backlog。

## 阶段 11 — 批量运维统计与数据贯穿

围绕批量运维与运维数据链做完整化打磨：

- **批量群发结果统计**：群发后显示「✅ 成功 N · ❌ 失败 M · 共 K 台」，配合每台 ok/fail+输出 与 AI 汇总。
- **批量巡检结果统计**：巡检后显示「⚠️ 告警 N · ✅ 正常 M · ❌ 失败 K」，配合告警置顶与 AI 总结。
- **运维数据贯穿**：状态面板新增 负载（1/5/15）/ 运行时长 → 同步贯穿到 批量巡检 AI 素材 + 健康分析 AI 素材，AI 分析能看到完整指标。
- **连接导入稳健**：JSON / SSH config 导入按 host+user+port 去重 + 「已导入 N / 跳过 M」数量反馈。
- **审计方法论三类**：① 单端落后→补齐（apple 端口校验/色选器、android 清空确认/删除确认/状态面板字段）② 双端同缺→同步新增（群发结果统计）③ 数据增强→下游同步（负载/运行时长贯穿巡检/健康）。PARITY 配对能力维持 🟡=0。

## 阶段 12 — 批量运维闭环与结果留存

把批量运维补成完整闭环，结果可结构化留存：

- **批量结果导出**：批量群发结果 + 批量巡检报告 都可导出 Markdown（apple 复制 / android 分享 Intent），含命令/统计/各机状态，便于运维记录、汇报、团队共享。
- **服务状态采集补齐**：android 状态采集加 关键服务（nginx/docker/mysql/redis/sshd）`systemctl is-active` → 与 apple 一致，运维数据维度齐全（CPU/内存/磁盘/负载/运行时长/服务 6 维度）→ 全部贯穿到 状态面板/巡检/健康分析 AI 素材。
- **批量运维完整闭环**：选目标（全选/清空/按分组）→ 执行/采集 → 结果统计（群发成功/失败、巡检告警/正常/失败）→ AI 洞察（汇总/总结）→ 导出留存。每环双端齐。
- **审计方法论持续**：单端落后补齐（android 服务采集、apple 巡检统计）· 双端同缺同步新增（群发/巡检统计、结果导出）· 数据增强下游同步（服务状态贯穿 AI 素材）。PARITY 配对能力维持 🟡=0。

> 批量运维是 Termind 区别于单连接 SSH 工具（Xshell/Termius）的运维工作台核心差异化——从「逐台敲命令」升级为「一批机器：选目标 → 批量操作 → 智能洞察 → 结果留存」的完整工作流。

## 阶段 13 — 护城河场景库扩充与 AI 对话完善

把护城河两大场景库扩到 11，AI 对话补齐时间戳：

- **Z4 排障工作流 8→11**：新增 定时任务排查（crontab/timer）· 日志异常扫描（journalctl/dmesg）· 防火墙规则检查（ufw/iptables/firewalld）。命令均只读诊断，真执行 + AI 总结。
- **Z8 初始化模板 8→11**：新增 MongoDB 数据库 · Caddy 反代（自动 HTTPS）· Prometheus + Grafana 监控栈。真执行 + 执行前预览 + 风险标注。
- **AI 消息时间戳**：双端对话消息显发送时间（HH:mm）。apple ChatMessage.createdAt（Codable 向后兼容）/ android 消息类型 Pair→ChatMsg data class 重构（持久化向后兼容）。
- **质量基线**：CLAUDE.md 自测清单补全 10→18 项；以 18 项自测全集做完整回归，核心逻辑（连接/AI/持久化/巡检/排障/模板/回滚/风险/指标/收藏/知识卡片）全无回归。
- PARITY 配对能力维持 🟡=0（android 消息时间戳 🟡 当轮补齐归零）。

## 阶段 14 — 知识卡片增强与导出全覆盖

把知识卡片做到多维归类检索，导出能力补全到各类数据：

- **知识卡片自由标签**：除类型（问题/方案/笔记）外支持自由标签，录入（逗号分隔）+ 卡片显 #标签，持久化向后兼容（旧卡片无标签不崩）。
- **知识卡片三维检索**：类型筛选 + 标签筛选（#标签 Chip）+ 关键词搜索，组合过滤快速定位。
- **排障结论存方案**：android 排障 AI 结论从「只在终端看」到「一键存为方案卡片」，与 apple（AI 对话区入口）对齐——「AI 结论存方案」完整覆盖**所有 AI 路径**（对话/解释/报错/排障/健康）。
- **导出能力全覆盖**：AI 对话 · 批量群发结果 · 批量巡检报告 · 知识卡片 · 快捷命令 · 连接配置，均可导出 Markdown/JSON（apple 复制 / android 分享）。运维资产可留存可共享。
- **双端对齐规模**：PARITY 配对能力达 **95 项双端共有全 ✅✅**，🟡=0（仅余 2 项各自独有特性，平台定位差异）。

## 阶段 15 — 导入导出对称与质量基线

把核心资产的导入导出做成对称，质量以 18 项自测兜底：

- **知识卡片导入**：粘贴导出的 Markdown（`## 类型` + `- 内容`）→ 解析 + 去重导入，与 exportMarkdown 对称。团队可共享运维经验（导出→他人导入）。
- **快捷命令导入**：粘贴导出的 Markdown（`- **标题**：\`命令\``）或宽松 `标题|命令` → 解析 + 去重导入，与导出对称。常用命令集可备份恢复/团队共享。
- **核心资产导入导出全对称**：连接配置（JSON，去重+反馈）· 知识卡片（Markdown）· 快捷命令（Markdown）三类核心资产导入导出都对称完整；AI 对话/批量群发结果/批量巡检报告可导出 Markdown；SSH config 可导入。运维资产可流转。
- **质量基线**：18 项自测全集（连接/AI/持久化/巡检/排障11/模板11/回滚/风险/指标/收藏/知识卡片）逐一回归，知识卡片模型增强（tags+导入）后核心逻辑全无回归。
- **双端对齐规模**：PARITY 配对能力达 **97 项双端共有全 ✅✅**，🟡=0。

## 阶段 16 — 五端全平台本机编译打通 + UI 设计语言统一（2026-06-27）

里程碑级突破：从「双端原生」扩展到**五端全平台本机编译打通**，并统一 UI 设计语言。

- **🔑 工具链钥匙 = 系统代理 + 国外官方源**：本机系统代理端口 1082 走国外，命令行设 `https_proxy/http_proxy/all_proxy=http://127.0.0.1:1082` + 用国外官方源（国内镜像在代理下反而 TLS 失败）。装齐 Xcode 26.4 / Rust 1.96 / .NET 9.0.315。
- **🏆 五端本机编译全打通**：macOS（xcodebuild 出 .app 运行）· iOS（同 xcodeproj scheme）· Linux（cargo build termind 15MB）· Android（gradle APK 零 deprecated）· **Windows（新建 Avalonia C#/.NET9，dotnet build 0 错 + dotnet run mac 上运行真界面）**。
- **五端 UI 设计语言统一**：apple/windows/linux 三栏工作台（连接列表 + 终端区 + AI 面板），android 移动单页；统一深色 + accent 粉红 + 卡片化。
- **UI 现代化 26 项（多数双端/五端对齐）**：状态面板 CPU/内存进度条（五端）· 终端区快捷命令栏（五端）· 连接搜索（五端）· 终端可滚动（五端）· AI 代码块复制+toast（双端）· SFTP 文件类型图标（双端）· 终端键栏功能着色（双端）· 空状态体系（连接/群发/巡检/AI 对话，双端）· 品牌名 Termind · windows/linux 从骨架→可交互工作台。
- **CI**：workflow 覆盖五端真编译，待 workflow scope 授权激活。

## 阶段 17 — 40 项 UI 现代化 · 五端设计语言高度一致（2026-06-27）

阶段 16 打通编译后，持续「一点点对照实现」打磨 UI，达 **40 项 UI 现代化**，五端工作台高度一致。

- **五端对齐能力（设计语言完全一致）**：状态面板 CPU/内存进度条（绿/橙/红三档）· 关键服务运行状态点（Z6）· 终端区快捷命令栏 · 终端可滚动 · 连接搜索 · 连接分组（apple/android/linux 折叠）· 连接卡片可达指示 · AI 对话面板全套（角色标签「你」/「✦ AI」+ 气泡 + 代码块 + 快捷追问 chips + 输入框 + 发送按钮 + 多轮对话）· 三栏工作台布局（apple/windows/linux）。
- **双端对齐 UI 现代化**：AI 代码块一键复制 + toast · SFTP 文件类型语义图标 · 终端键栏功能着色（^C 红/方向键 accent）· 空状态体系（连接列表/批量群发/巡检/AI 对话，图标+标题+引导）· 连接编辑端口实时校验（红框+警告图标）。
- **windows/linux 从骨架→功能完整工作台**：windows（ListBox 可交互连接列表/输入框/侧边栏工具栏/服务状态/可滚动终端/连接分组/可达指示/AI 多轮）· linux（搜索框/AI 输入+发送/服务状态/卡片备注/角色标签/分组折叠/顶栏工具栏/可达指示/AI 多轮）。
- **质量基线**：30+ 轮 UI 迭代后 apple 18 自测全集无回归，PARITY **103 项 ✅✅**；流程修正「build 通过再 push」。
- **工具链**：全程靠系统代理 1082 + 国外官方源支撑五端编译验证（带 proxy env）。

## 阶段 18 — windows/linux 真实交互（mock 数据驱动）（2026-06-27）

UI 对齐后，给 windows/linux 从「静态 mock 展示」打磨到「数据驱动真实交互」，交互体验对齐 apple/android。

- **选连接联动**：点连接列表 → 终端区状态条（host + 在线状态）+ 终端提示符（user@host:~$）反映选中连接（windows SelectionChanged / linux self.selected）。
- **快捷命令/追问填入**：终端快捷命令 chip 点击 → 填入命令输入框；AI 快捷追问 chip 点击 → 填入 AI 输入框（windows Button Click / linux egui clicked）。
- **回车执行/提问**：终端命令输入回车 → 追加到终端输出（带选中连接 host 提示符）；AI 输入回车/发送 → 追加提问气泡（windows code-behind 动态加 TextBlock/Border / linux Vec 状态 + egui 渲染）。
- **windows/linux 双端双区回车交互完整**：终端区（命令执行回显）+ AI 区（提问追加气泡）都支持回车。
- **质量基线**：五端 build 全绿（apple swift build + 8 自测无回归 + linux cargo + windows dotnet 0 错），PARITY 103 项 ✅✅。58 项 UI 现代化。
- **流程修正**：严格「build 通过再 commit+push」（一次 android 漏 import 误推后建立）。

## 阶段 19 — windows/linux 真实逻辑接入 + AI 配置五端对齐（2026-06-27）

UI 与真实交互完成后，进入「真实逻辑接入」阶段：windows/linux 从 mock 数据 → 真实数据，AI 配置能力补齐对齐 apple。

- **真实 TCP 可达性探测（双端）**：windows/linux 连接 online 状态从 mock → 真实 TCP 探测（linux `probe_tcp` std::net 后台线程 + channel；windows `TcpClient.ConnectAsync` + 2s 超时 + Dispatcher.UIThread.Post）。连接卡片探测中 ⏳ / 可达 ✓ / 不可达 ✕ 三态 UX 双端对齐。windows ConnItem record → observable class（INotifyPropertyChanged）。
- **AI 配置能力五端完整对齐**：API Key + 模型 + **Base URL（API 地址）** + **AI 系统提示词** 五端（apple/android/windows/linux）设置都有。android 补齐 Base URL（AiClient baseUrl 参数替代硬编码 + 5 调用点 + SettingsScreen 对话框）+ 系统提示词自定义（loadSystemPrompt + 多行编辑 + 恢复默认）；windows/linux 设置 Flyout/Window 加 API 地址 + 系统提示词输入。AI 支持 OpenAI 兼容/代理/自托管 endpoint。
- **质量基线**：五端 build 全绿（apple swift build + 8 自测无回归 + linux cargo + windows dotnet 0 错），PARITY 103 项 ✅✅，累计 640+ 提交。30+ 轮迭代核心逻辑零回归。

## 阶段 37 — UI 品质 U4 字号可调 + SFTP 上传双端（2026-06-28）

落地用户 UI 品质要求 U4（字号可调），SFTP 上传双端完成。

- **终端字号可调 U4（windows/linux）**：终端状态条 A-/A+ 按钮实时调整字号（clamp 9-22），windows 更新所有现有行 + 新行，linux 渲染用动态字号（ansi_to_job 字号参数化）。响应用户「字号可调」要求。
- **SFTP 文件上传双端（windows/linux）**：windows StorageProvider / linux rfd 原生文件对话框选本地文件 → base64 → SSH 写远程，至此 SFTP 文件操作全覆盖双端。
- **UI 品质专项进展**：U1 图标库化（去 emoji，五端）✅ / U2 配色协调（整窗深色）✅ / U4 字号可调（windows/linux）✅ / U3 主题切换（进行中）。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，855 提交。

## 阶段 36 — 🎯 SFTP 文件操作全覆盖双端（含上传，2026-06-27）

里程碑：windows/linux SFTP 增加上传，文件操作全覆盖，与 apple 真 SFTP 标杆功能对等。

- **SFTP 文件上传（windows/linux）**：windows StorageProvider / linux rfd 原生文件对话框选本地文件 → base64 编码 → SSH `printf | base64 -d > 远程` 写入当前目录 + 刷新；大小守门 5MB（命令行限制）；对照 apple sftpUpload。
- **🎯 windows/linux SFTP 文件操作全覆盖**：浏览 / 目录导航 / 文件预览 / 下载 / 上传 / 删除（确认）/ 新建目录 / 重命名。用 ls + base64 + 命令模拟达到与 apple 真 SFTP（Citadel SFTPClient）功能对等。
- **双端能力总览**：windows/linux 双端全模块真实 + 护城河能力一致（Z1-Z3 + 风险四级 + batch 批量）+ SFTP 全覆盖 + 终端 ANSI 彩色 + 连接 CRUD + 配置持久化，功能完整度达 apple 标杆。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，849 提交。

## 阶段 35 — SFTP 重命名 + 写操作齐全双端（2026-06-27）

windows/linux SFTP 增加文件重命名，文件读写常用操作齐全。

- **SFTP 文件重命名（windows/linux）**：文件右键「重命名」→ 复用新建目录输入框（重命名模式标志，避免新 UI）→ SSH `mv` 原→同目录新名 + 刷新；对照 apple sftpRename，路径单引号防注入。
- **windows/linux SFTP 写操作齐全**：浏览 → 目录导航 → 文件预览 → 下载 → 删除（确认）→ 新建目录 → 重命名，覆盖文件读写常用操作。与 apple 真 SFTP 标杆仅差上传。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，843 提交。

## 阶段 34 — SFTP 新建目录 + 写操作能力齐备双端（2026-06-27）

windows/linux SFTP 增加新建目录，文件读写常用操作齐备。

- **SFTP 新建目录（windows/linux）**：SFTP 面板输入目录名 → SSH `mkdir -p` 当前目录下 → 刷新；对照 apple sftpMakeDirectory，路径单引号防注入。
- **windows/linux SFTP 能力一致**：浏览 → 目录导航 → 文件预览 → 下载 → 删除（确认）→ 新建目录，覆盖文件读写常用操作，向 apple 真 SFTP 标杆靠拢（apple 另有上传/重命名/批量）。
- **截图归档**：`apple/screenshots/windows-smart-ops.png`（windows 三栏 + 终端命令栏批量按钮 + AI 面板）。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，837 提交。

## 阶段 33 — 护城河 batch 批量群发双端对齐（2026-06-27）

windows/linux 移植 apple 的 batch 批量运维能力，护城河能力完全一致。

- **batch 批量群发命令（windows/linux）**：命令输入旁批量按钮 → 对所有连接并发 SSH 执行同一命令（windows Task.WhenAll / linux 多线程 spawn）→ 结果按连接分段聚合显示（连接名/host/✓✕ + 输出），windows 另带成功率统计。各连接独立连接（不复用会话避免并发冲突），超时保护。
- **windows/linux 护城河能力一致**：Z1 命令解释 / Z2 报错分析一键 / Z3 健康巡检一键 + 风险四级分级（Z7）+ batch 批量群发，对照 apple/android。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，831 提交。

## 阶段 32 — SFTP 文件下载/删除双端对齐（写操作，2026-06-27）

windows/linux SFTP 增加文件下载与删除，能力一致覆盖浏览/导航/预览/下载/删除。

- **SFTP 文件下载（windows/linux）**：右键「下载到本地」→ SSH `base64` 取内容 → 解码 → 存本地 Downloads（windows Convert.FromBase64String / linux base64 crate），大小守门 >10MB。
- **SFTP 文件删除（windows/linux）**：右键「删除」→ 嵌套子菜单「⚠确认删除 xxx」（防误删）→ SSH `rm -f` → 刷新当前目录；对照 apple sftpRemove。
- **windows/linux SFTP 能力一致**：浏览 → 目录导航 → 文件预览 → 下载 → 删除，向 apple 真 SFTP 标杆靠拢（apple 另有上传/重命名/mkdir/批量）。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，825 提交。

## 阶段 31 — SFTP 文件下载 + AI 时间戳 + apple SFTP 标杆确认（2026-06-27）

- **windows SFTP 文件下载**：文件右键「下载到本地」→ SSH `base64` 取内容 → 解码 → 存 ~/Downloads，大小守门（>10MB 跳过），终端显进度。SFTP 能力向 apple 标杆靠拢（浏览/导航/预览/下载）。
- **AI 气泡时间戳（windows）**：用户/AI 角色标签带 HH:mm，对话有时间参考。
- **apple SFTP 标杆确认**：apple 用 Citadel SFTPClient 真 SFTP 协议（sftpList/Download/Upload/MakeDirectory/Remove/Rename + 批量下载删除），是最完整实现；windows/linux 用 ls 解析 + base64 模拟（够日常浏览/预览/下载，上传/删除是后续方向）。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，817 提交。

## 阶段 30 — 终端 ANSI 彩色 + 体验细节双端对齐（2026-06-27）

终端体验提升：windows/linux 真实呈现 SSH 彩色输出，接近原生终端。

- **终端 ANSI 颜色解析（windows/linux）**：解析 ANSI SGR 转义（\x1b[..m），SGR 码 30-37 标准前景 / 90-97 亮色映射颜色 + 粗体，分段着色。windows 用 Inlines/Run，linux 用 egui LayoutJob（手动解析，无 regex 依赖）。SSH 彩色输出（ls --color 目录蓝/可执行绿、grep 高亮、systemctl active 绿）真实呈现。
- **终端体验双端对齐总览**：命令真实 SSH 执行 + ANSI 彩色 + 命令耗时显示 + 快捷命令栏 + SSH Session 复用。
- **windows/linux 双端能力完整度**：连接管理 CRUD（windows 含新建/删除/持久化）+ 终端（真实+彩色）+ AI 运维（三模式 Auto 闭环+护城河 Z1-Z3）+ SFTP（浏览/导航/预览），全模块真实。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，807 提交。

## 阶段 29 — SFTP 文件预览 + 连接 CRUD 完整（2026-06-27）

windows/linux SFTP 增加文件预览，windows 连接管理形成完整 CRUD 闭环。

- **SFTP 文件预览（windows/linux）**：点击文件 SSH `stat`/`file` 守门（>1MB 或二进制跳过），文本 `head -n 200` 到终端区显示。SFTP 至此完整：浏览 → 目录导航 → 文件预览。
- **连接管理 CRUD（windows）**：列表（分组+TCP 可达探测）+ 新建（工具栏填表）+ 删除（右键菜单）+ 持久化（用户连接存 AppData 跨重启）+ 选中切换驱动 SSH 目标 + 真实执行命令/巡检/报错。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，801 提交。

## 阶段 28 — SFTP 真实文件浏览 + 目录导航双端对齐（2026-06-27）

windows/linux 双端 SFTP 从 mock 升级为真实 SSH 文件浏览，并支持目录导航。

- **SFTP 真实文件列表（windows/linux）**：SSH `ls -la` 取选中连接目录真实文件，解析权限（d=目录）/大小/时间/名，渲染文件类型图标（目录/脚本/压缩/文本）。
- **SFTP 目录导航（windows/linux）**：点击目录 `cd` 进入并 ls 子目录，`..` 返回上级，显示真实 pwd；路径单引号防注入；linux 后台线程 + channel 异步 ls。
- **真实连接管理（windows）**：列表 + 新建连接（填表）+ 持久化（AppData 跨重启）+ 选中切换驱动 SSH 目标；linux 选中连接驱动 ssh_target。
- **双端全模块真实**：windows/linux 的连接管理、终端、AI 运维（三模式+护城河 Z1-Z3）、SFTP 都接真实 SSH/AI，无 mock。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，793 提交。

## 阶段 27 — windows 全模块真实化：连接管理 + SFTP（2026-06-27）

windows 端从「能编译的 mock UI」打磨到全模块真实（连接、终端、AI 运维、SFTP 都接真实 SSH/AI）。

- **连接管理完整闭环（windows）**：连接列表（分组+TCP 可达探测）→ 新建连接（工具栏填表 name/host/user/port）→ 持久化（用户连接存 AppData 跨重启恢复）→ 选中切换驱动 SSH 目标 → 在选中主机真实执行命令/巡检/报错。
- **SFTP 真实文件浏览（windows）**：SFTP 面板 SSH `ls -la` 取选中连接 home 真实文件，解析权限（d=目录）/大小/日期/名，动态渲染（目录蓝/文件灰图标），SftpPath 显真实 pwd。
- **windows 端真实化总览**：真实 AI（HttpClient 流式 nexcores）+ 真实 SSH（SSH.NET Session 复用）+ 三模式 Auto 闭环 + 护城河 Z1-Z3 一键真闭环 + 风险四级 + 真实连接管理 + 真实 SFTP，全模块不再有 mock。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，785 提交。

## 阶段 26 — 真实连接管理 + 配置/交互细节双端对齐（2026-06-27）

S7 深化打磨继续，把真实连接管理在 windows/linux 落地，AI 配置/交互细节双端对齐。

- **真实连接切换（windows/linux）**：连接列表选中项驱动 SSH 执行目标（host/user，优先级 选中连接 > env > 默认），点不同连接在不同主机执行命令/巡检/报错；windows 切换重置复用会话 + 环境缓存，linux 每帧预取 active target。首项为真实测试机。
- **AI 配置 UI 生效 + 持久化（windows）**：API Key/地址 UI 可填（优先环境变量），存 AppData 跨重启。
- **命令填入终端 + AI 对话导出 Markdown（windows/linux）**：AI 命令一键填入可编辑；对话导出存档/分享。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，775 提交。

## 阶段 25 — 🎯 AI 三模式 + Auto 自主闭环五端全对齐（2026-06-27）

里程碑：用户核心设计的 AI 三模式（Chat / Agent / Auto Agent，安全梯度）+ Auto 自主闭环在**五端全部真正完整落地**。

- **🎯 apple Auto 自主闭环 agent loop**：runParsedCommands Auto 模式注入命令前 startRecording 录制**真实终端输出** → 延迟取 recordedText（去 ANSI）→ 回喂 sendAIMessage 决策下一步（限轮 5）。apple 基础最强——真实终端会话输出录制 + 注入，是真正的 agentic 终端操作。
- **三模式五端对齐总览**：
  - **Chat**：纯聊天，AI 只建议不碰终端（五端）。
  - **Agent**：AI 生成命令，每条人工确认放行才执行（五端）。
  - **Auto Agent**：AI 自主「读输出→决策→执行→回喂」闭环（五端：apple 录制终端输出 / windows·linux SSH exec 结果回喂）。
- **安全梯度一致**：危险命令（风险四级 high/critical）即使 Auto 也强制人工确认，不被自主闭环绕过（五端）。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，769 提交。

## 阶段 24 — 深化打磨：AI 配置 / 交互 / 导出双端补齐（2026-06-27）

S7 深化打磨继续，把 AI 配置、命令交互、对话导出在 windows/linux 补齐对齐。

- **AI 配置 UI 生效 + 持久化（windows）**：设置面板 API Key/API 地址可填（优先于环境变量），存 AppData/Termind/config.json 跨重启持久化（失焦自动保存）。
- **命令卡片「填入终端」（windows/linux）**：AI 生成的命令一键填入终端输入框，可编辑后执行（Chat 模式也能用 AI 建议命令）。
- **AI 对话导出 Markdown（windows/linux，对照 apple ai-md）**：一键把当前对话导出为 Markdown（你/AI 分节），运维对话可存档/分享。
- **命令卡片复制/填入**：踩坑记录——Avalonia 12 clipboard API 大改（DataObject/DataFormats 弃用），改用「填入终端」更实用可靠。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，765 提交。

## 阶段 23 — 护城河 Z2/Z3 一键真闭环 + SSH 复用双端（2026-06-27）

深化打磨继续，把 apple 护城河的「命令解释/报错分析/健康巡检」在 windows/linux 做到一键真闭环 + SSH 性能优化双端对齐。

- **🎯 护城河 Z2 报错分析一键真闭环（windows/linux）**：运维快捷「分析报错」一键 → SSH 取系统错误日志（journalctl -p err，回退 dmesg）+ 失败服务（systemctl --failed）→ 流式 AI 诊断（现象→原因→修复，[EXECUTE] 修复命令→卡片）。
- **🎯 护城河 Z3 健康巡检一键真闭环（windows/linux）**：运维快捷「健康巡检」一键 → SSH 取真实指标（负载/内存/磁盘/CPU Top5/服务）→ AI 诊断（资源水位→风险点→优化建议）。端到端验证 AI 给出专业巡检报告（磁盘 88% 告警 + OOM 风险 + 服务异常，⚠️ 标注）。
- **SSH Session 复用（windows/linux）**：持久会话（windows _sshClient + 锁 / linux OnceLock<Mutex<Session>>），连接+握手+认证只首次/断线后做，断线重连；多命令/一键巡检/报错分析显著提速。
- **命令执行耗时显示（windows/linux）**：结果后「✓/✕ 耗时 Xms」运维参考。
- **终端快捷命令栏增强（windows/linux）**：磁盘/内存/进程/网络/日志/服务一键，按风险配色。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，749 提交。

## 阶段 22 — 深化打磨：对照 apple 护城河补齐 windows/linux（2026-06-27）

S1-S5 完成后转入深化打磨，对照 apple 护城河把智能运维细节在 windows/linux 补齐对齐。

- **运维快捷入口（对照护城河 Z1命令解释/Z2报错分析/Z3健康巡检）**：windows/linux AI 面板加「解释命令/分析报错/健康巡检」快捷按钮 → 预填专用运维提问，降低使用门槛。
- **命令风险四级分级（对照 Z7 CommandRisk）**：windows/linux 从二元 is_dangerous → 四级（安全/注意/高风险/极高危），命令卡片按级别配色（绿/橙/深橙/红）+ [级别] 标签；高/极高危 Auto 也强制确认。
- **AI 体验打磨**：windows 流式输出（SSE content_block_delta 逐字）+ 代码块渲染 + 清空对话；linux 代码块渲染 + 清空对话。
- **性能**：windows SSH Session 复用（持久会话，连接+握手+认证只首次/断线后做，Auto 闭环多命令显著提速）。
- **AI 运维提示词五端对齐**：apple/windows/linux 统一资深运维专家提示词。
- **截图归档**：`apple/screenshots/windows-smart-ops.png`（windows 三栏 + AI 三模式 + 运维快捷入口 + 代码块对话）。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，729 提交。

## 阶段 21 — 智能运维 S1-S5 全部完成 + AI 体验打磨（2026-06-27）

ROADMAP S1-S5（用户核心需求「智能运维全平台落地 + AI 三模式」）**全部 ✅ 完成**，全平台真实落地、能力体系一致、端到端验证。

- **S1-S5 全完成**：S1 linux 真实 SSH（ssh2）/ S2 linux 真实 AI（ureq）/ S3 windows 真实 SSH+AI（SSH.NET + HttpClient 流式）/ S4 智能运维移植（Z3 环境感知 + 优化运维提示词 + 危险拦截）/ S5 AI 三模式（Chat/Agent/Auto，五端对齐 UI+逻辑）。
- **AI 体验打磨（windows）**：流式输出（SSE content_block_delta 逐字显示）+ 代码块渲染（```bash→等宽深色代码框）+ AI 对话清空/新建会话。linux 同步代码块渲染。
- **AI 运维系统提示词五端对齐**：apple/windows/linux 统一资深 Linux/SSH 运维专家提示词（结合真实环境 / 命令代码块 / 危险操作风险分级+备份 / 排障先诊断后修复验证 / 常见故障识别 / [EXECUTE] 标记）。
- **能力对齐总览**：真实 AI（windows HttpClient 流式 / linux ureq / apple URLSession）+ 真实 SSH（windows SSH.NET / linux ssh2 / apple SSHTerminalSession）+ AI 三模式安全梯度 + Z3 环境感知（windows/linux）+ 危险命令拦截（各端）。windows 更有 Auto 自主闭环 agent loop（读输出→决策→执行→回喂）。
- **端到端验证**：真实 AI nexcores（claude-opus-4-8）+ 真实 SSH 47.85.19.31（Ubuntu 20.04），凭据环境变量不硬编码；windows GUI 跑通 + linux ureq/ssh2 逻辑临时项目验证（LINUX_AI_OK/LINUX_SSH_OK）。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，PARITY 103 项 ✅✅，717 提交。

## 阶段 20 — 智能运维全链路真实落地 + AI 三模式 Agent（2026-06-27）

里程碑级突破：智能运维从「仅 apple/android 真实」→ **windows 端全链路真实**，用户提供真实 AI 接口（nexcores claude-opus-4-8）+ SSH 测试机（47.85.19.31），每步端到端验证。

- **真实 AI（windows + linux）**：windows HttpClient / linux ureq 调 Anthropic 兼容接口（nexcores），优化系统级运维提示词（资深运维专家/结合真实环境/危险操作风险分级/排障先诊断后修复/[EXECUTE] 标记）。key 从环境变量，不硬编码。端到端验证：「CPU 飙 95% 排查」→ 专业三步走方案。
- **🤖 AI 三模式（用户核心设计，安全梯度）**：
  - **Chat**：纯聊天，AI 只建议不碰终端。
  - **Agent**：AI 生成命令，每条「▶ 执行」按钮人工确认放行。
  - **Auto Agent**：AI 读输出→决策→执行→读结果**自主闭环**（agent loop），端到端验证：回喂 ps 结果→AI 自主决策 top -Hp 查线程。限轮 5 + 危险中断防失控。
- **真实 SSH（windows，SSH.NET）**：连 47.85.19.31 真实 exec，手输命令 + AI 生成命令都真实在服务器执行，结果回终端。端到端验证：SSH.NET 认证通过 + RunCommand 返回结果。
- **Z3 环境感知（windows）**：提问前 SSH 取服务器真实状态（系统/CPU/内存/负载/服务）注入 AI 系统提示。端到端验证：注入 2核/899MB 真实配置→AI 精准指出内存不足 OOM 风险 + 低配 JVM 方案。
- **安全铁律**：极高危命令（rm-rf/mkfs/dd/shutdown/fork 炸弹/chmod777）⚠ 标注，即使 Auto 模式也强制人工确认、不自动绕过；所有执行可回滚（对齐护城河）。
- **AI 多轮对话历史**（windows）：上下文累积，AI 记住多轮，为 Auto 闭环铺垫。
- **UI 品质专项 U1-U4**：windows PathIcon + linux Phosphor 图标库化（去 emoji）；JetBrains Mono 字体双端；整窗深色配色协调（ExtendClientAreaToDecorationsHint）；AI 三模式切换器 UI。
- **AI 三模式五端对齐（UI + 逻辑）**：apple/windows/linux（iOS 同 apple）AI 面板都有 Chat/Agent/Auto 三档切换器 + 安全梯度行为（Chat 不执行 / Agent 待确认放行 / Auto 自主，危险命令各端强制确认）。apple 复用真实终端会话注入（injectCommand），windows/linux 真实 SSH 执行。
- **真实能力双端落地（windows + linux，都端到端验证）**：真实 AI（windows HttpClient / linux ureq 调 nexcores）+ 真实 SSH（windows SSH.NET / linux ssh2 连 47.85.19.31）。临时项目端到端验证：linux ureq AI 跑通 + ssh2 连服务器跑通。
- **质量基线**：五端 build 全绿，apple 18 自测全集无回归，PARITY 103 项 ✅✅，699 提交。
- **真实测试资源**：AI nexcores（Anthropic 格式，claude-opus-4-8）+ SSH 47.85.19.31（Ubuntu 20.04），密码/key 环境变量不硬编码。

## 当前状态

- **双端原生可构建**：apple（Swift，swift build + 自测齐全 + 截图渲染验证）+ android（Kotlin，gradle 出 APK，零 deprecated warning）。
- **双端配对能力 100% 对齐**（PARITY 配对能力 🟡=0）：核心智能运维护城河 Z1–Z8 + SSH/终端/SFTP（完整）/AI（完整）/安全/跳板机/批量运维/连接管理 全 ✅✅。
- **差异化深化 + 细节打磨 + 功能完整化**：知识沉淀闭环六环（随手记→记录→筛选/搜索→喂 AI 全路径→AI 结论存方案→导出共享）+ 护城河场景库扩充（Z4 排障 11 场景 / Z8 部署 11 模板）+ 命令收藏夹/快捷命令增删改分组 + 连接批量编辑/最近使用/色选器/校验 + SFTP 批量删除/下载 + AI 提示词 25 条 + AI 消息时间戳 + 批量结果统计/导出 + 破坏性操作二次确认，双端落地且交互一致、平台差异处理得当。
- 仅余各自独有特性（非缺陷）：android 定时后台巡检（WorkManager）、apple 分屏/会话录制（移动端意义有限）。
- linux（Rust+egui）🟡 骨架（本机无 Rust 工具链，未编译验证，backlog）；windows（C#/.NET）⬜ 待建。
- 边界：本机无完整 Xcode → apple 未出 iOS/macOS 包、未真机实测；android 真实连接/AI 需真机 + 服务器 + API Key。
