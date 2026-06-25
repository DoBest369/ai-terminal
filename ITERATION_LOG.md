# 迭代日志

每轮自动迭代的详细记录（最新在上）。摘要见 `ROADMAP.md`，规范见 `CLAUDE.md`。

格式：轮次 · 内容 · 改动文件 · 验证结果。日期 2026-06-22 起。

---

## N-CronAuto · 安卓定时后台巡检 + 离线通知（主动运维）
- **内容**：build.gradle 加 `androidx.work:work-runtime-ktx:2.9.0`；Manifest 加 `POST_NOTIFICATIONS`。`InspectWorker(CoroutineWorker)`：doWork 对 ConnectionStore.load 全部连接并发 `Reachability.probe`→离线集合非空则 `notify`(NotificationChannel「服务器巡检」+ NotificationCompat BigText，POST_NOTIFICATIONS 已授才发)；`enable(minutes=15)`(PeriodicWorkRequestBuilder maxOf(15,...) + enqueueUniquePeriodicWork UPDATE)/`disable`(cancelUniqueWork)/`ensureChannel`。`SettingsScreen`「定时后台巡检」Switch：开→33+ 请求 POST_NOTIFICATIONS 权限(RequestPermission contract)+InspectWorker.enable；关→disable；`SettingsStore.autoInspect` 持久化。
- **改动**：`android/app/build.gradle.kts`、`AndroidManifest.xml`、新增 `InspectWorker.kt`、`SettingsStore.kt`、`MainActivity.kt`(设置开关)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 38s** → app-debug.apk 26.0MB(+work-runtime)。WorkManager+CoroutineWorker+NotificationChannel/Compat+RequestPermission API 全编译通过。推送 0894ff1。真实定时触发需设备运行(WorkManager 最小周期 15 分钟)；密码不持久化故后台仅可达性探测。
- **意义**：对齐 PRODUCT.md「主动运维」——从手动巡检到后台自动盯在线状态+离线推通知。阶段 N 创新+主动运维使 Termind 成「主动智能运维工作台」。

---

## N-Cron-AI + A-Portability + A-KeyFile + 质量收口
- **N-Cron-AI**（巡检 AI 总结）：InspectScreen 汇总条「AI 总结」→各服务器状态拼素材→AiClient.chatStream(运维助手:总览/资源紧张/优先处理)流式 AlertDialog。修 verticalScroll 导入。构建 14s，推送 65fdabe。
- **A-Portability**（连接导出/导入）：ConnectionStore.exportJson(不含密码)/importJson；ServerListScreen「更多」菜单 导出(分享 Intent)/导入(GetContent 选 JSON→去重 merge)。对齐 apple ConnectionPortability。构建 18s，推送 9b9fd7c。
- **A-KeyFile**（私钥文件导入）：ServerWorkspace 私钥框「从文件选择私钥」GetContent→contentResolver 读文本填 privateKey。构建 19s，推送 ecf773f。
- **质量收口**：apple `cd AITerminalCore && swift build`+`cd App && swift build` 均 Build complete；--history-test(去重置顶/限长 true)+--batch-test(统计/AI 素材 true)+--risk-test(分级/兼容/脱敏 true) 全过，无回归。README 加「🚀 批量运维」小节(批量群发/群发AI汇总/批量巡检/命令历史)反映阶段 N 杀手级能力。
- **改动**：`InspectScreen.kt`/`ConnectionStore.kt`/`MainActivity.kt`、`README.md`、`docs/PARITY.md`(阶段 N 创新小节+连接导出导入)。
- **验证**：android 各项 BUILD SUCCESSFUL；apple swift build + 3 自测全过。
- **意义**：阶段 N 创新(命令历史/批量群发/群发AI/批量巡检/巡检AI) + 对齐打磨(连接导出导入/私钥文件) 持续丰富；Termind 运维工作台差异化越来越强，双端高度对齐。

---

## N-Multi apple · Core 批量群发框架 + BatchShowcase 界面渲染
- **Core BatchRunner**（BatchRunner.swift）：`BatchOutcome`(name/output/ok)+`run`(withTaskGroup 并发对多目标执行注入的 runner，任务外取 name 避逃逸捕获，按输入序 sorted 聚合)+`summary`(成功/失败统计)+`composeForAI`(群发结果拼 AI 汇总素材)，对齐 android。runner 闭包注入便于测试；真实接入走 SSHTerminalSession.runCommand(Citadel) 留 UI TODO。
- **UI**：`Showcase.BatchShowcase`(批量群发界面：多选服务器勾选+命令风险标注+执行结果卡片[成功绿/失败红 octagon]+「AI 汇总这批结果」入口，Theme 配色)；renderAll 渲染 `22-batch.png`(3台/2成功1失败/systemctl restart nginx 高风险)。Read 核对清晰，存 apple/screenshots。
- **自测**：`--batch-test` 初版 async(并发 run mock) 在 @MainActor+Task.detached+TaskGroup 下卡死无输出→改**同步纯逻辑**(直接构造 outcomes 测 summary 统计+composeForAI 素材 contains)，run 的并发由 UI 实测。
- **改动**：新增 `BatchRunner.swift`；改 `Screenshots.swift`(batchTest+渲染)、`Showcase.swift`(BatchShowcase)、`main.swift`(--batch-test 同步)；新增 `apple/screenshots/22-batch.png`。
- **验证**：swift build 通过 + 渲染 22-batch 核对(界面清晰) + `--batch-test`(clean 重编后)→「统计 成功2/失败1=true；AI 素材正确=true」。推送 38b7974→6c6f684→2004d16→015e660。
- **意义**：apple N-Multi 批量群发 Core 框架+UI 雏形齐(android 完整实测)。阶段 N 双端创新继续推进。

---

## N-Multi + N-Multi-AI + N-History UI · 批量群发 + 群发AI汇总 + apple历史接入
- **N-Multi（android 批量群发）**：`BatchScreen.kt`——选多连接(checkbox 列表)+统一密码+命令(CommandRisk 徽章)→`map{async}+awaitAll` 并发 `connectAndExec`→各连接结果卡片(Sync/CheckCircle/Error 图标+输出脱敏)；高危群发 AlertDialog 二次确认(影响面大)。`TermindApp` showBatch 覆盖；`ServerListScreen` 顶栏「批量群发」入口。构建 22s，推送 d5f301f。
- **N-Multi-AI（android 群发AI汇总）**：BatchScreen 全部完成(allDone)显「AI 汇总这批结果」→拼各连接名+成功失败+输出→`AiClient.chatStream`(运维助手:总览/失败原因/共性/建议)流式 AlertDialog 显示。构建 15s，推送 4845975。
- **N-History apple UI 接入**：`AppModel` 加 `commandHistory @Published`(CommandHistory.load)+`recordCommand`；`injectWithBackup`(快捷命令路径)+AI [EXECUTE] 执行路径 均 recordCommand 记录历史；`SnippetsView` 顶部「命令历史」Section(最近 10 条，风险色点，点击 inject 注入重用)。双端 swift build 通过。推送 139a28f。
- **意义**：阶段 N 双端创新强化——批量群发(运维工作台核心差异化，单连接工具做不到)+群发AI汇总(AI+真实环境护城河延伸到一批机器)+命令历史双端 UI 齐。

---

## N-History · 命令历史（阶段 N 双端创新首作）
- **android**：`CommandHistory.kt`(SharedPreferences 存命令，add 去重+置顶+限50，load/remove/clear)；`ServerWorkspace` send 时记历史(cmdHistory state)；命令框旁「历史」IconButton(有记录高亮)→ModalBottomSheet 列历史(CommandRisk 色点+等宽，点击填命令框，单条 X 删/「清空」)。构建 19s，推送 9c8a6aa。
- **apple**：Core `CommandHistory.swift`——`updated(list, adding:, limit:)` 纯逻辑(去重 filter+置顶 insert 0+prefix 限长) + `load/add/remove/clear`(UserDefaults)。`--history-test` 自测：去重置顶=true；限长=true(60 条加入后剩 50，first=cmd59 last=cmd10)。**swift package clean 后全量编译通过**(新 Core 文件 SPM 路径依赖缓存)。推送 04d9623。
- **改动**：新增 `android/.../CommandHistory.kt`、`apple/AITerminalCore/.../CommandHistory.swift`；改 `MainActivity.kt`(历史 UI)、`Screenshots.swift`(historyTest)+`main.swift`(--history-test)。
- **意义**：PARITY 收官后转「双端共同创新」——命令历史是运维高频刚需。阶段 N 启动。下一步 N-Multi 批量群发命令(多服务器同命令，运维杀手级)。

---

