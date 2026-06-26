# Termind — 智能 SSH 服务器运维工作台 路线图

> **定位**（2026-06-25 确立，见 [docs/PRODUCT.md](docs/PRODUCT.md)）：不是本地终端，而是
> **以 SSH 为入口、AI 为助手、服务器管理为核心的智能运维工作台**，对标 Xshell/Termius。
> 护城河 = AI + 真实服务器状态 + 安全执行 + 可回滚。

## 🏆 里程碑（截至最新迭代）

- **全平台原生双端可构建**：apple（Swift/SwiftUI，swift build + 自测齐全）+ android（Kotlin/Compose，gradle 出 APK ~26MB）；linux🟡(Rust+egui 骨架) windows⬜
- **智能运维护城河 Z1–Z8 双端完全对齐**：命令解释 · 报错分析 · 环境感知 · 排障工作流 · 操作回滚 · 状态面板 · 风险分级/脱敏 · 初始化模板
- **SSH/SFTP/AI/安全主线双端齐平**：密码+私钥认证 · 交互式彩色 PTY 终端 · SFTP 浏览/查看/下载/上传 · AI 对话流式+多对话+解释/报错/健康分析 · Keychain/加密存储 · TOFU · 端口转发 · 可达性探测 · 多主题
- **阶段 N 批量运维创新（运维工作台杀手级，单连接工具做不到）**：命令历史 · 批量群发命令 · 群发结果 AI 汇总 · 批量健康巡检 · 巡检 AI 总结 · **定时后台巡检+通知（主动运维）**

## 🧱 架构：全平台原生（2026-06-25 决策）

用户决策：**全部使用原生语言**、按愿景重新全面开发。已删除 Electron(src/) + Capacitor(mobile/) 等 Web 方案。

| 平台 | 原生技术 | 目录 | 本机可编译验证 |
|------|---------|------|:---:|
| macOS / iOS / iPadOS | **Swift + SwiftUI**（Citadel SSH + SwiftTerm） | `apple/` | ✅ swift build（无 Xcode 不能出包/跑） |
| Android | **Kotlin + Jetpack Compose**（✅ 骨架+APK 跑通） | `android/` | ✅ gradle 8.13+AGP 8.7.2 出 app-debug.apk 14.7MB |
| Windows | **C# + WinUI 3 / .NET**（待建） | `windows/` | ❌ 需 Windows |
| Linux | **Rust + egui/eframe**（🟡 骨架已搭，未本机验证） | `linux/` | ❌ 本机无 Rust，需 Linux+cargo |

### 🐧 Linux 原生 backlog（linux/ Rust+egui）
- [x] **L0** 工程骨架（Cargo.toml eframe/egui+ssh2+ureq；src/main.rs TermindApp 连接列表占位 UI；README 构建说明+路线；⚠️ 本机无 cargo 未编译验证，需 Linux+Rust 环境；推送 9550426）
- [ ] **L1** 真实 SSH（ssh2 crate）+ 交互终端 / **L2** 连接管理持久化 / **L3** AI 助手(ureq) / **L4** 智能运维逻辑移植

> apple/ 保留为 macOS/iOS 原生旗舰（按 SSH 运维愿景重设计），不推倒重来——它本就是原生 Swift。
> 可选后端 `relay/`（Node WebSocket→SSH）保留供原生移动端可选使用。

### ✨ 阶段 N — 双端产品创新（PARITY 收官后，加运维工作台杀手级能力）
- [x] **N-History** 命令历史 + 调出重用 ✅（android CommandHistory.kt[SharedPreferences 去重/置顶/限50]+ServerWorkspace 历史按钮+sheet[风险色点/点击填命令/删/清空]；apple Core CommandHistory[updated 纯逻辑+UserDefaults]+--history-test 自测过；双端落地；推送 9c8a6aa→04d9623）
- [x] **N-Multi** 批量群发命令 ✅（BatchScreen 选多连接+统一密码+命令[风险徽章]→并发 async+awaitAll connectAndExec→结果卡片[运行/成功/失败+输出脱敏]；高危群发二次确认；ServerListScreen「批量群发」入口；构建 22s；推送 d5f301f。运维工作台核心差异化）
- [x] **N-Multi-AI** 群发结果 AI 汇总 ✅（BatchScreen 全部完成后「AI 汇总」按钮→拼各连接结果→AiClient.chatStream 流式总结[总览/失败原因/共性/建议]；群发+AI 洞察=单连接工具做不到；构建 15s；推送 4845975）
- [x] **N-Multi apple** Core 框架 + UI 渲染 ✅（Core BatchRunner[run/summary/composeForAI]+--batch-test；Showcase BatchShowcase[多选+命令风险+结果卡片+AI 汇总入口]+渲染 22-batch.png 核对；swift build；推送 38b7974→6c6f684。真实 SSH 接入[SSHTerminalSession.runCommand] 留 UI TODO）
- [x] **N-Cron** 批量健康巡检（手动）✅（InspectScreen 统一密码→并发 fetchStatus 全部连接→各服务器 CPU/内存/磁盘卡片+hasWarning 红/绿/错误，异常置顶+「N 台需关注」汇总；ServerListScreen「健康巡检」入口；构建 31s；推送 8ca6f96。定时调度 WorkManager 留 TODO）
- [x] **N-Cron-AI** 巡检结果 AI 总结 ✅（InspectScreen 汇总条「AI 总结」→各服务器状态拼素材→AiClient.chatStream[总览/资源紧张机器/优先处理]流式；构建 14s；推送 65fdabe）
- [x] **N-CronAuto** WorkManager 定时后台巡检+离线通知 ✅（work-runtime 依赖+POST_NOTIFICATIONS；InspectWorker CoroutineWorker 周期并发 probe→离线发通知；设置「定时后台巡检」Switch[请求权限+enable/disable]+通知渠道；构建 38s 出 APK 26.0MB；推送 0894ff1。主动运维；密码不持久化故后台仅可达性探测，状态巡检需凭据 TODO）

### 🤖 安卓原生 backlog（android/ Kotlin+Compose）
- [x] **A0** 工程骨架 + APK 跑通 ✅（gradle 8.13[缓存] + AGP 8.7.2 + Kotlin 1.9.24 + Compose 1.5.14；MainActivity 连接列表 UI[Termind 顶栏+按分组 ServerCard]；assembleDebug 出 app-debug.apk 14.7MB；推送）
- [x] **A1** 安卓真实 SSH（sshj exec）✅（sshj 0.38.0+slf4j-nop+coroutines 依赖，packaging 排 META-INF 冲突；SshClient.connectAndExec[SSHClient+PromiscuousVerifier MVP+authPassword+exec stdout/stderr/退出码，IO+超时+Result]；ServerWorkspace 密码框+命令框+执行+滚动输出；构建 7m 出 APK 25.9MB[含 sshj/BC]，无打包冲突；推送 479ef31。实连需真服务器；A1b PTY 交互终端待做）
- [x] **A2-UI** 安卓界面充实 ✅（底部导航 连接/AI 助手/设置 三 tab；AI 助手屏[运维提示卡片+输入占位]；设置屏[配色/AI 服务商/Key/关于]；连接卡片→ServerWorkspace[状态面板 CPU/内存/磁盘+终端区+AI 入口，呼应工作台三层]；增量构建 13s 出 APK 14.8MB；推送 9d3a823）
- [x] **A2** 连接管理（持久化+增删改）✅（ConnectionStore[SharedPreferences+JSON，零依赖]load/save+seed；EditConnectionScreen 新建/编辑表单[host/user 必填]；MainActivity mutableStateListOf+FAB 新建+卡片⋮菜单 编辑/删除+空状态+persist；增量构建 14s 出 APK 14.8MB；推送 0d69774）
- [x] **A3** 智能运维 Kotlin 化（风险分级+脱敏）✅（OpsCore.kt：CommandRisk 四级[label/color/needsConfirm/riskLevel，照搬 apple 规则与配色]+Redactor.redact[移植 apple]；ServerWorkspace 命令实时风险徽章+高危 AlertDialog 二次确认+SSH 输出脱敏；构建 14s 出 APK 25.9MB；推送 ac8791f）
- [x] **A3b** 排障工作流 + 初始化模板 Kotlin 化 ✅（OpsWorkflows.kt：DiagnosticWorkflow 5 内置+SetupTemplate 5 内置[risk 复用 CommandRisk+previewText]，移植 apple；ServerWorkspace 顶栏「排障」「初始化模板」Menu 点击填命令框；推送 80b3533）
- [x] **A4** 安卓 AI 助手（OkHttp 调 Anthropic）✅（AiClient.chat[Messages API 非流式 org.json]；SettingsStore[SharedPreferences 存 Key/模型]；AIAssistantScreen 真对话气泡+输入栏+发送；SettingsScreen API Key 弹框配置；构建 58s 出 APK 30.8MB[含 OkHttp]；推送 6df2aff。流式+状态面板真采集待后续）
- [x] **A1b** 交互式 PTY 终端 ✅（SshClient.openShell[allocateDefaultPTY+startShell，协程读 inputStream→onOutput 脱敏，stripAnsi 去转义]+SshShellSession[write/close]；ServerWorkspace ConnState 状态机[未连/连接中/已连/失败]+状态条+断开+持久 shell send(cmd+\n)+DisposableEffect 防泄漏；构建 15s 出 APK 30.8MB；推送 7864c66）
- [x] **A-Status** 状态面板真实采集 ✅（SshClient.fetchStatus[top -bn1|grep %Cpu + free -m + df -h /]+ServerStatus.parse[CPU=100-idle/内存 used/total GB/磁盘 used/total 占用%]；ServerWorkspace 连接后 refreshStatus 采集，状态面板显真实值+刷新按钮；构建 16s 出 APK 30.8MB；推送 8f42c33）
- [x] **A-Env** 环境感知 Kotlin 化 + AI 接环境 ✅（EnvCore.kt ServerProfile[+aiSummary]+EnvDetector[detectCommand+parse]，移植 apple ServerProfile.swift；SshClient.fetchEnv；ServerWorkspace 连接后探测→onProfile 上报+终端显🔎摘要；TermindApp activeProfile；AIAssistantScreen 注入 aiSummary 到 systemPrompt[AI 结合真实环境]+顶栏「已感知环境」；构建 16s 出 APK 30.8MB；推送 de655eb）

> **🎉 安卓端核心能力全齐**：连接管理 · 真实 SSH · 交互式 PTY 终端 · 状态面板真采集 · 风险分级/脱敏 · AI 对话+环境感知 · 排障工作流 · 初始化模板 —— 与 apple 端智能运维护城河高度对齐，从零数轮迭代建成。

#### 安卓打磨
- [x] **A-Diag** 排障工作流真实执行+AI总结 ✅（DiagnosticWorkflow.joinedCommand/composeForAI；ServerWorkspace.runDiagnostic 一次跑全部命令→拆分→终端显原始(脱敏)→AiClient summaryPrompt 总结「AI 结论」；从填命令框升级；构建 16s 出 APK 30.8MB；推送 d36e4d8）
- [x] **A-Snippets** 快捷命令面板 ✅（Snippets.kt CommandSnippet+12 内置常用命令[磁盘/内存/进程/端口/Nginx/Docker/日志/登录失败等]+risk；ServerWorkspace 已连接时命令框上方横滑 AssistChip 行，点击填命令框，带风险色点；构建 17s 出 APK 30.8MB；推送 139238e）
- [x] **A-Stream** AI 流式输出 ✅（AiClient.chatStream[stream=true，source().readUtf8Line 读 SSE，解析 content_block_delta.delta.text 逐块 onDelta 切 Main]；AIAssistantScreen.send 流式：空 assistant 消息→delta 追加；构建 16s 出 APK 30.8MB；推送 4195a06）
- [x] **A-SFTP** 远程文件浏览 ✅（SshClient.listDir[newSFTPClient.ls→RemoteFile 列表，文件夹优先排序]+RemoteFile[sizeLabel]；ServerWorkspace「文件」入口→SftpBrowser ModalBottomSheet[路径栏+上级+列表 文件夹/文件图标+大小+点进入]；构建 16s 出 APK 30.8MB；推送 cbd4e44）
- [x] **A-Tpl-Exec** 初始化模板真执行 ✅（ServerWorkspace.runSetupTemplate 按 SetupStep 逐步执行[过滤注释，每步「▶N.步骤名」+connectAndExec 输出脱敏，完成✅+刷新状态]；执行前 AlertDialog 确认[previewText+风险着色]；模板 Menu 改 pendingTemplate 触发；构建 16s 出 APK 30.8MB；推送 d178cca）
- [x] **A-Rollback** 操作回滚 Kotlin 化 ✅（RollbackCore.kt OpRollback[criticalPrefixes/isCriticalConfig/criticalTargets/backupCommand/sshAutoRollbackCommand]+OpTimelineEntry[rollbackCommand]，移植 apple；ServerWorkspace.send 改关键配置前自动 cp 备份+记 opTimeline；顶栏「时间线」History 入口→ModalBottomSheet 列操作+可回滚项一键回滚；构建 17s 出 APK 30.8MB；推送 8425732）

