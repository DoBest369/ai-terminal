# Termind — 智能终端 / SSH + AI 工具 路线图

目标：做一个 **全平台覆盖、好用、好看** 的智能终端（**Termind** = Terminal + Mind）。

## 🏗️ 阶段 Y — 统一前端 · 多端封装（架构决策）· 进行中

**决策（用户授权自行定夺「重构前端/换框架/多端 mac·iOS·win·linux·安卓」）**：
- 工具链现状：本机有 Android SDK + Java 17 + Node，**无 Flutter/Rust、仅 CLT 无完整 Xcode**。
- **不换 Flutter**（需装 SDK + 从零重写上百轮，iOS/mac 仍卡 Xcode）。
- **采用「一套 React Web UI（已 iOS26 玻璃化）→ 多端封装」**：桌面 Electron（win/linux/mac，working）+ 移动 Capacitor（**安卓本机 SDK 齐全可真打 APK**；iOS 待 Xcode）。一套代码 5 端统一 UI，复用现有 SSH（桌面 node-pty / 移动 relay）。原生 SwiftUI（apple/）保留为 Apple 高端选项。
- [ ] **Y1** mobile Capacitor 接安卓：mobile 装依赖 + 配置 Termind + `cap add android`（用本机 Android SDK）+ gradle 构建验证 APK 能出
- [ ] **Y2** 统一 UI：把 React 前端抽成平台无关（SSH/AI/系统 经适配器：Electron IPC / 移动 relay·Capacitor 插件），移动端也加载同一套玻璃 UI（替换 mobile/www 旧壳）
- [ ] **Y3** 安卓端 SSH：经 relay（已实现）或 Capacitor 原生 SSH 插件，移动端跑通连接
- [ ] **Y4** iOS（Capacitor，待完整 Xcode）+ 全端统一玻璃 UI 打磨 + 性能优化

## 🎨 阶段 X — 设计大改版（iOS 26 液态玻璃风 + 持续优化）· Electron 端已完成

用户方向：界面颜色/设计迭代优化，**参考 iOS 26 最新 Liquid Glass（液态玻璃）设计风格**；功能自动扩展；性能优化。每轮择一推进，编译 + 截图验证。
- [x] **X0** 品牌重塑：命名 **Termind** + 全新图标（squircle+珊瑚红渐变+`>_`+AI 火花），Electron productName/icon/dock/侧栏接入，已提交推送公开仓库
- [x] **X1** Electron 液态玻璃 UI（侧栏）✅（main.js vibrancy:'under-window'+visualEffectState+mac 透明 bg；app.css body 透明、侧栏 color-mix 半透明+backdrop-filter blur34 saturate185+高光描边；截图验证磨砂玻璃透出桌面、功能完好；已推送 0bf3d13）
- [x] **X1b** 液态玻璃扩展 ✅（终端/SSH 头部、AI 面板、设置弹窗、连接抽屉、右键菜单 统一 color-mix 半透明+backdrop-filter；终端正文保持不透明保可读；index.html title 改 Termind[AXRaise 确认窗口标题]；截图验证功能完好；推送 a9c728b）
- [x] **X1c** 玻璃细节打磨 ✅（nav-item hover 微光+active 发光阴影；AI 气泡玻璃化+圆角 16+投影；滚动条细窄半透明 color-mix；AI 面板 40→55% 改善可读性；切 AI 面板截图验证透出桌面呈玻璃质感、可读 OK；推送 c63fde0）
- [ ] **X2** 原生 SwiftUI 液态玻璃：Theme 引入 .ultraThinMaterial / 半透明分层 / 精修 5 套主题
- [ ] **X3** 配色系统升级：更有层次的色板（深度/高光/玻璃叠加），全端一致
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