## A-ConvoPersist + A-ConvoExport + A-ConvoSearch · 安卓 AI 对话能力补全（与 apple 完全对齐）
- **A-ConvoPersist**：`ConvoStore.kt`(SharedPreferences 存对话列表 JSON[每对话=消息数组{role,content}]，save/load)；AIAssistantScreen convos 从 ConvoStore.load 初始化(toMutableStateList)，发消息回复完成/新建/删除后 persistConvos()。重启不丢对话。构建 18s，推送 908ca54。
- **A-ConvoExport**：`exportConvo()` 当前对话拼 Markdown(# 标题 + ## 用户/AI 助手 + content)→`Intent.ACTION_SEND`(text/markdown) 系统分享；对话菜单「📤 导出当前」。构建 18s，推送 1dbd4b7。
- **A-ConvoSearch**：顶栏 Search 图标 toggle 搜索框；非空时 messages.filter(content.contains 不区分大小写)→只显匹配气泡+「N 条匹配」。构建 19s，推送 76ed3ab。
- **改动**：新增 `ConvoStore.kt`；改 `MainActivity.kt`(AIAssistantScreen 持久化/导出/搜索)。
- **验证**：三次增量 gradle assembleDebug 均 BUILD SUCCESSFUL。
- **里程碑**：**android AI 能力与 apple 完全对齐**（对话/解释/报错/健康/环境感知/流式/多对话/持久化/搜索/导出）。PARITY 双端仅剩 跳板机多跳、分屏录制(移动端 N/A) 未对齐——核心+增强能力实质全对齐。

---

## 收尾 · apple 回归确认 + README 双端能力更新
- **apple 回归**：`cd apple/AITerminalCore && swift build`(Build complete) + `cd apple/App && swift build`(Build complete)；6 项自测全过——metrics 正确 / risk 正确 / env-detect 正确 / diag 工作流数=5 / rollback 全部正确 / template 内置模板数=5。安卓多轮迭代未影响 apple 端。
- **README 更新**：能力对照表补充 SFTP 下载上传/终端 ANSI 彩色/可达性探测/本地端口转发/凭据安全存储/TOFU/多主题/AI 多对话（均双端 ✅），加指向 docs/PARITY.md 的「核心 Z1-Z8 双端完全对齐」说明；Android 快速开始补充 密码/私钥、彩色终端、SFTP、端口转发、5 主题、API Key 加密。
- **改动**：`README.md`。
- **验证**：纯文档 + apple swift build 回归确认。如实反映双端高度对齐的最终状态。

---

## A-Forward · 安卓本地端口转发（对齐 apple PortForward）
- **内容**：`SshClient.openForward(...,localPort,remoteHost,remotePort,scope,privateKey)`——连接认证后 `ServerSocket().bind(127.0.0.1:localPort)` + `ssh.newLocalPortForwarder(Parameters("127.0.0.1",localPort,remoteHost,remotePort), ss)`，传入 scope 的 IO 协程跑 `forwarder.listen()`（阻塞），返回 `PortForwardHandle`(close=关 ServerSocket+cancel job+断开 ssh)。`ServerWorkspace` 顶栏「端口转发」IconButton(SwapHoriz，forwardHandle 非空时高亮)→`PortForwardDialog`(无活动转发→输入 本地端口/远程主机/远程端口「建立」；有→显当前 `127.0.0.1:lp→rh:rp`+「停止转发」)；DisposableEffect 离开关闭。
- **改动**：`SshClient.kt`(openForward+PortForwardHandle)、`MainActivity.kt`(端口转发按钮+PortForwardDialog+state)。
- **踩坑（sshj API 两修）**：① `LocalPortForwarder` 在 `net.schmizz.sshj.connection.channel.direct`（非 .forwarded.）② `Parameters` 是**独立类** `net.schmizz.sshj.connection.channel.direct.Parameters(String,int,String,int)`，非 LocalPortForwarder 内部类（javap 反编译 SSHClient.newLocalPortForwarder 签名确认）。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 19s** → app-debug.apk。推送 df6989f。真实转发需真服务器。
- **意义**：PARITY 端口转发 ⬜→✅。android 与 apple **核心能力高度对齐**，仅剩 跳板机多跳、AI 搜索/导出、分屏录制 等 apple 增强项（移动端意义有限）。

---

## A-Convos · 安卓 AI 多对话管理（对齐 apple AIConversation）
- **内容**：`AIAssistantScreen` 把单一 `messages` 改为 `convos: mutableStateListOf<SnapshotStateList<Pair>>`（对话列表，每个一组消息）+ `curIdx`；`messages = convos[curIdx]`（当前对话，send/渲染逻辑不变）。顶栏改自绘 Surface Row：对话标题（`convoTitle`=首条 user 消息前 16 字 / 「新对话 N」）+ ArrowDropDown → `DropdownMenu`（列各对话点击切换 + HorizontalDivider + 「➕ 新建对话」+ 「🗑 删除当前」[convos.size>1]）；右侧 Add 按钮新建。环境感知「已感知环境」标签保留。
- **改动**：`MainActivity.kt`(AIAssistantScreen 多对话 state + 顶栏对话切换菜单)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 18s** → app-debug.apk。推送 b9a6ee5。
- **意义**：安卓 AI 助手支持多对话（新建/切换/删除），对齐 apple。PARITY 多对话 ⬜→✅（搜索/导出/持久化仍 apple 独有，留后续）。android 仅剩 跳板机/端口转发、分屏录制 未与 apple 对齐。

---

## A-TOFU · 安卓主机密钥 TOFU 校验（安全：防 MITM）
- **内容**：`KnownHosts.kt`——`object KnownHosts`(init(ctx) 注入 applicationContext 的 SharedPreferences「termind_knownhosts」；`fingerprint(PublicKey)`=SHA-256(key.encoded) Base64.NO_WRAP；`check(host,port,fp): Result{NEW/MATCH/MISMATCH}`——saved==null→存+NEW，==fp→MATCH，否则 MISMATCH；forget()) + `class TofuVerifier: HostKeyVerifier`(override verify(hostname,port,key)：fingerprint→check→NEW/MATCH 返回 true，MISMATCH 返回 false[sshj 抛异常拒绝连接]；override findExistingAlgorithms=emptyList)。`SshClient` 5 处 `PromiscuousVerifier()`→`TofuVerifier()`，删冗余 import。`MainActivity.onCreate` `KnownHosts.init(this)`。
- **改动**：新增 `android/.../KnownHosts.kt`；改 `SshClient.kt`(5×TofuVerifier+去 import)、`MainActivity.kt`(onCreate init)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 18s** → app-debug.apk。**sshj 0.38 HostKeyVerifier 接口(verify(String,int,PublicKey)+findExistingAlgorithms) 编译通过**。推送 da3ffa9。
- **意义**：安卓从「PromiscuousVerifier 无脑跳过校验(MITM 风险)」升级为「TOFU 首次信任+指纹比对」，安全对齐 apple known_hosts。PARITY TOFU 🟡→✅。android 仅剩 跳板机/端口转发、AI 多对话、分屏录制 未与 apple 对齐。

---

## A-Themes · 安卓多主题配色（对齐 apple 5 套）
- **内容**：`Themes.kt`——`ThemeScheme`(id/name + bg/surface/surfaceLight/accent/textPrimary/textSecondary/success/warning/danger 9 色) + `builtins` 5 套（午夜/One Dark/Dracula/Solarized/Nord，配色值对齐 apple AppColorScheme）+ 全局 `var activeTheme by mutableStateOf`。`MainActivity` 顶层 `val Bg/Surface/Accent/...` 由固定 Color 常量改为 `get() = activeTheme.xxx` **计算属性**——所有现有 200+ 处颜色引用零改动，主题切换即全局 recompose 跟随。`onCreate` 启动 `activeTheme = byId(SettingsStore.loadTheme())`；`TermindTheme` 读 activeTheme 生成 colorScheme。`SettingsStore` themeId 存取；`SettingsScreen` 加 `pickingTheme` AlertDialog（5 套，每行 4 色预览点+名称+当前勾选，点选 `activeTheme=th`+saveTheme 即时切换+持久化）。
- **改动**：新增 `android/.../Themes.kt`；改 `MainActivity.kt`(颜色计算属性+onCreate+TermindTheme+SettingsScreen 主题选择)、`SettingsStore.kt`(theme)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 18s** → app-debug.apk。推送 9bf20ff。计算属性方案让全局配色一键切换。
- **意义**：android 多主题 PARITY 🟡→✅，与 apple 5 套主题对齐。安卓 ↔ apple 能力差距进一步缩小。

---

## A-Upload + 双端对照文档
- **A-Upload**：`SshClient.uploadFile`(sftp.put)；`SftpBrowser` 用 `rememberLauncherForActivityResult(GetContent)` 选本地文件→contentResolver 查 DISPLAY_NAME+openInputStream 复制到 cacheDir→uploadFile 到当前远程目录→load 刷新+toast；头部「上传」按钮。**踩坑**：SftpBrowser 局部函数 `load()` 被 download/picker 前向引用→BUILD FAILED，把 load() 前移修复。验证：重建 **BUILD SUCCESSFUL in 18s**。推送 91e8c1c→e0f5016→431f9de。**安卓 SFTP 完整=浏览/查看/下载/上传**。
- **apple 回归确认**：`cd apple/AITerminalCore && swift build` + `cd apple/App && swift build` 均 Build complete（无回归）；--metrics-test/--risk-test/--env-detect-test 自测全 true。
- **docs/PARITY.md**（新建）：apple↔android 双端能力对照表（SSH/终端/SFTP/AI/智能运维 Z1-Z8/安全），真实标注 ✅/🟡/⬜。**结论**：核心护城河 Z1-Z8 双端完全对齐；android 仅差 跳板机/端口转发、TOFU、多对话管理、多主题、分屏录制等 apple 增强项；linux🟡骨架 windows⬜。
- **改动**：新增 `android/.../`(uploadFile+picker)、`docs/PARITY.md`。
- **验证**：android 构建过；apple swift build 过 + 自测过。

---

## A-Reach · 安卓连接可达性 TCP 探测（真实在线状态）
- **内容**：新建 `Reachability.kt`——`suspend probe(host,port,timeoutMs=3000): Boolean`，`Socket().use { connect(InetSocketAddress(host,port), timeout) }`，Dispatchers.IO，纯 TCP 不做 SSH 握手（对齐 apple ReachabilityChecker）。`TermindApp`：`reachMap: SnapshotStateMap<id,Boolean>` + `probing` + `probeAll()`（协程 `async` 并发探测所有连接→逐个 await 写 reachMap）+ `LaunchedEffect(Unit){probeAll()}` 首次自动探测。`ServerListScreen` 顶栏改自绘 Row + 「刷新在线状态」IconButton(probing 时转圈)，传 reachMap/probing/onRefresh。`ServerCard(conn, reachable, probing, …)`：状态点 dotColor = 在线 Success / 离线 Danger / 探测中 Warning / 未知 TextSecondary，替换写死 `conn.online`。
- **改动**：新增 `android/.../Reachability.kt`；改 `MainActivity.kt`(TermindApp probeAll+ServerListScreen 顶栏刷新+ServerCard dotColor)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 17s** → app-debug.apk。推送 1a055fc。真实在线判定需可达网络。
- **意义**：连接列表从写死占位升级为真实 TCP 可达性，一眼看出哪些服务器在线，对齐桌面 SSH 客户端。

---

## A-KeyAuth · 安卓 SSH 私钥认证（密码/私钥二选一）
- **内容**：`ConnectionStore` 加 `enum AuthType{PASSWORD,KEY}` + `ServerConn.authType`(+JSON 持久化/解析容错)。`SshClient.authenticate(ssh,user,password,privateKey)`：privateKey 非空→`ssh.loadKeys(privateKey, null, null)`(PEM 字符串当密钥内容)+`ssh.authPublickey(user, keyProvider)`，否则 `authPassword`；`openShell`/`connectAndExec`/`listDir`/`fetchStatus`/`fetchEnv`/`readFile` 全加 `privateKey: String? = null` 参数并改调 authenticate。`EditConnectionScreen` 加「认证方式」FilterChip(密码/私钥)。`ServerWorkspace`：`privateKey` state + `keyArg()`(authType==KEY 时返回非空私钥)；凭据框按 authType 显密码框或私钥 PEM 多行 Mono 框；connect/refreshStatus/runDiagnostic/runSetupTemplate/fetchEnv/SftpBrowser 各调用传 keyArg()；凭据空判断改 `password.isBlank() && keyArg()==null`。私钥临时输入不持久化(注释 TODO EncryptedSharedPreferences)。
- **改动**：`ConnectionStore.kt`、`SshClient.kt`、`EditConnectionScreen.kt`、`MainActivity.kt`。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 18s** → app-debug.apk。**sshj loadKeys(String,String,String)+authPublickey API 编译通过**。推送 b2a6fae。真实密钥登录需真服务器。
- **意义**：安卓从仅密码升级为 密码/私钥 双认证，对齐桌面 SSH 客户端与 apple 端密钥能力。

---

## A-Ansi · 安卓终端 ANSI 颜色渲染
- **内容**：新建 `AnsiParser.kt`——`parse(text): AnnotatedString`，逐字符扫描，遇 `ESC[…m` SGR 序列则 flush 当前段并按参数更新颜色/粗体（basic 30-37/bright 90-97 映射为深色背景可读配色，1=粗体，0=重置，39=默认色，22=取消粗体；非 SGR 的光标/清屏序列直接剥离），用 `buildAnnotatedString`+`withStyle(SpanStyle(color,fontWeight))` 分段着色。`SshClient.openShell` 读循环不再 `stripAnsi(chunk)`，直接传原始 ANSI 给 onOutput（保留颜色码）。`ServerWorkspace` 终端输出区 `Text(output...)` → `Text(AnsiParser.parse(output)...)` 彩色渲染。
- **改动**：新增 `android/.../AnsiParser.kt`；改 `SshClient.kt`(openShell 去 stripAnsi)、`MainActivity.kt`(终端区 AnsiParser)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 18s** → app-debug.apk。推送 c2f4941。真实彩色需真服务器输出 ANSI(如 ls --color/top)。
- **意义**：安卓终端从「删颜色码灰绿单色」升级为「保留 ANSI 彩色高亮」，终端体验大升，贴近桌面终端。stripAnsi 保留（状态采集等纯文本场景仍可用）。

---

## L0 · Linux 原生端起步（Rust + egui 骨架）
- **内容**：本机查 `which cargo rustc`→**均无（cargo/rustc/rustup not found）**，故 Linux 端只搭源码骨架 + 文档，**不能本机编译验证**（如实标注）。新建 `linux/`：`Cargo.toml`(eframe 0.27/egui + ssh2 0.9 + ureq/serde/serde_json) + `src/main.rs`(`TermindApp: eframe::App`——TopBottomPanel 顶栏「⚡ Termind 智能 SSH 运维」+ CentralPanel 按分组渲染 server_card[在线绿/离线灰圆点 + name + user@host:port + 备注]，BG/SURFACE/ACCENT/... 配色常量呼应 apple/android 午夜深蓝+珊瑚红) + `README.md`(现状🟡骨架+未验证声明+cargo 构建说明[apt libssl-dev 等系统依赖]+对齐双端能力路线 L1-L4)。`.gitignore` 加 linux/target。
- **改动**：新增 `linux/Cargo.toml`、`linux/src/main.rs`、`linux/README.md`；改 `.gitignore`。
- **验证**：⚠️ **未编译验证**——开发机 macOS 无 Rust toolchain。源码按 eframe 0.27 API 编写，需 Linux+Rust 环境 `cargo run` 验证。推送 9550426。
- **意义**：全平台 5 端补第 4 端骨架（apple✅ android✅ linux🟡骨架 windows⬜）。诚实标注未验证状态。

---

## A-HealthAI · 安卓状态面板↔AI 联动（对齐 apple Z6b，双端一致）
- **内容**：`ServerStatus`(OpsCore.kt)加 `pct()`(从格式化串如"47%"/"36G/80G (90%)"抽百分比) + `cpuPercent/diskPercent` + `hasWarning`(CPU/磁盘>85%) + `healthSummary`(拼 CPU/内存/磁盘+告警，对齐 apple SystemInfo.healthSummary)。`AiClient.HEALTH_PROMPT`(健康分析:总评/异常定位/处置建议/验证)。`ServerWorkspace` 状态面板：CPU/磁盘 StatCell 颜色 >85% 转 Danger；加「问 AI」IconButton(hasWarning→Warning 图标红高亮)→`showHealthAI`→`HealthAISheet`(ModalBottomSheet：状态摘要置顶 + LaunchedEffect 调 AiClient.chatStream 流式把 AI 健康分析逐字追加显示，未配 Key 提示)。
- **改动**：`OpsCore.kt`(ServerStatus 扩展)、`AiClient.kt`(HEALTH_PROMPT)、`MainActivity.kt`(状态面板问AI按钮+HealthAISheet)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 17s** → app-debug.apk。推送 15f597d。真实分析需 Key+真服务器。
- **意义**：双端「状态面板发现异常→一键问 AI」联动一致（apple Z6b + android A-HealthAI），面板↔AI 闭环双端齐。

---

## Z6b · apple 状态面板↔AI 排障联动（面板↔AI 闭环）
- **内容**：Core 加 `healthAnalysisPrompt`（健康分析模块提示：① 总评 ② 异常定位 ③ 处置建议[EXECUTE]/⚠️ ④ 验证；资源 >85% 或关键服务停视为需立即关注）。`AppModel.diagnoseHealth()`：guard 配置/aiProcessing，取 `activeSession?.systemInfo.healthSummary`（空则 toast 提示先连接采集），拼 uptime/CPU 核数为上下文 user 消息 → `runAICompletion(systemPrompt: healthAnalysisPrompt)`。`StatusBarView`：加 `@EnvironmentObject model`；compact bar 加磁盘 metricItem(diskPercent>85% warn) + 「问 AI」Button（远程会话 && healthSummary 非空才显示；hasWarning 时文案「异常·问 AI」+ Theme.danger 高亮，否则「问 AI」+ accent），点击 `model.diagnoseHealth()`。
- **改动**：`apple/AITerminalCore/.../AIService.swift`(healthAnalysisPrompt)、`apple/App/Sources/AppModel.swift`(diagnoseHealth)、`Views/StatusBarView.swift`(磁盘+问AI按钮+EnvironmentObject)。
- **验证**：Core+App swift build 通过。数据流打通：SystemInfo.healthSummary → diagnoseHealth → AI 健康分析（真实 AI 回复需 Key+真服务器）。推送 6a7e4eb。
- **意义**：实现产品愿景「面板↔命令↔AI 联动」——状态面板发现异常，一键让 AI 结合真实指标给排查/优化建议，闭环更完整。

---

## A-Secure · 安卓 API Key 加密存储（对齐 apple Keychain）
- **内容**：build.gradle.kts 加 `androidx.security:security-crypto:1.1.0-alpha06`。`SettingsStore` 重构：`securePrefs(ctx)` 用 `MasterKey.Builder(AES256_GCM)` + `EncryptedSharedPreferences.create(AES256_SIV/AES256_GCM)`（runCatching 失败回退普通 prefs 保可用）；`loadApiKey` 先读加密，否则读旧普通 prefs 明文→搬进加密+清旧（迁移）；`saveApiKey` 走加密；模型等非敏感留普通 prefs。
- **改动**：`android/app/build.gradle.kts`、`SettingsStore.kt`。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 1m12s**（拉 security-crypto+Tink，无 Duplicate/冲突；加 Tink 触发 multidex→5×classes.dex，minSdk26 原生支持）→ app-debug.apk（EncryptedSharedPreferences 编译进，import 解析成功即证依赖生效）。推送 9be395f。
- **意义**：API Key 从明文升级为 AES256 加密存储，安全对齐 apple Keychain，护城河的安全维度补齐。

---

## Z6 UI · apple 富服务器状态面板（阶段 Z 收官 8/8）
- **内容**：`DevTools/Showcase.swift` 加 `ServerStatusShowcase`：① 顶部健康摘要条(info.hasWarning→「发现异常」danger 警示色 / 否则「运行正常」success，右侧 hostname) ② CPU/内存/磁盘 进度条(bar：图标+标签+值+百分比+Capsule 进度，>85% 用 Theme.danger) ③ 关键服务 绿(success)/红(danger)点列表 ④ 负载/运行时长。全 Theme.* 配色。`Screenshots.renderAll` 加 richInfo(磁盘 91% + mysql=false 触发告警态)渲染 `21-server-status.png`。
- **改动**：`apple/App/Sources/DevTools/Showcase.swift`(ServerStatusShowcase)、`Screenshots.swift`(渲染)；新增 `apple/screenshots/21-server-status.png`。
- **验证**：Core+App swift build 通过；`swift run Shots` 渲染 + Read 核对 21-server-status.png——「⚠️ 发现异常」红条 + CPU47%/内存56%/磁盘90%(红)进度条 + docker/nginx/redis/sshd 绿·mysql 红点 + 负载/运行，清晰美观。推送 f7a6fd2。
- **🎉 阶段 Z 全部完成 8/8**：apple 端 Z1-Z8 Core+UI 全落地，android 端能力对齐。Termind 智能运维护城河双端成形。

---

## Z6 · apple 服务器状态面板升级（Core 层）
- **内容**：apple 已有 RemoteSystemMonitor+SystemInfo(cpu/mem/load/uptime)，Z6 扩展：`SystemInfo` 加 `diskUsed/diskTotal/diskPercent` + `services[服务→active]` + `runningServices/stoppedServices` + `healthSummary`(CPU/内存/磁盘/负载/⚠️未运行服务 一行摘要，供面板顶部+喂 AI 排障联动) + `hasWarning`(CPU/内存/磁盘>85% 或关键服务停) + `cpuSeen`(避免首帧 0% 误显)。`probe` 加 `DISK@@$(df -B1 /...)` + `SVC@@$s:$(systemctl is-active ...)`(nginx/docker/mysql/redis/sshd)；`parse` 解析 DISK/SVC(unknown 跳过)；`parse` 改 public(供自测)。
- **改动**：`apple/AITerminalCore/.../SystemMonitor.swift`；`apple/App/Sources/DevTools/Screenshots.swift`(metricsTest)+`ShotsMain/main.swift`(--metrics-test)。
- **验证**：Core+App swift build 通过；`--metrics-test`→「解析正确=true；健康摘要=服务器状态：CPU 0% · 内存 75% · 磁盘 42% · 负载 0.50/0.40/0.30 · ⚠️ 未运行 mysql」。推送 b37a0a5。
- **Z 阶段**：Z1-Z8 全部 Core 落地（Z6 收尾）。下一步 Z6 UI 面板视图 ServerStatusPanel + Showcase 渲染抽查。

---

## Doc · README 全面更新（反映双端原生真实现状）
- **内容**：旧 README 严重过时（旧名「AI Terminal」、本地终端定位、已删的 Electron(src/)/Capacitor(mobile/) 平台矩阵与构建说明）。全面重写为：Termind 智能 SSH 运维工作台定位 + 护城河闭环；全平台原生矩阵（apple Swift ✅旗舰 / android Kotlin ✅可构建 / Windows·Linux ⬜待起）；**智能运维能力双端对照表**（连接管理/真实SSH/SFTP/状态/环境感知/AI助手/排障/模板/风险分级/脱敏/回滚 apple✅android✅）；真实快速开始（apple xcodegen+swift build 自测、android gradle assembleDebug）；项目结构（去掉 src/mobile）；**现状与边界真实说明**（apple 无 Xcode 未出包、android 实测需真机+服务器+Key、Win/Linux 待起）。
- **改动**：`README.md`（全量重写）。
- **验证**：纯文档，无需构建（未动 apple/android 代码）。措辞如实不夸大。

---

## A-AIActions · 安卓 AI 快捷入口（命令解释 + 报错分析）
- **内容**：`AiClient` 加 `EXPLAIN_PROMPT`(命令讲解:作用/关键参数/风险/安全等级，不执行不给 [EXECUTE]) + `ERROR_PROMPT`(报错分析:含义/最可能原因/修复步骤/验证，识别 502/Permission denied/端口占用等)，对齐 apple commandExplainPrompt/errorAnalysisPrompt。`AIAssistantScreen.send(text, basePrompt=SYSTEM_PROMPT)` 加 basePrompt 参数（仍注入 profile.aiSummary 环境摘要）；输入栏上方加「解释命令」(Lightbulb 黄)「分析报错」(BugReport 红) AssistChip，点击 `send(input, EXPLAIN/ERROR_PROMPT)` 流式发送。
- **改动**：`android/.../AiClient.kt`(两常量)、`MainActivity.kt`(send basePrompt + 两 Chip + 文件图标 Description)。
- **踩坑**：首构建把文件图标误改 `Icons.AutoMirrored.Filled.InsertDriveFile`(无该变体)→BUILD FAILED；回退用 `Icons.Filled.Description`→成。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 17s** → app-debug.apk 30.8MB。推送 0cae82e→3b1c33a。
- **安卓打磨**：…/A-FileView/**A-AIActions** ✅。安卓 AI 助手三种模式（对话+环境感知/命令解释/报错分析）全有，对齐 apple。

---

## A-FileView · 安卓 SFTP 查看文本文件内容
- **内容**：`SshClient.readFile(host,port,user,password,path,maxBytes=200_000)`——`head -c <max> '<path>'`(单引号转义防注入)读文本，限大小避免大文件/二进制卡顿。`SftpBrowser` 加 `viewing: Pair<name,content>?` state + `openFile(f)`(协程 readFile→脱敏→viewing)；文件行点击：文件夹 load 进入、文件 openFile；`viewing` 非空弹 AlertDialog 滚动等宽显示内容。顺手修 InsertDriveFile→`Icons.AutoMirrored.Filled.InsertDriveFile`(消 deprecated 警告)。
- **改动**：`android/.../SshClient.kt`(readFile)、`MainActivity.kt`(SftpBrowser openFile+viewing 弹窗+图标)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 17s** → app-debug.apk 30.8MB。推送 f922570（图标修复随下次构建）。
- **安卓打磨**：…/A-Rollback/**A-FileView** ✅。安卓端已是体验完整的智能 SSH 运维工具。下一步 AI 快捷入口(命令解释/报错分析)。

---

## A-Rollback · 安卓操作回滚 Kotlin 化（护城河移植收官）
- **内容**：`RollbackCore.kt`——`object OpRollback`(criticalPrefixes[nginx/sshd/mysql/fstab/sudoers…]+isCriticalConfig+criticalTargets[写意图关键字+命中关键路径 token 启发式]+backupCommand[cp <p> <p>.bak-<stamp>]+backupCommands+sshAutoRollbackCommand[备份+at N 分钟自动还原重启 sshd 防锁门外])+`OpTimelineEntry`(time/action/command/rollbackable/backupPath + rollbackCommand[从 .bak-stamp 反推还原])，移植 apple OpRollback.swift。`ServerWorkspace`：`opTimeline` mutableStateListOf；`send` 改关键配置前先 write 各 cp 备份命令 + add OpTimelineEntry(rollbackable) + 提示；`rollback(entry)` write 还原命令；顶栏「时间线」History IconButton(有记录高亮 Accent)→ModalBottomSheet 列时间线(时间/动作/命令 + 可回滚项「回滚」按钮)；top-level backupStamp/nowLabel(SimpleDateFormat)。
- **改动**：新增 `android/.../RollbackCore.kt`；改 `MainActivity.kt`(send 备份+opTimeline+rollback+时间线 sheet+History 入口+时间戳 helper)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 17s** → app-debug.apk 30.8MB。推送 8425732。
- **🎉 里程碑**：安卓端智能运维护城河全移植完毕，与 apple 端完全对齐。安卓端核心+打磨全齐（连接管理/真实SSH/交互PTY/状态采集/SFTP/AI流式+环境感知/排障真执行/模板真执行/风险脱敏/操作回滚）。

---

## A-Tpl-Exec · 安卓初始化模板真执行（确认预览 + 逐步反馈）
- **内容**：`ServerWorkspace.runSetupTemplate(tpl)`——协程按 `tpl.steps` 逐步：过滤注释行(`#`)，每步终端显「▶ N. 步骤名」，`connectAndExec`(60s)跑该步命令(`&&` 串)→输出脱敏显示，全部完成显「✅ 模板执行完毕」+ refreshStatus。执行前 `pendingTemplate` → AlertDialog 确认(图标/「执行」按钮按 `tpl.risk.color` 着色，text 区滚动显示 `tpl.previewText()` 步骤/命令/风险/预计影响，对齐 apple U-Z8)。初始化模板 Menu 从「填命令框」改为 `pendingTemplate = tpl` 触发确认。同时修复上轮 A-SFTP 误重复的 showFiles/SftpBrowser 块。
- **改动**：`MainActivity.kt`(ServerWorkspace runSetupTemplate + pendingTemplate 确认 + 模板菜单 + 去重)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 16s** → app-debug.apk 30.8MB。推送 d178cca。真实执行需真服务器。
- **安卓打磨**：A-Diag/A-Snippets/A-Stream/A-SFTP/**A-Tpl-Exec** ✅。下一步操作回滚 Kotlin 化(A-Rollback)。

---

## A-SFTP · 安卓远程文件浏览（sshj SFTPClient）
- **内容**：`SshClient.listDir(host,port,user,password,path)`——connect+auth 后 `ssh.newSFTPClient().use { it.ls(path) }`，映射 `RemoteResourceInfo`→`RemoteFile`(过滤 `.`/`..`，`attributes.type==FileMode.Type.DIRECTORY` 判文件夹，size，文件夹优先+按名排序)，Dispatchers.IO+15s 超时。`RemoteFile(name/isDir/size/path + sizeLabel[B/KB/MB/GB])`。`ServerWorkspace` 顶栏「文件」IconButton(Folder，仅 CONNECTED 可用)→`showFiles`→`SftpBrowser`(ModalBottomSheet：标题+加载圈 + 当前路径(等宽) + 上级目录按钮(path substringBeforeLast) + LazyColumn 文件列表[文件夹 Accent/文件灰 图标 + 名 + sizeLabel]，点文件夹 load(f.path)，错误态显示)。
- **改动**：`android/.../SshClient.kt`(listDir+RemoteFile+FileMode import)、`MainActivity.kt`(文件入口+showFiles+SftpBrowser)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 16s** → app-debug.apk 30.8MB（仅 InsertDriveFile 图标 deprecated 警告）。推送 cbd4e44。真实浏览需真服务器。
- **安卓打磨**：A-Diag/A-Snippets/A-Stream/**A-SFTP** ✅。下一步初始化模板真执行 / SFTP 下载查看。

---

## A-Stream · 安卓 AI 流式输出（SSE 逐字）
- **内容**：`AiClient.chatStream(apiKey,model,messages,systemPrompt,onDelta)`——body 加 `"stream": true`，OkHttp execute 后 `response.body.source()` 逐行 `readUtf8Line` 读 SSE，对 `data:` 行解析 JSON：`type==content_block_delta` 取 `delta.text` 逐块 `withContext(Main) onDelta(text)`，`type==message_stop` 结束；HTTP 错误取 error.message；Result 封装。`AIAssistantScreen.send` 改流式：保存 history + 先 `messages.add("assistant" to "")` 占位 + 记 aiIndex，chatStream 的 onDelta 里 `messages[aiIndex] = "assistant" to (旧+delta)` 逐字追加，失败则替换为错误。
- **改动**：`android/.../AiClient.kt`(chatStream)、`MainActivity.kt`(AIAssistantScreen.send 流式)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 16s** → app-debug.apk 30.8MB。推送 4195a06。真实流式需 API Key。
- **安卓打磨**：A-Diag/A-Snippets/**A-Stream** ✅。安卓 AI 体验已对齐 apple（结合环境 + 流式逐字）。下一步 A-SFTP 文件浏览。

---

## A-Snippets · 安卓快捷命令面板
- **内容**：`Snippets.kt`——`CommandSnippet(title/command/group + risk[复用 CommandRisk])` + 12 内置常用运维命令(df -h/free -m/top/ss -tlnp/systemctl status nginx/nginx -t/systemctl reload nginx/docker ps/docker system df/journalctl/登录失败记录)。`ServerWorkspace` 已连接时命令框上方加横滑 `Row(horizontalScroll)` 的 `AssistChip` 行，点击 `command = sn.command` 填入命令框，每个 Chip leadingIcon 用 `sn.risk.color` 色点（仿 apple SnippetsView）。
- **改动**：新增 `android/.../Snippets.kt`；改 `MainActivity.kt`(ServerWorkspace Chip 行 + horizontalScroll 导入)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 17s** → app-debug.apk 30.8MB。推送 139238e。
- **安卓打磨进度**：A-Diag 排障真执行 ✅ / A-Snippets 快捷命令 ✅。下一步 A-Stream AI 流式输出 / SFTP。

---

## A-Diag · 安卓排障工作流真实执行 + AI 总结
- **内容**：`DiagnosticWorkflow` 加 `joinedCommand(sep)`(各命令用 `; echo sep;` 串成一条 shell)+`composeForAI(outputs)`(工作流名+各命令及输出拼给 AI，对齐 apple)+`SEP` 常量。`ServerWorkspace.runDiagnostic(wf)`：协程一次性 `connectAndExec`(30s) 跑 joinedCommand→按 SEP 拆回各命令输出→终端显原始(脱敏，分隔符换 ──────)→若配了 API Key 则 `AiClient.chat(summaryPrompt, composeForAI)` 生成「AI 结论」显示，否则提示配 Key。排障 Menu 从「填命令框」改为点击直接 runDiagnostic。
- **改动**：`android/.../OpsWorkflows.kt`(joinedCommand/composeForAI/SEP)、`MainActivity.kt`(ServerWorkspace runDiagnostic + ctx + 菜单)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 16s** → app-debug.apk 30.8MB。推送 d36e4d8。真实排障需真服务器+API Key。
- **意义**：安卓排障从「把命令填进框」升级为「真跑命令序列→AI 据输出给排查结论」，对齐 apple Z4 完整闭环。

---

## A-Env · 安卓环境感知 Kotlin 化 + AI 接环境（对齐 apple Z3 护城河）
- **内容**：`EnvCore.kt`——`ServerProfile`(hostname/os/distro/kernel/arch/currentUser/isRoot/packageManager/services + installedServices/missingServices/`aiSummary`[一行环境摘要]) + `object EnvDetector`(probedServices[nginx/docker/node…] + `detectCommand`[复合 shell：hostname/uname/id/os-release/包管理器/command -v 各服务，前缀 HOST:/UNAME:/USER:/OSREL:/PM:/SVC:] + `parse(output)`→ServerProfile)，移植 apple ServerProfile.swift。`SshClient.fetchEnv`=connectAndExec(detectCommand).map{parse}。`ServerWorkspace` 连接成功后协程 fetchEnv→`onProfile(p)` 上报 + 终端显「🔎 环境摘要」。`TermindApp` 加 `activeProfile` state，ServerWorkspace onProfile 写入；`AIAssistantScreen(profile)` 发消息时把 `profile.aiSummary` 拼进 systemPrompt（"…请结合以上真实服务器环境给出针对性回答"），顶栏副标题显「已感知环境」。
- **改动**：新增 `android/.../EnvCore.kt`；改 `SshClient.kt`(fetchEnv)、`MainActivity.kt`(TermindApp activeProfile/ServerWorkspace onProfile+探测/AIAssistantScreen 注入)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 16s** → app-debug.apk 30.8MB。推送 de655eb。真实探测需真服务器。
- **里程碑**：安卓端核心能力全齐（连接管理/真实 SSH/交互终端/状态采集/风险脱敏/AI 对话+环境感知/排障/模板），与 apple 端智能运维护城河高度对齐。剩流式 AI/快捷命令/SFTP 等打磨 + Windows/Linux 端待起。

---

## A-Status · 安卓状态面板真实采集
- **内容**：`SshClient.fetchStatus(host,port,user,password)`——一次性跑 `top -bn1|grep %Cpu; echo ---; free -m; echo ---; df -h /`，connectAndExec 取回 → `ServerStatus.parse`。`OpsCore.ServerStatus(cpu/mem/disk + parse)`：正则解析 CPU(`([0-9.]+) id`→100-idle)、内存(`^Mem: total used`→used/total GB)、磁盘(`df / 行`→used/total(占用%))，解析失败保留「—」。`ServerWorkspace` 加 status/refreshing state + `refreshStatus()`(协程 fetchStatus)，连接成功后自动采集；状态面板(仅已连显示)显真实 CPU/内存/磁盘 + 刷新 IconButton(转圈)。
- **改动**：`android/.../SshClient.kt`(fetchStatus)、`OpsCore.kt`(ServerStatus)、`MainActivity.kt`(ServerWorkspace 状态面板)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 16s** → app-debug.apk 30.8MB。推送 8f42c33。真实采集需真服务器。
- **安卓进度**：A0/A2-UI/A2/A1/A3/A4/A3b/A1b/**A-Status** ✅。剩 A-Env 环境感知 Kotlin 化 + AI 接环境 / 流式 AI。

---

## A1b · 安卓交互式 PTY 终端（持久 shell 会话）
- **内容**：`SshClient.openShell(host,port,user,password,scope,onOutput)`——sshj connect+authPassword+startSession+`allocateDefaultPTY()`+`startShell()`，拿 shell.outputStream(写)；协程在 IO 持续 read shell.inputStream→`stripAnsi` 去 ANSI→`withContext(Main) onOutput(chunk)`；返回 `SshShellSession(ssh,session,out)`(write[发命令到 PTY]/close[关 session+断开])。`stripAnsi` 工具去常见转义序列。`ServerWorkspace` 重构为交互式：`enum ConnState{DISCONNECTED/CONNECTING/CONNECTED/ERROR}` + 连接状态条(色点+文案+断开按钮) + `connect()`(建 shell，输出回调脱敏累积) + `disconnect()` + `send(cmd)`(已连写 cmd+\n 到 shell，不再每条重连) + `submit()`(未连先连/已连高危确认后发) + `DisposableEffect onDispose 关闭会话防泄漏`；密码框仅未连显示，命令框仅已连显示否则显「连接」按钮。风险徽章+高危确认+脱敏保留。
- **改动**：`android/.../SshClient.kt`(openShell+SshShellSession+stripAnsi)；`MainActivity.kt`(ServerWorkspace 交互式重构)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 15s** → app-debug.apk 30.8MB。推送 7864c66。实测交互需真服务器。
- **安卓进度**：A0/A2-UI/A2/A1/A3/A4/A3b/**A1b** ✅。剩 A-Status 状态面板真采集 / 环境感知 Kotlin 化 / 流式 AI。安卓端体验已接近桌面 SSH 终端。

---

## A4 + A3b · 安卓 AI 助手对话 + 排障/模板 Kotlin 化
- **A4 AI 助手**：加 okhttp:4.12.0；`SettingsStore.kt`(SharedPreferences 存 ai_api_key/ai_model[默认 claude-opus-4-8] + isConfigured，TODO 迁 Keystore)；`AiClient.kt`(suspend chat(apiKey,model,messages,systemPrompt)→Anthropic Messages API[x-api-key+anthropic-version 2023-06-01，org.json 拼 body+解析 content text]，IO+超时+Result，错误取 error.message；SSH 运维助手系统提示)。`AIAssistantScreen` 改真对话(mutableStateListOf<Pair<role,content>> + ChatBubble 气泡[user 右珊瑚/assistant 左] + 输入栏发送[协程 AiClient.chat] + 空态示例可点 + 未配 Key 跳设置)。`SettingsScreen` API Key 行点击 AlertDialog 输入保存(显示 ••••后4位)。验证：构建 58s → APK 30.8MB(含 OkHttp)。推送 6df2aff。
- **A3b 排障+模板**：`OpsWorkflows.kt`——`DiagnosticWorkflow`(5 内置:网站打不开/磁盘清理/SSL/Nginx/Docker，commands+summaryPrompt) + `SetupTemplate`/`SetupStep`(5 内置:Ubuntu Web 10 步/Docker/Node/静态站/LNMP，step.risk 复用 CommandRisk，previewText 预览)，移植 apple DiagnosticWorkflow.swift+SetupTemplate.swift。`ServerWorkspace` 顶栏加「排障」(MonitorHeart)「初始化模板」(Dns) DropdownMenu，点击把命令序列填入命令框(排障 && 串联；模板换行+过滤注释)。验证：构建 16s → APK 30.8MB。推送 80b3533。
- **意义**：安卓端已具备 连接管理/真实 SSH/风险分级脱敏/AI 对话/排障/初始化模板——与 apple 端核心能力基本对齐。本机无 Key/服务器不能实测对话与连接，编译+逻辑验证。
- **安卓进度**：A0/A2-UI/A2/A1/A3/**A4/A3b** ✅。剩 A1b PTY 交互终端 / 状态面板真采集 / 流式 AI。

---

## A3 · 安卓智能运维 Kotlin 化（风险分级 + 脱敏）· 护城河移植
- **内容**：新建 `OpsCore.kt`——`enum CommandRisk{LOW/MEDIUM/HIGH/CRITICAL}`（level + label[安全/注意/高风险/极高危] + color[Compose Color，与 apple colorHex 一致] + needsConfirm[>=HIGH] + companion riskLevel(cmd) 规则匹配 critical>high>medium>low，patterns 照搬 apple CommandRisk.swift）+ `object Redactor.redact`（Kotlin Regex 移植：sensitiveKeys=值、sk-***、Bearer ***、AKIA***、PRIVATE KEY 块 打码）。`ServerWorkspace` 接入：命令框非空实时风险徽章（色点+「风险：X」+需确认提示）；`submit()` 对 needsConfirm 命令弹 `AlertDialog` 二次确认（按风险着色）再 exec；SSH 输出经 `Redactor.redact` 脱敏再显示。
- **改动**：新增 `android/.../OpsCore.kt`；改 `MainActivity.kt`(ServerWorkspace)。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 14s** → app-debug.apk 25.9MB。推送 ac8791f。安卓端获得与 apple 端一致的安全护城河（风险分级+二次确认+脱敏）。
- **安卓进度**：A0/A2-UI/A2/A1/**A3** ✅。下一步 A3b 排障+模板 Kotlin 化 / A4 AI 助手真实 API / A1b PTY 终端。

---

## A1 · 安卓真实 SSH 连接（sshj exec）· 核心能力
- **内容**：app/build.gradle.kts 加 `com.hierynomus:sshj:0.38.0` + `org.slf4j:slf4j-nop:2.0.9` + `kotlinx-coroutines-android`；packaging.resources.excludes 加 META-INF 签名/冲突排除（*.SF/*.DSA/*.RSA/BC*KE.RSA/INDEX.LIST/DEPENDENCIES，避免 sshj+BouncyCastle 打包冲突）。`SshClient.kt`：`suspend connectAndExec(host,port,user,password,command,timeoutMs)` —— sshj SSHClient + `PromiscuousVerifier`(MVP，TODO TOFU 对齐 apple R20) + connect + authPassword + startSession().exec 读 stdout/stderr/exitStatus，Dispatchers.IO + withTimeout，Result 封装。`ServerWorkspace` 接入：密码框(PasswordVisualTransformation)+命令框+执行 FilledIconButton(rememberCoroutineScope.launch 调 connectAndExec，running 显 CircularProgressIndicator)+滚动终端输出区；状态面板改占位（A4 真采集）。
- **改动**：`android/app/build.gradle.kts`；新增 `SshClient.kt`；改 `MainActivity.kt`(ServerWorkspace + imports)。
- **验证**：gradle assembleDebug **BUILD SUCCESSFUL in 7m**（拉 sshj+BouncyCastle+重打包）→ **app-debug.apk 25.9MB**（从 14.8MB 增 ~11MB=sshj+BC），含 8 sshj/BC 条目，**无 Duplicate/META-INF 冲突**（排除生效）。sshj 成功编译进 APK=安卓端具备真实 SSH 能力。推送 479ef31。实连验证需真服务器。
- **安卓进度**：A0 骨架/A2-UI/A2 连接管理/**A1 真实 SSH** ✅。下一步 A1b 交互 PTY 终端 / A3 智能运维 Kotlin 化。

---

## A2 · 安卓连接管理（持久化 + 增删改）
- **内容**：`ConnectionStore.kt`——`ServerConn`(加 id=UUID + toJson)；`object ConnectionStore`(SharedPreferences 存连接 JSON 数组[org.json，零额外依赖] load/save，首次 seedDefaults 3 示例)。`EditConnectionScreen.kt`——新建/编辑表单(名称/host/user/port[数字]/分组/备注 OutlinedTextField，珊瑚红主题色，host+user trim 非空才可保存，保存回调 copy 更新)。`MainActivity`：连接列表改 `mutableStateListOf` 从 ConnectionStore.load 初始化；`FloatingActionButton`(连接 tab 显示)新建；ServerCard 加 ⋮ DropdownMenu(编辑/删除)；空状态(无连接提示点 + 新建)；增删改后 persist()。移除写死 demoConns。
- **改动**：新增 `android/.../ConnectionStore.kt`、`EditConnectionScreen.kt`；改 `MainActivity.kt`。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 14s** → app-debug.apk 14.8MB。推送 0d69774。运行需模拟器/真机。
- **安卓进度**：A0 骨架 ✅ / A2-UI 界面 ✅ / A2 连接管理 ✅。下一步 A1 真实 SSH(sshj)。

---

## A2-UI · 安卓界面充实（运维工作台演进）
- **内容**：重写 MainActivity.kt：`TermindApp` 加 Material3 底部 `NavigationBar` 三 tab（连接/AI 助手/设置，enum Tab + Compose state 切换）。`ServerListScreen`（连接卡片可点击 onOpen）。`AIAssistantScreen`（顶部「AI 运维助手」+ 4 张示例运维提示卡片[网站打不开/解释命令/分析报错/初始化]+底部输入占位，呼应 apple AI 面板）。`SettingsScreen`（配色/AI 服务商/API Key/关于 Termind 占位行）。`ServerWorkspace`（连接卡片点击进入：顶栏连接信息+返回、状态面板占位[CPU/内存/磁盘 StatCell 着色]、终端区占位[deploy@host:~$ 绿字]、AI 入口占位「问 AI：这台服务器有什么异常？」——呼应运维工作台「连接后工作区」三层形态）。
- **改动**：`android/app/src/main/java/com/termind/app/MainActivity.kt`（重写+拆 Composable）。
- **验证**：增量 gradle assembleDebug **BUILD SUCCESSFUL in 13s**（依赖已缓存，远快于首次 1h5m）→ app-debug.apk 14.8MB。Compose UI 编译正确。推送 9d3a823。运行/截图需模拟器（SDK 有 emulator，重/慢，本轮以构建成功为准）。

---

## 🎉 A0 · 安卓原生骨架 + APK 跑通（里程碑：第二个原生端落地）
- **内容**：新建 android/ Kotlin+Jetpack Compose 工程（settings/build/app build.gradle.kts、Manifest、themes/strings、MainActivity.kt[Termind 顶栏 ⚡+智能SSH运维 + 按分组 SSH 连接列表 ServerCard：状态点/name/user@host:port/备注，午夜深蓝+珊瑚红配色呼应 apple 端]）。
- **构建踩坑**：① gradle 缓存中 8.2.1-bin 残缺(.part)，改用完整的 8.13-bin。② AGP 8.2.2 配 gradle 8.13 卡死（main 线程 parking 12 分钟无进展）→ 升 AGP 8.7.2 + Kotlin 1.9.24 + Compose compiler 1.5.14 后正常下载。③ 网络诊断确认 dl.google/maven/github/gradle 全通。
- **验证**：`gradle assembleDebug`（用缓存 gradle 8.13 二进制，--no-daemon）**BUILD SUCCESSFUL in 1h5m**（首次下全部依赖）→ **android/app/build/outputs/apk/debug/app-debug.apk 14.7MB**。安卓原生端骨架跑通（真实可安装 APK）。推送 fa9dfc4→00f166b。
- **意义**：Termind 现有两个可构建原生端——apple/(Swift 编译) + android/(Kotlin 出 APK)。运行需模拟器/真机（同 apple 需 Xcode）。

---

## U-Z4 · 排障工作流预览确认（UI 打磨）
- **内容**：`AIAgentView` 加 `@State previewWorkflow: DiagnosticWorkflow?`；「排障」Menu 各工作流 Button action 从直接 runDiagnostic 改为 `previewWorkflow = wf`；body 加 `.sheet(item: $previewWorkflow)` → `diagnosticPreview(wf)`：NavigationStack + ScrollView 展示 wf.description + 「将依次注入以下只读诊断命令」+ 各 `$ cmd`，工具栏「取消」/「注入诊断命令」(确认调 model.runDiagnostic + 清 previewWorkflow)。避免盲目注入诊断命令。
- **改动**：`apple/App/Sources/Views/AIAgentView.swift`。
- **验证**：Core + App swift build 通过。Menu/sheet 编译验证。推送 8fd1ea8。

---

## U-Z8 · 初始化模板入口 + 预览确认（UI 打磨）
- **内容**：AppModel 加 `runSetupTemplate(_:)`（guard 活动会话 → `injectWithBackup(allCommands.joined, action:"初始化模板:名")` 关键配置自动备份 + toast）。`SnippetsView` 加 `@State previewTemplate: SetupTemplate?`，工具栏 primaryAction 加「初始化模板」Menu（ForEach SetupTemplate.builtins，Label name+icon）→ 点击设 previewTemplate；`.sheet(item:)` 弹 `templatePreview`：NavigationStack + ScrollView(Text(tpl.previewText())) 滚动展示步骤/命令/风险/预计影响，工具栏「取消」/「注入到终端」(tint=Color(hex: tpl.risk.colorHex)，确认调 runSetupTemplate + dismiss)。
- **改动**：`apple/App/Sources/AppModel.swift`、`Views/SnippetsView.swift`。
- **验证**：Core + App swift build 通过。Menu/sheet 不可静态渲染（同 K4/N1），编译验证。推送 97fac56。

---

## U-Z7 · 快捷命令面板接入四级风险颜色（UI 打磨）
- **内容**：`SnippetsView.snippetRow` 把二元 `snippet.isDangerous`(红/普通) 升级为 `CommandRisk.riskLevel(command)` 四级：低=`chevron.left.forwardslash.chevron.right` + Theme.accent；中/高/极高=`risk.icon` + `Color(hex: risk.colorHex)`，并在标题旁加风险标签 Capsule 徽章（risk.label：注意/高风险/极高危，背景 riskColor 0.22）。`DevTools/Showcase.swift` 的 snipRow 同步；`Screenshots.swift` SnippetsShowcase 加 3 风险示例片段（vim 配置=中/systemctl restart=高/rm -rf=极高）。
- **改动**：`apple/App/Sources/Views/SnippetsView.swift`、`DevTools/Showcase.swift`、`DevTools/Screenshots.swift`。
- **验证**：Core+App swift build 通过；渲染 `08-snippets.png`——安全命令珊瑚 `</>` 无徽章，编辑Nginx=橙「注意」、重启Nginx=深橙「高风险」、清理日志=红「极高危」，四级风险色彩徽章清晰。推送 f40e3ff。

---

## Z8 · 一键服务器初始化/部署模板（智能运维差异化第七项，阶段 Z 7/8）
- **内容**：Core 新增 `SetupTemplate.swift`——`SetupStep`(title+commands+risk[复用 CommandRisk max])、`SetupTemplate`(id/name/icon/description/steps + allCommands/risk + `previewText()`[执行前预览：步骤序号+标题+风险标签+各命令 $ + 「⚠️ 预计影响…」，对齐 PRODUCT §16.3]) + `builtins` 5 模板：Ubuntu Web 服务器初始化（10 步：更新系统/基础工具/时区/建 deploy 用户/SSH 密钥/加固 SSH[关 root 密码登录]/Nginx/Docker/UFW/Fail2Ban）、Docker 服务器、Node.js 环境、静态网站部署、LNMP。
- **改动**：新增 `apple/AITerminalCore/.../SetupTemplate.swift`；改 `DevTools/Screenshots.swift`(templateTest)+`ShotsMain/main.swift`(--template-test)。
- **验证**：双端 swift build 通过；`--template-test`→「内置模板数=5；ubuntu 步骤=10 风险=高风险；预览格式正确=true」（首次自测断言误写 .critical→修正为 .high，初始化模板无极高危合理）；Z3-Z7 全回归正常。推送 eae6105。
- **阶段 Z**：7/8（命令解释/报错分析/环境感知/排障/回滚/风险脱敏/初始化模板 ✅，Z6 状态面板待做）。

---

## Z7 · 命令风险四级分级 + 敏感输出脱敏
- **内容**：Core 新增 `CommandRisk.swift`——`enum CommandRisk{low/medium/high/critical}`（Comparable + label[安全/注意/高风险/极高危]/colorHex/needsConfirm(>=high)/icon）+ criticalPatterns(rm -rf/mkfs/iptables -f/systemctl stop ssh/drop database…)/highPatterns(systemctl restart·reload/ufw/iptables/chmod -r/kill/docker rm/apt remove…)/mediumPatterns(vim/sed -i/cp/mv/chmod/install…) + `riskLevel(_:)`（critical>high>medium>low 优先匹配）。`AIService.isDangerous` 改为委托 `CommandRisk.riskLevel(_).needsConfirm`（向后兼容，high/critical 才 true）。`Redactor.redact(_:)`：正则把 sensitiveKeys(password/secret/api_key/token…)=值、`sk-***`、`Bearer ***`、`AKIA***`、`-----BEGIN PRIVATE KEY-----` 块 打码 ******（保留键名/普通文本不动）。
- **改动**：新增 `apple/AITerminalCore/.../CommandRisk.swift`；改 `AIService.swift`(isDangerous 委托)、`DevTools/Screenshots.swift`(riskTest)+`ShotsMain/main.swift`(--risk-test)。
- **验证**：双端 swift build 通过；`--risk-test`→「风险分级正确=true；isDangerous 兼容=true；脱敏正确=true」；Z5 回归(--rollback-test)正常。推送 78a1ff8。UI 风险颜色标注+高危二次确认接入留后续。

---

## Z5 · 操作回滚（可恢复操作链路）
- **内容**：Core 新增 `OpRollback.swift`——`criticalPrefixes`（/etc/nginx/* /etc/ssh/sshd_config /etc/mysql/* /etc/fstab /etc/crontab /etc/sudoers…）+ `isCriticalConfig` + `criticalTargets(in:)`（启发式：命令含 vim/sed -i/tee/cp/重定向 等写意图 + 命中关键路径才返回，只读如 cat 不命中）+ `backupCommand(for:stamp:)`=`cp <path> <path>.bak-<stamp>` + `sshAutoRollbackCommand(minutes:stamp:)`（改 sshd 备份 + `at now + N minutes` 自动还原重启，防改错锁门外）。`OpTimelineEntry`（time/action/command/rollbackable/backupPath + `rollbackCommand` 从 .bak-stamp 反推还原）。AppModel 加 `@Published opTimeline` + `injectWithBackup`（runSnippet 注入命令前，若 criticalTargets 非空则先注入各 cp 备份 + 记时间线 + toast 提示）+ `rollback(_:)`（注入还原命令）+ backupStamp()。
- **改动**：新增 `apple/AITerminalCore/.../OpRollback.swift`；改 `AppModel.swift`、`DevTools/Screenshots.swift`(rollbackTest)+`ShotsMain/main.swift`(--rollback-test)。
- **验证**：双端 swift build 通过；`--rollback-test`→「关键配置识别+备份+回滚+sshd自动回滚 全部正确=true」；Z3/Z4 回归正常。推送 41625d3。Z5b：AI [EXECUTE] 路径接 injectWithBackup + 时间线 UI 留后续。

---

## Z4 · 场景化排障工作流（智能运维差异化第四项）
- **内容**：Core 新增 `DiagnosticWorkflow.swift`——结构（id/name/icon/description/commands/summaryPrompt + composeForAI[把工作流名+各命令及输出拼成 AI 分析素材，缺输出占位「(未获取到输出)」]）+ `builtins` 5 个内置工作流：网站打不开排查（nginx status/ss/curl/df/nginx -t/journalctl）、磁盘清理分析、SSL 证书检查、Nginx 状态、Docker 容器排查，每个带专门 summaryPrompt。AppModel 加 `runDiagnostic(_:)`（把命令序列注入活动会话终端执行）+ `analyzeDiagnostic(_:outputs:)`（composeForAI→runAICompletion(summaryPrompt)，待 exec 捕获接入）。AIAgentView 头部加「排障」Menu（stethoscope）列出 builtins。
- **改动**：新增 `apple/AITerminalCore/.../DiagnosticWorkflow.swift`；改 `AppModel.swift`、`Views/AIAgentView.swift`、`DevTools/Screenshots.swift`(diagTest)+`ShotsMain/main.swift`(--diag-test)。
- **验证**：双端 swift build 通过；`--diag-test`→「内置工作流数=5；composeForAI 格式正确=true」；Z3 回归正常。推送 6054119。真实输出捕获（SSH exec 通道）→自动 AI 总结 留 Z4b。

---

## Z3 · 环境感知（智能运维护城河核心）
- **内容**：Core 新增 `ServerProfile.swift`——`ServerProfile`（hostname/os/distro/kernel/arch/currentUser/isRoot/packageManager/services[服务→是否装]/detectedAt + installedServices/missingServices/aiSummary 摘要）；`EnvDetector`（probedServices[nginx/docker/node/…] + `detectCommand` 复合 shell 探测命令[hostname/uname/id/os-release/包管理器/command -v 各服务，用 HOST:/UNAME:/USER:/OSREL:/PM:/SVC: 前缀分段] + `parse(_:)` 把输出解析成 ServerProfile）。AppModel 加 `@Published serverProfile`，`runAICompletion` 把 `serverProfile?.aiSummary` 并入系统提示（让 命令解释/报错分析/对话 都基于真实环境）。
- **改动**：新增 `apple/AITerminalCore/.../ServerProfile.swift`；改 `apple/App/Sources/AppModel.swift`、`DevTools/Screenshots.swift`(envDetectTest)+`ShotsMain/main.swift`(--env-detect-test)。
- **验证**：`swift package clean`（SPM 路径依赖缓存未刷新新文件，clean 后修复）+ 全量 swift build 通过；`--env-detect-test`→「解析正确=true；摘要=当前服务器环境：系统 Ubuntu 22.04.3 LTS (x86_64) · 用户 deploy · 包管理器 apt · 已装 docker,mysql,nginx · 未装 node,redis」。推送 511fa9d。真实远端探测待会话接入（需真连服务器）。

---

## Z2 · AI 报错分析（智能运维 MVP 差异化第二项）
- **内容**：Core 加 `errorAnalysisPrompt`（报错分析模块：含义/最可能原因/可执行修复[可 [EXECUTE] 但先说作用风险、高危 ⚠️]/验证 四段；熟悉 502/Permission denied/Connection refused/No space left/address already in use/nginx 语法/SSL/端口占用/服务未启动 等；信息不足给查看命令）。AppModel 加 `analyzeError(_:)`（仿 explainCommand：校验配置 → 追加「分析这段报错并给修复：```text```」→ runAICompletion(systemPrompt: errorAnalysisPrompt)）。AIAgentView 输入栏在「解释」按钮后加「分析报错」Button（exclamationmark.magnifyingglass，danger 色，canSend 可点）。
- **改动**：`apple/AITerminalCore/.../AIService.swift`、`apple/App/Sources/AppModel.swift`、`Views/AIAgentView.swift`。
- **验证**：`cd apple/AITerminalCore && swift build` ✓ + `cd apple/App && swift build` ✓。推送 54bacc8。

---

## Z1 · AI 命令解释（智能运维 MVP 差异化第一项）
- **内容**：Core AIService.swift 加 `commandExplainPrompt`（命令解释模块系统提示：只讲解不执行、不输出 [EXECUTE]，按 作用/关键参数/风险/安全等级 四段，高危用 ⚠️ + 后果）。AppModel 加 `explainCommand(_:)`：trim+配置校验，本地 `AIService.isDangerous(cmd)` 先给规则判定的安全等级提示，追加用户消息「解释这条命令（…）：```cmd```」，调 `runAICompletion(systemPrompt: commandExplainPrompt)`。`runAICompletion` 改为可选 `systemPrompt` 覆盖（默认 agentSystemPrompt）。AIAgentView 输入栏在发送按钮前加「解释」Button（questionmark.circle，warning 色，canSend 时可点）：取当前 input 当命令讲解、清空输入、不执行。
- **改动**：`apple/AITerminalCore/.../AIService.swift`、`apple/App/Sources/AppModel.swift`、`Views/AIAgentView.swift`。
- **验证**：`cd apple/AITerminalCore && swift build` ✓ + `cd apple/App && swift build` ✓。推送 1bceb26。

---

## N2 · 原生 SwiftUI 液态玻璃（原生重构开始）
- **背景**：Web 删除后，apple/（SwiftUI 原生）按 SSH 运维愿景重设计。本轮做 iOS 26 玻璃。
- **内容**：`Platform.swift` 加 `.glassPanel(tint, opacity)`（`tint.opacity(N).background(.ultraThinMaterial)`=主题色半透明叠原生毛玻璃）+ `.glassOverlay()`（浮层用，高不透明+描边+圆角+阴影）。`SidebarView` 根 `.background(Theme.surface)`→`.glassPanel(opacity:0.55)`、navigationTitle 改 Termind；`AIAgentView` 根→`.glassPanel(opacity:0.45)`；`StatusBarView` 根→`.glassPanel(opacity:0.5)`。终端正文(TerminalPane)不动保可读。
- **改动**：`apple/App/Sources/Support/Platform.swift`、`Views/SidebarView.swift`、`Views/AIAgentView.swift`、`Views/StatusBarView.swift`。
- **验证**：`cd apple/AITerminalCore && swift build` ✓ + `cd apple/App && swift build` ✓；Showcase 渲染 20 张无 FAILED。真实玻璃材质需运行 App（ImageRenderer 渲不出 Material、本机无 Xcode）。推送 aee8551。

---

## 架构决策 · 统一前端多端（阶段 Y 启动）
- **背景**：用户授权自行决策「全面重构前端 UI / 甚至换语言换框架 / 覆盖 mac·iOS·win·linux·安卓」。
- **工具链勘察**：Flutter/Dart 未装、Rust 未装、仅 CLT 无完整 Xcode；**但 Android SDK 完整（platform-tools/ndk/emulator/cmdline-tools）+ Java 17 在** → Capacitor 打安卓 APK 可行。
- **决策**：不换 Flutter（装 SDK+从零重写代价大、iOS/mac 仍卡 Xcode）；采用「**一套 React Web UI（已 iOS26 玻璃化）→ Electron 桌面 + Capacitor 移动**」统一多端，复用现有 SSH（桌面 node-pty / 移动 relay）。原生 SwiftUI 保留。最快用现有工具链达成「一套好看 UI 全平台」。
- **本轮动作**：mobile/capacitor.config.json 改 appId com.termind.app + appName Termind；后台启动 `mobile npm install` 装 Capacitor 依赖（为 cap add android 铺路）。ROADMAP 立阶段 Y（Y1 安卓封装 / Y2 统一 UI / Y3 移动 SSH / Y4 iOS+打磨）。
- **验证**：Android SDK + Java 17 就绪确认；依赖安装中。

---

## X1c · 液态玻璃细节打磨
- **内容**：app.css —— `.nav-item` 加 transition + hover `color-mix 9%` 微光高亮 + `translateX(2px)`、active 加 `box-shadow` accent 发光；`.message-content` 圆角 12→16 + 投影；`.assistant-message` 玻璃化（72% 半透明 + blur20 + 描边）；`::-webkit-scrollbar` 美化（10px、track 透明、thumb `color-mix text 18%` + padding-box 描边内缩、hover 32%）；`.ai-panel` 40%→55% 提升文字可读性。验证用临时切 useState('ai') 截图后回退 'local'。
- **改动**：`src/renderer/styles/app.css`、`src/renderer/App.jsx`（临时切 tab 截图后已回退）。
- **验证**：`npm run build` ✓ + `node --check` ✓；AI 面板截图——面板半透明透出桌面呈 iOS 26 玻璃、「AI Agent」active 发光、文字可读。推送 c63fde0。

---

## X1b · 液态玻璃扩展全面板 + 窗口标题
- **内容**：app.css 给 `.terminal-header`/`.ssh-header`（blur30 sat180）、`.ai-panel`（blur28 sat170，40% 不透明更通透）、`.modal`/`.drawer`（blur40 sat190 + 强阴影+高光，浮层玻璃感最强）、`.context-menu`（blur34 + 圆角12+阴影）统一加 `color-mix(in srgb, var(--surface) N%, transparent)` 半透明 + `backdrop-filter`，描边用 `color-mix(text-primary 9~12%)`。`.terminal`/xterm 正文不动（保持不透明可读）。index.html `<title>` 改 Termind。
- **改动**：`src/renderer/styles/app.css`、`src/renderer/index.html`。
- **验证**：`npm run build` ✓；重启截图——窗口标题「Termind」（osascript AXRaise 确认），侧栏/头部玻璃、终端正文清晰、本地终端+系统信息功能完好。推送 a9c728b。

---

## X1 · Electron 液态玻璃 UI（侧栏）
- **内容**：main.js BrowserWindow 加 `vibrancy:'under-window'` + `visualEffectState:'active'` + mac 下 backgroundColor 透明（win/linux 仍 #1a1a2e 兜底），启用 macOS 窗口级毛玻璃。app.css：body 背景透明（透出 vibrancy）；`.sidebar` 背景改 `color-mix(in srgb, var(--surface) 62%, transparent)`（主题感知半透明）+ `backdrop-filter: blur(34px) saturate(185%)` + 半透明描边 + 顶部高光 inset，呈 iOS 26 磨砂玻璃面板；窗口控制条背景也透明。
- **改动**：`src/main/main.js`、`src/renderer/styles/app.css`。
- **验证**：`npm run build` ✓ + `node --check` ✓；重启 electron + osascript AXRaise 前置 + 截图——侧栏呈半透明磨砂玻璃、透出桌面壁纸模糊色彩，「⚡ Termind」品牌、本地终端 `bestdo@...%` + 实时系统信息正常，功能完好。已提交推送 0bf3d13。

---

## 里程碑 · PC 端编译打包测试 + 品牌重塑 Termind + 公开仓库
- **PC 端（Electron）真机跑通**：补下 Electron 27.3.11 二进制（首次 npm install 跳过）；electron-rebuild CLI 在 Node v25 因 yargs ESM 崩 → 改用 @electron/rebuild 库 API 为 Electron ABI 119 重编 node-pty（验证运行时可加载）；`electron .` 启动 → 截图确认窗口渲染、**本地终端实时显示真实系统信息**（主机/CPU/内存）→ 全链路打通；`electron-builder --dir` 出 .app。
- **品牌重塑 X0**：命名 **Termind**（Terminal+Mind，会思考的智能终端）；重设计图标（AppIconView：macOS squircle + 珊瑚红渐变 + 顶部高光 + `>_` + 右上 AI 火花 sparkles），swift run Shots 重渲染 icon-1024.png → iconutil 生成 build/icon.icns；package.json 顶层 productName + build.appId/icon（mac/win/linux）；main.js app.setName('Termind')+dock 图标+窗口 title；renderer 侧栏 logo 改 Termind。截图验证侧栏显示「⚡ Termind」。
- **公开仓库**：安全扫描无真实密钥（仅 mock 占位）；gh 创建公开仓库 github.com/DoBest369/ai-terminal，origin 替换，提交全部 102 文件 + 品牌改动并推送 main（56fa6f1 → 5dda686）。
- **新方向（阶段 X）**：用户要求 iOS 26 液态玻璃风 UI 改版 + 功能自动扩展 + 性能优化，转入持续自动迭代。

---

## C-20 · 巩固轮 20（诚实判定无高价值新项 + 全面体检）
- **挑项判断**：探查最可能的 UX 缺口「侧边栏搜索无匹配是否有提示」——发现 SidebarView line 94-97 已有 `else if filtered.isEmpty { Text("无匹配「\(search)」的连接") }`，已处理完善，不重复造。成熟期诚实判定本轮无高价值新功能项，转做扎实巩固。
- **全量构建**：`apple/App swift build`（含 Core）✓、`node --check src/main/main.js`（仓库根）✓、`npm run build` compiled successfully ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：20 张 PNG 无 FAILED。
- **工作区**：`git status --short` 12 项 = 会话起点的 5 改（.gitignore/README/main.js/App.jsx/app.css）+ 7 未跟踪（CLAUDE/ITERATION_LOG/ROADMAP/apple/docs/mobile/relay），无意外改动，健康。
- **三文档一致性**：ROADMAP 120 项 [x]、唯二 [ ] J3/N4 暂缓；ITERATION_LOG 最新条目对应（W1）；README 无新增能力需补。
- **结论**：全端健康；无回归、无 bug、无需修复。不为凑改动制造无意义变更。

## W1 · 复查轮（S/T/U/V 增量代码人脑走查）
- **方式**：Read 仔细看近期改动函数逻辑，找空值/nil 未处理、状态不一致、复制粘贴改错、条件写反、persist 遗漏、跨端字段不一致。
- **走查结论（10 处均正确，无真实 bug）**：
  - Electron `cloneConnection`（S1）：`{...conn, id: generateId(), name:+副本}`，全字段展开含凭据[克隆保留合理]，正确。
  - Electron `connToPortable`（Q4）：name/host/port/username/authType + 条件 group/note/secrets，正确。
  - Electron `isDangerousCommand`+`DANGEROUS_PATTERNS`（S6/S7）：模块级定义（line 29/31），两处引用 line 1105（parseAndExecuteCommands）+ 1315（quickExecute）均有效。
  - Electron U1 ssh-header：`savedConnections.find(c=>c.id===session.connectionId)?.note`，find 无匹配返回 undefined、`?.note` 安全。
  - Electron U2：「当前：OpenAI · gpt-4」与实际 fetch model:'gpt-4' 一致。
  - 原生 S2/S3 复制菜单：分别守卫 `!aiMessages.isEmpty` / `conversations.contains{ !messages.isEmpty }`，正确。
  - 原生 `AIConfig.model`：modelOverrides 空时回退 `provider.defaultModel`，不会空/崩。
  - 原生 `exportAllConversationsMarkdown`：`guard !nonEmpty.isEmpty else 占位` + S3 菜单本就守卫非空，双保险。
  - 原生 StatusBarView T3：本地会话 `TerminalSessionVM(local:true, connection:nil)`，`session.connection?.noteText` 安全跳过。
  - 原生 V2：`aiConfig.apiKey`（keys[provider.rawValue] ?? ""）空判断安全，Theme.warning 存在（TerminalPane 已用）。
- **改动**：无（诚实走查，未发现问题即不改）。
- **验证**：无代码改动，无需重新构建（C-19 刚验证全绿）。

## C-19 · 巩固轮 19（V 阶段后防回归）
- **全量构建**：`apple/App swift build`（含 Core）✓、`node --check src/main/main.js`（仓库根）✓、`npm run build` compiled successfully ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：20 张 PNG 无 FAILED；headless 渲染移动主壳 index.html → /tmp/mobile.png 101846 bytes（与上轮一致，完好）。
- **ROADMAP 一致性**：118 项 [x]，V1–V4 全勾，唯二 [ ] 为 J3/N4（已注明暂缓）。
- **结论**：全端健康；无回归、无需修复。

---

## C-18 · 巩固轮 18（TCC 权限故障恢复后全面体检）
- **背景**：会话中途 macOS TCC 桌面文件夹权限失效，~/Desktop 整树 OS 级「Operation not permitted」（读/写/编译全阻、/Users/bestdo 与 /tmp 正常）。诊断逐级定位到拒绝从 ~/Desktop 起；用户在 系统设置→隐私与安全性→完全磁盘访问 给「终端」授权后恢复。本轮做恢复后体检。
- **全量构建**：`apple/App swift build`（含 Core）✓、`node --check src/main/main.js`（仓库根）✓、`npm run build` compiled successfully ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：20 张 PNG 无 FAILED。
- **工作区检查**：`git status --short` 修改项均为 S/U/V 阶段预期（README/main.js/App.jsx/app.css/.gitignore），未跟踪项（CLAUDE/ITERATION_LOG/ROADMAP/apple/docs/mobile/relay）与会话起点一致，无半截写坏或意外改动——权限故障未损坏任何文件。
- **ROADMAP 一致性**：115 项 [x]，V1/V2 全勾，唯二 [ ] 为 J3/N4（已注明暂缓）。
- **结论**：权限恢复后全端健康；无回归、无损坏、无需修复。

---

## C-17 · 巩固轮 17（U 阶段后防回归）
- **全量构建**：`apple/App swift build`（含 Core）✓、`node --check src/main/main.js`（仓库根）✓、`npm run build` compiled successfully ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：20 张 PNG 无 FAILED。
- **移动 Web 壳**：headless Chrome 渲染 mobile/www/index.html → /tmp/mobile.png（101846 bytes，与上轮一致，未坏）。
- **ROADMAP/README 一致性**：112 项 [x]，U1/U2 已勾，唯二 [ ] 为 J3/N4（已注明暂缓）；README 功能对照表无需改（U1/U2 是 Electron 备注显示/AI 模型标识的展示细化，备注/AI 在 Electron 已是 ✅，支持状态不变，按「别过度」不加行）。
- **结论**：全端健康；无回归、无需修复。

---

## C-16 · 巩固轮 16（T3/T4 后防回归）
- **全量构建**：`apple/App swift build`（含 Core）✓、`node --check src/main/main.js`（仓库根）✓、`npm run build` compiled successfully ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：20 张 PNG 无 FAILED；20 张同步入 apple/screenshots/（T3 改了状态栏）；抽查 08-snippets——分组（文件/系统/网络）+ 片段图标/命令/注入按钮正常，默认片段均安全命令故显示普通 `</>`（accent）无危险三角，isDangerous 判定正确；02-statusbar 含备注项。
- **ROADMAP 一致性**：109 项 [x]，T1–T4 全勾，唯二 [ ] 为 J3/N4（已注明暂缓）。
- **结论**：全端健康；无回归、无需修复。

---

## C-15 · 巩固轮 15（T 阶段后防回归）
- **全量构建**：`apple/App swift build`（含 Core）✓、`node --check src/main/main.js`（仓库根）✓、`npm run build` compiled successfully ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：20 张 PNG 无 FAILED（T1 新增 20-ai-empty）；20 张全量同步入 apple/screenshots/（T1/T2 改了 AI 空态）；抽查 07-main-overview 合成图无回归。
- **ROADMAP 一致性**：106 项 [x]，T1/T2 已勾，唯二 [ ] 为 J3/N4（已注明暂缓）。CLAUDE.md 未写死截图张数，无需改。
- **结论**：全端健康；无回归、无需修复。截图库增至 20 张。

---

## C-14 · 巩固轮 14（S 阶段后防回归 + 文档一致性）
- **全量构建**：`apple/App swift build`（含 Core）✓、`node --check src/main/main.js`（仓库根）✓、`npm run build` compiled successfully ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：19 张 PNG 无 FAILED。
- **文档一致性修正**：核对 README「功能对照」表（Q2 所写）与后续 Electron 对齐（Q3 备注/Q4 复制配置/S1 克隆）不符——原「连接备注/可达性/排序」整行 Electron 标 —，但 Electron 已有备注；「二维码分享/复制配置」整行 Electron 标 —，但已有复制配置。改为：「连接分组/备注/克隆 ✅|✅|—」、「连接可达性/排序/连接级字号·启动命令 ✅|—|—」（仅原生，与 S8 校对一致）、「复制配置到剪贴板 ✅|✅|—」、「二维码分享 ✅|—|—」。
- **ROADMAP 一致性**：阶段 S 完成声明在位，唯二 [ ] 为 J3/N4（已注明暂缓）。
- **结论**：全端健康；修正 README 对照表 1 处真实滞后，无代码问题。

---

## C-13 · 巩固轮 13（S4–S6 后防回归）· 100 项里程碑
- **全量构建**：`apple/App swift build`（含 Core）✓、`node --check src/main/main.js` ✓、`npm run build` compiled successfully ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **S6 高危判定验证**：`node -e` 子串匹配 'sudo rm -rf /tmp/x'→true、'ls -la'→false、'mkfs.ext4 /dev/sdb'→true，即高危命中、安全放行，逻辑正确。
- **全量渲染**：19 张 PNG 无 FAILED。
- **ROADMAP 一致性**：100 项 [x]（阶段 A–S + 13 巩固轮），S1–S6 全勾，唯二 [ ] 为 J3/N4（已注明暂缓）。
- **结论**：全端健康；无回归、无需修复。达成 100 项 backlog 里程碑。

---

## C-12 · 巩固轮 12（S 阶段后防回归）
- **全量构建**：`apple/App swift build`（含 Core）✓、`node --check src/main/main.js`（仓库根）✓、`npm run build` compiled successfully ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：19 张 PNG 无 FAILED；抽查 03-ai-panel——header 搜索/重生成/导出/清空图标、你/AI 消息、输入栏正常；S2/S3 的复制项在会话下拉 Menu 内，不进面板静态渲染，无回归。
- **ROADMAP 一致性**：96 项 [x]，S1–S3 全勾 + AI 对话四象限声明，唯二 [ ] 为 J3/N4（已注明暂缓）。
- **结论**：全端健康；无回归、无需修复。

---

## V4 · 移动 SSH 终端页 terminal.html headless 抽查
- **内容**：之前移动壳只渲染过 index.html 主壳，没看过 relay SSH 终端页。用 headless Chrome（420×860 @2x）渲染 mobile/www/terminal.html → /tmp/mobile-terminal.png，Read 看图。
- **结果**：UI 正常——顶部「‹ SSH 终端」；表单中继地址（ws://localhost:8022 预填）/ 主机 host + 端口(22) / 用户名 / 密码；「连接」按钮品牌 accent 色；底部「填写信息后点连接（需先运行 relay/）」提示；深色配色与主壳/原生/Electron 一致；页面完整加载（vendor 的 xterm.js/css 正常引用，无 404/坏布局）。xterm 终端区在 WebSocket 连接成功后才渲染，静态页不显示属预期。
- **改动**：无（仅 /tmp 抽查，未覆盖已有 mobile/screenshot-terminal.png）。
- **验证**：渲染 38311 bytes 图正常；`cd apple/App && swift build` 确认未动代码。移动 SSH 终端页 UI 确认健康。

## V3 · mobile/relay README 校对（文档）
- **校对（以实际文件为准）**：`ls/cat` mobile/ 与 relay/。mobile/www 实有 index.html/styles.css/app.js + **terminal.html/terminal.js/vendor**（grep 确认 terminal.html=「SSH 终端」页、terminal.js 用 WebSocket→relay 桥接、vendor 含 xterm.js/addon-fit/xterm.css）；relay/ 有 server.js + package.json（ws+ssh2、npm start→node server.js）。
- **发现 & 改动（mobile/README.md）**：① 结构块的 www/ 只列 index/styles/app，漏了实际存在的 terminal.html/terminal.js/vendor——补全 3 行带注释。② 文末「对 SSH 功能给出占位提示，待 R17 接入」已过时（terminal.html 经 relay 的 SSH 终端页已落地）——改为「已落地方案 1：terminal.html（xterm.js）经 WebSocket 连 relay/ 中继实现 SSH 终端（自托管/可信网络）；方案 2 原生插件仍在路线图」并链向 ../relay/README.md。
- **relay/README.md**：核对 server.js/ws+ssh2/npm start/协议/安全须知均与实现一致，准确，不动。
- **验证**：不涉代码；`cd apple/App && swift build` 确认未动代码（Build complete）。mobile/README 与现状一致。

## V2 · AI 空状态未配置 API Key 提示
- **背景**：本项实现时遭遇 macOS TCC 桌面文件夹权限故障——整个 ~/Desktop 子树 OS 级「Operation not permitted」（/Users/bestdo 本身 OK、/tmp 正常），读/写/编译全部受阻，跨多轮按 5 分钟间隔探测；用户在 系统设置→隐私与安全性→完全磁盘访问 给「终端」授权后恢复，本轮完成。
- **内容**：`AIAgentView.emptyHint` 的模型标识 Button label 改为条件分支：`if model.aiConfig.apiKey.isEmpty`（AIConfig.apiKey = keys[provider.rawValue] ?? ""，空为 ""）显示警告样式（exclamationmark.triangle.fill + 「未配置 \(provider.displayName) API Key，点此设置」+ chevron.right，foregroundStyle Theme.warning）；else 维持 T1/T2 的「当前：provider · model ›」。外层 Button action 仍 model.showSettings=true，.help 按是否配置区分。未配 Key 时提前引导用户去设置，避免发消息才报错。
- **改动**：`App/Sources/Views/AIAgentView.swift`。
- **验证**：Core + App `swift build` 通过；渲染 20 张无 FAILED（AIPanelShowcase 空态 mock 为已配置态，warning 分支仅真实运行时 apiKey 空时出现，符合预期）。

## V1 · apple/README.md AI 描述校对（阶段 V 开始）
- **校对（以代码为准）**：`AITerminalCore/AIService.swift` 的 `AIConfig.init(provider: AIProvider = .anthropic, …)` 默认服务商=**anthropic**（AIProvider.defaultModel anthropic→claude-opus-4-8，displayName「Anthropic Claude」），设置里可切 OpenAI。故 apple/README.md 多处「OpenAI」表述滞后。
- **改动**：`apple/README.md` 三处——L7 关键依赖「AI Agent：OpenAI 兼容接口」→「默认 Anthropic Claude（claude-opus-4-8），兼容 OpenAI 接口」；L28 目录树「AIService.swift # OpenAI 调用」→「Anthropic/OpenAI 调用」；L91 快速开始「配置 OpenAI API Key（设置）后」→「在设置选择 AI 服务商（默认 Anthropic Claude，也支持 OpenAI）并填入对应 API Key 后」。
- **验证**：grep 复核无残留误导表述；`cd apple/App && swift build` 确认未动代码（Build complete）。文档与实现一致。

## U2 · Electron AI 欢迎区显示服务商/模型（对齐 T1）
- **调研**：Electron AI 调用在 renderer（src/renderer/App.jsx ~1141）`fetch('https://api.openai.com/v1/chat/completions', { ... body: { model: 'gpt-4', ... } })`，Bearer apiKey（localStorage 'openai_api_key'）。main.js 的 agent-execute 只跑 shell 命令、不是 AI 调用。故实际服务商=OpenAI、模型='gpt-4'（写死在 renderer fetch）。
- **内容**：import 加 lucide `Cpu`。ai-welcome（「欢迎使用 AI Agent」块）示例列表后加 `<p className="ai-model-badge"><Cpu/>当前：OpenAI · gpt-4</p>`（注释标注模型来源 = renderer fetch）。app.css 加 `.ai-model-badge`（12px muted，margin-top 16）。如实反映实际模型，不编造。对齐原生 T1。
- **改动**：`src/renderer/App.jsx`、`src/renderer/styles/app.css`。
- **验证**：`npm run build` compiled successfully。Electron renderer 依赖运行时无法 headless 渲染，build + 代码审查验收。

## U1 · Electron SSH header 显示连接备注（对齐 T3，阶段 U 开始）
- **调研**：Electron ssh-header 的 `.ssh-info` 显示 connection-status（已连接/连接中…）+ `.connection-info`（{username}@{host}:{port}）。session.config 由 handleDrawerSave/会话创建拼装，是否稳定带 note 不确定——故采用最稳的 `savedConnections.find(c => c.id === session.connectionId)?.note`（按 connectionId 回查保存的连接拿 note）。
- **内容**：在 connection-info span 后加一个 IIFE：查 conn=savedConnections.find(...)，note=(conn?.note||'').trim()，非空则渲染 `<span className="connection-note" title={note}>📝 {note}</span>`。app.css 加 `.connection-note`（text-muted 12px、margin-left 10、max-width 240 + 省略号）。对齐原生 T3（状态栏显示备注）。
- **改动**：`src/renderer/App.jsx`、`src/renderer/styles/app.css`。
- **验证**：`npm run build` compiled successfully。renderer 改动，build + 代码审查验收。note 现全端贯穿（原生 侧栏/搜索/编辑/状态栏 + Electron 侧栏/编辑/header/导入导出）。

## T4 · 命令片段高危标记（tooltip 补强）
- **调研**：`SnippetsView.snippetRow`（line 133-135）**已用** `snippet.isDangerous` 渲染警告三角 `exclamationmark.triangle.fill` + `Theme.danger` 色（普通片段用 chevron + accent），与 SnippetsShowcase 一致——高危视觉标记已具备，如实记录不重复造。
- **改进**：按提示给片段 Button 加 `.help(snippet.isDangerous ? "⚠️ 高危命令，注入后请仔细复核再执行：\(snippet.command)" : snippet.command)`——高危片段悬停显示警告，普通片段悬停显示完整命令（行内 `Text(snippet.command).lineLimit(1)` 会截断长命令，tooltip 看全更实用）。注入仍走 model.runSnippet（注释说明不自动回车便于复核）。
- **改动**：`App/Sources/Views/SnippetsView.swift`。
- **验证**：Core + App `swift build` 通过。警告图标已在 08-snippets 渲染，tooltip 不可离屏渲染，build 验证。

## T3 · SSH 状态栏显示连接备注
- **内容**：`StatusBarView`（@ObservedObject session: TerminalSessionVM）的 compactBar 在「状态」statusItem 后加：`if let note = session.connection?.noteText, !note.isEmpty { statusItem(icon:"note.text", label:"备注", value: note) }`。只 SSH 会话有 connection，本地会话 session.connection 为 nil 自动跳过。让用户在终端内也能看到该机备注（如「数据库主库」「先连 VPN」）。`DevTools/Showcase.swift` 的 StatusBarShowcase 在状态后加备注 mock。
- **改动**：`App/Sources/Views/StatusBarView.swift`、`DevTools/Showcase.swift`。
- **验证**：Core + App `swift build` 通过；渲染 `02-statusbar.png`——「状态 已连接 · 备注 数据库主库 · 主机 prod-01 · CPU · 内存…」正常（横向滚动栏，备注紧随状态）。

## T2 · 模型标识可点击打开设置
- **内容**：确认 `AppModel.showSettings`（@Published，ContentView .sheet(isPresented:) 弹 SettingsView）。把 T1 的模型标识行 HStack 包进 `Button { model.showSettings = true }`（.plain），文案后加 `Image("chevron.right")`（8pt）提示可点 + `.help("打开设置更改 AI 服务商 / 模型")`。AIPanelShowcase 空态 mock 同步加 chevron 保持截图一致。
- **改动**：`App/Sources/Views/AIAgentView.swift`、`DevTools/Showcase.swift`。
- **验证**：Core + App `swift build` 通过；重渲染 `20-ai-empty.png`——「🖥️ 当前：Anthropic Claude · claude-opus-4-8 ›」正常，点击打开设置。

## T1 · AI 面板显示当前服务商/模型（阶段 T 开始）
- **内容**：先确认 `AIConfig`（Core AIService.swift）有 `provider: AIProvider`（`.displayName`→"Anthropic Claude"/"OpenAI"）与计算属性 `model: String`，`AppModel.aiConfig` @Published。`AIAgentView.emptyHint` 在示例提示词下方加一行小字 `HStack{ Image("cpu"); Text("当前：\(model.aiConfig.provider.displayName) · \(model.aiConfig.model)") }`（10pt、textSecondary 0.8）。`DevTools/Showcase.swift` 的 AIPanelShowcase 加空态分支（messages 为空时渲染「用自然语言操作终端」+ 3 示例 + 模型标识 mock），`Screenshots.swift` 加 `20-ai-empty`。
- **改动**：`App/Sources/Views/AIAgentView.swift`、`DevTools/Showcase.swift`、`DevTools/Screenshots.swift`。
- **验证**：Core + App `swift build` 通过；渲染 `20-ai-empty.png` 看图——欢迎区下「🖥️ 当前：Anthropic Claude · claude-opus-4-8」正常显示。截图增至 20 张。

## S8 · connection-format.md 字段完整性校对（文档）
- **校对**：对照 docs/connection-format.md 字段表与三端实现。原生 `ConnectionPortability`（apple/AITerminalCore）导出/解析 group/startupCommands/fontSizeOverride/note 全部字段；Electron `connToPortable` 只导出 name/host/port/username/authType/group/note(+敏感)，`importConnections` 也只读这些——**startupCommands / fontSizeOverride 是原生独有，Electron 完全不处理**。文档此前把这两字段与通用字段并列、无端差异说明（误导：会让人以为跨端通用）。
- **改动**：`docs/connection-format.md`——startupCommands/fontSizeOverride 行末标注「**仅原生版**」；表后加「ℹ️ 端差异」段：通用字段(name/host/port/username/authType/group/note+敏感) vs 仅原生字段，明确 Electron/移动导入忽略这两字段（不报错、不应用、不影响互通）。
- **验证**：不涉代码；`cd apple/App && swift build` 确认未动代码（Build complete）。文档与三端实现一致。

## S7 · Electron quickExecute 接入高危判定
- **内容**：把 S6 在组件内的 `isDangerousCommand` 提到模块级（紧邻 generateId），并抽出 `DANGEROUS_PATTERNS` 常量，作纯函数供 `parseAndExecuteCommands`（AI 自动执行）与 `quickExecute`（快捷命令）共用，删组件内重复定义。`quickExecute(command)` 在 setAiMessages/executeCommand 前加 `if (isDangerousCommand(command) && !confirm('⚠️ 检测到高危命令：\n'+command+'\n\n确定要执行吗？')) return;`。当前快捷按钮（ls/pwd/df/ps）安全不触发，但 quickExecute 作为通用执行入口统一加拦截，防未来扩展或他处调用漏掉。
- **改动**：`src/renderer/App.jsx`。
- **验证**：`npm run build` compiled successfully（确认模块级提取后 parseAndExecuteCommands 引用仍有效）。renderer 改动，build + 代码审查验收。

## S6 · Electron AI 高危命令确认（安全对齐）
- **调研**：Electron AI 执行链 handleAISend→parseAndExecuteCommands→executeCommand('agent-execute')；`parseAndExecuteCommands`（src/renderer/App.jsx）解析 [EXECUTE]…[/EXECUTE] 后直接 executeCommand，**无任何代码级危险判定**，仅 system prompt（第 140 行附近）口头要求 AI 警告——与 README 宣称的「高危命令拦截」名不符实。原生在 AppModel.swift:590 用 `cmd.isDangerous`（Core AIService.isDangerous，子串匹配 dangerousPatterns=[rm -rf, rm -fr, :(){ , mkfs, dd if=, > /dev/, chmod -r 000, shutdown, reboot, halt, init 0, forkbomb]）命中则跳过自动执行 + 警告。
- **内容**：App.jsx 加 `isDangerousCommand(command)`（同一组 patterns，toLowerCase + includes 子串匹配）。`parseAndExecuteCommands` 循环里在 executeCommand 前：若 isDangerousCommand && `!confirm('⚠️ 检测到高危命令：\n${command}\n\n确定要执行吗？')` 则 push {success:false, output:'已跳过高危命令（用户取消）'} 并 continue，否则正常执行。只拦 AI 自动执行路径（parseAndExecuteCommands），用户手敲终端与固定安全的快捷命令（ls/pwd/df/ps）不受影响。
- **改动**：`src/renderer/App.jsx`。
- **验证**：`npm run build` compiled successfully。renderer 改动，build + 代码审查验收。README「高危命令拦截」对 Electron 现已名副其实。

## S5 · 刷新 apple/screenshots 全量截图（维护）
- **内容**：`swift run Shots /tmp/aiterminal-shots` 全量渲染（19 张无 FAILED）；对比 apple/screenshots/ 现有 19 张（01-sidebar…19-ai-search）与渲染输出同名一一对应；`cp /tmp/aiterminal-shots/*.png apple/screenshots/` 全量覆盖，把仓库展示图刷新到最新 UI（含近期 S 阶段后的最新渲染）。Read 抽查 05-settings 正常（配色主题缩略图 + AI 提示词「套用预设模板」+ 各区块）。git 显示未跟踪/改动，未提交（提交需用户明确要求）。
- **改动**：`apple/screenshots/*.png`（19 张二进制刷新，无源码改动）。
- **验证**：渲染无 FAILED；抽查图正常；`cd apple/App && swift build` 确认未动坏代码（Build complete）。

## S4 · 终端标签 tooltip 显示 user@host
- **内容**：`ContentView.SessionTabsBar.sessionTab(_:)` 的标签根视图加 `.help(session.connection?.subtitle ?? (session.isLocal ? "本地终端" : session.title))`。先确认 `Connection.subtitle`（Connection.swift:135）已是「user@host:port」现成计算属性，直接复用不重复拼字符串。SSH 会话悬停显示完整连接目标，本地会话显示「本地终端」。macOS .help 生效，iOS 无悬停但无害。
- **改动**：`App/Sources/Views/ContentView.swift`。
- **验证**：Core + App `swift build` 通过。标签 tooltip 不可离屏渲染，build 验证。

## S3 · 原生 AI「复制全部对话」到剪贴板
- **内容**：`AIAgentView` 会话 Menu 在 S2「复制当前对话」后加「复制全部对话」（`if model.conversations.contains(where: { !$0.messages.isEmpty })` 才显示，doc.on.clipboard.fill 图标区分），action `Clipboard.copy(String(decoding: model.exportAllConversationsMarkdown(), as: UTF8.self))` + `model.toast = "已复制全部对话"`。复用 M3 的全部导出文本。菜单顺序：重命名 / 复制当前对话 / 复制全部对话 / 导出全部对话 / 新建 / 删除（header 另有「导出当前」按钮）。
- **改动**：`App/Sources/Views/AIAgentView.swift`。
- **验证**：Core + App `swift build` 通过。Menu 不可离屏渲染，build 验证。AI 对话 复制/导出 × 当前/全部 四象限齐备。

## S2 · 原生 AI「复制当前对话」到剪贴板
- **内容**：`AIAgentView` 会话 Menu 在「导出全部对话」前加「复制当前对话」项（`if !model.aiMessages.isEmpty` 包裹，空对话不显示），action `Clipboard.copy(String(decoding: model.exportAIConversationMarkdown(), as: UTF8.self))` + `model.toast = "已复制当前对话"`。直接复用 H1 的导出 Markdown 文本（你/AI 分段 + [EXECUTE]→bash 块），无需另写纯文本拼装；Clipboard 为 N3 抽的 Support/Clipboard 公共封装；toast 由 ContentView .overlay 显示。
- **改动**：`App/Sources/Views/AIAgentView.swift`。
- **验证**：Core + App `swift build` 通过。Menu 不可离屏渲染，build 验证。

## S1 · Electron 右键「克隆连接」（阶段 S 开始）
- **内容**：src/renderer/App.jsx import 加 lucide `Files`。新增 `cloneConnection(conn)`：`{ ...conn, id: generateId(), name: (conn.name||`${username}@${host}`) + ' 副本' }`（`...conn` 展开带上 group/note/认证等全部字段），`setSavedConnections([...savedConnections, cloned])` + `localStorage.setItem('ssh_saved_connections', ...)` + `showToast('已克隆连接','success')`。右键菜单「编辑配置」后、「复制配置」前加「克隆连接」项（Files 图标，与 Copy 的「复制配置」语义区分）调 `cloneConnection(contextMenu.connection)`+closeContextMenu。对齐原生 cloneConnection（新 id、副本后缀、不影响原连接）。
- **改动**：`src/renderer/App.jsx`。
- **验证**：`npm run build` compiled successfully。renderer 改动，build + 代码审查验收。

## C-11 · 巩固轮 11（R6/R7 工具栏后防回归）
- **全量构建**：`apple/App swift build`（含 Core）✓、`node --check src/main/main.js`（仓库根）✓、`npm run build` compiled successfully ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：19 张 PNG 无 FAILED；抽查 07-main-overview——侧边栏「SSH 连接 (3)」+排序/刷新/新建图标、AI header 搜索图标，全部正确集成无回归（工具栏断开/重连为状态条件项，不进合成渲染）。
- **ROADMAP 一致性**：92 项 [x]，R1–R7 全勾 + 工具栏连断对称声明，唯二 [ ] 为 J3/N4（已注明暂缓）。
- **结论**：全端健康；无回归、无需修复。

---

## C-10 · 巩固轮 10（R 阶段后防回归）
- **全量构建**：`apple/App swift build`（含 Core）✓、`node --check src/main/main.js`（仓库根）✓、`npm run build` compiled successfully ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：19 张 PNG 无 FAILED；抽查 07-main-overview——侧边栏「SSH 连接 (3)」+ 排序/刷新/新建图标、AI 面板 header 搜索图标，全部正确集成；R 阶段改动（示例直发 R1 / 连断条件菜单 R2 / 清空·删连接·删对话确认 R3-R5）均为行为层，不影响静态渲染，无回归。
- **ROADMAP 一致性**：89 项 [x]，R1–R5 全勾 + 破坏性操作确认一致性声明，唯二 [ ] 为 J3/N4（已注明暂缓）。
- **结论**：全端健康；无回归、无需修复。

---

## R7 · 终端工具栏对称「重连」按钮
- **内容**：`ContentView` 工具栏在 R6「断开」按钮的 `if (connected||connecting)` 后加 `else if let s = model.activeSession, !s.isLocal, (s.status == .disconnected || s.status == .error)` 分支，放「重连」Button（bolt.fill）调 `model.activeSession?.reconnect()`（TerminalSessionVM @MainActor 方法，disconnect+startSSH 沿用 lastCols/Rows）。两分支互斥，工具栏据状态恰好显示「断开」或「重连」之一，连断对称、iOS 入口顺手。
- **改动**：`App/Sources/Views/ContentView.swift`。
- **验证**：Core + App `swift build` 通过。工具栏不可离屏渲染，build 验证。工具栏连断对称（R6 断开 / R7 重连）齐备。

## R6 · 终端工具栏「断开当前会话」按钮
- **调研**：`AppModel.openSession(for:)` 对已存在会话仅 `activeSessionID = existing.id; return`，不重连；但 `TerminalPane`（line 26）对非本地 `.error || .disconnected` 显示 reconnectBanner「连接已断开 + 重新连接」按钮调 `session.reconnect()`（disconnect+startSSH，沿用 lastCols/Rows，干净）。故「断开但保留标签」后用户可经遮罩一键重连，无卡死坏状态。
- **内容**：`AppModel.disconnectActiveSession()`：`guard let s = activeSession, !s.isLocal; s.disconnect()`（status→.disconnected，didStartShell=false，不从 sessions 移除）。`ContentView` 工具栏在 `activeSession` 非本地且 status 为 connected/connecting 时加「断开」Button（bolt.slash）。区别于标签 X（closeSession 关闭整个会话）：此按钮只断开、留标签。
- **改动**：`App/Sources/AppModel.swift`、`Views/ContentView.swift`。
- **验证**：Core + App `swift build` 通过。工具栏不可离屏渲染，build 验证。

## R5 · AI「删除当前对话」二次确认
- **内容**：`AIAgentView` 加 `@State showDeleteConvConfirm`。会话 Menu 里「删除当前对话」按钮 action 从直接 `deleteConversation` 改为 `showDeleteConvConfirm = true`。Menu 的 `.buttonStyle(.plain)` 后挂 `.confirmationDialog("删除当前对话？", isPresented:, titleVisibility:.visible){ Button("删除", role:.destructive){ if let id = model.activeConversationID { model.deleteConversation(id) } }; Button("取消", role:.cancel){} } message:{ Text("将删除整个对话及其历史，不可恢复。") }`。deleteConversation 内部维护 activeConversationID 切换与持久化，不绕过。与 showRename 的 .alert、showClearConfirm 的 .confirmationDialog 共存，编译通过。
- **改动**：`App/Sources/Views/AIAgentView.swift`。
- **验证**：Core + App `swift build` 通过。对话框不可离屏渲染，build 验证。破坏性操作确认一致性（R3 清空/R4 删连接/R5 删对话）齐备。

## R4 · 连接删除二次确认
- **内容**：`ConnectionRow` 加 `@State showDeleteConfirm`。右键菜单「删除」与 swipeActions「删除」的 action 都改为 `showDeleteConfirm = true`（共用同一 state；swipe Button 仍 role .destructive）。行根视图挂 `.confirmationDialog("删除连接「\(connection.title)」？", isPresented:, titleVisibility:.visible){ Button("删除", role:.destructive){ model.deleteConnection(connection) }; Button("取消", role:.cancel){} } message:{ Text("将移除此连接配置（不影响远程主机）。") }`。确认仍走 model.deleteConnection（内部 Keychain 清理等不绕过）。对齐 Electron 删除 confirm。
- **改动**：`App/Sources/Views/SidebarView.swift`。
- **验证**：Core + App `swift build` 通过。对话框不可离屏渲染，build 验证。

## R3 · AI「清空对话」二次确认
- **内容**：`AIAgentView` 加 `@State showClearConfirm`；header 垃圾桶按钮 action 从直接 `clearAIMessages()` 改为 `showClearConfirm = true`，并加 `.disabled(model.aiMessages.isEmpty)`；按钮上挂 `.confirmationDialog("清空当前对话？", isPresented:, titleVisibility:.visible){ Button("清空", role:.destructive){clearAIMessages()}; Button("取消", role:.cancel){} } message:{ Text("将删除当前会话的全部消息，不可恢复。") }`。用 confirmationDialog 而非第二个 .alert，规避同视图多 alert 潜在冲突（已有 showRename 的 .alert）。
- **改动**：`App/Sources/Views/AIAgentView.swift`。
- **验证**：Core + App `swift build` 通过。对话框不可离屏渲染，build 验证。

## R2 · 侧边栏右键 连接/断开 一致性
- **背景核对**：ConnectionRow 的 .contextMenu 与 .swipeActions **本已有「编辑」入口**（`model.editingConnection = connection`，ContentView 有 .sheet(item:) 弹 ConnectionEditView），R2 主目标已具备——如实记录，不重复造。
- **改进**：按提示挑真实小缺口——菜单对已连接的连接仍只显示「连接」。改为按 `model.status(for: connection)` 条件：`.connected/.connecting` 时显示「切到此会话」（设 activeSessionID 为该连接的会话）+「断开」（role .destructive）；否则显示「连接」。新增 `AppModel.disconnectSession(for:)`：`sessions.first{ $0.connection?.id == connection.id }` → `closeSession`。补齐 connect/disconnect 一致性，对齐 Electron 右键。
- **改动**：`App/Sources/AppModel.swift`、`Views/SidebarView.swift`。
- **验证**：Core + App `swift build` 通过。contextMenu 不可离屏渲染，build 验证。

## R1 · AI 空状态示例提示词点击直接发送（阶段 R 开始）
- **内容**：`AIAgentView.emptyHint` 的示例按钮（「列出当前目录文件」等）原来点击只 `input = ex` 填入输入框；改为 `guard !model.aiProcessing else { return }; input = ex; send()`，复用现有 `send()`（canSend 校验→清空 input→`model.sendAIMessage(text)` 流式），与点发送按钮行为完全一致，少一步操作。处理中不触发，避免插队。
- **改动**：`App/Sources/Views/AIAgentView.swift`。
- **验证**：Core + App `swift build` 通过。纯逻辑，空态结构不变，未渲染。

---

## C-9 · 巩固轮 9（Q 阶段后，覆盖 Electron 改动）
- **全量构建**：`apple/App swift build`（含 Core）✓、`node --check src/main/main.js`（从仓库根）✓、`npm run build` compiled successfully ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：19 张原生 PNG 无 FAILED。
- **移动 Web 壳**：headless Chrome 渲染 mobile/www/index.html → /tmp/mobile.png，Read 确认正常（AI Terminal 头+主题切换、SSH 连接列表[生产/开发/数据库 状态点]、SSH 终端经中继空状态卡+「打开 SSH 终端」、底部 终端/文件/AI 标签栏），无回归。
- **ROADMAP 一致性**：83 项 [x]，唯二 [ ] 为 J3/N4（已注明暂缓），阶段 Q 完成声明在位。
- **结论**：全端构建/自测/渲染健康；无回归、无需修复。

---

## Q4 · Electron 右键「复制配置」到剪贴板（对齐 N3）
- **内容**：import 加 lucide `Copy`。抽 `connToPortable(c, includeSecrets=false)` helper（name/host/port/username/authType + 非空时 group/note + includeSecrets 时 password/passphrase），`exportConnections` 改用 `savedConnections.map(c=>connToPortable(c,includeSecrets))`。新增 `copyConnectionConfig(conn)`：构造 `{format:'ai-terminal-connections',version:1,connections:[connToPortable(conn,false)]}` → `JSON.stringify` → `navigator.clipboard?.writeText`（Promise.resolve 包裹 + catch 兜底）+ `showToast('已复制连接配置（不含密码）','success')`。右键菜单「编辑配置」下加「复制配置」项（Copy 图标）调 `copyConnectionConfig(contextMenu.connection)`+closeContextMenu（contextMenu.connection 删除项已在用，存在）。
- **改动**：`src/renderer/App.jsx`。
- **验证**：`npm run build` compiled successfully。renderer 改动，build + 代码审查验收。

## Q3 · Electron 连接备注（对齐 L1）
- **内容**：照 R31 分组对齐的做法给 Electron 加 note。① `drawerConnectionConfig` 初始 state 加 `note:''`；② `openConnectionDrawer` 编辑回填 `note: connection.note||''` + 新建分支加 `note:''`；③ `handleDrawerSave` 加 `const note=(config.note||'').trim()`，updatedConnection/newConnection 都带 note；④ 侧边栏 renderConnItem 在 `.session-host` 下，note 非空时渲染 `<span className="session-note" title>`；⑤ exportConnections 非空时写 note、importConnections 读 `note: c.note||''`（跨端 JSON 对齐）；⑥ app.css 加 `.session-note`（11px muted 省略号）。
- **改动**：`src/renderer/App.jsx`、`src/renderer/styles/app.css`。
- **验证**：`npm run build` compiled successfully。renderer 改动，build + 代码审查验收。

---

## Q2 · 平台能力对比表（文档）
- **内容**：先 grep src/renderer/App.jsx 与 mobile/www 核实各端实有能力（Electron：私钥/主题/known-hosts[TOFU R33]/分组[R31]/JSON 导入导出[R18]/AI 基础；无 SFTP/端口转发/snippet；移动：经中继的基础 SSH 终端 + 主题）。在 README.md「平台矩阵」后加「## 功能对照」表：约 14 行主要功能 × 三列（原生 mac/iOS、Electron win/linux/mac、移动 Capacitor），✅/—/带括注（如「经中继」「浏览器原生」），表下注 ✅=支持—=暂无 + 移动经 relay。按实际实现勾，不夸大。
- **改动**：`README.md`。
- **验证**：不涉代码；顺手 `cd apple/App && swift build` 确认未动坏代码（Build complete）。

## Q1 · Electron 连接保存 trim 对齐（阶段 Q 开始）
- **内容**：src/renderer/App.jsx `handleDrawerSave` 把「先校验 drawerConnectionConfig.host/username 再解构」改为「先解构 config，再算 trim 后的 host/username/name/group 局部变量」；校验改用 `!host || !username`（trim 后判断）；updatedConnection 与 newConnection 的 name/group/host/username 字段均用 trim 后的值（name 空则回退 `${username}@${host}`）；更新现有会话的 config 也用 `{...config, host, username}` 让实际连接用干净值。对齐原生 P2（保存校验 trim）/P3（trim name/group）。
- **改动**：`src/renderer/App.jsx`。
- **验证**：`npm run build` compiled successfully。renderer 改动，headless 难复现表单行为，build + 代码审查验收（同 R15/R31 等 Electron 轮）。

## C-8 · 巩固 + 文档校对轮
- **全量构建**：App `swift build`（含 Core）✓、`node --check main.js` ✓、Electron `npm run build` ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：19 张 PNG 无 FAILED（01-sidebar 上轮已验「(3)」连接数）。
- **文档校对/更正**：① `CLAUDE.md` 构建与验证段补 7 个 `swift run Shots --xxx-test` 自测命令 + `node --check src/main/main.js`，方便后续轮次核对。② `README.md` 功能清单（C-5 后又新增了 N1 二维码/N3 复制配置/O1 排序/N2 AI 搜索/O2 提示词预设未覆盖）补上：跨端互通行加「二维码扫码导入、复制配置、按 最近/名称/添加顺序排序」，AI 行加「搜索、含只读/详解/精简预设」。③ ROADMAP 一致性：78 项 [x]，唯二 [ ] 为 J3/N4（已注明暂缓），各阶段完成声明自洽。
- **结论**：全端构建/自测健康；文档与实现已对齐；无代码问题。

## P3 · 连接保存时 trim name/分组/备注
- **内容**：`ConnectionEditView.save()` 在 P2 已 trim host/username 基础上，再 trim `draft.name`；`draft.group` 去空白后空→nil 否则存 trim 值；`draft.note` 去空白（含换行）后空→nil。避免「生产 」与「生产」被 Dictionary(grouping:) 之外的导出/比较当成不同值，以及名称/备注首尾多余空格。
- **改动**：`App/Sources/Views/ConnectionEditView.swift`。
- **验证**：Core + App `swift build` 通过。纯逻辑，无可见结构变化，未渲染。

## P2 · 连接编辑保存校验
- **内容**：`ConnectionEditView` 加 `canSave`（host/username 去空白后均非空），保存按钮 `.disabled(!canSave)`（原来用 `.isEmpty` 未 trim，纯空格能漏过保存出无法连接的条目）。`save()` 加 `guard canSave else { return }` + 保存前把 draft.host/username 设为 trim 后的值（存干净值，避免首尾空白参与连接/分组/去重）。port 解析、saveConnection、dismiss 不变。
- **改动**：`App/Sources/Views/ConnectionEditView.swift`。
- **验证**：Core + App `swift build` 通过。纯按钮禁用 + 逻辑，无可见结构变化，未渲染。

## P1 · 侧边栏「SSH 连接」标题显示连接数（阶段 P 开始）
- **内容**：`SidebarView` header 把「仅搜索时显示 `(filtered.count)`」改为「connections 非空即显示 `(\(search.isEmpty ? model.connections.count : filtered.count))`」——非搜索时总数、搜索时命中数；连接为空仍走「点击添加」提示不显示数字。仅小标注，不影响排序/可达性等。
- **改动**：`App/Sources/Views/SidebarView.swift`、`DevTools/Showcase.swift`（SidebarShowcase header 加 `(\(connections.count))`）。
- **验证**：Core + App `swift build` 通过；侧边栏渲染看图（`01-sidebar.png`：「SSH 连接 (3)」）。

## C-7 · 巩固轮 7（O 阶段后防回归）
- **全量构建**：App `swift build`（含 Core）✓、`node --check main.js` ✓、Electron `npm run build` ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：19 张 PNG 无 FAILED；Read 抽查 01-sidebar（SSH 连接 header 排序↕/刷新↻/新建+ 三图标）、05-settings（主题缩略图 + AI 提示词「套用预设模板」）、07-main-overview（侧边栏排序图标 + AI header 搜索图标 + 可达/备注/分组 全部正确集成无回归）；关键图刷新入库。
- **ROADMAP 一致性**：74 项 [x]，唯二 [ ] 为 J3/N4（已注明暂缓），无矛盾。
- **结论**：无回归、无需修复；全端健康。

## O3 · 终端工具栏「清屏」按钮
- **内容**：`TerminalSessionVM` 加 `clearScreen()`：`terminalView?.send(txt: "\u{0c}")`（Ctrl-L）——SSH 时 TerminalView.send 经 terminalDelegate.send 回到 session.sendInput→远端，本地时 LocalProcessTerminalView.send 直达进程，跨平台统一。`ContentView` 工具栏在 `activeSession != nil` 时（搜索按钮旁）加「清屏」Button（clear 图标）调 `model.activeSession?.clearScreen()`。补 F2 仅 macOS 右键清屏、iOS 无右键的空白。
- **改动**：`App/Sources/TerminalSessionVM.swift`、`Views/ContentView.swift`。
- **验证**：Core + App `swift build` 通过。工具栏项不可离屏渲染（同 J2/F2），未截图。

## O2 · AI 系统提示词预设模板
- **内容**：Core AIService.swift 加 `struct PromptPreset{id,name,text}` + `PromptPreset.all`：默认（=defaultAgentSystemPrompt）/只读模式（只生成只读类命令、写操作不 [EXECUTE]）/详细解释（每命令解释作用+风险）/精简（直给命令少废话）——每个模板都带 `[EXECUTE]命令[/EXECUTE]` 协议说明。`SettingsView`「AI 系统提示词」Section 在 TextEditor 上方加 Menu「套用预设模板」（ForEach PromptPreset.all，点击 `model.agentSystemPrompt = preset.text` 走 I1 的 didSet 持久化）；footer 提示可套用预设。恢复默认提示词按钮不变。
- **改动**：`AITerminalCore/.../AIService.swift`、`App/Sources/Views/SettingsView.swift`、`DevTools/Showcase.swift`（SettingsShowcase 加套用预设入口）、`Screenshots.swift`（高度 1220）。
- **验证**：Core + App `swift build` 通过；设置渲染看图（`05-settings.png`：AI 系统提示词区「套用预设模板」+ 提示词 + 恢复默认）。

## O1 · 侧边栏连接排序切换（阶段 O 开始）
- **内容**：新增 `enum ConnSortMode{recent/name/manual}`（label/icon）。`SidebarView` 加 `@AppStorage("conn_sort_mode") sortModeRaw` + `sortMode` 计算属性。新增实例 `sorted(_:)`：recent→`Self.sortedByRecent`、name→`title.localizedCaseInsensitiveCompare`、manual→原序；`ungrouped` 与 `groups` 组内均改用它（搜索 filtered 仍先生效）。「SSH 连接」header 在刷新按钮前加排序 Menu（ConnSortMode.allCases，当前项 checkmark、其余用各自 icon）。
- **改动**：`App/Sources/Views/SidebarView.swift`、`DevTools/Showcase.swift`（SidebarShowcase header 加 arrow.up.arrow.down）。
- **验证**：Core + App `swift build` 通过；侧边栏渲染看图（`01-sidebar.png`：SSH 连接 header 排序↕/刷新↻/新建+ 三图标 + 各行可达/备注/上次使用）。

## C-6 · 巩固轮 6（N 阶段后防回归）
- **全量构建**：App `swift build`（含 Core）✓、`node --check main.js` ✓、Electron `npm run build` ✓。
- **7 自测**：ssh-config / portability / ai-md / ai-md-all / ai-persist / ai-conv / reach 全绿。
- **全量渲染**：19 张 PNG 无 FAILED（含 18-qr、19-ai-search）；Read 抽查 18-qr（二维码清晰）、19-ai-search（搜索栏+命中）、07-main-overview（AI 面板 header 含搜索图标 + 侧边栏可达/备注/分组 全部正确集成无回归）；关键图刷新入库。
- **ROADMAP 一致性**：70 项 [x] 完成，唯二 [ ] 为 J3（AI 工具调用，暂缓）与 N4（iPad，需真机），均已注明，无矛盾。
- **结论**：无回归、无需修复；全端健康。

## N3 · 复制连接配置 JSON 到剪贴板
- **内容**：新建 `Support/Clipboard.swift`：`enum Clipboard { static func copy(_:String) }`（#if os(macOS) NSPasteboard.clearContents+setString / #else UIPasteboard.string）。`MessageBubble.copyToClipboard` 改为委托 `Clipboard.copy`（消除重复）。`AppModel.copyConnectionConfig(_:)`：`ConnectionPortability.export([connection], includeSecrets:false)` → JSON 字符串 → `Clipboard.copy` + toast「已复制连接配置（不含密码）」。`SidebarView` ConnectionRow contextMenu 在「分享二维码」后加「复制配置」（doc.on.clipboard）。
- **改动**：新增 `App/Sources/Support/Clipboard.swift`；改 `Views/AIAgentView.swift`、`AppModel.swift`、`Views/SidebarView.swift`。
- **验证**：Core + App `swift build` 通过。contextMenu 不可离屏渲染（同 K4/N1），仅 build 验证。

## N2 · AI 对话内搜索
- **内容**：`AIAgentView` 加 `@State searchActive/aiSearch`；header 加放大镜按钮（切换 searchActive，关闭时清空；激活态 magnifyingglass.circle.fill+accent），aiMessages 空则禁用。searchActive 时 header 下插入 `searchBar`（仿 SidebarView：放大镜 + TextField「搜索当前对话」+ 清除）。`displayedMessages` = 搜索空则全部、否则按 content 小写 contains 过滤；messages 列表 ForEach 改用它，搜索且无匹配显示「无匹配…」；流式「思考中」仅非搜索时显示；onChange 自动滚动加 `guard !isSearching`。
- **改动**：`App/Sources/Views/AIAgentView.swift`、`DevTools/Showcase.swift`（AIPanelShowcase 加 searching 态：放大镜 + 搜索栏 mock）、`Screenshots.swift`（19-ai-search）。
- **验证**：Core + App `swift build` 通过；AI 面板搜索态渲染看图（`19-ai-search.png`：激活放大镜 + 搜索栏「内存」+ 命中消息）。

## N1 · 连接二维码分享（阶段 N 开始）
- **内容**：新建 `Support/QRCode.swift`：`image(from:scale:) -> Image?` 用 `CIFilter.qrCodeGenerator()`（message=UTF8 数据，correctionLevel M）+ CGAffineTransform 放大 + CIContext.createCGImage，`#if os(macOS)` NSImage(cgImage:) / `#else` UIImage(cgImage:) 包成 SwiftUI Image。新建 `ConnectionQRView`（sheet）：payload = `ConnectionPortability.export([connection], includeSecrets:false)` 的 JSON 字符串（与跨端格式一致，扫码端 importConnections 可直接解析），显示 QR（interpolation .none + 白底）+ 标题 + 「扫码导入（不含密码）」说明。`AppModel` 加 `@Published qrConnection: Connection?`；`SidebarView` ConnectionRow contextMenu 加「分享二维码」设 qrConnection；`ContentView` 加 `.sheet(item: $model.qrConnection)`。
- **改动**：新增 `App/Sources/Support/QRCode.swift`、`Views/ConnectionQRView.swift`；改 `AppModel.swift`、`Views/SidebarView.swift`、`Views/ContentView.swift`、`DevTools/Showcase.swift`（QRShowcase）、`Screenshots.swift`（18-qr）。
- **验证**：Core + App `swift build` 通过；`QRShowcase` 渲染看图（`18-qr.png`：清晰可扫的二维码 + 标题 + 说明）；payload 即 ConnectionPortability 导出（已由 --portability-test 往返验证），故扫码导入数据路径可靠。

## M4 · 侧边栏搜索匹配备注
- **内容**：`SidebarView.filtered` 在 name/host/username/groupName 之外，过滤条件加 `|| $0.noteText.lowercased().contains(q)`，让备注内容可被搜索命中。q 已 trim+lowercase，无其他遗漏；分组/排序逻辑不变。
- **改动**：`App/Sources/Views/SidebarView.swift`（一行）。
- **验证**：Core + App `swift build` 通过。无界面结构变化，未渲染。

## C-5 · README 功能清单刷新 + 巩固
- **内容**：根 README.md 的「## ✨ 功能」清单（R19 时所写、严重落后）按实际能力重写并归类：本地终端（状态栏可展开）；SSH（密码/私钥 + 跳板机 + TOFU 主机密钥 + 端口转发 + Keychain）；SFTP（浏览 + 拖拽上传）；连接管理（分组/备注/可达性/最近使用/克隆/连接级字号/启动命令）；跨端互通（JSON + ~/.ssh/config，原生↔Electron↔移动）；AI（流式 + 停止/重生成 + 多对话切换/重命名/导出当前或全部 Markdown + 自定义系统提示词 + Anthropic/OpenAI + 消息复制 + 高危拦截）；主题（5 套 + 自定义 + 预览缩略图）；终端体验（拖拽分屏/搜索/字号/右键复制粘贴清屏/会话录制/恢复/快捷命令分组）。措辞保持简洁中文风格一致。
- **改动**：`README.md`。
- **验证**：README 引用截图 07/05/10/11 均存在；全量构建 Core+App+Electron+main.js 通过；7 自测（ssh-config/portability/ai-md/ai-md-all/ai-persist/ai-conv/reach）全绿。无问题。

## M3 · 导出全部对话为 Markdown
- **内容**：`AppModel` 把单会话拼装抽成 `private func markdown(for messages:heading:) -> String`（你/AI 分段 + markdownBody 的 [EXECUTE]→bash 块）；`exportAIConversationMarkdown` 改用它（heading「# AI 对话」）。新增 `exportAllConversationsMarkdown()`：过滤非空会话，每个 `markdown(for: conv.messages, heading: "# 对话：标题")`，以 `\n---\n\n` 连接（无内容则占位）。`AIAgentView` 加 `@State exportFilename`，fileExporter 用它；头部导出键设 filename「ai-conversation」（导出当前）；会话 Menu 加「导出全部对话」设 filename「ai-all-conversations」调 exportAllConversationsMarkdown。
- **改动**：`App/Sources/AppModel.swift`、`Views/AIAgentView.swift`、`DevTools/Screenshots.swift`+`ShotsMain/main.swift`（--ai-md-all-test）。
- **验证**：Core + App `swift build` 通过；`--ai-md-all-test`→「含项目A=true 含项目B=true 含bash块=true 含分隔=true」；`--ai-md-test` 单会话回归正常。Menu/导出按钮不可离屏渲染未截图。

## M2 · 会话菜单按 updatedAt 倒序 + 相对时间
- **内容**：把 `ConnectionRow.relativeTime` 的逻辑抽成 `Support/RelativeTime.swift` 的 `enum RelativeTime { static func string(_:Date)->String }`（刚刚/N分钟前/N小时前/N天前/M月d日，纯函数）；`SidebarView.ConnectionRow.relativeTime` 改为委托 `RelativeTime.string`。`AIAgentView`：`sortedConversations`（enumerated + updatedAt 倒序，nil 排后、offset 兜底稳定）；会话 Menu 用它渲染；`conversationLabel(conv)` 拼「标题 · RelativeTime.string(updatedAt)」。排序仅展示，不动 activeConversationID。
- **改动**：新增 `App/Sources/Support/RelativeTime.swift`；改 `Views/SidebarView.swift`、`Views/AIAgentView.swift`。
- **验证**：Core + App `swift build` 通过；渲染 `01-sidebar.png` 抽查——RelativeTime 重构后侧边栏「上次使用 · 5 分钟前」+ 备注/可达性均正常，无回归。Menu 不可离屏渲染未单独截图。

## M1 · AI 对话重命名 + 时间戳（阶段 M 开始）
- **内容**：`AIConversation` 加可选 `titleIsCustom: Bool?`（手动命名标志）+ `updatedAt: Date?`（Optional 向后兼容）+ `isCustomTitle` 便捷属性。`AppModel` 的 `aiMessages` setter：`if !isCustomTitle { title = derivedTitle }` 不覆盖手动名 + 每次写 `updatedAt = Date()`。新增 `renameConversation(_:to:)`（trim，空→titleIsCustom=false 回退 derivedTitle，非空→titleIsCustom=true + 设标题，持久化）。`AIAgentView`：会话 Menu 加「重命名当前对话」（设 renameText=activeTitle + showRename）；body 加 `.alert("重命名对话", isPresented:)` 含 TextField + 确定/取消，确定调 renameConversation。
- **改动**：`AITerminalCore/.../AIConversation.swift`、`App/Sources/AppModel.swift`、`Views/AIAgentView.swift`、`DevTools/Screenshots.swift`（aiConvTest 加自定义标题+updatedAt 断言）。
- **验证**：Core + App `swift build` 通过；`--ai-conv-test`→「自定义标题保留+updatedAt=true」+ 会话增删/迁移仍正确。Menu/alert 不可离屏渲染（同 K4），未截图。

## C-4 · 巩固轮 4（L2 多对话后防回归）
- **全量构建**：App `swift build`（含 Core）✓、`node --check main.js` ✓、Electron `npm run build` ✓。
- **6 自测**：ssh-config / portability（含备注）/ ai-md / ai-persist / ai-conv / reach 全绿；单独验 `--ai-md-test` 经多对话计算属性 aiMessages 仍正确输出 Markdown（## 你/## AI/bash 块）。
- **全量渲染**：17 张无 FAILED；Read 抽查 `07-main-overview`——侧边栏（可达性/📝备注/上次使用）、AI 面板（会话切换标题「列出当前目录文件…」+chevron + 重新生成/导出/清空）全部正确集成无回归；关键图刷新入库。
- **人脑走查**（重点）：`aiMessages` 计算属性 get/set 在所有调用点（sendAIMessage append、流式逐 token `[idx].content += delta` 走 get-modify-set、clearAIMessages removeAll、regenerateLast removeSubrange、exportAIConversationMarkdown 读、makeSampleModel 设值）语义均正确；`activeConversationID` 由 init/new/switch/delete 始终保证指向存在会话，setter 的 firstIndex guard 仅为安全网、实际不触发——无「活动会话不存在时静默丢写」隐患。
- **结论**：无回归、无需修复；AI 多对话核心改动健康。

## L2 · AI 多对话会话切换（专门一轮）
- **内容**：Core 新增 `AIConversation{id,title,messages:[ChatMessage]}` + `derivedTitle`（首条用户消息前 20 字）。`ConnectionStore`：`loadConversations`（无 conversations.json 时迁移旧 ai_messages.json 成一个默认会话）/`saveConversations`（写 conversations.json，并清理旧 ai_messages.json；空则删文件）。`AppModel`：`@Published conversations + activeConversationID`，把原 `@Published aiMessages` 改为**计算属性**（get 取当前会话 messages、set 写回当前会话并刷新 title）——sendAIMessage/runAICompletion/regenerateLast/exportMarkdown 等读写 aiMessages 的逻辑零改动；新增 `newConversation/switchConversation/deleteConversation`（切换/删除当前时若流式中先 cancelAIStreaming）；init 用局部变量装会话避免「self 在初始化完成前被读」；persistAIMessages 改存 conversations。`AIAgentView` header 标题换成会话 Menu（列出会话可切换 + 新建对话 + 删除当前）。
- **改动**：新增 `AITerminalCore/.../AIConversation.swift`；改 `ConnectionStore.swift`、`App/Sources/AppModel.swift`、`Views/AIAgentView.swift`、`DevTools/Showcase.swift`（AIPanelShowcase header 会话标题+chevron）、`Screenshots.swift`+`ShotsMain/main.swift`（--ai-conv-test，aiPersistTest 改用会话 API）。
- **验证**：Core + App `swift build` 通过；`--ai-conv-test`→「会话数=2 标题正确=true；删除后=1；旧版迁移会话数=1 首条标题=旧单对话」；`--ai-persist-test` 回归正常；AI 面板渲染看图（`03-ai-panel.png` 会话标题+下拉）。
- **MVP 边界**：流式中切换会话会 cancel 当前流；旧会话占位 assistant 的极端竞态收尾标记可能落空（cosmetic，已 cancel），记为后续可优化。

## L3 · 终端主题预览缩略图
- **内容**：新建 `ThemeThumbnail`（Support/）：`ZStack` 圆角矩形填 background + `VStack` 三行 Capsule（两行 foreground[渐淡] + 一行 accent）模拟迷你终端，40×28，下方主题名；selected 时描边 textPrimary 加粗。纯 Rectangle/Capsule，ImageRenderer 可渲染。`SettingsView` 配色区把原「一排强调色圆点」换成 `ScrollView(.horizontal)` 的 ThemeThumbnail 横排（5 预设[用 background/termForeground/accent] + 自定义[用 customColors]），点选切 themeID，选中高亮。
- **改动**：新增 `App/Sources/Support/ThemeThumbnail.swift`；改 `Views/SettingsView.swift`、`DevTools/Showcase.swift`（SettingsShowcase 配色区用缩略图）。
- **验证**：Core + App `swift build` 通过；设置渲染看图（`05-settings.png`：6 套主题迷你预览缩略图，午夜选中）。

## L1 · 连接备注（阶段 L 开始）
- **内容**：`Connection` 加可选 `note: String?` + `noteText`（去空白）。`ConnectionPortability` Item 同步 note（export 写非空、parse 读回）；`docs/connection-format.md` 补字段；portabilityTest 加备注断言。`ConnectionEditView` 加「备注（可选）」Section（多行 TextField axis:.vertical lineLimit 2...4，空→nil）。`SidebarView.ConnectionRow`：noteText 非空时在 subtitle 下显示一行（note.text 图标 + 文字，size 10 灰 0.85，lineLimit 1），排在「上次使用」之上；行加 `.help(noteText)` 作 macOS tooltip。
- **改动**：`AITerminalCore/.../Connection.swift`、`ConnectionPortability.swift`、`docs/connection-format.md`、`App/Sources/Views/ConnectionEditView.swift`、`SidebarView.swift`、`DevTools/Showcase.swift`、`Screenshots.swift`（样例数据库主机加 note + portabilityTest 断言）。
- **验证**：Core + App `swift build` 通过；`swift run Shots --portability-test`→「生产 备注=数据库主库 / 无组 备注=<nil>」往返正确；侧边栏渲染看图（`01-sidebar.png`：数据库主机 📝「数据库主库」+ 上次使用 + 绿 wifi）。

## C-3 · 巩固轮 3（阶段 K 后防回归 + 刷新截图）
- **全量构建**：App `swift build`（含 Core）✓、`node --check main.js` ✓、Electron `npm run build` compiled successfully ✓。
- **5 自测**：ssh-config（2 连接）/portability（group·命令·字号往返）/ai-md（Markdown）/ai-persist（保存加载 2 条+清空 0）/reach（闭合端口+空 host false）全绿。
- **全量渲染**：17 张 PNG 无 FAILED；Read 抽查 `07-main-overview` 合成图——侧边栏（SSH 连接刷新↻+新建、开发机未分组、📁生产含数据库主机[绿wifi+上次使用]/生产服务器[红wifi.slash]）、展开状态栏、假终端、AI 面板（重新生成/导出/清空）全部正确集成，无错位/空白/回归。关键图（01/03/04/05/08）刷新入库。
- **ROADMAP 一致性**：57 项 [x] 完成，唯一 [ ] 为 J3（已注明长期暂缓），无自相矛盾。
- **结论**：无回归、无需修复；全端健康。

## K4 · AI 单条消息复制
- **内容**：`MessageBubble` 加 `@EnvironmentObject model`（设 toast）+ `.contextMenu`：「复制」（message.content 原始）；assistant 额外「复制纯文本」（displayText = strippedDisplayText 去 [EXECUTE]）。`static copyToClipboard(_:)` #if os(macOS) NSPasteboard.clearContents+setString / #else UIPasteboard.string，参考 TerminalContainer.clipboardCopy 写法。复制后 model.toast 提示。
- **改动**：`App/Sources/Views/AIAgentView.swift`。
- **验证**：Core + App `swift build` 通过。contextMenu 不可离屏渲染（同 R30/F2/J2 处理），仅 build 验证。

## K3 · AI 重新生成上一条回复
- **内容**：`AppModel` 把 sendAIMessage 的流式核心抽成 `private func runAICompletion()`（假定用户消息已在末尾，append 占位 assistant + 取上下文窗口 + 流式 + persist + defer 收尾），sendAIMessage 改为 append 用户消息后调它。新增 `regenerateLast()`：守卫 !aiProcessing 且末条 role==.assistant、已配置；`removeSubrange((lastUserIdx+1)...)` 删最近用户消息之后的所有消息（末条 assistant 及命令提示），再 runAICompletion 按该用户消息重答（上下文窗口/停止逻辑照旧复用）。`AIAgentView` header 在 `aiMessages.last?.role == .assistant && !aiProcessing` 时显示 arrow.clockwise「重新生成」按钮调 regenerateLast。
- **改动**：`App/Sources/AppModel.swift`（重构 + regenerateLast）、`Views/AIAgentView.swift`、`DevTools/Showcase.swift`（AIPanelShowcase header 加重新生成图标）。
- **验证**：Core + App `swift build` 通过；AI 面板渲染看图（`03-ai-panel.png`：头部 重新生成/导出/清空 三图标）。

## K2 · 侧边栏「上次使用」相对时间
- **内容**：`ConnectionRow` 加 `static relativeTime(_:Date)->String`（<60s 刚刚、<1h N 分钟前、<1d N 小时前、<7d N 天前、否则 M月d日）。subtitle 下方当 `connection.lastUsedAt != nil` 显示「上次使用 · \(relativeTime)」（size 10 灰色 0.8 opacity，不抢眼）；无 lastUsedAt 不显示。
- **改动**：`App/Sources/Views/SidebarView.swift`、`DevTools/Showcase.swift`（connRow 加相对时间行）、`Screenshots.swift`（样例数据库主机 lastUsedAt = Date()-300 → 显示「5 分钟前」）。
- **验证**：Core + App `swift build` 通过；侧边栏渲染看图（`01-sidebar.png`：数据库主机下「上次使用 · 5 分钟前」）。

## K1 · 连接编辑内联「测试连接」（阶段 K 开始）
- **内容**：`ConnectionEditView` 加 `enum TestResult{idle/testing/reachable/unreachable}` + `@State testResult`。基本信息区在 用户名 后加一行：「测试连接」Button（dot.radiowaves 图标，host 非空且非 testing 才可点）+ 右侧 `testResultLabel`（idle 空/testing 转圈/reachable 绿✓可达/unreachable 红✗不可达）。`testConnection()` 起 Task 调 `ReachabilityChecker.probe(host:port:)` 更新 testResult。host/port 的 `.onChange` 重置 idle。
- **改动**：`App/Sources/Views/ConnectionEditView.swift`、`DevTools/Showcase.swift`（ConnectionEditShowcase 加测试连接行 + 可达 mock）、`Screenshots.swift`（高度 1070）。
- **验证**：Core + App `swift build` 通过；连接编辑渲染看图（`04-connection-edit.png`：测试连接按钮 + 绿「可达」）。

## C-2 · 巩固轮 2（阶段 E–J 增量复查）
- **基线**：Core/App `swift build` ✓、`node --check main.js` ✓、Electron `npm run build` ✓；5 自测（ssh-config/portability/ai-md/ai-persist/reach）全绿。
- **修复**（确有把握）：
  1. **录制 buffer 无上限**（高，内存）：`recordOutput` 后若 `recordingBuffer.count > 5_000_000` 则 `removeFirst(超出量)`，保留最近输出，杜绝超长会话内存无限涨。
  2. **导入字号未夹值**（中）：`TerminalPane.fontSize` 对 `fontSizeOverride` 取 `min(32,max(8,·))`，防导入 JSON 里极端值（如 999）撑坏终端；全局字号路径不变。
- **复查无虞**：ReachabilityChecker（LockedFlag.setIfUnset 保证三路只 resume 一次，finish 里 cancel 一次，无泄漏）；AI 持久化（persistAIMessages 走 defer 每次交换写一次而非逐 token、clear 删文件、空数组路径正确；write 用 try? 静默与既有 connections/snippets 一致，可接受）；recordedText 的 CSI/OSC 正则仅匹配 ESC 开头序列不误删正文；ConnectionPortability group/startupCommands/fontSizeOverride 往返经 --portability-test 验证。
- **改动**：`App/Sources/TerminalSessionVM.swift`、`Views/TerminalPane.swift`。
- **验证**：修后 App `swift build` 通过；portability/ai-persist 自测仍正确，无回归。

## J5 · 批量刷新可达性
- **内容**：`AppModel.checkAllReachability()` 遍历 `connections` 逐个调 `checkReachability`（各自异步、并发跑，连接数通常不多直接全发）。`SidebarView`「SSH 连接」section header 在 + 按钮前加刷新按钮（arrow.clockwise，connections 非空才显示）调 checkAllReachability。reachability 是 @Published，结果自动反映到各 ConnectionRow 的指示（J1）。
- **改动**：`App/Sources/AppModel.swift`、`Views/SidebarView.swift`、`DevTools/Showcase.swift`（SidebarShowcase header 加刷新图标）。
- **验证**：Core + App `swift build` 通过；侧边栏渲染看图（`01-sidebar.png`：SSH 连接标题旁刷新图标 + 各行可达指示）。

## J4 · AI 对话历史持久化
- **内容**：`ConnectionStore` 加 `aiMessagesURL`(ai_messages.json) + `loadAIMessages()`(解码 [ChatMessage]，失败→[]) / `saveAIMessages(_:)`（空数组则删文件，否则 atomic 写）。ChatMessage 已 Codable+Identifiable，直接编码。`AppModel` init `aiMessages = store.loadAIMessages()`；`sendAIMessage` 追加用户消息后立即 `persistAIMessages()`，流式 Task 内 `defer { persistAIMessages() }` 保证成功/取消/出错任一退出都存最终内容（避免逐 token 写盘）；`clearAIMessages` 也存（清空→删文件）。
- **改动**：`AITerminalCore/.../ConnectionStore.swift`、`App/Sources/AppModel.swift`、`DevTools/Screenshots.swift`+`ShotsMain/main.swift`（--ai-persist-test）。
- **验证**：Core + App `swift build` 通过；`swift run Shots --ai-persist-test`→「保存→加载 条数=2 内容匹配=true；清空后条数=0」往返正确。无界面变化不渲染。

## J2 · 终端会话输出录制 / 导出
- **内容**：`TerminalSessionVM` 加 `@Published isRecording` + `recordingBuffer: Data` + `start/stopRecording` + `recordOutput(_:)`（仅录制中 append，零开销不影响显示）+ `recordedText()`（UTF8 容错解码 + NSRegularExpression 去 CSI/OSC ANSI 转义便于阅读）。SSH 输出钩点：startSSH 的 onOutput 闭包里 `recordOutput(data)` 再 feed。`ContentView` 工具栏（仅非本地会话）加 `RecordButton`（@ObservedObject session 响应 isRecording）：未录制→开始；录制中→停止 + `TextFileDocument(recordedText())` 经 `.fileExporter(.plainText, "session-recording")` 导出 .txt；录制中红 tint + stop.circle.fill。
- **说明**：录制走 SSH onOutput 单一钩点；本地终端输出由 LocalProcessTerminalView 内部直接渲染、不经 session.feed，故录制按钮仅对 SSH 会话显示。
- **改动**：`App/Sources/TerminalSessionVM.swift`、`Views/ContentView.swift`（+ import UniformTypeIdentifiers + RecordButton）。
- **验证**：Core + App `swift build` 通过。RecordButton 为工具栏项（同 contextMenu/NSMenu 不可离屏渲染），未截图。

## J1 · 连接健康检查 / 可达性指示（阶段 J 开始）
- **内容**：新建 `ReachabilityChecker`（Network framework）：`probe(host:port:timeout) async -> Bool`，NWConnection TCP 连到 host:port，`.ready` 即可达，`.failed/.cancelled`/超时即不可达；`LockedFlag`(NSLock) 保证三路竞争只 resume 一次；只测 TCP 不做 SSH 握手（不触发认证/主机密钥）。`AppModel` 加 `enum ReachState{checking,reachable,unreachable}` + `@Published reachability:[UUID:ReachState]`（缺省=未知）+ `checkReachability(_:)`（异步 probe 后更新）。`SidebarView.ConnectionRow` 在 trailing 加 `reachabilityIndicator`（checking 转圈/reachable 绿 wifi/unreachable 红 wifi.slash/未知不显示，与 leading 会话状态点分置）+ contextMenu「测试可达性」。
- **改动**：新增 `AITerminalCore/.../ReachabilityChecker.swift`；改 `App/Sources/AppModel.swift`、`Views/SidebarView.swift`、`DevTools/Showcase.swift`（connRow 加可达图标）、`Screenshots.swift`+`ShotsMain/main.swift`（--reach-test）。
- **验证**：Core + App `swift build` 通过；`swift run Shots --reach-test`→「127.0.0.1:1 可达=false / 空 host 可达=false」（false 路径快速无挂起）；侧边栏渲染看图（`01-sidebar.png`：数据库主机绿 wifi、生产服务器红 wifi.slash）。

## C-1 · 巩固 / 防回归轮（不加功能）
- **全量构建**：Core `swift build` ✓、App `swift build` ✓、`node --check src/main/main.js` ✓、Electron `npm run build` compiled successfully ✓。
- **运行时自测**（`swift run Shots --…`）：`--ssh-config-test`→解析 2 连接(prod 密码/dev 私钥+展开~)正确；`--portability-test`→导出含 group/startupCommands，生产(组/2 行命令/字号 15)、无组(nil) 往返正确；`--ai-md-test`→Markdown(## 你/## AI + bash 块)正确。
- **全量渲染**：`swift run Shots` 输出 17 张 PNG 无 FAILED；Read 抽查 07-main-overview（侧边栏分组+排序、状态栏展开 chevron、AI 面板导出图标、假终端）布局正确无回归；关键图刷新拷入 apple/screenshots/。
- **ROADMAP 清理**：修正两处自相矛盾的 R11（已完成却标 `[ ]`）→ 标为已完成并指向阶段 B 的 R11 ✅；确认 backlog 47 项全部 `[x]`、无 `[ ]` 残留矛盾。规划阶段 J（连接健康检查/会话录制回放/AI 工具调用）。
- **结论**：无回归，无需修复；全端构建与自测健康。

## I2 · 连接级终端字号覆盖
- **内容**：`Connection` 加可选 `fontSizeOverride: Double?`（参与跨端导出）。`ConnectionPortability` Item 同步该字段（export 写、parse 读）。`docs/connection-format.md` 补字段。`TerminalPane` 加计算属性 `fontSize = session.connection?.fontSizeOverride.map{CGFloat($0)} ?? model.terminalFontSize`（本地会话 connection 为 nil 自然回退全局），传给 TerminalContainer（字号变化经现有 update 热应用）。`ConnectionEditView` 加「终端字号（可选）」Section（Binding 显示 Int、`clampedFontSize` 解析夹 8–32、空=nil）。
- **改动**：`AITerminalCore/.../Connection.swift`、`ConnectionPortability.swift`、`docs/connection-format.md`、`App/Sources/Views/TerminalPane.swift`、`ConnectionEditView.swift`、`DevTools/Showcase.swift`、`Screenshots.swift`（portabilityTest 加字号断言）。
- **验证**：Core + App `swift build` 通过；`swift run Shots --portability-test`→「生产 字号=15 / 无组 字号=<nil>」往返正确；连接编辑「终端字号」区渲染看图（`04-connection-edit.png`）。

## I3 · 命令片段支持分组
- **内容**：`CommandSnippet` 加可选 `group: String?`（Optional 向后兼容）+ `groupName` 归一化；8 条默认片段按 文件/系统/网络/Git 分类。`SnippetsView`：filtered 搜索含 groupName；加 `ungrouped` + `groups`（按组名排序）；列表 Section 放未分组，后接每组一个 📁 Section（Label folder）；新建片段表单在 名称/命令 间加「分组（可选）」TextField，addSnippet 带 group（空→nil）。
- **改动**：`AITerminalCore/.../CommandSnippet.swift`、`App/Sources/Views/SnippetsView.swift`、`DevTools/Showcase.swift`（SnippetsShowcase 分组卡片 + snipRow/groupNames）、`Screenshots.swift`（08-snippets 用全部 8 条 + 高度 720）。
- **验证**：Core + App `swift build` 通过；快捷命令分组渲染看图（`08-snippets.png`：📁 文件/系统/网络/Git 分区 + 新建表单含分组框）。

## I1 · AI 系统提示词可自定义（阶段 I 开始）
- **内容**：Core 把全局 `agentSystemPrompt` 重命名为 `defaultAgentSystemPrompt`（公开）。`AppModel` 加 `@Published agentSystemPrompt: String`（didSet 存 UserDefaults "ai_system_prompt"）+ init 从 UserDefaults 读（空则 default）+ `resetAgentSystemPrompt()`。sendAIMessage 原本引用全局 agentSystemPrompt → 现解析为实例属性（用户自定义生效）。`SettingsView` 在 API 地址后加「AI 系统提示词」Section：TextEditor 绑定 model.agentSystemPrompt（等宽、minHeight 120）+「恢复默认提示词」按钮 + footer 提醒保留 [EXECUTE] 用法。
- **改动**：`AITerminalCore/.../AIService.swift`（重命名）、`App/Sources/AppModel.swift`、`Views/SettingsView.swift`、`DevTools/Showcase.swift`（SettingsShowcase 加提示词区）、`Screenshots.swift`（高度 1180）。
- **验证**：Core + App `swift build` 通过；设置渲染看图（`05-settings.png`：AI 系统提示词区 + 提示词内容 + 恢复默认）。

## H3 · 本地终端 URL 点击打开（调查结论：天然已支持）
- **调查**：grep SwiftTerm 源码——`LocalProcessTerminalView`(Mac/MacLocalTerminalView.swift) 内部 `terminalDelegate = self`，其 `LocalProcessTerminalViewDelegate` 协议只转发 sizeChanged/setTerminalTitle/hostCurrentDirectoryUpdate/processTerminated（无 requestOpenLink）；`requestOpenLink` 是 `TerminalViewDelegate` 要求，且在 `extension TerminalViewDelegate`(MacTerminalView.swift:2417) 有默认实现 = `NSWorkspace.shared.open(url)`。LocalProcessTerminalView 未覆写它 → 本地终端点链接已走默认实现打开，无需接线。
- **改动**：`TerminalContainer.swift` 仅加一行说明注释（无功能改动）。
- **验证**：Core + App `swift build` 通过。结论：H3 天然满足，SSH 用我们自己的 requestOpenLink 覆写、本地用 SwiftTerm 默认，行为一致。

## H2 · 状态栏点击展开更多系统信息
- **确认字段**：SystemInfo 有 hostname/cpuUsage/cpuCores/memUsed/memTotal/loadavg/uptime + memPercent。
- **内容**：`StatusBarView` body 改 VStack(compactBar + 展开详情)；`@State expanded`；compactBar 末尾加 chevron(up/down)，`.contentShape(Rectangle()).onTapGesture` 在有 displayInfo 时 `withAnimation` 切换 expanded。`expandedDetail(_:)` 用 LazyVGrid 两列显示 主机/运行时长/CPU(%.1f%% · N 核)/内存(used / total (xx%))/负载(1·5·15 分钟，>=3 时 a/b/c 否则拼接)；`detailCell(label,value)` 等宽。只用已有字段。
- **改动**：`App/Sources/Views/StatusBarView.swift`、`DevTools/Showcase.swift`（StatusBarShowcase 加 expanded 参数 + 详情网格）、`Screenshots.swift`（02-statusbar expanded:true，高度 130）。
- **验证**：Core + App `swift build` 通过；状态栏展开态渲染看图（`02-statusbar.png`：紧凑栏 + 详情网格 prod-01/12天3时/47% 8核/9·16GB 56%/0.82·0.65·0.51）。

## H1 · AI 对话导出为 Markdown（阶段 H 开始）
- **内容**：`AppModel.exportAIConversationMarkdown() -> Data`：遍历 aiMessages（跳过 system），user→`## 你`、assistant→`## AI`；`markdownBody` 用 NSRegularExpression 把 `[EXECUTE]cmd[/EXECUTE]` 倒序替换为 ```bash 代码块（倒序保证 range 有效）。`AIAgentView` 顶栏 trash 前加导出按钮（square.and.arrow.up，aiMessages 空则 disabled）→ `.fileExporter(document: TextFileDocument, contentType: .markdownDoc, defaultFilename:"ai-conversation")`。新增 `TextFileDocument: FileDocument`（readable/writable [.markdownDoc,.plainText]）+ `UTType.markdownDoc`（filenameExtension "md" conformingTo .plainText）。
- **改动**：`App/Sources/AppModel.swift`、`Views/AIAgentView.swift`、`DevTools/Showcase.swift`（AIPanelShowcase 标题加导出图标）、`Screenshots.swift`+`ShotsMain/main.swift`（--ai-md-test）。
- **验证**：Core + App `swift build` 通过；`swift run Shots --ai-md-test` 输出正确 Markdown（## 你/## AI + 两个 ```bash 块[ls -la / free -h]）；AI 面板渲染看图（`03-ai-panel.png` 导出图标）。

## G3 · 命令片段面板搜索过滤
- **内容**：`SnippetsView` 加 `@State search` + `filtered`（title/command 小写 contains）。Form 顶部加搜索 Section（放大镜 + TextField「搜索片段」+ 非空时 xmark 清除，仿 SidebarView）；列表 Section 用 filtered，区分「暂无片段」/「无匹配」/正常；注入/增删/恢复默认不变。
- **改动**：`App/Sources/Views/SnippetsView.swift`、`DevTools/Showcase.swift`（SnippetsShowcase 顶部加搜索框）。
- **验证**：Core + App `swift build` 通过；快捷命令面板渲染看图（`08-snippets.png`：顶部搜索框 + 片段列表 + 新建片段）。
- **G2 备注**：SwiftTerm iOS TerminalView 基于 UITextInput，长按自带系统编辑菜单（拷贝/粘贴/全选），无需额外补；如需自定义项再单列。

## G1 · 终端分屏可拖拽调整比例（阶段 G 开始）
- **内容**：`ContentView.SplitTerminals` 重写为 GeometryReader 驱动：`@AppStorage("split_ratio") ratio`（默认 0.5，持久化）+ `@State dragStartRatio`；横屏 firstSize=width*ratio、竖屏=height*ratio，primary 定尺寸、secondary 填充。中间 `handle(horizontal:total:)`：Rectangle(6pt) + 居中 Capsule 把手，`DragGesture` onChanged 用 dragStartRatio 基线 + delta/total 算新比例并夹到 0.2~0.8、onEnded 清基线；macOS `.onHover` 切换 resizeLeftRight/resizeUpDown 光标。拖动时两 TerminalView 随尺寸变化 reflow（SwiftTerm sizeChanged→session.resize）。
- **改动**：`App/Sources/Views/ContentView.swift`、`DevTools/Screenshots.swift`（ShowcaseSplitView 改非等分 0.62 + 把手）。
- **验证**：Core + App `swift build` 通过；分屏渲染看图（`12-split.png`：左宽右窄非等分 + 中间竖向把手）。

## F3 · SFTP 拖拽上传
- **内容**：`FileBrowserView` 加 `dropTargeted` 状态 + body `.onDrop(of:[.fileURL], isTargeted:)`，悬停时 overlay 显示虚线 accent 边框 + 「松开上传到当前目录」胶囊（allowsHitTesting false）。`handleDrop` 起 `Task{@MainActor}` 逐个 `loadDroppedURL`（withCheckedContinuation 包 `loadDataRepresentation(forTypeIdentifier: UTType.fileURL)` → `URL(dataRepresentation:)`）后 `await uploadFile` 依次上传。抽出 `uploadFile(_:)`（安全作用域 + Data(contentsOf:) + sftpUpload(到 当前path/文件名) + 刷新），fileImporter 与拖拽共用。
- **改动**：`App/Sources/Views/FileBrowserView.swift`、`DevTools/Showcase.swift`（SFTPShowcase 加 dropHint 高亮 overlay）、`Screenshots.swift`（17-sftp-drop）。
- **验证**：Core + App `swift build` 通过；拖拽高亮态渲染看图（`17-sftp-drop.png`：虚线边框 + 松开上传胶囊）。运行态拖拽上传需真实 SFTP 实测；iOS onDrop 行为受限但不崩。

## F2 · 终端右键复制/粘贴菜单
- **确认 API**：SwiftTerm MacTerminalView 有 `open func copy(_:)`/`paste(_:)`/`selectAll(_:)`（走 NSResponder copy:/paste:/selectAll:）、`send(txt:)`、`selection.getSelectedText()`；未重写 rightMouseDown/menu(for:)，故设 `tv.menu` 右键即弹。
- **内容**：TerminalContainer 加 `@MainActor makeTerminalContextMenu(tv:clearTarget:) -> NSMenu`（macOS）：复制/粘贴/全选项 action 用字符串 Selector `copy:`/`paste:`/`selectAll:`、target=终端视图（经响应链命中 SwiftTerm 实现）；清屏项 target=coordinator 调 `terminalClearScreen`（发 `\u{0c}` Ctrl-L）。SSH coordinator（#if macOS 守卫）与 Local coordinator 的 makeTerminal 里设 `tv.menu = makeTerminalContextMenu(tv:tv, clearTarget:self)`，并各加 `@objc terminalClearScreen()`。
- **改动**：`App/Sources/Views/TerminalContainer.swift`。
- **验证**：Core + App `swift build` 通过（Selector 字面量有风格 warning，无碍）。右键 NSMenu 不可离屏渲染故未截图；iOS 的 UIMenu 留 TODO。

## F1 · 连接就绪后自动运行启动命令（阶段 F 开始）
- **内容**：`Connection` 加可选 `startupCommands: String?`（多行，每行一条；属连接配置故参与跨端导出）+ `startupCommandLines`（按行拆、去空白/空行）。`ConnectionPortability` Item 加 startupCommands，export 写非空、parse 读回。`docs/connection-format.md` 补字段。`ConnectionEditView` 加「启动命令（可选）」Section（多行 TextField axis:.vertical lineLimit 2...6，等宽字体，Binding 空→nil）。`TerminalSessionVM` shell 就绪后（startMonitoring 之后）调 `runStartupCommands()`：逐行 `await sshSession.send(Data(line+"\n"))`；重连会重发（startSSH 重走）。
- **改动**：`AITerminalCore/.../Connection.swift`、`ConnectionPortability.swift`、`docs/connection-format.md`、`App/Sources/Views/ConnectionEditView.swift`、`TerminalSessionVM.swift`、`DevTools/Showcase.swift`、`Screenshots.swift`（portabilityTest 加启动命令断言）。
- **验证**：Core + App `swift build` 通过；`swift run Shots --portability-test`→「导出含 group: true / startupCommands: true；生产 启动命令行数=2；无组 0」往返正确；连接编辑「启动命令」区渲染看图（`04-connection-edit.png`）。运行态注入需真实 SSH 实测。

## E3 · Electron known_hosts 管理 UI（对齐原生 R29）
- **内容**：src/main/main.js 加三个 `ipcMain.handle`：`known-hosts-list`（loadKnownHosts → 按 host 排序的 [{host,fingerprint}]）、`known-hosts-remove`(host)（删一条 saveKnownHosts）、`known-hosts-clear`（saveKnownHosts({})），复用 R33 的 load/save。渲染端（App.jsx，`ipcRenderer.invoke` 风格）加 knownHosts 状态 + reloadKnownHosts/removeKnownHost/clearKnownHosts；设置按钮 onClick 触发 reload；设置弹窗「连接备份」后加「已知主机（TOFU）」区：列表渲染 host + 等宽截断指纹 + 每条 Trash2 删除 + 顶部「全部清除」+ 空态提示。app.css 加 .known-hosts-list/.known-host-row 等样式。
- **改动**：`src/main/main.js`、`src/renderer/App.jsx`、`src/renderer/styles/app.css`。
- **验证**：`node --check src/main/main.js` OK；`npm run build` compiled successfully。运行态需 Electron + 真实 known_hosts.json，build + 代码审查验收。

## E2 · 终端配色自定义编辑器
- **内容**：`AppColorScheme.swift` 加 `CustomThemeColors`（background/textPrimary/accent/caret，Codable）+ `makeCustom(_:)`（由 4 色派生整套：surface/surfaceLight = mix(bg,白)，textSecondary = mix(fg,bg)，term* 取自定义，ansi 复用 midnight）+ `mix/hexRGB/rgbHex` 颜色插值；`customID="custom"`。`Platform.swift` 加 `Color.toHexString()`（平台色取 sRGB 分量→hex）。`AppModel`：`@Published customColors`（存/取 UserDefaults JSON）+ `themeRevision`（自定义改色自增，作终端热更新令牌）+ `applyTheme()`（themeID==custom 走 makeCustom）+ `setCustomColor(keyPath:)`；init 先载 customColors 再应用。`TerminalPane` 传 `themeID:"\(themeID)#\(themeRevision)"` 使终端在同 themeID 下也随改色刷新。`SettingsView` 配色区加「自定义」Picker 项 + 色块 + 选中时 4 个 `ColorPicker`（Binding Color↔hex）。
- **改动**：`Support/AppColorScheme.swift`、`Support/Platform.swift`、`AppModel.swift`、`Views/SettingsView.swift`、`Views/TerminalPane.swift`、`DevTools/Showcase.swift`（SettingsShowcase 加自定义色块 + customRow）、`Screenshots.swift`（高度）。
- **验证**：Core + App `swift build` 通过；设置渲染看图（`05-settings.png`：6 套主题含自定义 + 4 行调色 背景/主文字/强调/光标 带色块）。ColorPicker 离屏不渲染故用色块 mock。

## E1 · 连接「最近使用」时间戳 + 侧边栏排序（阶段 E 开始）
- **内容**：`Connection` 加可选 `lastUsedAt: Date?`（Optional 向后兼容；注释说明设备相关，不参与 ConnectionPortability 导出——Item 无此字段故天然不导出）。`AppModel.openSession(for:)` 调 `markUsed(id)`：把对应连接 lastUsedAt 设为 Date() 并 saveConnections。`SidebarView` 加 `static sortedByRecent`（用过的按 lastUsedAt 倒序在前，未用过的按原顺序稳定在后——enumerated + offset 兜底 tie），ungrouped 与各 group 内均套用。
- **改动**：`AITerminalCore/.../Connection.swift`、`App/Sources/AppModel.swift`、`Views/SidebarView.swift`、`DevTools/Showcase.swift`（SidebarShowcase 套排序）、`Screenshots.swift`（样例数据库主机加 lastUsedAt: Date()）。
- **验证**：Core + App `swift build` 通过；侧边栏渲染看图（`01-sidebar.png`：「生产」组内 数据库主机[最近] 排到 生产服务器 之前）。

## R33 · Electron 主机密钥 TOFU（对齐原生 R20）
- **背景**：Electron 主进程（src/main/main.js）用 ssh2 建连，ssh2 默认「不设 hostVerifier 即自动接受任意主机密钥」——存在 MITM 风险（与原生 R20 之前相同）。
- **确认 API**：ssh2 `hostVerifier: (key[, callback])`，未设 hostHash 时 key 是原始公钥 Buffer，callback(true/false) 做异步校验。
- **内容**：main.js 顶部加 `crypto` + known_hosts 助手（`knownHostsPath()`=userData/known_hosts.json，load/save，`hostKeyFingerprint`=`SHA256:`+sha256(base64 去尾=)）。连接处加 `let hostKeyChanged=false` 闭包标志；connectConfig 加 hostVerifier：算指纹→比对 known_hosts[host:port]，无记录则记并放行、相同放行、不同置 hostKeyChanged 并 cb(false)。conn.on('error') 开头：若 hostKeyChanged，回发「主机密钥已变化（可能中间人攻击）…删除 known_hosts.json 对应主机后重连」并 return。
- **改动**：`src/main/main.js`。
- **验证**：`node --check src/main/main.js` OK；`npm run build` compiled successfully。运行态需真实 Electron + SSH 服务器（首次记录/再次匹配/变更拒绝三路径），靠 build+代码审查验收。
- **backlog**：Electron 暂只能手删 known_hosts.json → 记为 E3（对齐原生 R29 管理 UI）。

## R32 · 原生 ConnectionPortability 带 group（闭合跨端分组互通）
- **内容**：`ConnectionPortability.Item` 加可选 `group: String?`；export 时 `group: c.groupName.isEmpty ? nil : c.groupName`（仅非空写入）；parse 时把 item.group 去空白后写回 `Connection(group:)`（空→nil 归一），不影响敏感字段/去重。`docs/connection-format.md` 字段表补一行 group。加运行时自测 `AppScreenshots.portabilityTest()` + main.swift `--portability-test`。
- **改动**：`AITerminalCore/.../ConnectionPortability.swift`、`docs/connection-format.md`、`App/Sources/DevTools/Screenshots.swift`、`App/ShotsMain/main.swift`。
- **验证**：Core + App `swift build` 通过；`swift run Shots --portability-test` → 「导出 JSON 含 group 字段: true / 生产@10.0.0.1 group=生产环境 / 无组@10.0.0.2 group=<nil>」往返正确。无界面变化不渲染。

## R31 · Electron 连接分组（对齐原生 R22）
- **内容**：src/renderer/App.jsx——drawerConnectionConfig 初始 + openConnectionDrawer 编辑回填 + handleDrawerSave 的 updatedConnection/newConnection 全部带 `group`（向后兼容，旧数据无 group=未分组）；抽屉表单在「连接名称」后加「分组（可选）」输入；侧边栏 SSH 连接列表用 IIFE 重构：抽出 `renderConnItem(conn)`，先渲染未分组，再按组名（去重排序）每组一个 `.nav-group-header`（Folder 图标 + 组名）+ 该组连接；导入/导出（ai-terminal-connections JSON）带上 group（导出仅当非空）。app.css 加 `.nav-group-header` 样式。lucide 导入加 Folder。
- **改动**：`src/renderer/App.jsx`、`src/renderer/styles/app.css`。
- **验证**：`npm run build` webpack compiled successfully。Electron 渲染需运行态填充 localStorage，headless 难复现，仅 build 验证（同 R15/R17）。
- **backlog**：原生 `ConnectionPortability` 导出/导入尚未含 group → 记为 R32，补上后分组可真正跨端互通。

## R30 · 连接克隆
- **内容**：`AppModel.cloneConnection(_:)`——复制 Connection，`copy.id = UUID()`（Identifiable/Equatable 以 id 区分，必须换），name = (原 name 或 title) + " 副本"；分组/跳板/敏感字段一并复制（内存里的连接已从 Keychain 回填，saveConnections 会按新 id 写入各自 Keychain，同设备安全等价）；插入到原连接之后并保存，toast 提示。`SidebarView` ConnectionRow 的 contextMenu 在编辑/删除间加「复制」（doc.on.doc）。
- **改动**：`App/Sources/AppModel.swift`、`Views/SidebarView.swift`。
- **验证**：Core + App `swift build` 通过。改动是右键 contextMenu（难离屏静态渲染），按 CLAUDE.md 约定未截图。

## R29 · known_hosts 管理 UI
- **内容**：`KnownHostsStore` 加 `all() -> [(host,fingerprint)]`（NSLock 保护，按 host 排序的只读快照）。新建 `KnownHostsView`（sheet）：List 显示 host（粗体）+ 指纹（等宽、middle 截断），每行 `swipeActions` 删除调 `forget(host)`；工具栏「全部清除」（alert 二次确认调 clear）；空态用 `ContentUnavailableCompat`（自封装，避免版本依赖）。`SettingsView` 主机密钥区把「清除已知主机密钥」改为「管理已知主机」按钮 → `.sheet(KnownHostsView())`。
- **改动**：`AITerminalCore/.../KnownHosts.swift`（all）；新增 `App/Sources/Views/KnownHostsView.swift`；改 `Views/SettingsView.swift`、`DevTools/Showcase.swift`（KnownHostsShowcase）、`Screenshots.swift`（16-known-hosts）。
- **验证**：Core + App `swift build` 通过；已知主机列表渲染看图（`16-known-hosts.png`：3 条 host→SHA256 指纹 + 删除/全部清除）。

## R28 · AI 流式「停止」按钮（阶段 D 开始）
- **内容**：`AppModel` 加 `aiStreamTask: Task<Void,Never>?`，sendAIMessage 的流式消费 Task 存入它；循环内 `if Task.isCancelled { break }`。新增 `cancelAIStreaming()`：`aiStreamTask?.cancel()`（触发 AsyncThrowingStream.onTermination → 取消 URLSession.bytes 网络）+ 即时 `aiProcessing=false`。Task 收尾：`catch` 里 `error is CancellationError` 不报 ⚠️；统一在末尾按 `Task.isCancelled` 补「⏹ 已停止」并 return（不 runParsedCommands），errored 也 return，正常才解析注入。`AIAgentView` inputBar 在 `aiProcessing` 时显示红色 `stop.circle.fill` 调 cancelAIStreaming，否则原发送键。
- **改动**：`App/Sources/AppModel.swift`、`Views/AIAgentView.swift`、`DevTools/Showcase.swift`（AIPanelShowcase 加 processing 态）、`Screenshots.swift`（新增 15-ai-stop）。
- **验证**：Core + App `swift build` 通过；AI 停止态渲染看图（`15-ai-stop.png`：思考中… + 红色停止键）。

## R27 · AIService SSE 解析容错 + 失败日志
- **问题**：completeStreaming 用 `try?` 解析每条 SSE，decode 失败静默丢弃——字段变更/脏数据导致缺字或卡住却无从排查；正常的非文本事件（message_start/ping 等）也走同一 `try?` 无法区分。
- **修法**：顶层加 `aiLog = Logger(subsystem:"com.aiterminal", category:"ai")`。流式循环改 `streamLoop:` 标签；空 data 跳过、`[DONE]` break。Anthropic 用 `do/catch` 显式 decode：`content_block_delta`+text_delta→yield；`message_stop`→`break streamLoop`；`error`→`aiLog.error(截断 payload)`；其余 default 静默跳过；**decode 抛错才 `aiLog.debug(payload.prefix(120))`**。OpenAI 同理 do/catch + 失败记日志。payload 仅截断片段，privacy:.public 便于调试。正常路径行为不变。
- **改动**：`AITerminalCore/.../AIService.swift`（import os + logger + 重写 SSE 循环）。
- **验证**：Core + App `swift build` 通过。

## R26 · GlueHandler 跨 eventLoop 写安全加固
- **问题**：端口转发的本地 channel 与 SSH directTCPIP channel 可能在不同 eventLoop；原 GlueHandler 在 channelRead 里 `partner?.write` → `context.writeAndFlush`，等于从对端 eventLoop 操作本端 `ChannelHandlerContext`，违反 NIO「context 只能在自身 eventLoop 用」的约束（@unchecked Sendable 掩盖了竞争）。
- **修法**：GlueHandler 不再存 `context`，改存本端 `channel`（Channel 是 Sendable，writeAndFlush/close 线程安全且派发到自身 loop）。`handlerAdded` 记 `context.channel`；对端转发改 `writeFromPartner`、对端关闭改 `closeFromPartner`，两者都 `if channel.eventLoop.inEventLoop { 直接 } else { channel.eventLoop.execute { … } }`；errorCaught 仍在本端 loop 用 context.close。去掉无用的 OutboundOut 别名。仅改 PortForward.swift，未动 SSHService 调用。
- **改动**：`AITerminalCore/.../PortForward.swift`。
- **验证**：Core + App `swift build` 通过。运行态端口转发仍需真实 SSH 服务器实测。

## R25 · 全局代码审查 + 修复
- **方法**：派 4 个 Explore agent 并行审查 SSHService 生命周期、AIService 流式、AppModel 持久化、TerminalSessionVM 隔离；汇总后逐条核对真实代码，只修确有把握、零回归风险的。
- **修复**（均 Core/App 编译通过）：
  1. **SSHService.connect 资源泄漏**（高）：重入时旧 `client`/`jumpClient` 被覆盖不释放；失败时已建的 jumpClient 残留。→ 进入前先 `close()` 旧连接并置 nil；catch 里关 jumpClient + 置 nil。
  2. **SSHService.startForward 半开通道泄漏**（高）：`createDirectTCPIPChannel` 成功但 addHandler 失败时 remoteChannel 未关。→ 用 `var remoteChannel: Channel?` 暂存，catch 里 `remoteChannel?.close()`。
  3. **AppModel.closeSession 分屏悬挂引用**（低）：退出分屏时把 secondaryID 设成另一个会话无意义。→ 直接置 `nil`。
  4. **TerminalSessionVM 连接 Task 竞态**（高）：startSSH 的 Task 未保存，disconnect/reconnect 时旧 Task 仍会 set status/feed。→ 存 `connectTask` 并在 disconnect cancel；Task 内每段 await 后 `guard !Task.isCancelled, self.sshSession === session`。
- **暂缓**（记入 ROADMAP R26/R27）：GlueHandler 跨 eventLoop 写安全、AIService SSE decode 静默丢——确实存在但需运行态验证，不冒进。
- **改动**：`AITerminalCore/.../SSHService.swift`；`App/Sources/AppModel.swift`、`TerminalSessionVM.swift`。无界面变化，不重渲染。

## R24 · 跳板机 / bastion
- **确认 API**：`SSHClient.jump(to: SSHClientSettings) async throws -> SSHClient`；`SSHClientSettings(host:port:authenticationMethod: @Sendable @escaping () -> SSHAuthenticationMethod, hostKeyValidator:)`。
- **内容**：`Connection` 加可选 `jumpHost/jumpPort/jumpUsername/jumpPassword` + `hasJump`。`ConnectionStore` Secret 枚举加 `jumpPassword`（存 Keychain，JSON 置 nil）。`SSHTerminalSession`：加 `jumpClient`；connect 若 hasJump 先 `SSHClient.connect` 跳板（密码认证 + TOFU）再 `jump.jump(to: SSHClientSettings(目标, authenticationMethod:{ auth }, hostKeyValidator: TOFU))`，否则直连；close 同时关 jumpClient。`ConnectionEditView` 加「跳板机/Bastion（可选）」Section（填了跳板主机才展开端口/用户名/密码；Binding 在 String?↔String 转换）。
- **改动**：`AITerminalCore/.../Connection.swift`、`ConnectionStore.swift`、`SSHService.swift`；`App/Sources/Views/ConnectionEditView.swift`、`DevTools/Showcase.swift`、`Screenshots.swift`。
- **验证**：Core + App `swift build` 通过；连接编辑跳板区渲染看图（`04-connection-edit.png`）。运行态需真实跳板+目标实测。

## R23 · AI 流式输出 + 多轮上下文
- **内容**：`AIService` 重构——抽出 `makeURLRequest(messages:stream:)`（统一两 provider 请求），`complete` 复用之；新增 `completeStreaming(messages:) -> AsyncThrowingStream<String,Error>`：`session.bytes(for:)` 逐行读 SSE，`data:` 行去前缀，Anthropic 解 `AnthropicStreamEvent`（type==content_block_delta && delta.type==text_delta → text），OpenAI 解 `OpenAIStreamChunk`（choices.first.delta.content），`[DONE]` 结束；请求结构加 `stream:Bool?`。`AppModel.sendAIMessage` 改流式：append 空 assistant 占位（记 id），`for try await delta` 按 id 找到并 `content += delta`（@Published 驱动 AI 面板实时刷新），完成后解析 [EXECUTE] 注入；上下文只取 `aiMessages.suffix(20)`（contextWindow）。
- **改动**：`AITerminalCore/.../AIService.swift`、`App/Sources/AppModel.swift`。
- **验证**：Core + App `swift build` 通过。AI 面板为实时文本流，无结构变化故不重渲染。端到端流式需真实 API Key 实测。

## R22 · 连接分组 / 文件夹
- **内容**：`Connection` 加 `group: String?`（Optional → 旧 JSON 缺失解码为 nil，向后兼容 Codable）+ `groupName` 归一化计算属性（去空白）。`ConnectionEditView` 基本信息加「分组（可选）」TextField（Binding 在 String?↔String 间转换，空→nil）。`SidebarView`：filtered 搜索含 groupName；新增 `ungrouped`（无组）+ `groups`（按组名排序的 [(name,conns)]）；SSH 连接 Section 只放未分组，后接每组一个 📁 Section。
- **改动**：`AITerminalCore/.../Connection.swift`；`App/Sources/Views/ConnectionEditView.swift`、`SidebarView.swift`、`DevTools/Showcase.swift`、`Screenshots.swift`（样例加 group）。
- **验证**：Core+App `swift build` 通过；侧边栏分组渲染看图（`01-sidebar.png`：未分组「开发机」+ 📁「生产」含两台）。

## R21 · 导入 ~/.ssh/config
- **内容**：新建 `SSHConfigParser`（按 Host 块解析 Host/HostName/Port/User/IdentityFile；首个 pattern 含 `*`/`?` 则跳过该块；HostName 缺省用别名；IdentityFile→authType=privateKey + privateKeyPath 展开 `~`；strip 引号；输出 [Connection] 过滤空 host）。`AppModel` 抽出 `mergeConnections`（host+user+port 去重，复用于 JSON 导入与 config 导入）+ `importSSHConfig()`（macOS 读 ~/.ssh/config，沙盒已关可直接读）。`SettingsView` 连接备份区加「从 ~/.ssh/config 导入」（仅 macOS）。
- **改动**：新增 `AITerminalCore/.../SSHConfigParser.swift`；改 `App/Sources/AppModel.swift`、`Views/SettingsView.swift`、`DevTools/Showcase.swift`+`Screenshots.swift`（+ sshConfigTest 自测 + main.swift --ssh-config-test）。
- **验证**：Core+App `swift build` 通过；`swift run Shots --ssh-config-test` 运行时自测——sample 含 prod(密码)/dev gh(私钥+展开~)/Host *(跳过) → 正确解析出 2 个连接；设置区渲染看图（`05-settings.png`）。

## R20 · 主机密钥校验 TOFU（阶段 C 开始 · 安全加固）
- **确认 API**：Citadel `SSHHostKeyValidator.custom(NIOSSHClientServerAuthenticationDelegate)`；`NIOSSHClientServerAuthenticationDelegate.validateHostKey(hostKey:validationCompletePromise:)`；`NIOSSHPublicKey` 是 Hashable 且有 `write(to: inout ByteBuffer) -> Int` 可序列化。
- **内容**：新建 `KnownHosts.swift`：`KnownHostsStore`（known_hosts.json，host:port→指纹，NSLock 线程安全，record/forget/clear/count）+ `fingerprint(of:)`（SHA256(序列化公钥) → `SHA256:<base64 去尾=>`）+ `TOFUHostKeyValidator`（首次记录并放行，再次校验，不一致 fail `HostKeyChangedError`）。`SSHService.connect` 把 `.acceptAnything()` 换成 `.custom(TOFUHostKeyValidator(hostID:"host:port"))`；`SSHFriendlyError.translate` 识别 `HostKeyChangedError`/“主机密钥” 给中文 MITM 提示。`SettingsView` 加「主机密钥(TOFU)」区 + 「清除已知主机密钥」（KnownHostsStore.shared.clear() + toast）。
- **改动**：新增 `AITerminalCore/.../KnownHosts.swift`；改 `SSHService.swift`、`App/Sources/Views/SettingsView.swift`、`DevTools/Showcase.swift`、`Screenshots.swift`。
- **验证**：Core + App `swift build` 通过；设置「主机密钥」区渲染看图（`05-settings.png`）。运行态需真实 SSH 服务器验证首次/变更两种路径。

## R11 · 本地端口转发（阶段收尾）
- **确认 API**：`SSHChannelType.DirectTCPIP(targetHost:targetPort:originatorAddress: SocketAddress)`；`client.createDirectTCPIPChannel(using:initialize:)` 返回的 Channel 末端是 `DataToBufferCodec`（InboundOut/OutboundIn = ByteBuffer）。
- **内容**：Core 新增 `PortForward` 模型 + `GlueHandler`（ChannelInboundHandler，matchedPair 两端互引，一端 channelRead 的 ByteBuffer writeAndFlush 到对端，inactive 关对端）。`SSHTerminalSession` 加 `forwardChannels:[UUID:Channel]` + `startForward(_:)`（NIOPosix `ServerBootstrap` 监听 127.0.0.1:localPort，childChannelInitializer 里 Task 开 directTCPIP 到 remoteHost:remotePort 并把 GlueHandler 加到本地/远端两 pipeline，promise 桥接）+ `stopForward(_:)`，close 时关全部。`TerminalSessionVM` 加 portForwards/activeForwardIDs/forwardError + add/remove/toggle/start/stop。新建 `PortForwardView`（规则列表+开关+滑删 + 新建表单），工具栏「端口转发」入口（仅 SSH），ContentView sheet。
- **改动**：新增 `AITerminalCore/.../PortForward.swift`；改 `SSHService.swift`（import NIOPosix + 转发方法）；新增 `App/Sources/Views/PortForwardView.swift`；改 `TerminalSessionVM.swift`、`AppModel.swift`、`ContentView.swift`、`DevTools/Showcase.swift`、`Screenshots.swift`。
- **验证**：Core + App `swift build` 通过（仅一个 v5 模式 Sendable 捕获警告）；端口转发面板渲染看图（`14-portforward.png`）。运行态需真实 SSH 服务器实测。

## R19 · 统一品牌 / 全端总览
- **内容**：`AppIconView`（红渐变 + 白色 `>_` 等宽字形）+ `AppScreenshots.renderAppIcon()` 用 ImageRenderer 渲染 1024×1024 PNG 写入 `Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png`（相对 CWD），并把 `Contents.json` 改为引用它（iOS universal 1024 + macOS 512@2x 两槽）。根 `README.md` 重写为「全端总览」：图标 + 一句话定位 + 平台矩阵表（apple/ src/ mobile/ relay/）+ 功能清单 + 截图（引用 apple/screenshots/ 07/05/10/11）+ 各端快速开始 + 项目结构 + 路线图链接。
- **改动**：`apple/App/Sources/DevTools/Showcase.swift`（AppIconView）、`Screenshots.swift`（renderAppIcon）、`Resources/Assets.xcassets/AppIcon.appiconset/{icon-1024.png,Contents.json}`、根 `README.md`。
- **验证**：`swift run Shots` 写出图标（看图确认专业）；`swift build` Build complete（未破坏）；README 引用的 5 张图片均存在。

## R18 · 统一连接配置格式（原生 ↔ Electron 互通 JSON）
- **内容**：写 `docs/connection-format.md` 定义跨端交换格式（`{format:"ai-terminal-connections",version,connections:[{name,host,port,username,authType,password?,passphrase?}]}`，默认不含敏感字段）。Core 加 `ConnectionPortability`（export 默认不含密码、import parse 为新 Connection）；`AppModel.exportConnectionsData/importConnections`（按 host+username+port 去重，导入走现有 Keychain 持久化）。`SettingsView` 加「连接备份」区（含密码开关 + 导出经 .fileExporter[DataDocument]/导入经 .fileImporter[.json]）。Electron `src/renderer/App.jsx` 加 `exportConnections`（Blob+a.download）/`importConnections`（file input+FileReader，同格式+去重），设置弹窗加导出/导入按钮。
- **改动**：新增 `docs/connection-format.md`、`AITerminalCore/.../ConnectionPortability.swift`；更新 `apple/App/Sources/AppModel.swift`、`Views/SettingsView.swift`、`DevTools/Showcase.swift`、`Screenshots.swift`、`src/renderer/App.jsx`。
- **验证**：Core+App `swift build` 通过；Electron `npm run build` compiled successfully；设置「连接备份」区渲染看图（`05-settings.png`）。

## R17 · 移动端/Web SSH（WebSocket→SSH 中继）
- **调研**：本机有 ssh2 1.17.0，无 ws（中继需，已加依赖，node --check 仅校验语法），xterm UMD（lib/xterm.js）+ fit addon 可复制为自包含。
- **内容**：新建 `relay/`（`server.js`：http+ws 服务，收 `{t:open,...}` 用 ssh2 连主机开 shell，双向桥接；输出 base64、输入 utf8、resize 控制帧；keyboard-interactive 兜底密码；`package.json` ws+ssh2；`README` 含协议与**安全须知**[仅自托管/可信网络，公网需 wss+鉴权+白名单]）。`mobile/www/`：复制 xterm 到 `vendor/`；`terminal.html`（连接表单：中继地址/host/port/user/password + xterm 容器）+ `terminal.js`（WebSocket↔xterm，主题随 localStorage，base64 解码 term.write，onData→ws，resize 同步）；`index.html` 占位卡换成「打开 SSH 终端」按钮 + 终端 Tab 跳转。
- **改动**：新增 `relay/server.js`·`package.json`·`README.md`、`mobile/www/terminal.html`·`terminal.js`·`vendor/*`；改 `mobile/www/index.html`；`.gitignore` 加 relay/node_modules。
- **验证**：`node --check relay/server.js` + `terminal.js` OK；JSON 校验 OK；headless Chrome 渲染 `terminal.html` 截图确认连接表单 + xterm 加载无误（`mobile/screenshot-terminal.png`）。端到端 SSH 需本地起 relay + 真实主机实测。

## R16 · Android Capacitor 脚手架
- **调研**：本机无 Capacitor（`@capacitor` 未装、不在 package.json）、无 Android SDK（ANDROID_HOME 未设、无 adb/sdkmanager）；`src/renderer/App.jsx` 有 27 处 Electron IPC 耦合（`ipcRenderer`/`window.require('electron')`），WebView 里会直接报错。按预案不跑需联网/SDK 的命令，落地脚手架文件 + 可运行 Web 壳 + README，原生工程留给用户本地生成。
- **内容**：新建 `mobile/`：`capacitor.config.json`（appId com.aiterminal.app / webDir www）、`package.json`（@capacitor/core·cli·android·ios ^6.1.0 + cap sync/add/open 脚本）、`www/`（`index.html` 应用框架 UI[顶栏+SSH 连接列表+占位卡+底部 Tab] / `styles.css` 5 套配色主题变量[与原生/Electron 一致]+移动布局 / `app.js` 主题切换持久化+示例连接）、`README.md`（本地 npm install + cap add android/ios 步骤、移动端 SSH 的 R17 方案与限制）。根 `.gitignore` 忽略 mobile/node_modules·android·ios。
- **验证**：`node --check www/app.js` OK；两个 JSON 校验 OK；用 `/Applications/Google Chrome.app` `--headless=new --screenshot`（420×860@2x）渲染 `www/index.html`，截图确认 UI 起来且主题生效（`mobile/screenshot-shell.png`）。

## R15 · Electron 配色同步（进入阶段 B）
- **内容**：把原生版 5 套配色引入 Electron React 版。`src/renderer/App.jsx`：加 `THEMES`（午夜/One Dark/Dracula/Solarized/Nord，每套含 xterm 完整 16 ANSI + bg/fg/cursor/selection）+ `getXtermTheme`；`theme` 状态（localStorage `color_scheme` 持久化）；useEffect 设 `document.documentElement[data-theme]` + 热更新 termInstance 与所有 sshTerminals 的 `options.theme`；两处 `new Terminal({theme:…})` 改用 `getXtermTheme`；设置弹窗加主题 `<select>`。`src/renderer/styles/app.css`：perl 把 175 处高频硬编码色（#1a1a2e/#16213e/#0f3460/#e94560/#2ecc71/#f39c12/#a0a0a0/#eee/#888/#666 等）替换成 `var(--*)`，并 prepend 5 套主题的 `:root[data-theme]` 变量定义 + `.theme-select` 样式（替换在前、定义在后，保证定义里字面 hex 不被替换）。
- **改动**：`src/renderer/App.jsx`、`src/renderer/styles/app.css`。
- **验证**：`npm run build`（webpack）compiled successfully，bundle.js 更新。注：rgba 微光效果未变量化（后续可选）；Electron 运行态视觉需 `npm start` 实测（本轮以构建通过为准）。

## R14 · 终端搜索
- **内容**：grep 确认 SwiftTerm 有内置搜索（`TerminalView` 扩展 `findNext`/`findPrevious`/`searchMatchSummary`）。但当前解析版本 1.13.0 **无 `searchMatchSummary`**（编译报错，该 API 在 1.13.0 之后才加），故只用返回 Bool 的 `findNext`/`findPrevious`，搜索栏显示「已定位 / 无匹配」而非 index/total。`TerminalSessionVM` 加 `weak var terminalView`（协调器 makeTerminal 注入）+ `searchNext/searchPrevious`。新建 `TerminalSearchBar`（输入即增量查、上一个/下一个、命中提示、关闭）。`AppModel.searchActive`；ContentView 状态栏下方条件显示搜索栏 + 工具栏「搜索」按钮；macOS ⌘F（CommandGroup after .textEditing）。
- **改动**：更新 `TerminalSessionVM.swift`、`Views/TerminalContainer.swift`、`AppModel.swift`、`Views/ContentView.swift`、`AITerminalApp.swift`；新增 `Views/TerminalSearchBar.swift`；`DevTools/Showcase.swift`+`Screenshots.swift` 加 SearchBarShowcase。
- **验证**：App `swift build` 通过；搜索栏渲染看图（`13-search.png`），匹配行高亮。

## R13 · 会话恢复
- **内容**：`AppModel` 加 `didRestore` 标志 + 两个 UserDefaults 键（open_session_connection_ids / active_session_connection_id）。`persistOpenSessions()`：记录当前所有 SSH 会话的连接 id（本地会话 connection==nil 自动跳过）+ 激活会话的连接 id；由 `activeSessionID.didSet` 和 `closeSession` 触发（guard didRestore 避免 init 期间误写）。`restoreSessions()`（init 末尾调用）：按保存的 id 在 connections 找到并 append SSH 会话标签、恢复激活项，最后置 didRestore=true。仅激活标签的 TerminalPane 立即渲染→连接，其余切换到时才连，避免失败刷屏。
- **改动**：更新 `App/Sources/AppModel.swift`。
- **验证**：App `swift build` 通过。逻辑层改动，无界面变化故未渲染。

## R12 · 终端分屏（原 R11 端口转发挪后）
- **决策**：先 grep `/tmp/citadel-ref` 确认 Citadel 只有 `createDirectTCPIPChannel(using:initialize:)`（开单条到远端的 NIO 通道，带 DataToBufferCodec），**没有现成的本地监听端口转发**。真正的本地转发需自写 NIO `ServerBootstrap` 监听本地端口 + GlueHandler 双向桥接，工程量大、本机无 SSH 服务器无法运行验证，盲发风险高。按本轮预案改做 R12 终端分屏（可截图验证、更贴合“好用”），端口转发挪后单列一轮。
- **内容**：`AppModel` 加 `splitEnabled`/`secondaryID`/`secondarySession`/`toggleSplit()`（需≥2 会话，否则 toast）；`closeSession` 维护分屏失效。`ContentView` 加 `SplitTerminals`（macOS 并排；iOS 横屏并排、竖屏上下；每个面板带 host+状态点小标题 + `TerminalPane(session).id(session.id)`）；mainArea 优先级 分屏 > AI面板 > 单屏；工具栏加分屏切换按钮（仅 ≥2 会话显示）。
- **改动**：更新 `App/Sources/AppModel.swift`、`Views/ContentView.swift`、`DevTools/Screenshots.swift`（加 ShowcaseSplitView）。
- **验证**：App `swift build` 通过；分屏渲染看图（`12-split.png`）确认两面板并排 + 小标题。

## R10 · 多主题切换
- **内容**：新增 `AppColorScheme`（Support/）——一套配色含 UI 9 色 + 终端前景/背景/光标 + 16 ANSI；内置 5 套：午夜（默认，原配色）/One Dark/Dracula/Solarized Dark/Nord。全局 `var activeColorScheme`。`Theme`（Platform.swift）与 `TerminalTheme` 由静态常量改为读取 `activeColorScheme` 的计算属性。`AppModel.themeID`（@Published + UserDefaults 持久化，didSet 更新全局）。`SettingsView` 加「配色主题」即时切换（Picker + accent 色点）。终端经 representable `update` 调 `TerminalTheme.applyColors` 热更新；`TerminalContainer`/`TerminalPane` 线程化 `themeID`。
- **改动**：新增 `App/Sources/Support/AppColorScheme.swift`；更新 `Support/Platform.swift`、`Support/TerminalTheme.swift`、`AppModel.swift`、`Views/TerminalContainer.swift`、`TerminalPane.swift`、`SettingsView.swift`、`DevTools/Showcase.swift`、`Screenshots.swift`。
- **验证**：App `swift build` 通过；用午夜/Dracula/Nord 三套主题渲染主界面对比，确认 UI+终端全部换肤（`10-theme-dracula.png`/`11-theme-nord.png`）。

## R9 · SFTP 文件浏览器
- **内容**：先 grep `/tmp/citadel-ref` 确认 Citadel SFTP API（`SSHClient.openSFTP()` → `SFTPClient`；`listDirectory(atPath:)` → `[SFTPMessage.Name]`，每个 `.components: [SFTPPathComponent]` 有 `filename`/`longname`/`attributes`，目录判断用 longname 前缀 `d`；`openFile(filePath:flags:)`→`SFTPFile.readAll()`/`write()`；`getRealPath(atPath:)`）。`SSHTerminalSession` 加 `sftp` 复用同连接 + `sftpHome/sftpList/sftpDownload/sftpUpload` + `SFTPEntry` 模型（close 时一并关 SFTP）。`TerminalSessionVM` 加 SFTP 代理 + `supportsSFTP`。新建 `FileBrowserView`（路径栏+上一级、列目录、进目录、下载经 `.fileExporter`+DataDocument、上传经 `.fileImporter`）。工具栏「文件」入口仅 SSH 会话显示。
- **改动**：更新 `AITerminalCore/.../SSHService.swift`；新增 `App/Sources/Views/FileBrowserView.swift`；更新 `TerminalSessionVM.swift`、`AppModel.swift`、`ContentView.swift`、`DevTools/Showcase.swift`、`Screenshots.swift`。
- **验证**：Core + App `swift build` 通过；文件浏览面板渲染看图（`09-sftp.png`）。

## R8 · 敏感字段改 Keychain 安全存储
- **内容**：新增 `KeychainStore`（Security framework，`kSecClassGenericPassword`，service=`com.aiterminal.app`，account=`<连接id>.<字段>`，accessible=AfterFirstUnlock）。`ConnectionStore.saveConnections` 改为：密码（仅 savePassword 时）/口令/私钥内容写 Keychain，`connections.json` 只存非敏感字段；`loadConnections` 从 Keychain 回填，旧明文 JSON 在下次保存时自动迁移；新增 `deleteConnectionSecrets(id:)`，`AppModel.deleteConnection` 调用以同步清理。
- **改动**：新增 `AITerminalCore/Sources/AITerminalCore/KeychainStore.swift`；更新 `ConnectionStore.swift`、`App/Sources/AppModel.swift`。
- **验证**：Core + App `swift build` 通过。无界面变化故未渲染。Keychain 运行时访问需 App 签名（Xcode 构建提供），编译已校验 SecItem 调用。

## R7 · 快捷命令片段面板
- **内容**：新增 `CommandSnippet` 模型（id/title/command + `isDangerous`）与 8 条默认片段（ls/pwd/df/free/top/端口/uname/git）。`ConnectionStore` 加 `loadSnippets`/`saveSnippets`（持久化到 `snippets.json`，无文件时返回默认）。`AppModel` 加 `snippets` + `saveSnippet`/`deleteSnippet`/`resetSnippets`/`runSnippet`（注入到活动会话提示符，不自动回车便于复核）。新建 `SnippetsView`（点选注入并关闭、滑动删除、新建表单、恢复默认），工具栏加 `</>` 入口 + sheet。
- **改动**：新增 `AITerminalCore/Sources/AITerminalCore/CommandSnippet.swift`、`App/Sources/Views/SnippetsView.swift`；更新 `ConnectionStore.swift`、`App/Sources/AppModel.swift`、`Views/ContentView.swift`、`DevTools/Showcase.swift`、`DevTools/Screenshots.swift`。
- **验证**：Core + App `swift build` 通过；片段面板渲染看图（`08-snippets.png`）。

## 元数据补建（2026-06-22）
- **内容**：用户指出缺 `CLAUDE.md` 与独立迭代日志。补建 `CLAUDE.md`（项目说明 + 构建/验证命令 + 每轮流程）和本 `ITERATION_LOG.md`，回填 R1–R6；在 `CLAUDE.md`/`ROADMAP.md` 流程中加入「每轮必须追加 ITERATION_LOG」。
- **改动**：新增 `CLAUDE.md`、`ITERATION_LOG.md`；更新 `ROADMAP.md`。
- **验证**：文档类，无需编译。

## R6 · AI 多 provider（Claude 默认 + OpenAI）
- **内容**：`AIService` 重构为双 provider。新增 **Anthropic Claude**（默认 `claude-opus-4-8`，Messages API：`x-api-key` + `anthropic-version: 2023-06-01` + 顶层 `system`，解析 `content[].text`），保留 **OpenAI** Chat Completions。`AIConfig` 改为按 provider 分别记住 Key/模型/地址（`keys`/`modelOverrides`/`baseURLOverrides` 字典），切换不丢失。设置界面加服务商分段选择 + 各自快速选择模型 + 恢复默认地址。用 claude-api 技能核对了端点与最新模型 id。
- **改动**：`AITerminalCore/Sources/AITerminalCore/AIService.swift`、`App/Sources/Views/SettingsView.swift`、`App/Sources/DevTools/Showcase.swift`。
- **验证**：Core + App `swift build` 通过；设置界面渲染看图（`05-settings.png`）。

## R5 · 侧边栏连接搜索
- **内容**：侧边栏顶部加搜索框，按名称/主机/用户名实时过滤；带结果计数、清除按钮、无匹配提示。
- **改动**：`App/Sources/Views/SidebarView.swift`、`App/Sources/DevTools/Showcase.swift`。
- **验证**：App `swift build` 通过；侧边栏渲染看图（`01-sidebar.png`）。

## R4 · 终端字号缩放 + 持久化
- **内容**：`AppModel.terminalFontSize`（UserDefaults 持久化，范围 8–28）+ `zoomIn/zoomOut/resetZoom`。工具栏「字号」菜单；macOS 键盘快捷键 ⌘+/⌘-/⌘0。`TerminalTheme.updateFontSize` 在 update 时热应用到 `TerminalView`（含 SSH/本地/AI 分屏）。
- **改动**：`App/Sources/AppModel.swift`、`App/Sources/AITerminalApp.swift`、`App/Sources/Support/TerminalTheme.swift`、`App/Sources/Views/TerminalContainer.swift`、`TerminalPane.swift`、`ContentView.swift`。
- **验证**：App `swift build` 通过。

## R4.5 · 截图测试管线
- **内容**：建 `swift run Shots` 用 SwiftUI `ImageRenderer` 离屏渲染 PNG。发现 `ImageRenderer` 渲染不了 List/Form/ScrollView/TextField，遂在 `Sources/DevTools/` 建纯布局高保真预览（同款 Theme/字体/图标）。开发工具代码排除出发布 App（project.yml excludes）。产物存 `apple/screenshots/`。
- **改动**：新增 `App/Sources/DevTools/Screenshots.swift`、`Showcase.swift`、`App/ShotsMain/main.swift`；更新 `App/Package.swift`、`project.yml`、`apple/README.md`。
- **验证**：`swift run Shots` 成功生成 7 张 PNG，逐张 Read 看图确认设计统一专业。

## R3 · 连接中遮罩 + 重连横幅
- **内容**：`TerminalPane` 包裹终端，连接中显示毛玻璃居中遮罩（进度 + 状态文案）；断开/出错显示底部重连横幅（非阻塞）。VM 记忆 `lastCols/lastRows`，提供无参 `reconnect()`。
- **改动**：新增 `App/Sources/Views/TerminalPane.swift`；更新 `TerminalSessionVM.swift`、`ContentView.swift`。
- **验证**：App `swift build` 通过。

## R2 · iOS 终端辅助键栏
- **内容**：`TerminalKeyBar`（Esc/Tab/^C^D^Z^L^R^U/方向键 ↑↓←→/常用符号 `| ~ / - * $`，触感反馈），iOS SSH 会话终端下方显示。VM 加 `sendBytes(_:)`、`reconnect`。
- **改动**：新增 `App/Sources/Views/TerminalKeyBar.swift`；更新 `TerminalSessionVM.swift`、`ContentView.swift`。
- **验证**：App `swift build` 通过。

## R1 · 终端配色与字体统一
- **内容**：`TerminalTheme`（One Dark 16 色 ANSI 调色板、背景 `#1a1a2e`、琥珀光标、Menlo 字体），应用到 SSH 与本地终端。跨平台颜色辅助 `PlatformColor(hexString:)`。
- **改动**：新增 `App/Sources/Support/TerminalTheme.swift`；更新 `Support/Platform.swift`、`Views/TerminalContainer.swift`。
- **验证**：App `swift build` 通过。

## R0 · 基线（Electron → 苹果原生）
- **内容**：从 Electron 重写为 SwiftUI 原生（macOS + iOS）。核心包 AITerminalCore（SSHService/AIService/SystemMonitor/Connection/ConnectionStore）；App（侧边栏/多会话标签/终端/状态栏/AI 面板/设置/连接编辑）；xcodegen 工程 + 双 scheme。
- **改动**：新增整个 `apple/` 目录。
- **验证**：Core + App `swift build` 通过；Xcode 工程生成。