- [x] **A-FileView** SFTP 查看文本文件内容 ✅（SshClient.readFile[head -c 200KB 限大小+单引号转义]；SftpBrowser 点文件→openFile 读→AlertDialog 滚动显示(脱敏)；构建 17s 出 APK 30.8MB；推送 f922570）
- [x] **A-Forward** 本地端口转发 ✅（SshClient.openForward[ServerSocket bind+newLocalPortForwarder+协程 listen]+PortForwardHandle；ServerWorkspace「端口转发」按钮→PortForwardDialog 建立/停止；修 sshj API[LocalPortForwarder 在 .direct.；Parameters 独立类]；构建 19s；推送 df6989f。PARITY 端口转发 ⬜→✅）
- [x] **A-ConvoSearch** AI 对话内搜索 ✅（顶栏搜索框过滤当前对话消息 contains+「N 条匹配」；构建 19s；推送 76ed3ab。PARITY AI 能力双端完全对齐）
- [x] **A-ConvoExport** AI 对话导出 Markdown ✅（exportConvo 拼 Markdown→Intent.ACTION_SEND 分享；对话菜单「📤 导出当前」；构建 18s；推送 1dbd4b7）
- [x] **A-ConvoPersist** AI 对话持久化 ✅（ConvoStore SharedPreferences 存对话 JSON；AIAssistantScreen 加载+发消息/新建/删除后 persist；重启不丢；构建 18s；推送 908ca54）
- [x] **A-Convos** AI 多对话管理 ✅（AIAssistantScreen messages→convos 列表+curIdx；顶栏对话标题下拉 切换/新建/删除当前；内存多对话；构建 18s；推送 b9a6ee5。PARITY 多对话 ⬜→✅）
- [x] **A-TOFU** 主机密钥 TOFU 校验 ✅（KnownHosts 指纹[SHA-256 Base64]存 SharedPreferences+check NEW/MATCH/MISMATCH；TofuVerifier 实现 sshj HostKeyVerifier；5 处 PromiscuousVerifier→TofuVerifier；onCreate init；首次信任+后续比对防 MITM；构建 18s；推送 da3ffa9。PARITY TOFU 🟡→✅）
- [x] **A-Themes** 多主题配色 ✅（Themes.kt 5 套 ThemeScheme[午夜/One Dark/Dracula/Solarized/Nord，对齐 apple]+全局 activeTheme；顶层颜色改计算属性自动跟随；SettingsStore themeId；SettingsScreen 主题选择 dialog 即时切换+持久化；构建 18s；推送 9bf20ff。PARITY 多主题 🟡→✅）
- [x] **A-Download** SFTP 文件下载 ✅（SshClient.downloadFile sftp.get→getExternalFilesDir；SftpBrowser 文件行下载图标+toast 显路径；构建 18s；推送 45971f8）
- [x] **A-Upload** SFTP 文件上传 ✅（SshClient.uploadFile sftp.put；SftpBrowser GetContent 文件选择器→contentResolver 查名+复制到 cacheDir→上传当前目录→刷新+toast；头部「上传」按钮；修 load() 前向引用；构建 18s；推送 91e8c1c→e0f5016。安卓 SFTP 完整=浏览/查看/下载/上传）
- [x] **A-KeyFile** 私钥从文件导入 ✅（ServerWorkspace 私钥框「从文件选择私钥」GetContent→读文本填入；构建 19s；推送 ecf773f）
- [x] **A-Portability** 连接配置导出/导入 ✅（ConnectionStore exportJson[不含密码]/importJson；ServerListScreen 更多菜单 导出分享/导入文件去重 merge；对齐 apple ConnectionPortability；构建 18s；推送 9b9fd7c）
- [x] **A-Reach** 连接可达性 TCP 探测 ✅（Reachability.probe[Socket+InetSocketAddress 纯 TCP 探测，对齐 apple]；TermindApp probeAll 并发 async 探测+LaunchedEffect 自动+「刷新在线状态」按钮；ServerCard 状态点 在线绿/离线红/探测中黄/未知灰 替写死 online；构建 17s；推送 1a055fc）
- [x] **A-KeyAuth** 私钥认证 ✅（ServerConn.authType[PASSWORD/KEY]+持久化；SshClient.authenticate[loadKeys PEM+authPublickey / authPassword]+各调用加 privateKey 参数；EditConnectionScreen 认证方式 FilterChip；ServerWorkspace 凭据框按 authType 显密码/私钥 PEM 框+keyArg() 传各调用；私钥临时不持久化；构建 18s；推送 b2a6fae）
- [x] **A-SnippetCRUD** 快捷命令自定义增删 ✅（SnippetStore SharedPreferences 持久化；ServerWorkspace 快捷命令 Chip 默认+自定义+「+新建」对话框+删除；修 termColors 前向引用；构建 20s；推送 2c48299→88b814a）
- [x] **apple 巡检自测 --inspect-test** ✅（Core HealthInspection.sorted/composeForAI 纯逻辑解耦；AppModel 复用；自测「告警置顶排序=true；AI 素材正确=true」；CLAUDE.md 加清单；推送 ffa2815）
- [x] **A-SftpFilter** SFTP 文件名过滤 ✅（SftpBrowser 过滤图标 toggle 过滤框→contains 过滤+排序联动；构建 21s 无 warning；推送 c787f76）
- [x] **A-AIClear** AI 清空当前对话消息 ✅（对话菜单「🧹 清空当前消息」→messages.clear()+持久化保留对话壳；构建 21s 无 warning；推送 f8f30dd）
- [x] **A-Duration** 终端连接时长显示 ✅（connectedAt+LaunchedEffect 每秒 tick；状态条显 formatDuration mm:ss/HH:mm:ss；构建 22s 无 warning；推送 34370d2）
- [x] **质量收口·快捷命令+连接管理体验快照** ✅（apple 8 自测+android clean 零 warning；PARITY 🟡=0；快捷命令增删改分组/连接管理批量+最近+导入 双端完整；推送见下）
- [x] **快捷命令编辑双端** ✅（编辑自定义片段 名称/命令/分组；apple swipe 编辑 upsert[9cd48ca]/android 长按编辑 SnippetStore.update[41b7bec]+OptIn 修复[a6f7c90]）
- [x] **linux 端现状评估** ✅（本机无 cargo/rustc 无法编译验证；骨架=114 行 egui 连接列表 UI mock，无真实 SSH/AI；需 Linux+Rust 环境推进；如实记录 backlog，不盲写无法验证的 Rust；推送见下）
- [x] **质量收口·AI 对话体验全景快照** ✅（apple 8 自测+android clean 零 warning+APK；PARITY 🟡=0；AI 对话 输入/生成/操作/沉淀 全链路丰富双端齐；推送见下）
- [x] **AI 单条 user 消息重发双端** ✅（user 消息 右键/长按菜单「重发」→重新发该问题；apple MessageBubble[a0fc4d4]/android ChatBubble onResend[18f26ff]）
- [x] **android 快捷命令分组显示** ✅（横滑行按 group 分组+分组标签，对齐 apple SnippetsView 早有分组；构建 27s 无 warning；推送 7ca4dec）
- [x] **质量收口·知识沉淀入口全覆盖快照** ✅（apple 8 自测+android clean 零 warning；PARITY 🟡=0；录入四入口 随手记/手动/AI结论/任意消息 全覆盖；推送见下）
- [x] **AI 单条消息存为知识卡片双端** ✅（任意 AI 回复 右键/长按菜单存为 笔记/方案；apple MessageBubble contextMenu[a48f793]/android ChatBubble 长按菜单[d8c0a53]；知识沉淀入口更灵活）
- [x] **README 更新** ✅（能力清单加 Z4 8场景/Z8 8模板/命令收藏夹/批量编辑/最近使用/快捷追问；知识卡片升级闭环六环；apple build 抽查；推送 735ae03）
- [x] **质量收口·知识卡片体验全齐快照** ✅（apple 8 自测+android clean 零 warning+APK；PARITY 🟡=0；知识卡片 记录/随手记/AI结论存方案/筛选/搜索/喂AI/导出 全齐；推送见下）
- [x] **知识卡片关键词搜索双端** ✅（类型筛选+关键词组合过滤；android 搜索框[>3条]/apple .searchable；shownNotes 双过滤；推送 a417e5a）
- [x] **docs/PRODUCT.md 更新** ✅（Z4 8场景/Z8 8模板/命令收藏夹/批量编辑/最近使用 入 MVP 对照；新增「🎯 知识沉淀闭环六环」章节；apple build 抽查通过；推送 59062b9）
- [x] **apple AI 面板 Showcase 补新 UI** ✅（AIPanelShowcase 加 重新生成/存为方案/快捷追问 Chip；渲染 03-ai-panel.png 核对+拷 screenshots；截图与功能同步；8 自测全过；推送 a5b41a6）
- [x] **质量收口·知识沉淀闭环全景快照** ✅（apple 8 自测+android clean 零 warning；PARITY 🟡=0；闭环六环 随手记→记录→筛选→喂AI全路径→AI结论存方案→导出 全双端打通；推送见下）
- [x] **AI 结论一键存为方案双端** ✅（AI 回复后「存为方案」→ServerNotebook SOLUTION；发现问题→AI分析→沉淀方案 闭环；android 7e3e4d9/apple 2c6ac74）
- [x] **质量收口·双端对齐 100% 恢复快照** ✅（apple 8 自测+android clean 零 warning+APK；PARITY 🟡=0；连接批量编辑/最近使用 双端✅✅；推送见下）
- [x] **apple 连接批量编辑对齐** ✅（multiSelectMode+batchSetGroup/Color/Delete；SidebarView 头部开关+勾选+底部操作栏；双端连接批量编辑对齐 PARITY 🟡=0；8 自测全过；推送 aa57038）
- [x] **apple 最近使用快速访问对齐** ✅（SidebarView「最近使用」横滑区 lastUsedAt 倒序前 5→openSession；双端最近使用对齐；8 自测全过；推送 fa88c20）
- [x] **android 最近使用快速访问 + 质量收口** ✅（连接列表顶部「最近使用」横滑前 5；apple 8 自测+android clean 零 warning；推送 a307bda）
- [x] **android 批量编辑扩展** ✅（操作栏加 批量颜色标签[颜色选择]+批量删除[二次确认]；onBatchColor/onBatchDelete；构建 24s 无 warning；推送 b34e523）
- [x] **android 连接批量编辑** ✅（ServerCard 多选模式[combinedClickable 长按+勾选]+批量改分组对话框→批量 copy；apple 8 自测+android clean 零 warning；推送 1f4cfc7）
- [x] **质量收口·近期进展快照** ✅（apple 8 自测+android clean 零 warning；PARITY 🟡=0；知识卡片/AI对话/命令快捷/批量运维/连接管理 全景；推送见下）
- [x] **知识卡片类型筛选双端** ✅（NotebookSheet FilterChip/NotebookView Picker 按 全部/问题/方案/笔记 筛选；shownNotes 过滤；推送 9b029da）
- [x] **AI 对话快捷追问双端** ✅（末条 assistant 后 给我命令/换思路/解释/风险 快捷 Chip→send；android e9626fa/apple e8abe06；提升对话流畅度）
- [x] **命令收藏夹自测 + 质量收口** ✅（--favorites-test「置顶加入/取消/去空=true」自测 7→8 项；apple 8 自测+android clean 零 warning；推送 d15529f）
- [x] **命令收藏夹双端** ✅（CommandFavorites 持久化[Core/Kotlin 对齐]；命令历史星标收藏+收藏命令置顶快捷 Chip/Section；android dac2a90/apple 7d31e36；常用命令跨连接快捷）
- [x] **知识卡片喂 AI 全路径双端** ✅（android AIAssistantScreen connId+send 注入[2c3c6d1]/apple runAICompletion 中心化注入[03242b9]；知识沉淀闭环覆盖 对话/解释/报错/排障/健康 全 AI 路径）
- [x] **CHANGELOG 阶段8·差异化深化** ✅（知识沉淀闭环全链路+护城河场景库扩充+批量分组全选+SSH config 导入；当前状态从双端对齐→差异化深化；推送 07eef3e）
- [x] **质量收口·近期进展快照** ✅（apple 7 自测+android clean 零 warning；PARITY 🟡=0；知识卡片闭环+场景库扩充+批量效率 全景；推送见下）
- [x] **apple 批量群发/巡检分组全选** ✅（BatchView/InspectView 全选/清空/分组按钮；双端批量选目标对齐；7 自测通过；推送 9a860eb）
- [x] **android 批量群发分组全选** ✅（BatchScreen 全选/清空+各分组 Chip 一键选中该组+选择计数；修 horizontalScroll 导入；推送 a64e168→e6b26ed）
- [x] **知识卡片随手记双端** ✅（命令历史一键存为知识卡片；android 书签图标[b3d7c8a]/apple contextMenu[67415a5]；强化知识沉淀:随手记）
- [x] **质量收口·护城河能力库快照** ✅（apple 7 自测全过+android clean 零 warning；Z1-Z8+阶段N+知识卡片闭环 全景；推送见下）
- [x] **深化初始化模板 Z8** ✅（内置 5→8：加 Redis 缓存/PostgreSQL 数据库/Python 应用环境；双端 builtins 对齐；含密码占位；双端构建通过；推送 07f7a3d）
- [x] **深化排障工作流 Z4** ✅（内置 5→8：加 内存占用/端口占用/服务启动失败 排查；双端 builtins 对齐；只读诊断命令；双端构建通过；推送 642392e）
- [x] **质量收口 + README 更新** ✅（apple 7 自测+android clean 零 warning；README 加知识卡片护城河区+新截图[24/23/22]+能力表补充；推送 0a6bda1）
- [x] **SSH config 导入双端** ✅（android SshConfigParser.kt 对齐 apple+粘贴文本导入；apple 早有读 ~/.ssh/config 文件[SettingsView 入口]→双端，方式各适配平台；推送 8da9e25）
- [x] **知识卡片导出 Markdown** ✅（双端 Core exportMarkdown[按类型分组]+--notebook-test 导出 MD=true；apple 复制/android 分享 Intent；apple 7 自测+android clean 零 warning；推送 d0c52df）
- [x] **知识卡片喂 AI 健康分析** ✅（双端健康分析 AI 注入本机历史；android HealthAISheet[e628343]/apple diagnoseHealth[779c0dc]；闭环扩展到健康分析）
- [x] **CHANGELOG 阶段7 + PRODUCT 更新** ✅（双端对齐达成+差异化深化里程碑；服务器知识卡片/知识沉淀闭环 PRODUCT ⬜→✅已具备；推送 f226d0b）
- [x] **知识卡片喂 AI 排障（闭环）** ✅（双端排障 AI 总结注入 ServerNotebook.composeForAI 本机历史→针对性结论；android runDiagnostic[2f6c29f]/apple analyzeDiagnostic[3e0c3b8]；记录→喂 AI→针对性排障）
- [x] **apple 服务器知识卡片 UI** ✅（NotebookView 类型 Picker+列表着色+swipe 删除；AppModel.notebookConnection+ContentView sheet+SidebarView 入口；Showcase 渲染 24-notebook；服务器知识卡片**双端✅**；推送 b10a51f）
- [x] **android 服务器知识卡片**（Kotlin化+UI）✅（ServerNotebook.kt 对齐 apple+NotebookSheet 类型选择/列表/新增/删除；MenuBook 修 AutoMirrored；构建 21s；推送 88efa3c→5982b02）
- [x] **服务器知识卡片 Core**（差异化新方向）✅（ServerNotebook：ServerNote[问题/方案/笔记]+按连接持久化+composeForAI；--notebook-test 自测 6→7 项；推送 5c0b94b）；UI 待接
- [x] **apple 终端连接时长对齐** ✅（TerminalSessionVM.connectedAt；StatusBarView TimelineView 每秒显时长；**双端配对能力完全对齐**！推送 8573667）
- [x] **apple 连接分组折叠对齐** ✅（SidebarView 分组 header 可点折叠+chevron+数量；collapsedGroups Set；Showcase 渲染；PARITY 分组折叠 apple✅；推送 5dfe5e9）
- [x] **质量收口·双端对齐里程碑** ✅（apple 6 自测全过+android clean 零 warning；SFTP 完全对齐+阶段N UI双端+AI 全对齐；PARITY 剩 4 项单端特性；推送见下）
- [x] **apple SFTP 文件名过滤对齐** ✅（FileBrowserView .searchable+sortedEntries 过滤；双端 SFTP 完全对齐；推送 8dc91e6）
- [x] **apple SFTP 时间+排序对齐** ✅（SFTPEntry.modifiedAt[Citadel accessModificationTime]；FileBrowserView 行显时间+排序 Menu 名称/大小/时间；Showcase 渲染；PARITY SFTP 时间/排序 apple✅；推送 4edb21f）
- [x] **PARITY 校正·连接复制** ✅（核查发现 apple 早有 cloneConnection[插原连接后+toast]+SidebarView contextMenu 已接→连接复制 apple🟡→✅；文档滞后纠正）
- [x] **apple AI 气泡头像对齐** ✅（MessageBubble AI 标签加 sparkles 图标对齐 android A-Avatar；Showcase 同步+渲染 03-ai-panel；推送 b7003ab）
- [x] **A-Paste** 终端命令框粘贴按钮 ✅（命令行加 ContentPaste 按钮→clipboard 填入 command；构建 23s 无 warning；推送 3382537）
- [x] **A-Version** 关于页版本号动态 ✅（build.gradle buildConfig=true；关于行 BuildConfig.VERSION_NAME；构建 28s 无 warning；推送 98be4c7）
- [x] **A-Multiline** AI 输入框支持多行 ✅（singleLine=false+maxLines 5；粘贴报错日志/长指令；构建 22s 无 warning；推送 bf4a664）
- [x] **A-Clone** 连接复制/克隆 ✅（ServerCard 复制菜单→conn.copy[新 id+名称加副本]插入+立即编辑；构建 22s 无 warning；推送 87dc681）
- [x] **A-LastUsed** 连接卡片上次使用相对时间 ✅（relativeTime helper[刚刚/N分钟/小时/天前/日期]；ServerCard lastUsed>0 显「上次使用 · X」对齐 apple；构建 22s 无 warning；推送 435a5a2）
- [x] **A-GroupFold** 连接列表分组折叠 ✅（分组标题可点行+箭头+组内数量→toggle collapsedGroups 隐藏连接；构建 21s 无 warning；推送 02916ff）
- [x] **A-SftpSort** SFTP 文件排序 ✅（顶栏排序 Menu 名称/大小/时间；文件夹优先+组内 sortedWith；构建 21s 无 warning；推送 b9e7421）
- [x] **A-SftpTime** SFTP 行显示修改时间 ✅（RemoteFile.mtime[sshj getMtime]+timeLabel[今年 MM-dd HH:mm/往年 yyyy-MM-dd]；行名下显时间；构建 22s 无 warning；推送 559689f）
- [x] **A-AutoScroll** 终端输出自动滚到底部 ✅（具名 termScroll+LaunchedEffect(output.length) 非搜索时 scrollTo maxValue；长会话刚需；构建 21s 无 warning；推送 1121efd）
- [x] **A-Avatar** AI 气泡角色头像 ✅（ChatBubble assistant 左侧小圆 AI 头像[AutoAwesome]；对话角色一眼区分；构建 20s 无 warning；推送 de27d65）
- [x] **A-Complete** 终端命令历史补全 ✅（命令输入框上方显匹配历史 Chip[contains 取 4 条]→点击填入；构建 21s 无 warning；推送 90da71d）
- [x] **apple 批量群发 UI** ✅（BatchView 多选+命令风险徽章+高危确认+runBatch 结果+AI 汇总；ContentView 入口+sheet；与巡检 UI 对称；推送 730ae50）
- [x] **apple 批量巡检 UI** ✅（InspectView 多选+巡检+告警置顶结果+AI 总结按钮；ContentView 入口+sheet；Showcase 渲染 23-inspect；PARITY 批量巡检 apple🟡→✅；推送 b39fb6c）
- [x] **CHANGELOG 阶段 6** ✅（双端深度对齐里程碑 + 当前状态刷新；推送 a59bd8e）
- [x] **apple 批量巡检逻辑接入** ✅（AppModel.runHealthInspection[TaskGroup 并发采集 SystemInfo+异常置顶]+summarizeInspection[AI 总结]；复用 RemoteSystemMonitor；UI 待接；推送 2bf2ddb）
- [x] **apple SFTP 路径跳转 + 消息复制确认** ✅（FileBrowserView 路径栏可点→alert 输路径→load；apple MessageBubble contextMenu 已有复制=等价；PARITY 🟡 清零；推送 ddea1fe）
- [x] **apple AI 提示词库对齐** ✅（AIAgentView.emptyHint 5 类分类提示词+胶囊切换；Showcase 渲染 20-ai-empty；PARITY AI 提示词库 apple✅；推送 a6b4e54）
- [x] **apple SFTP 增删改对齐** ✅（SSHTerminalSession sftpMakeDirectory/sftpRemove/sftpRename[Citadel createDirectory/rmdir/remove/rename]；FileBrowserView 新建文件夹工具栏+右键重命名/删除+确认；Showcase 渲染；PARITY SFTP 增删改/重命名 apple✅；推送 4ad9160）
- [x] **PARITY 续校正** ✅（apple TerminalSearchBar SwiftTerm 搜索→终端搜索 apple✅渲染 13-search；ConnectionEditView 已有测试连接→连接测试 apple✅；推送 73e6de7）
- [x] **PARITY 校正** ✅（确认 apple TerminalKeyBar 18 键完整→终端控制键栏 apple✅；批量群发已接 runBatch→apple✅；渲染 06-keybar 验证；推送 633df9c）
- [x] **apple AI 代码块渲染对齐** ✅（MessageBubble 按 ``` 拆代码块等宽深色框+stripLangLine；Showcase 同步+渲染 03-ai-panel 验证；PARITY apple 🟡→✅；推送 c60e6a0）
- [x] **A-About** 设置页开源仓库链接 ✅（「开源仓库」行→Intent 打开 github.com/DoBest369/ai-terminal；构建 21s 无 warning；推送 7fce75b）
- [x] **A-FormValid** 连接编辑表单校验 ✅（端口/跳板端口 1-65535 isError 红字；跳板填主机需补用户名；保存按钮 canSave 联动禁用；构建 12s 无 warning；推送 c2f2d6a）
- [x] **README 完善** ✅（平台矩阵/能力表刷新双端全对齐 + 界面预览截图 + apple runBatch 真接 SSH；推送 86c343b）
- [x] **A-Prompts** AI 运维提示词库 ✅（空对话提示词扩为 5 类[排障/部署/安全/性能/日志]×3；FilterChip 分类切换+点击 send；构建 21s 无 warning；推送 af89171）
- [x] **A-SftpRename** SFTP 文件重命名 ✅（SshClient.renamePath[sshj rename，支持 jump]；SftpBrowser 每行重命名图标+对话框；SFTP 文件管理完整[浏览/查看/下载/上传/新建/删除/重命名/路径跳转]；构建 22s 无 warning；推送 4467ec9）
- [x] **A-TermSearch** 终端输出搜索高亮 ✅（终端区搜索 toggle→关键词高亮[黄底黑字 buildAnnotatedString]+匹配计数；长日志定位；构建 21s 无 warning；推送 0081c80）
- [x] **A-SftpPath** SFTP 路径直接输入跳转 ✅（路径栏可点+Edit 图标→对话框输路径→load；直达 /etc 等深目录；构建 21s 无 warning；推送 b7e381b）
- [x] **A-Model** AI 模型选择 ✅（SettingsScreen「AI 模型」行→对话框选 Opus 4.8/Sonnet 4.6/Haiku 4.5+持久化；AiClient 已用 loadModel；构建 21s 无 warning；推送 0fc8ee9）
- [x] **零 deprecated warning** ✅（clean 全量编译确认 deprecated 计数=0；AltRoute/Sort/ArrowBack×3 全改 AutoMirrored）
- [x] **A-CardBadge** 连接卡片特性图标 ✅（ServerCard 名称旁 跳板[AutoMirrored AltRoute]/启动命令[Bolt]/私钥[VpnKey] 小图标；修 AltRoute deprecated；PRODUCT.md 刷新现状；构建 21s；推送 2b1f12c→1016f85）
- [x] **A-JumpAll** SFTP/端口转发经跳板补完 ✅（listDir/down/up/mkdir/del/readFile/openForward 全用 connectClient+关 bastion；SftpBrowser+openForward 调用传 jump；跳板覆盖全 SSH 操作；构建 21s；推送 90a8d21）
- [x] **A-Jump** 跳板机 ProxyJump ✅（android 最后核心缺口！sshj connectVia：bastion.newDirectConnection→target.connectVia；ServerConn jumpHost/Port/User 持久化+跳板密码运行时；connectClient 助手；openShell/connectAndExec/fetchStatus/fetchEnv 接 jump；EditConnectionScreen 跳板字段；SFTP/转发 TODO；构建 24s；推送 b457378）
- [x] **A-SftpEdit** SFTP 新建文件夹+删除 ✅（SshClient.makeDir/deletePath[mkdir/rm/rmdir]；SftpBrowser 新建文件夹按钮+每行删除二次确认；构建 21s；推送 03dac29）
- [x] **A-KeepAlive** 终端会话心跳防断连 ✅（openShell connect 后 ssh.connection.keepAlive.keepAliveInterval=30；javap 确认 sshj KeepAlive API；防 NAT/超时断连；构建 11s；推送 abe0f01）
- [x] **A-MsgCopy** AI 消息长按复制整条 ✅（ChatBubble combinedClickable 长按→clipboard+Toast；构建 20s；推送 d5dfa50）
- [x] **A-TestConn** 连接编辑测试连接 ✅（EditConnectionScreen「测试连接」按钮→Reachability.probe→✅可达/❌不可达；建连前验证地址端口；构建 13s；推送 45e77b4）
- [x] **A-Regen** AI 重新生成上一条 ✅（lastSent 记录上次(text,basePrompt)；regenerate 移除末 assistant+user 重发；末条 assistant 时显「🔄 重新生成」Chip；构建 20s；推送 dbb1f98）
- [x] **A-Stop** AI 助手停止生成 ✅（send 流式任务存 sendJob；stop() cancel 协程+保留已生成+[已停止]；输入栏发送按钮生成中变红停止按钮；构建 19s；推送 1aa07f3）
- [x] **A-Filter** 连接列表搜索过滤 ✅（ServerListScreen 搜索框按 name/host/user/group contains 过滤；构建 20s；推送 21b4416）
- [x] **A-Sort** 连接列表排序 ✅（ServerConn.lastUsed[打开连接更新]+JSON 持久化；ServerListScreen 排序 Menu 名称/最近使用/在线优先；构建 23s；推送 4731fae）
- [x] **A-TermActions** 终端复制全部+清屏 ✅（终端区按钮：复制全部[stripAnsi]/清屏[output=""]；构建 20s；推送 5887ec7）
- [x] **A-Startup** 连接启动命令 ✅（ServerConn.startupCommand+JSON 持久化；EditConnectionScreen 字段；connect 建立 shell 后自动执行 cd/source/tmux 等；构建 22s；推送 48230de）
- [x] **A-Tags** 连接颜色标签 ✅（ServerConn.colorTag[6 色枚举]+JSON 持久化；EditConnectionScreen 颜色选择圆点；ServerCard 左侧色条；一眼区分环境；构建 22s；推送 2eee143）
- [x] **A-FontSize** 终端字号调节 ✅（SettingsStore termFont[8-22sp]；终端区右上 +/- 按钮调字号+持久化；构建 20s；推送 506d155）
- [x] **A-Copy** AI 代码块一键复制 ✅（ChatBubble 代码块右上复制图标→clipboard.setText；推送 199272e）
- [x] **A-Md** AI 气泡代码块渲染 ✅（ChatBubble 按 ``` 拆代码块→等宽深色框[绿字+横滑]，其余文本正常；手写轻量无依赖；构建 19s；推送 dc40f61）
- [x] **A-Keys** 终端控制键栏 ✅（ServerWorkspace 终端区下方横滑键栏：Tab/Esc/Ctrl+C/D/L/Z/A/E+方向键↑↓←→→shellSession.write 控制字符/ESC 序列；移动端无 Ctrl/Tab，让 vim/top 可用；构建 19s；推送 370a550）
- [x] **A-Ansi** 终端 ANSI 颜色渲染 ✅（AnsiParser.parse→AnnotatedString 解析 SGR 前景色 30-37/90-97+粗体+重置；openShell 传原始 ANSI；终端区彩色显示替代删色单色；构建 18s；推送 c2f4941）
- [x] **A-HealthAI** 状态面板↔AI 联动 ✅（ServerStatus.healthSummary/hasWarning/cpuPercent/diskPercent；AiClient.HEALTH_PROMPT；ServerWorkspace 状态面板 CPU/磁盘>85% 红+「问 AI」按钮[告警高亮]→HealthAISheet chatStream 流式分析；对齐 apple Z6b；构建 17s；推送 15f597d）
- [x] **A-Secure** API Key 加密存储 ✅（security-crypto:1.1.0-alpha06；SettingsStore API Key 走 EncryptedSharedPreferences[MasterKey AES256_GCM]，对齐 apple Keychain；旧明文→加密迁移+失败回退；构建 1m12s 加 Tink 触发 multidex；推送 9be395f）
- [x] **A-AIActions** AI 快捷入口（命令解释+报错分析）✅（AiClient EXPLAIN_PROMPT/ERROR_PROMPT[对齐 apple commandExplain/errorAnalysis]；AIAssistantScreen.send 加 basePrompt 参数；输入栏上方「解释命令」(灯泡)「分析报错」(虫子)AssistChip 流式发送；文件图标改 Description；构建 17s 出 APK 30.8MB；推送 3b1c33a）

> **🎉🎉 安卓端与 apple 端智能运维护城河完全对齐**：环境感知 · 排障工作流 · 操作回滚 · 风险分级/脱敏 · 初始化模板 全部双端落地。安卓端从零数轮迭代建成功能完整的智能 SSH 运维工具（连接管理/真实SSH/交互PTY终端/状态采集/SFTP浏览/AI对话流式+环境感知/排障真执行/模板真执行/操作回滚），APK 30.8MB。

## 🤖 阶段 Z — 智能 SSH 运维能力（MVP 差异化核心）· 最高优先级

围绕「理解环境→规划→评估风险→确认→验证→回滚」闭环，建 MVP 差异化能力（已具备 SSH/SFTP/分组/密钥/危险拦截/确认/脚本/状态栏）：
- [x] **Z1** AI 命令解释 ✅（Core commandExplainPrompt[只讲解不执行：作用/参数/风险/安全等级，高危⚠️]；AppModel.explainCommand[本地 isDangerous 先判+解释 prompt 流式]；AIAgentView 输入栏「解释」按钮[questionmark.circle 警示色，不执行]；runAICompletion 支持 systemPrompt 覆盖；双端 build 通过；推送 1bceb26）
- [x] **Z2** AI 报错分析 ✅（Core errorAnalysisPrompt[含义/原因/修复 EXECUTE/验证，识别 502/permission denied/no space/端口占用/nginx/SSL 等]；AppModel.analyzeError；AIAgentView「分析报错」按钮[exclamationmark.magnifyingglass danger 色]；双端 build 通过；推送 54bacc8）
- [x] **Z3** 环境感知（护城河核心）✅（Core ServerProfile[os/distro/arch/user/isRoot/包管理器/services/aiSummary] + EnvDetector[detectCommand 复合探测 + parse 解析]；AppModel.serverProfile 注入 AI 系统提示；--env-detect-test 自测解析正确；swift package clean 后全量编译通过；推送 511fa9d。待会话接入真实探测[需真连服务器]）
- [x] **Z4** 场景化排障工作流 ✅（Core DiagnosticWorkflow+5 内置[网站打不开/磁盘清理/SSL/Nginx/Docker]+composeForAI；AppModel.runDiagnostic[注入诊断命令]+analyzeDiagnostic[输出→AI 总结]；AIAgentView「排障」Menu[stethoscope]；--diag-test 自测过；双端 build；推送 6054119。待 Z4b SSH exec 捕获输出后自动 AI 总结）
- [x] **Z5** 操作回滚 ✅（Core OpRollback[criticalPrefixes/isCriticalConfig/criticalTargets/backupCommand/sshAutoRollbackCommand]+OpTimelineEntry[rollbackCommand]；AppModel.opTimeline+injectWithBackup[runSnippet 改关键配置前自动 cp 备份+记时间线]+rollback；--rollback-test 全过；双端 build；推送 41625d3。待 Z5b：AI [EXECUTE] 执行路径也接 injectWithBackup + 时间线 UI）
- [x] **Z6** 服务器状态面板升级 ✅（Core: SystemInfo 扩展 disk/services/healthSummary/hasWarning/cpuSeen + probe/parse + --metrics-test 自测过；UI: ServerStatusShowcase 健康摘要条+CPU/内存/磁盘进度条+服务绿红点+负载/运行，渲染 21-server-status 验证[发现异常/磁盘90%/mysql停 清晰]；双端 build；推送 b37a0a5→f7a6fd2）

> **🎉🎉🎉 阶段 Z 全部完成（8/8）**：apple 端智能运维 Z1-Z8 Core+UI 全落地，android 端能力全对齐。Termind 智能 SSH 运维护城河双端成形。

- [x] **Z6b** 状态面板↔AI 排障联动 ✅（Core healthAnalysisPrompt；AppModel.diagnoseHealth[systemInfo.healthSummary→AI 健康分析]；StatusBarView 加磁盘进度条+「问 AI」按钮(hasWarning 时「异常·问 AI」danger 高亮)；双端 build；推送 6a7e4eb）——实现产品愿景的「面板发现异常→一键问 AI 怎么办」联动
- [x] **Z7** 命令风险分级 + 敏感输出脱敏 ✅（Core CommandRisk 四级[low/medium/high/critical]+riskLevel+label/colorHex/needsConfirm/icon；isDangerous 委托 riskLevel.needsConfirm 兼容；Redactor.redact 打码 password/token/sk-/Bearer/AKIA/私钥块；--risk-test 全过；双端 build；推送 78a1ff8。待 UI 用风险颜色标注 + 高危二次确认接入）
- [x] **Z8** 一键服务器初始化/部署模板 ✅（Core SetupTemplate+SetupStep+5 内置[Ubuntu Web 初始化 10 步/Docker/Node/静态站/LNMP]+previewText 执行前预览[步骤+命令+风险+预计影响]+risk 复用 CommandRisk；--template-test 过；双端 build；推送 eae6105。UI 入口接入待后续）

> **阶段 Z 进度 7/8**：Z1-Z5,Z7,Z8 ✅ 落地原生 Core+逻辑+自测；唯 **Z6 状态面板升级**（需更多 UI/真连）待做。智能运维 MVP 差异化核心基本成形。

### UI 接入打磨
- [x] **U-Z7** 快捷命令面板接入四级风险颜色 ✅（SnippetsView snippetRow 用 CommandRisk.riskLevel 替二元 isDangerous：图标+colorHex+风险徽章[注意/高风险/极高危]；Showcase+3 风险示例；渲染 08-snippets 验证四级色彩清晰；推送 f40e3ff）
- [x] **U-Z8** 初始化模板入口 + 预览确认 ✅（AppModel.runSetupTemplate[allCommands 注入+injectWithBackup 备份]；SnippetsView 工具栏「初始化模板」Menu 列 builtins→预览 sheet[ScrollView previewText]→「注入到终端」按风险 colorHex 着色确认；双端 build；推送 97fac56）
- [x] **U-Z4** 排障预览确认 ✅（AIAgentView「排障」Menu→previewWorkflow 预览 sheet[description+诊断命令列表]→「注入诊断命令」确认调 runDiagnostic；双端 build；推送 8fd1ea8）

**Z 阶段 UI 接入齐：风险颜色(U-Z7) + 模板入口(U-Z8) + 排障预览(U-Z4) ✅**



## 📦 原生重构 backlog（apple/ macOS·iOS 旗舰，按愿景重设计）

- [ ] **N1** apple/ 产品重构：从「终端」改为「SSH 运维工作台」——主界面=服务器列表(资产卡片) + 连接后工作区(终端+状态面板+AI 助手)，对齐 docs/PRODUCT.md 三层形态
- [x] **N2** SwiftUI 液态玻璃（iOS 26 风）✅（Platform.swift 加 .glassPanel()/.glassOverlay() 修饰器=主题色半透明叠 .ultraThinMaterial；侧栏/AI 面板/状态栏改用 glassPanel[终端正文不动]；Core+App swift build 通过；真实玻璃需运行 App[无 Xcode 约束]；推送 aee8551）
- [ ] **N2b** 玻璃扩展到设置/连接编辑/sheet 弹窗用 .glassOverlay + 主界面窗口背景透明化（NSWindow，需运行验证）
- [ ] **N3** 安卓原生新建：Kotlin + Jetpack Compose（android/），SSH 用 sshj/JSch，复用愿景设计
- [ ] 阶段 Z 的智能运维能力（命令解释/报错分析/环境感知/排障/回滚）逐项落到各原生端

> 历史阶段 A–V（终端时代）+ X（Electron 玻璃）+ Y（Capacitor）已随 Web 删除归档于 git 历史；
> 复用其中可移植的原生 Swift 成果（apple/ 的 SSH/终端/连接管理/AI 服务）。
- [ ] **X4+** 功能扩展（自行规划，符合智能终端定位）+ 性能优化（启动/渲染/内存）



## 平台策略

| 平台 | 技术栈 | 状态 |
|------|--------|------|
| macOS | SwiftUI 原生（`apple/`） | ✅ 可编译，持续打磨 |
| iOS / iPadOS | SwiftUI 原生（`apple/`） | ✅ 可编译，持续打磨 |
| Windows | Electron（`src/`） | ✅ 已有 |
| Linux | Electron（`src/`） | ✅ 已有 |
| Android | Capacitor 包裹 React UI（计划 `mobile/`） | ⏳ 规划中 |

原生 Apple 版为精品体验；Electron 覆盖三大桌面端；Android 复用 React 渲染层。

## 每轮流程（务必全部执行，详见 CLAUDE.md）

1. 取下方 Backlog 第一个未完成项。
2. 实现 → `cd apple/AITerminalCore && swift build` + `cd apple/App && swift build` 必须通过。
3. 改了界面 → 更新 `apple/App/Sources/DevTools/Showcase.swift` → `swift run Shots` 渲染 → Read 看图。
4. 更新本文件「迭代日志」一行 + 勾掉 Backlog。
5. **追加 `ITERATION_LOG.md` 详细条目**（轮次/内容/改动文件/验证）。
6. 必要时更新 `CLAUDE.md`。
7. 汇报 → `ScheduleWakeup` 排 600 秒后下一轮。

## 迭代日志（摘要；详细见 ITERATION_LOG.md）

- **R1** ✅ 终端配色/字体统一（One Dark 主题，Menlo 字体，前景/背景/光标）
- **R2** ✅ iOS 终端辅助键栏（Esc/Tab/^C^D^Z^L^R^U/方向键/常用符号，触感反馈）+ 会话 `sendBytes`/`reconnect`
- **R3** ✅ 连接中遮罩（毛玻璃 + 进度）+ 断开/出错重连横幅（`TerminalPane` 包裹，VM 记忆 lastCols/Rows，无参 `reconnect()`）
- **R4** ✅ 终端字号缩放 + 持久化（AppModel.terminalFontSize→UserDefaults，工具栏字号菜单，macOS ⌘+/⌘-/⌘0，更新时热应用到 TerminalView）
- **R4.5** ✅ 截图测试管线（`swift run Shots` 用 ImageRenderer 离屏渲染 PNG；`Sources/DevTools/` 高保真预览；产物存 `apple/screenshots/`；已视觉检视主界面/侧边栏/连接编辑/状态栏/AI/键栏，设计统一专业）
- **R5** ✅ 侧边栏连接搜索（搜索框按名称/主机/用户名实时过滤，带计数与清除按钮，无匹配提示；已渲染检视）
- **R6** ✅ AI 多 provider：新增 Anthropic Claude（默认 claude-opus-4-8，Messages API）+ 兼容 OpenAI；AIConfig 分别记住各 provider 的 Key/模型/地址；设置界面服务商切换（已渲染检视）
- **R7** ✅ 快捷命令片段面板：CommandSnippet 模型 + 8 条默认片段 + ConnectionStore 持久化（snippets.json）；工具栏入口 + 增删/恢复默认/点选注入当前会话（不自动回车，高危标红）（已渲染检视）
- **R8** ✅ 敏感字段改 Keychain：新增 KeychainStore（Security framework）；ConnectionStore 保存时把 密码/口令/私钥内容 存 Keychain（按连接 id），JSON 只留非敏感字段；加载时回填 + 旧明文 JSON 自动迁移；删除连接同步清 Keychain
- **R9** ✅ SFTP 文件浏览器：SSHTerminalSession 复用同连接开 Citadel SFTP（列目录/家目录/下载/上传）+ SFTPEntry 模型；FileBrowserView 面板（路径导航/进目录/下载经 fileExporter/上传经 fileImporter）；工具栏「文件」入口（仅 SSH 会话显示）（已渲染检视）
- **R10** ✅ 多主题切换：AppColorScheme 5 套配色（午夜/One Dark/Dracula/Solarized/Nord，含 UI+终端+16 ANSI）；Theme/TerminalTheme 改为读取全局 activeColorScheme；AppModel.themeID 持久化；设置里即时切换；终端经 representable update 热更新（已用 3 套主题渲染对比验证）
- **R12** ✅ 终端分屏：AppModel splitEnabled/secondaryID + toggleSplit（需≥2会话）；ContentView 加 SplitTerminals（macOS 并排 / iOS 横屏并排竖屏上下，各带 host+状态点小标题）；工具栏分屏按钮；关会话时自动维护分屏（已渲染检视）。注：原 R11 端口转发因 Citadel 无本地监听转发 API 挪后
- **R13** ✅ 会话恢复：AppModel 把打开的 SSH 会话连接 id 列表 + 激活连接 id 持久化（UserDefaults，activeSessionID didSet + open/close 时写）；启动 restoreSessions 按 id 在 connections 找到并重开标签、恢复激活项；仅激活标签的终端视图立即连接（其余切到时才连，不会失败刷屏）
- **R14** ✅ 终端搜索：用 SwiftTerm 内置 `findNext`/`findPrevious`（1.13.0 无 searchMatchSummary，故用 Bool 命中）；VM 持终端视图引用 + 搜索方法；TerminalSearchBar（输入即查/上一个/下一个/已定位·无匹配/关闭）；工具栏入口 + macOS ⌘F（已渲染检视，匹配行高亮）

## Backlog（按优先级，每 10 分钟取一项推进）

### 阶段 A — Apple 原生体验打磨
- [x] **R2** iOS 终端辅助键栏 ✅
- [x] **R3** 连接中遮罩 + 断开后「重连」按钮 ✅
- [x] **R4** 终端字号缩放 + 持久化 ✅
- [x] **R5** 侧边栏搜索框 ✅
- [x] **R6** AI 多 provider（Claude 默认 + OpenAI）✅
- [x] **R7** 快捷命令片段面板 ✅
- [x] **R8** 敏感字段改 Keychain 安全存储 ✅
- [x] **R9** SFTP 文件浏览器 ✅
- [x] **R10** 多主题切换 ✅
- [x] **R12** 终端分屏 / 多面板 ✅（两个会话并排/上下，工具栏切换）
- [x] **R13** 会话恢复（重启保留打开的 SSH 标签 + 激活项）✅
- [x] **R14** 终端搜索（SwiftTerm 内置 find，⌘F）✅
- [x] **R11**（曾挪后，已完成）本地端口转发 —— 详见阶段 B 末尾的 R11 条目（NIOPosix ServerBootstrap + GlueHandler，R26 又加固了跨 eventLoop 写安全）

### 阶段 B — 全端统一（阶段 A R1–R14 基本完成，仅 R11 端口转发待专门一轮）
- [x] **R15** Electron 版配色同步 ✅（CSS 变量 + 5 套 data-theme；xterm 主题热更新；设置主题下拉 + localStorage；webpack 通过）
- [x] **R16** Android Capacitor 脚手架 ✅（`mobile/` + 可运行 Web 壳，headless Chrome 验证）⚠️ 需本地 `npm install` + `cap add android`（Android SDK）
- [x] **R17** 移动端/Web SSH ✅（`relay/` WebSocket→SSH 中继[ws+ssh2] + `mobile/www/terminal.html` xterm 终端页；headless 验证）⚠️ relay 需本地 `npm install`，且仅自托管/可信网络（安全见 relay/README）
- [x] **R18** 统一连接配置格式 ✅（`docs/connection-format.md` 共享 schema；原生 + Electron 双向导入/导出 JSON，默认不含密码，去重合并；均构建+渲染验证）
- [x] **R19** 统一品牌/总览 ✅（ImageRenderer 生成 App 图标 1024 写入 AppIcon + Contents.json；根 README 重写为全端总览[平台矩阵/构建/功能/截图]；swift build 未破坏）

- [x] **R11** 本地端口转发 ✅（Core：NIOPosix ServerBootstrap 监听 127.0.0.1:localPort + GlueHandler 双向桥接到 Citadel directTCPIP；App：PortForwardView 面板[增删/开关/状态] + 工具栏入口；编译通过，运行态需真实 SSH 服务器实测）

**阶段 A（R1–R14）+ 阶段 B（R15–R19）+ R11 全部完成。**

### 阶段 C — 加固与进阶（持续迭代）
- [x] **R20** 主机密钥校验 TOFU ✅（KnownHostsStore[known_hosts.json] + TOFUHostKeyValidator[NIOSSHPublicKey SHA256 指纹]，替换 acceptAnything；首次信任记录、变化报「主机密钥已变化/可能 MITM」；设置加「清除已知主机密钥」；编译+渲染验证）
- [x] **R21** 导入 ~/.ssh/config ✅（SSHConfigParser 解析 Host/HostName/Port/User/IdentityFile，跳过通配，IdentityFile→privateKey 且展开 ~；设置加「从 ~/.ssh/config 导入」[macOS] 去重合并；运行时自测+构建+渲染验证）
- [x] **R22** 连接分组 / 文件夹 ✅（Connection 加可选 group[Optional 向后兼容]；连接编辑加「分组」框；侧边栏未分组 + 各组 📁 Section；搜索含组名；已渲染检视）
- [x] **R23** AI 流式输出 + 多轮上下文 ✅（AIService.completeStreaming 用 URLSession.bytes SSE：Anthropic content_block_delta/text_delta、OpenAI choices.delta.content；sendAIMessage 流式追加到占位 assistant 消息实时刷新，完成后解析 [EXECUTE]；上下文窗口取最近 20 条）
- [x] **R24** 跳板机 / bastion ✅（Connection 加可选 jumpHost/Port/Username/Password[Keychain]；SSHTerminalSession.connect 若 hasJump 先连跳板再 SSHClient.jump(to: SSHClientSettings)；连接编辑加跳板机区；编译+渲染验证，运行态需真实环境）
- [x] **R25** 全局代码审查 + 修复 ✅（4 agent 并行审查 SSH/AI/AppModel/VM；修了 4 处确有把握问题：①connect 重入/失败清理旧 client+jumpClient 防泄漏 ②startForward 失败关半开 remoteChannel ③closeSession 退出分屏时 secondaryID 置 nil ④TerminalSessionVM 保存并取消 connectTask + 会话身份校验，杜绝 disconnect/reconnect 时旧 Task 覆盖状态；Core+App 编译通过）

#### 审查暂缓项（确实存在但需运行态验证，不冒进改）
- [x] **R26** GlueHandler 跨 eventLoop 写安全加固 ✅（改存本端 Channel[Sendable]，writeFromPartner/closeFromPartner 经 channel.eventLoop.inEventLoop 判断 + execute 跳转，杜绝跨 loop 触碰 ChannelHandlerContext；编译通过，运行态需真实服务器实测）
- [x] **R27** AIService SSE 解析容错 + 失败日志 ✅（os.Logger[com.aiterminal/ai]；区分解码失败[记 debug]与正常非文本事件[静默跳过]；识别 Anthropic error/message_stop，labeled break；不改正常路径）

**阶段 C 全部完成（R20–R27）。** （注：R11 端口转发已在阶段 B 末尾完成，见上方 R11 ✅ 条目）

### 阶段 D — 体验进阶 / 全端对齐（持续迭代）
- [x] **R28** AI 流式「停止」按钮 ✅（AppModel.aiStreamTask + cancelAIStreaming：cancel→onTermination 取消网络，补「⏹ 已停止」且不注入命令；区分 CancellationError 不报 ⚠️；AIAgentView 生成中显红色停止键；已渲染检视）
- [x] **R29** known_hosts 管理 UI ✅（KnownHostsStore.all() 只读快照；KnownHostsView 列表[host→指纹]+滑动删除[forget]+全部清除+空态；设置「主机密钥」改为「管理已知主机」sheet 入口；已渲染检视）
- [x] **R30** 连接克隆 ✅（AppModel.cloneConnection：换新 UUID、name 加「副本」、含分组/跳板/敏感字段照搬并按新 id 写 Keychain，插到原连接之后；侧边栏 ConnectionRow 右键菜单加「复制」；编译通过，contextMenu 难静态渲染故未截图）
- [x] **R31** Electron 连接分组（对齐原生 R22）✅（savedConnections 加可选 group；抽屉编辑加「分组」框；侧边栏未分组 + 各组 📁 小标题分区渲染；保存/编辑回填带 group；R18 导入/导出 JSON 带 group；npm build 通过）
- [x] **R32** 原生 ConnectionPortability 带 group ✅（Item 加可选 group；export 写非空 groupName，parse 读回 Connection.group；docs 字段表补 group；`swift run Shots --portability-test` 往返自测：导出含 group 字段 + 生产→生产环境/无组→nil 正确）
- [x] **R33** Electron 主机密钥 TOFU ✅（main.js ssh2 加 hostVerifier：SHA256 指纹比对 known_hosts.json[userData]，首次记录放行、不一致拒绝并报「主机密钥已变化/可能 MITM」；补 ssh2 默认不校验的安全空白；node --check + npm build 通过，运行态需真实环境）

**阶段 D（R28–R33）完成。**

### 阶段 E — 体验进阶（持续迭代）
- [x] **E1** 连接「最近使用」时间戳 + 侧边栏排序 ✅（Connection 加可选 lastUsedAt[Optional 向后兼容，不参与跨端导出]；openSession 标记并存盘；SidebarView.sortedByRecent 组内按 lastUsedAt 倒序、nil 稳定在后；已渲染检视：数据库主机最近用→排到生产服务器前）
- [x] **E2** 终端配色自定义编辑器 ✅（AppColorScheme.makeCustom 由 背景/主文字/强调/光标 4 色派生整套[mix 插值出 surface/textSecondary]；CustomThemeColors 存 UserDefaults；AppModel themeID==custom 时应用 + themeRevision 令牌驱动终端热更新；设置加「自定义」选项 + 4 个 ColorPicker[Color↔hex via toHexString]；已渲染检视）
- [x] **E3** Electron known_hosts 管理 UI ✅（main.js 加 ipcMain.handle known-hosts-list/remove/clear 复用 R33 load/save；设置弹窗「已知主机」区列出 host→指纹 + 单删 + 全清 + 空态；CSS 样式；node --check + npm build 通过）

**阶段 E（E1–E3）完成。**

### 阶段 F — 进阶交互（持续迭代）
- [x] **F1** 连接就绪后自动运行启动命令 ✅（Connection 加 startupCommands[多行，参与跨端导出]+ startupCommandLines；ConnectionEditView 多行框；TerminalSessionVM shell 就绪后逐行 send+\n，重连重发；ConnectionPortability+docs 同步，`--portability-test` 往返通过；已渲染检视）
- [x] **F2** 终端右键复制/粘贴菜单 ✅（macOS：makeTerminalContextMenu 设 tv.menu——复制/粘贴/全选走 SwiftTerm 的 copy:/paste:/selectAll:[target=终端视图]，清屏 target=coordinator 发 Ctrl-L；SSH+本地均接入；iOS 留 TODO；编译通过，NSMenu 不可离屏渲染故未截图）
- [x] **F3** SFTP 拖拽上传 ✅（FileBrowserView .onDrop([.fileURL])：loadDataRepresentation→URL(dataRepresentation:)→依次 uploadFile 到当前目录；拖拽悬停虚线高亮 + 「松开上传到当前目录」胶囊；复用 sftpUpload；已渲染检视）

**阶段 F（F1–F3）完成。**

### 阶段 G — 进阶交互（持续迭代）
- [x] **G1** 终端分屏可拖拽调整比例 ✅（SplitTerminals 用 GeometryReader + @AppStorage split_ratio[0.2~0.8]；中间分隔条 DragGesture 调比例[dragStartRatio 基线 + delta/total]，macOS 悬停变 resize 光标；横向/竖向都支持；已渲染检视非等分+把手）
- [x] **G3** 命令片段面板搜索过滤 ✅（SnippetsView 顶部加搜索框[放大镜+TextField+清除]，按 title/command 小写 contains 过滤，无匹配提示；不破坏注入/增删/恢复默认；已渲染检视）
- [~] **G2** iOS 终端编辑菜单：SwiftTerm 的 iOS TerminalView 基于 UITextInput，长按已自带系统「拷贝/粘贴/全选」编辑菜单，无需额外实现；降级备注，如需自定义项再单列

### 阶段 H — 进阶交互（持续迭代）
- [x] **H1** AI 对话导出为 Markdown ✅（AppModel.exportAIConversationMarkdown：## 你/## AI 分段、[EXECUTE]→```bash 代码块、跳过 system；AIAgentView 标题栏导出按钮[空则禁用]经 fileExporter 存 TextFileDocument[.md UTType]；`--ai-md-test` 自测通过；已渲染检视）
- [x] **H2** 状态栏点击展开更多系统信息 ✅（StatusBarView 加 expanded，点击紧凑栏切换[chevron 指示 + 动画]；展开 LazyVGrid 显示 主机/运行时长/CPU+核数/内存 used·total·%/负载 1·5·15 分钟，只用 SystemInfo 已有字段；已渲染检视）
- [x] **H3** 本地终端 URL 点击打开 ✅（天然已支持：requestOpenLink 协议扩展默认实现即 NSWorkspace.open，LocalProcessTerminalView 自任 terminalDelegate 未覆写 → 本地点链接已可打开；仅补说明注释）

**阶段 H（H1–H3）完成。**

### 阶段 I — 自定义与配置（持续迭代）
- [x] **I1** AI 系统提示词可自定义 ✅（Core 重命名 defaultAgentSystemPrompt；AppModel @Published agentSystemPrompt[UserDefaults 持久化] + resetAgentSystemPrompt；sendAIMessage 用实例属性；SettingsView 加 TextEditor + 恢复默认 + [EXECUTE] 保留提醒；已渲染检视）
- [x] **I3** 命令片段支持分组 ✅（CommandSnippet 加可选 group[向后兼容] + groupName，默认 8 条按 文件/系统/网络/Git 分类；SnippetsView 未分组 + 各组 📁 Section，搜索含组名；新建表单加分组框；已渲染检视）
- [x] **I2** 连接级终端字号覆盖 ✅（Connection 加可选 fontSizeOverride[参与跨端导出+往返自测]；TerminalPane 用 connection.fontSizeOverride ?? 全局[本地 nil 回退]；ConnectionEditView 加字号框[8–32 夹值，空=nil]；ConnectionPortability+docs 同步；已渲染检视）

**阶段 I（I1–I3）完成。**

### 巩固轮（防回归）
- [x] **C-1** 巩固/防回归 ✅（全量构建 Core+App+Electron+main.js 通过；3 个运行时自测[ssh-config/portability/ai-md]输出正确；17 张截图全量渲染无 FAILED，抽查主界面/侧边栏/状态栏/片段分组无回归；清理 ROADMAP 中 R11 重复/矛盾条目，47 项 backlog 全部一致完成）

### 阶段 J — 进阶能力（持续迭代）
- [x] **J1** 连接健康检查 / 可达性 ✅（Core ReachabilityChecker[NWConnection 测 TCP 连通，不做 SSH 握手，LockedFlag 保证单次 resume + 超时]；AppModel reachability[UUID:ReachState] + checkReachability；SidebarView ConnectionRow trailing 绿 wifi/红 wifi.slash 指示 + 右键「测试可达性」；--reach-test 自测[闭合端口/空 host 均 false]；已渲染检视）
- [x] **J2** 终端会话输出录制 / 导出 ✅（TerminalSessionVM isRecording + recordingBuffer，SSH onOutput 处录制中才 append；recordedText 去 ANSI(CSI/OSC) UTF8 容错；ContentView RecordButton[仅 SSH]开/停切换 + 停止经 fileExporter 导出 .txt；编译通过，工具栏项不可离屏渲染故未截图）
- [x] **J4** AI 对话历史持久化 ✅（ConnectionStore loadAIMessages/saveAIMessages[ai_messages.json，空则删文件]；AppModel init 加载、sendAIMessage 立即存+defer 收尾存、clearAIMessages 存；`--ai-persist-test` 自测[保存→加载 2 条匹配、清空后 0]通过）
- [x] **J5** 批量刷新可达性 ✅（AppModel.checkAllReachability 遍历 connections 并发探测；SidebarView「SSH 连接」header 加刷新按钮[arrow.clockwise]；@Published reachability 自动驱动各行指示；已渲染检视）
- [ ] **J3** AI 工具调用（结构化 tool_use 替代 [EXECUTE] 文本协议）—— 评估：现 [EXECUTE] 文本协议工作良好且流式/注入流程围绕它构建，改造风险大、收益有限，长期暂缓

### 阶段 K — 易用性细节（持续迭代）
- [x] **K1** 连接编辑内联「测试连接」✅（ConnectionEditView TestResult{idle/testing/reachable/unreachable} + 测试按钮[host 非空]调 ReachabilityChecker.probe 就地显示绿「可达」/红「不可达」/灰「测试中」；host/port 改动重置 idle；已渲染检视）
- [x] **K2** 侧边栏「上次使用」相对时间 ✅（ConnectionRow.relativeTime[刚刚/N分钟前/N小时前/N天前/M月d日]；subtitle 下当 lastUsedAt!=nil 显示「上次使用 · …」灰色小字；已渲染检视）
- [x] **K3** AI 重新生成上一条回复 ✅（抽公共 runAICompletion[sendAIMessage/regenerateLast 共用]；regenerateLast 删最近 user 之后所有消息后重流式；AIAgentView 头部末条为 assistant && !processing 时显示 arrow.clockwise；已渲染检视）
- [x] **K4** AI 单条消息复制 ✅（MessageBubble contextMenu「复制」[原始 content]+ assistant 额外「复制纯文本」[strippedDisplayText]；copyToClipboard 跨平台 NSPasteboard/UIPasteboard + toast；编译通过，contextMenu 不可离屏渲染故未截图）

**阶段 K（K1–K4）完成。**

### 巩固轮 2 / 3
- [x] **C-2** 复查阶段 E–J 增量 ✅（基线全量构建+5 自测绿；修 2 处确有把握问题：①录制 buffer 加 5MB 上限保留最近输出防内存涨 ②TerminalPane 用导入字号时夹 8…32 防极端值；复查 ReachabilityChecker/AI 持久化/ANSI 正则/跨端往返均无虞；修后构建+自测无回归）
- [x] **C-3** 巩固/防回归 ✅（全量构建 Core+App+Electron+main.js 通过；5 自测[ssh-config/portability/ai-md/ai-persist/reach]全绿；17 张截图全量渲染无 FAILED，抽查 07-main-overview 合成图确认 K 阶段特性[可达性/刷新/上次使用/重新生成]全部正确集成无回归；ROADMAP 一致：57 项完成，仅 J3 暂缓）
- [x] **C-4** 巩固/防回归（L2 后）✅（全量构建全过；6 自测[+ai-conv]全绿，ai-md 经多对话计算属性仍正确输出；17 图无 FAILED，07-main-overview 确认 L 阶段特性[备注/会话切换标题]集成无回归；人脑走查 aiMessages get/set 全调用点正确、activeConversationID 始终有效、无静默丢写；无需修复）

### 阶段 L — 自定义与配置 2（持续迭代）
- [x] **L1** 连接备注 ✅（Connection 加可选 note + noteText[参与跨端导出+往返自测]；ConnectionEditView 加「备注（可选）」多行框；侧边栏 ConnectionRow note.text 图标 + 备注小字行 + .help tooltip；ConnectionPortability/docs 同步；已渲染检视）
- [x] **L3** 终端主题预览缩略图 ✅（ThemeThumbnail：圆角 bg 块 + 3 行前景/强调 Capsule「文字」+ 名称，纯色块可离屏渲染；设置配色区把强调色圆点换成缩略图横排[ScrollView]含自定义；选中描边高亮；已渲染检视）
- [x] **L2** AI 多对话会话切换 ✅（Core AIConversation 模型；ConnectionStore saveConversations/loadConversations[conversations.json]+ 旧 ai_messages.json 迁移；AppModel conversations + activeConversationID + 计算属性 aiMessages[现有流式逻辑不改]+ new/switch/delete；AIAgentView header 会话菜单；--ai-conv-test 自测[2→删1+迁移+持久化回归]全过；已渲染检视）

**阶段 L（L1–L3）完成。**

### 阶段 M — AI 对话进阶（持续迭代）
- [x] **M1** AI 对话重命名 + 时间戳 ✅（AIConversation 加可选 titleIsCustom/updatedAt[向后兼容]；aiMessages setter 不覆盖自定义标题 + 刷新 updatedAt；AppModel.renameConversation[空则回退自动]；AIAgentView 会话菜单加「重命名」+ alert TextField；--ai-conv-test 加断言：自定义标题保留+updatedAt 往返=true）
- [x] **M2** 会话菜单按 updatedAt 倒序 + 相对时间 ✅（relativeTime 抽成公共 Support/RelativeTime.string，SidebarView 委托复用；AIAgentView 会话 Menu 按 updatedAt 倒序[nil 排后稳定]，项标题拼「标题 · 相对时间」；01-sidebar 渲染确认无回归）
- [x] **M3** 导出全部对话为 Markdown ✅（AppModel.exportAllConversationsMarkdown：每会话「# 对话：标题」一节 + --- 分隔，抽公共 markdown(for:heading:) 供单/全部共用；AIAgentView 头部=导出当前、会话菜单加「导出全部对话」[文件名 ai-all-conversations]；--ai-md-all-test 验证含两会话+bash+分隔）

### 巩固轮 5（文档/外观刷新）
- [x] **C-5** 刷新根 README 功能清单 ✅（「✨ 功能」按实际能力重写归类：本地终端/SSH[跳板·TOFU·端口转发]/SFTP 拖拽/连接管理[分组·备注·可达·最近·克隆·字号·启动命令]/跨端互通/AI[流式停止重生成·多对话·导出·自定义提示词]/主题[5+自定义+预览]/终端体验；引用截图齐全；全量构建+7 自测全绿）

### 阶段 M 余项
- [x] **M4** 侧边栏搜索匹配备注 ✅（SidebarView.filtered 过滤条件加 `|| noteText.lowercased().contains(q)`；q 已 trim+lowercase；不破坏分组/排序）

**阶段 M（M1–M4）完成。**

### 阶段 N — 进阶分享/搜索（持续迭代）
- [x] **N1** 连接二维码分享 ✅（QRCode.image[CIQRCodeGenerator 跨平台 NS/UIImage]；ConnectionQRView sheet 把 ConnectionPortability.export[不含密码]编码为 QR，扫码端 importConnections 解析；侧边栏右键「分享二维码」+ AppModel.qrConnection + ContentView .sheet(item:)；QRShowcase 渲染验证二维码可扫）
- [x] **N2** AI 对话内搜索 ✅（AIAgentView header 放大镜切换搜索栏；displayedMessages 按 content 小写 contains 过滤当前会话，无匹配提示；搜索时不自动滚动；已渲染检视）
- [x] **N3** 复制连接配置 JSON 到剪贴板 ✅（抽公共 Support/Clipboard.copy[跨平台]，MessageBubble 复用；AppModel.copyConnectionConfig 导出非敏感 JSON→剪贴板+toast；侧边栏右键「复制配置」；编译通过）
- [ ] **N4** iPad 多窗口 / 分栏适配（需真机验证，暂缓）

### 巩固轮 6 / 7
- [x] **C-6** 巩固/防回归（N 阶段后）✅（全量构建 Core+App+Electron+main.js 通过；7 自测全绿；19 张截图全量渲染无 FAILED，抽查 18-qr[二维码可见]/19-ai-search[搜索态]/07-main-overview[AI header 搜索图标集成无回归]；ROADMAP 一致：70 项完成，仅 J3/N4 暂缓）
- [x] **C-7** 巩固/防回归（O 阶段后）✅（全量构建全过；7 自测全绿；19 图无 FAILED，抽查 01-sidebar[排序↕图标]/05-settings[主题缩略图+提示词预设]/07-main-overview[全特性集成无回归]；ROADMAP 一致：74 项完成，仅 J3/N4 暂缓）
- [x] **C-8** 巩固 + 文档校对 ✅（全量构建全过；7 自测全绿；19 图无 FAILED；文档校对：CLAUDE.md 补 7 个 --xxx-test 自测命令 + node --check；README 功能清单补 二维码扫码/复制配置/排序/AI 搜索/提示词预设；ROADMAP 一致 78 项完成、仅 J3/N4 暂缓；无代码问题）
- [x] **C-9** 巩固/防回归（Q 阶段后，覆盖 Electron 改动）✅（全量构建 App+main.js+Electron 全过；7 自测全绿；19 原生图无 FAILED；headless 渲染移动 Web 壳 /tmp/mobile.png 正常[SSH 列表+中继空状态+底栏]；ROADMAP 一致 83 项完成、仅 J3/N4 暂缓；无问题）
- [x] **C-10** 巩固/防回归（R 阶段后）✅（全量构建 App+main.js+Electron 全过；7 自测全绿；19 图无 FAILED，抽查 07-main-overview[侧边栏 SSH(3)+排序图标 / AI header 搜索图标 集成无回归，R 阶段改动均行为层不影响渲染]；ROADMAP 一致 89 项完成、仅 J3/N4 暂缓；无问题）
- [x] **C-11** 巩固/防回归（R6/R7 工具栏后）✅（全量构建 App+main.js+Electron 全过；7 自测全绿；19 图无 FAILED，抽查 07-main-overview 无回归[工具栏断开/重连为状态条件项，不影响合成渲染]；ROADMAP 一致 92 项完成、R1–R7 全勾、仅 J3/N4 暂缓；无问题）
- [x] **C-12** 巩固/防回归（S 阶段后）✅（全量构建 App+main.js+Electron 全过；7 自测全绿；19 图无 FAILED，抽查 03-ai-panel 无回归[S2/S3 复制项在会话下拉菜单内，不影响面板渲染]；ROADMAP 一致 96 项完成、S1–S3 全勾、仅 J3/N4 暂缓；无问题）
- [x] **C-13** 巩固/防回归（S4–S6 后）✅（全量构建 App+main.js+Electron 全过；7 自测全绿；19 图无 FAILED；node 验证 S6 高危判定 rm-rf/mkfs 命中、ls 不命中=true false true；ROADMAP 一致 100 项完成、S1–S6 全勾、仅 J3/N4 暂缓；无问题）

> 🎯 里程碑：已完成 100 项 backlog（阶段 A–S + 13 轮巩固），唯二 J3/N4 长期暂缓。

- [x] **C-14** 巩固/防回归（S 阶段后）✅（全量构建 App+main.js+Electron 全过；7 自测全绿；19 图无 FAILED；文档一致性修正：README 功能对照表把 Q3 备注/S1 克隆/Q4 复制配置 在 Electron 的支持从 — 改为 ✅[原表 Q2 时所写、未随后续对齐更新]，可达性/排序/连接级字号·启动命令 保持仅原生[与 S8 一致]；ROADMAP 一致 仅 J3/N4 暂缓）
- [x] **C-15** 巩固/防回归（T 阶段后）✅（全量构建 App+main.js+Electron 全过；7 自测全绿；20 图无 FAILED[T1 新增 20-ai-empty]，抽查 20-ai-empty[模型标识+›]/07-main-overview 无回归；20 张全量同步入 apple/screenshots；ROADMAP 一致 106 项完成、仅 J3/N4 暂缓；无问题）
- [x] **C-16** 巩固/防回归（T3/T4 后）✅（全量构建 App+main.js+Electron 全过；7 自测全绿；20 图无 FAILED，抽查 08-snippets[分组+片段图标，默认均安全命令故无危险三角，判定正确]/02-statusbar[备注项]；20 张同步入 apple/screenshots；ROADMAP 一致 109 项完成、T1–T4 全勾、仅 J3/N4 暂缓；无问题）
- [x] **C-17** 巩固/防回归（U 阶段后，覆盖 Electron 改动）✅（全量构建 App+main.js+Electron 全过；7 自测全绿；20 图无 FAILED；headless 渲染移动 Web 壳 /tmp/mobile.png 正常[101846 bytes 与上轮一致]；ROADMAP 一致 112 项完成、U1/U2 全勾、仅 J3/N4 暂缓；README 对照表无需改[U1/U2 为展示细化非新支持]；无问题）

- [x] **S7** Electron quickExecute 接入高危判定 ✅（isDangerousCommand+DANGEROUS_PATTERNS 提到模块级纯函数，parseAndExecuteCommands[S6] 与 quickExecute 共用；quickExecute 执行前加同样 confirm 拦截，统一所有 AI 执行入口防未来扩展漏拦；npm build 通过）
- [x] **S8** connection-format.md 字段完整性校对 ✅（校对发现 startupCommands/fontSizeOverride 仅原生 ConnectionPortability 导出识别，Electron connToPortable/importConnections 无这两字段[导入忽略]；文档两行标注「仅原生版」+ 加「端差异」说明[通用字段 vs 仅原生字段、Electron/移动导入忽略不报错]，与三端实现对齐）

**阶段 S（S1–S8）完成：Electron 对齐[克隆/高危拦截]、AI 复制四象限、标签 tooltip、截图刷新、格式文档校对。**

### 巩固轮 18（TCC 权限故障恢复后体检）
- [x] **C-18** 恢复后全面体检 ✅（macOS TCC 桌面权限故障[~/Desktop 整树 Operation not permitted]经用户授予「完全磁盘访问」恢复后：全量构建 App+main.js+Electron 全过；7 自测全绿；20 图无 FAILED；git status 工作区健康[修改项均 S/U/V 预期、未跟踪项与会话起点一致、无半截写坏文件]；ROADMAP 一致 115 项完成、V1/V2 全勾、仅 J3/N4 暂缓；无问题）

### 巩固轮 20
- [x] **C-20** 巩固（本轮诚实判定无高价值新项）✅（先验证最可能的 UX 缺口「侧边栏搜索无匹配提示」——发现已存在[SidebarView line 94-97「无匹配「search」的连接」]，不重复造；转做扎实巩固：全量构建 App+main.js+Electron 全过；7 自测全绿；20 图无 FAILED；git 工作区 12 项变更=会话起点 5 改+7 未跟踪、健康；三文档一致[ROADMAP 120 完成/J3·N4 暂缓、ITERATION_LOG 最新 W1]；无回归）

### 复查轮 W1（S/T/U/V 增量代码走查）
- [x] **W1** 人脑走查近期增量找真实 bug ✅（走查 ~10 处：Electron cloneConnection[...conn+新id+副本，正确]/connToPortable[字段正确]/isDangerousCommand 模块级两处引用[1105 parseAndExecute、1315 quickExecute 有效]/U1 ssh-header note[savedConnections.find 安全]/U2 模型标识[gpt-4 与实际 fetch 一致]；原生 S2/S3 复制菜单[守卫非空]/AIConfig.model[defaultModel 兜底]/exportAllConversationsMarkdown[空占位+菜单双保险]/StatusBarView 备注[本地 connection:nil 安全跳过]/V2 apiKey 条件[getter 安全、Theme.warning 存在]。**均正确，未发现真实 bug**；未做改动，不为凑改动制造无意义变更）

### 巩固轮 19（V 阶段后）
- [x] **C-19** 巩固/防回归（V 阶段后）✅（全量构建 App+main.js+Electron 全过；7 自测全绿；20 图无 FAILED；headless 渲染移动主壳 index.html /tmp/mobile.png 101846 bytes[与上轮一致、完好]；ROADMAP 一致 118 项完成、V1–V4 全勾、仅 J3/N4 暂缓；无问题）

### 阶段 V — 文档正确性维护（成熟期）
- [x] **V1** apple/README.md AI 描述校对 ✅（代码确认 AIConfig 默认 provider=.anthropic[claude-opus-4-8]、兼容 OpenAI；修正 apple/README 三处旧表述：L7「OpenAI 兼容接口」→「默认 Anthropic Claude，兼容 OpenAI」、L28「OpenAI 调用」→「Anthropic/OpenAI 调用」、L91「配置 OpenAI API Key」→「选择服务商[默认 Anthropic Claude，也支持 OpenAI]填 API Key」；未动代码 swift build 通过）
- [x] **V2** AI 空状态未配置 API Key 时提示 ✅（emptyHint 模型标识 Button 改为 if aiConfig.apiKey.isEmpty { 警告样式 exclamationmark.triangle.fill + 「未配置 {provider.displayName} API Key，点此设置」+ chevron，Theme.warning } else { 原 T1/T2 模型标识 }，两态点击均 showSettings=true，.help 按状态区分；编译通过 + 渲染 20 张无 FAILED。注：本项因 macOS TCC 桌面权限故障跨多轮受阻，用户授予「完全磁盘访问」后恢复完成）
- [x] **V3** mobile/relay README 校对 ✅（先 ls/cat 看实际：mobile/www 实有 index/styles/app + terminal.html/terminal.js/vendor[xterm.js]，relay 有 server.js+ws+ssh2；修正 mobile/README 两处滞后——结构块补全 www/ 的 terminal.html/terminal.js/vendor、「SSH 占位待 R17」改为「方案1 已落地：terminal.html 经 relay 的 SSH 终端」链向 relay/；relay/README 核对准确不动；未动代码 swift build 通过）
- [x] **V4** 移动 SSH 终端页 terminal.html headless 抽查 ✅（headless Chrome 渲染 /tmp/mobile-terminal.png：「SSH 终端」标题 + 中继地址 ws://localhost:8022/主机 host/端口/用户名/密码 输入 + 连接按钮[品牌色] + 「需先运行 relay/」提示，配色与主壳/原生/Electron 一致，页面完整加载无缺失 vendor、无坏布局；xterm 终端区连接后才出现符合预期；未覆盖已有 mobile/screenshot-terminal.png；未动代码 swift build 通过）

### 阶段 U — 继续全端对齐（成熟期）
- [x] **U1** Electron SSH header 显示连接备注 ✅（对齐原生 T3；ssh-info 在 connection-info 旁，用最稳的 savedConnections.find(c=>c.id===session.connectionId)?.note 取备注[不假设 session.config 带 note]，非空时显示「📝 note」[.connection-note 样式 muted 省略号 title]；npm build 通过）
- [x] **U2** Electron AI 欢迎区显示服务商/模型 ✅（调研：Electron AI 实际 fetch openai /v1/chat/completions、model:'gpt-4'[renderer line 1148 写死]；ai-welcome 底部加「当前：OpenAI · gpt-4」[Cpu 图标 + .ai-model-badge]，如实反映实际模型+注释来源；对齐原生 T1；npm build 通过）

### 阶段 T — 原生 UX 小标识（成熟期）
- [x] **T1** AI 面板显示当前服务商/模型 ✅（emptyHint 底部加「当前：{aiConfig.provider.displayName} · {aiConfig.model}」小字[cpu 图标，灰色 caption]；AIPanelShowcase 加空态[messages 空时渲染欢迎+示例+模型标识]，新增 20-ai-empty 截图验证；编译通过）
- [x] **T2** 模型标识可点击打开设置 ✅（T1 那行包进 Button[.plain] action model.showSettings=true，文案后加 chevron.right 提示可点 + .help；ContentView 已有 .sheet 弹 SettingsView；重渲染 20-ai-empty 确认「…claude-opus-4-8 ›」正常；编译通过）
- [x] **T3** SSH 状态栏显示连接备注 ✅（StatusBarView compactBar 在「状态」后，session.connection?.noteText 非空时加「备注」statusItem[note.text 图标]；本地会话无 connection 自动跳过；StatusBarShowcase 同步 mock，渲染 02-statusbar 验证；编译通过）
- [x] **T4** 命令片段高危标记 ✅（调研：SnippetsView 已具备高危视觉标记[exclamationmark.triangle.fill+danger 色，line 133-135]，如实记录不重复；按提示加 .help tooltip——高危片段「⚠️ 高危命令，注入后请仔细复核再执行：cmd」、普通片段显示完整命令[补行内 lineLimit(1) 截断]；编译通过）

### 阶段 O — 列表/输入打磨（持续迭代）
- [x] **O1** 侧边栏连接排序切换 ✅（ConnSortMode{recent/name/manual} + @AppStorage 持久化；sorted() 按模式排 ungrouped 与各组：recent→sortedByRecent、name→title localizedCaseInsensitive、manual→原序；「SSH 连接」header 加排序 Menu[当前项打勾]；已渲染检视）
- [x] **O2** AI 系统提示词预设模板 ✅（Core PromptPreset.all：默认/只读模式/详细解释/精简，各保留 [EXECUTE] 协议；SettingsView「AI 系统提示词」区加「套用预设模板」Menu 一键设 agentSystemPrompt[沿用 didSet 持久化]；不破坏恢复默认；已渲染检视）
- [x] **O3** 终端工具栏「清屏」按钮 ✅（TerminalSessionVM.clearScreen 经 terminalView.send Ctrl-L[SSH delegate→sendInput / 本地直达]；ContentView 工具栏有活动会话时加「清屏」[clear]，iOS 也可用补 F2 右键空白；编译通过）

**阶段 O（O1–O3）完成。**

### 阶段 Q — 全端对齐 / 文档（成熟期）
- [x] **Q1** Electron 连接保存 trim 对齐 ✅（handleDrawerSave 先解构再 trim host/username/name/group，用 trim 值校验非空 + 构建 updated/newConnection + 会话 config 用 trim host/username；对齐原生 P2/P3；npm build 通过）
- [x] **Q2** 平台能力对比表 ✅（README 加「功能对照」表：本地终端/SSH·私钥/跳板·端口转发/TOFU/SFTP/分组/备注·可达·排序/导入导出/二维码·复制/主题/分屏·搜索·录制/右键菜单/AI 各项 × 原生·Electron·移动 三列 ✅—标注，先核实 Electron 实有[私钥/TOFU/分组/JSON/主题/AI 基础]再填，不夸大）
- [x] **Q3** Electron 连接备注 ✅（对齐原生 L1：drawerConnectionConfig 初始/回填/新建带 note；抽屉表单「分组」下加「备注（可选）」；handleDrawerSave trim note + updated/new 带 note；侧栏连接行 host 下显示备注小字 + .session-note 样式；导入导出 JSON 带 note；npm build 通过）
- [x] **Q4** Electron 右键「复制配置」到剪贴板 ✅（抽 connToPortable(c,includeSecrets) helper 供 exportConnections 与 copyConnectionConfig 共用；copyConnectionConfig 单条→ai-terminal-connections JSON[不含密码]→navigator.clipboard.writeText+toast；右键菜单「编辑配置」下加「复制配置」[Copy 图标]；对齐原生 N3；npm build 通过）

**阶段 Q（Q1–Q4）完成：Electron 对齐 trim 健壮性 / 备注 / 复制配置 + 平台能力对比文档。**

### 阶段 R — 原生小优化（成熟期）
- [x] **R1** AI 空状态示例提示词点击直接发送 ✅（emptyHint 示例按钮原仅 `input=ex`，改为 `guard !aiProcessing; input=ex; send()` 复用公共 send()[清空+入消息+流式]，少一步更顺手；编译通过）
- [x] **R2** 侧边栏右键 连接/断开 一致性 ✅（「编辑」入口本已具备[右键+侧滑]；本轮按提示补真实改进：右键菜单按 status 条件显示——未连接「连接」，已连接/连接中「切到此会话」+「断开」；加 AppModel.disconnectSession(for:) 按连接找会话 closeSession；对齐 Electron 右键连接/断开；编译通过）
- [x] **R3** AI「清空对话」二次确认 ✅（垃圾桶按钮改为 showClearConfirm=true 弹 .confirmationDialog「清空当前对话？」[清空 destructive/取消 + 不可恢复说明]，空对话禁用；用 confirmationDialog 避免同视图多 alert 冲突，复用 clearAIMessages；编译通过）
- [x] **R4** 连接删除二次确认 ✅（ConnectionRow 加 showDeleteConfirm；右键删除 + 侧滑删除均改为 showDeleteConfirm=true，根视图挂 .confirmationDialog「删除连接「title」？」[删除 destructive/取消 + 不影响远程主机]，确认走 model.deleteConnection[Keychain 清理不绕过]；对齐 Electron confirm；编译通过）
- [x] **R5** AI「删除当前对话」二次确认 ✅（会话菜单「删除当前对话」改为 showDeleteConvConfirm=true 弹 .confirmationDialog[删除 destructive/取消 + 不可恢复说明]，确认走 model.deleteConversation[维护 activeConversationID+持久化]；多 confirmationDialog/alert 共存编译通过）

**破坏性操作二次确认一致性完成：清空对话(R3) / 删除连接(R4) / 删除对话(R5)。**

- [x] **R6** 终端工具栏「断开当前会话」按钮 ✅（调研：openSession 对已存在会话只切 active 不重连，但 TerminalPane 对 .disconnected/.error 显示「重新连接」遮罩[reconnect() 干净]→断开保留标签无坏状态；AppModel.disconnectActiveSession[仅断开活动非本地会话]；ContentView 工具栏活动 SSH 连接/连接中时加「断开」bolt.slash；断开后由 TerminalPane 提供重连入口；编译通过）
- [x] **R7** 终端工具栏对称「重连」按钮 ✅（R6「断开」if 后加 else if：活动 SSH 非本地且 .disconnected/.error 时显示「重连」bolt.fill 调 activeSession.reconnect()；与「断开」bolt.slash 互斥，工具栏连断对称；编译通过）

**工具栏连断对称完成：connected/connecting→断开(R6) / disconnected/error→重连(R7)。**

### 阶段 P — 细节打磨（成熟期，小步为主）
- [x] **P1** 侧边栏「SSH 连接」标题始终显示连接数 ✅（header 改为 connections 非空时显示 `(\(search.isEmpty ? connections.count : filtered.count))`，搜索时命中数、否则总数；已渲染检视）
- [x] **P2** 连接编辑保存校验 ✅（canSave[host/username 去空白后非空]禁用保存按钮[原 .isEmpty 未 trim 纯空格会漏]；save() guard canSave + 保存前 trim host/username 存干净值；编译通过）
- [x] **P3** 连接保存时 trim name/分组/备注 ✅（save() 保存前 trim name；group/note 去空白后空→nil，避免「生产 」与「生产」分裂及多余空格；编译通过）

### 阶段 S — 继续全端对齐 / 小优化（成熟期）
- [x] **S1** Electron 右键「克隆连接」✅（cloneConnection(conn)：{...conn[带 group/note 全字段], id:generateId(), name:+' 副本'}→setSavedConnections+localStorage+toast；右键菜单「编辑配置」后加「克隆连接」[Files 图标，区分「复制配置」]；对齐原生 cloneConnection；npm build 通过）
- [x] **S2** 原生 AI「复制当前对话」到剪贴板 ✅（会话 Menu「导出全部对话」前加「复制当前对话」[aiMessages 非空时显示]，调 Clipboard.copy(exportAIConversationMarkdown 文本)+toast「已复制当前对话」；复用导出文本无需另拼装；编译通过）
- [x] **S3** 原生 AI「复制全部对话」到剪贴板 ✅（会话 Menu 在「复制当前对话」后加「复制全部对话」[有非空会话时显示]，调 Clipboard.copy(exportAllConversationsMarkdown 文本)+toast；编译通过）

**AI 对话 复制/导出 × 当前/全部 四象限齐备：复制当前(S2) / 导出当前(H1 header) / 复制全部(S3) / 导出全部(M3)。**

- [x] **S4** 终端标签 tooltip 显示 user@host ✅（SessionTabsBar.sessionTab 加 .help(session.connection?.subtitle ?? (isLocal ? "本地终端" : title))，复用现成 Connection.subtitle[user@host:port]；macOS 悬停可见、iOS 无害；编译通过）
- [x] **S5** 刷新 apple/screenshots 全量截图 ✅（swift run Shots 全量渲染 19 张无 FAILED，与 apple/screenshots/ 现有 19 张同名一一对应，cp 全量覆盖同步到最新 UI；抽查 05-settings[主题缩略图+提示词预设]正常；未动代码 swift build 通过）
- [x] **S6** Electron AI 高危命令确认 ✅（调研：Electron parseAndExecuteCommands 自动执行 [EXECUTE] 命令前无任何代码级拦截，仅系统提示词口头要求，与 README「高危命令拦截」不符；加 isDangerousCommand[对齐原生 AIService.dangerousPatterns 子串匹配] + 执行前命中则 confirm 二次确认[取消跳过并记录]，只拦 AI 自动执行路径不扰手动；npm build 通过）

## 验证方式（本机无完整 Xcode）
- `cd apple/AITerminalCore && swift build` — 核心逻辑
- `cd apple/App && swift build` — App 的 macOS 源码（AppCheck 包）
- Electron：`npm run build`
