package com.termind.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// Termind 配色（A-Themes：读全局 activeTheme，切换主题即全局 recompose 跟随）
val Bg: Color get() = activeTheme.bg
val Surface: Color get() = activeTheme.surface
val SurfaceLight: Color get() = activeTheme.surfaceLight
val Accent: Color get() = activeTheme.accent
val TextPrimary: Color get() = activeTheme.textPrimary
val TextSecondary: Color get() = activeTheme.textSecondary
val Success: Color get() = activeTheme.success
val Warning: Color get() = activeTheme.warning
val Danger: Color get() = activeTheme.danger

// A-Rollback 时间戳：备份文件名用 yyyyMMdd-HHmmss，时间线显示用 HH:mm:ss
private fun backupStamp(): String = java.text.SimpleDateFormat("yyyyMMdd-HHmmss", java.util.Locale.US).format(java.util.Date())
private fun nowLabel(): String = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.US).format(java.util.Date())

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        activeTheme = ThemeScheme.byId(SettingsStore.loadTheme(this))  // A-Themes：启动应用已存主题
        KnownHosts.init(this)  // A-TOFU：初始化 known_hosts 指纹存储
        setContent { TermindTheme { TermindApp() } }
    }
}

@Composable
fun TermindTheme(content: @Composable () -> Unit) {
    val t = activeTheme  // 读全局主题，切换即 recompose
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = t.accent, background = t.bg, surface = t.surface,
            onPrimary = Color.White, onBackground = t.textPrimary, onSurface = t.textPrimary
        ),
        content = content
    )
}

enum class Tab(val label: String, val icon: ImageVector) {
    Servers("连接", Icons.Filled.Dns),
    AI("AI 助手", Icons.Filled.AutoAwesome),
    Settings("设置", Icons.Filled.Settings)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TermindApp() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var tab by remember { mutableStateOf(Tab.Servers) }
    var detail by remember { mutableStateOf<ServerConn?>(null) }
    // 连接列表：从 store 加载，增删改后持久化
    val conns = remember { mutableStateListOf<ServerConn>().apply { addAll(ConnectionStore.load(ctx)) } }
    var editing by remember { mutableStateOf<ServerConn?>(null) }   // 当前编辑中的连接
    var showEditor by remember { mutableStateOf(false) }
    var activeProfile by remember { mutableStateOf<ServerProfile?>(null) }  // A-Env：当前连接的环境画像，喂给 AI
    var showBatch by remember { mutableStateOf(false) }  // N-Multi 批量群发
    var showInspect by remember { mutableStateOf(false) }  // N-Cron 批量巡检
    // A-Reach：可达性探测结果 id→可达(true/false)；不在 map=探测中/未探测
    val reachMap = remember { mutableStateMapOf<String, Boolean>() }
    var probing by remember { mutableStateOf(false) }
    fun persist() = ConnectionStore.save(ctx, conns)

    // 并发探测所有连接的 TCP 可达性
    fun probeAll() {
        if (probing) return
        probing = true; reachMap.clear()
        scope.launch {
            conns.map { c -> async { c.id to Reachability.probe(c.host, c.port) } }
                .forEach { val (id, ok) = it.await(); reachMap[id] = ok }
            probing = false
        }
    }
    LaunchedEffect(Unit) { probeAll() }

    // 连接详情「工作区」覆盖在最上层
    detail?.let { conn ->
        ServerWorkspace(conn, onBack = { detail = null }, onProfile = { activeProfile = it })
        return
    }
    // N-Multi 批量群发覆盖
    if (showBatch) {
        BatchScreen(conns = conns.toList(), onBack = { showBatch = false })
        return
    }
    // N-Cron 批量巡检覆盖
    if (showInspect) {
        InspectScreen(conns = conns.toList(), onBack = { showInspect = false })
        return
    }
    // 新建/编辑表单覆盖
    if (showEditor) {
        EditConnectionScreen(
            existing = editing,
            onCancel = { showEditor = false; editing = null },
            onSave = { saved ->
                val idx = conns.indexOfFirst { it.id == saved.id }
                if (idx >= 0) conns[idx] = saved else conns.add(saved)
                persist(); showEditor = false; editing = null
            }
        )
        return
    }

    Scaffold(
        containerColor = Bg,
        bottomBar = {
            NavigationBar(containerColor = Surface) {
                Tab.values().forEach { t ->
                    NavigationBarItem(
                        selected = tab == t,
                        onClick = { tab = t },
                        icon = { Icon(t.icon, contentDescription = t.label) },
                        label = { Text(t.label, fontSize = 11.sp) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Accent, selectedTextColor = Accent,
                            indicatorColor = SurfaceLight, unselectedIconColor = TextSecondary,
                            unselectedTextColor = TextSecondary
                        )
                    )
                }
            }
        },
        floatingActionButton = {
            if (tab == Tab.Servers) {
                FloatingActionButton(onClick = { editing = null; showEditor = true }, containerColor = Accent) {
                    Icon(Icons.Filled.Add, "新建连接", tint = Color.White)
                }
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (tab) {
                Tab.Servers -> ServerListScreen(
                    conns = conns,
                    reachMap = reachMap,
                    probing = probing,
                    onRefresh = { probeAll() },
                    onBatch = { showBatch = true },
                    onInspect = { showInspect = true },
                    onExport = {
                        runCatching {
                            ctx.startActivity(android.content.Intent.createChooser(
                                android.content.Intent(android.content.Intent.ACTION_SEND).setType("application/json")
                                    .putExtra(android.content.Intent.EXTRA_TEXT, ConnectionStore.exportJson(conns.toList())), "导出连接"))
                        }
                    },
                    onImport = { imported ->
                        val existing = conns.map { "${it.user}@${it.host}:${it.port}" }.toSet()
                        imported.filter { "${it.user}@${it.host}:${it.port}" !in existing }.forEach { conns.add(it) }
                        persist()
                    },
                    onOpen = { detail = it },
                    onEdit = { editing = it; showEditor = true },
                    onDelete = { conns.remove(it); persist() }
                )
                Tab.AI -> AIAssistantScreen(onGoSettings = { tab = Tab.Settings }, profile = activeProfile)
                Tab.Settings -> SettingsScreen()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TopBar(title: String, subtitle: String? = null) {
    TopAppBar(
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Bolt, contentDescription = null, tint = Accent)
                Spacer(Modifier.width(8.dp))
                Text(title, fontWeight = FontWeight.Bold, color = TextPrimary)
                subtitle?.let {
                    Spacer(Modifier.width(8.dp))
                    Text(it, fontSize = 12.sp, color = TextSecondary)
                }
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(containerColor = Surface)
    )
}

@Composable
fun ServerListScreen(
    conns: List<ServerConn>,
    reachMap: Map<String, Boolean>,
    probing: Boolean,
    onRefresh: () -> Unit,
    onBatch: () -> Unit,
    onInspect: () -> Unit,
    onExport: () -> Unit,
    onImport: (List<ServerConn>) -> Unit,
    onOpen: (ServerConn) -> Unit,
    onEdit: (ServerConn) -> Unit,
    onDelete: (ServerConn) -> Unit
) {
    val ctxLocal = LocalContext.current
    val importPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        runCatching {
            val json = ctxLocal.contentResolver.openInputStream(uri)!!.bufferedReader().use { it.readText() }
            onImport(ConnectionStore.importJson(json))
        }
    }
    var overflow by remember { mutableStateOf(false) }
    var searchActive by remember { mutableStateOf(false) }   // A-Filter
    var search by remember { mutableStateOf("") }
    Column {
        // 顶栏 + 刷新状态
        Surface(color = Surface) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Bolt, null, tint = Accent)
                Spacer(Modifier.width(8.dp))
                Text("Termind", fontWeight = FontWeight.Bold, color = TextPrimary)
                Spacer(Modifier.width(8.dp))
                Text("智能 SSH 运维", fontSize = 12.sp, color = TextSecondary)
                Spacer(Modifier.weight(1f))
                IconButton(onClick = { searchActive = !searchActive; if (!searchActive) search = "" }, enabled = conns.isNotEmpty()) {
                    Icon(Icons.Filled.Search, "搜索连接", tint = if (searchActive) Accent else TextSecondary, modifier = Modifier.size(18.dp))
                }
                Box {
                    IconButton(onClick = { overflow = true }) { Icon(Icons.Filled.MoreVert, "更多", tint = TextSecondary) }
                    DropdownMenu(expanded = overflow, onDismissRequest = { overflow = false }) {
                        DropdownMenuItem(text = { Text("📤 导出连接") }, onClick = { overflow = false; onExport() })
                        DropdownMenuItem(text = { Text("📥 导入连接") }, onClick = { overflow = false; importPicker.launch("application/json") })
                    }
                }
                IconButton(onClick = onInspect, enabled = conns.isNotEmpty()) {
                    Icon(Icons.Filled.MonitorHeart, "健康巡检", tint = Accent, modifier = Modifier.size(18.dp))
                }
                IconButton(onClick = onBatch, enabled = conns.isNotEmpty()) {
                    Icon(Icons.Filled.Dns, "批量群发", tint = Accent, modifier = Modifier.size(18.dp))
                }
                IconButton(onClick = onRefresh, enabled = !probing) {
                    if (probing) CircularProgressIndicator(Modifier.size(16.dp), color = Accent, strokeWidth = 2.dp)
                    else Icon(Icons.Filled.Refresh, "刷新在线状态", tint = TextSecondary, modifier = Modifier.size(18.dp))
                }
            }
        }
        // A-Filter：搜索框
        if (searchActive) {
            OutlinedTextField(
                search, { search = it }, placeholder = { Text("搜索 名称/主机/用户/分组…", color = TextSecondary) }, singleLine = true,
                leadingIcon = { Icon(Icons.Filled.Search, null, tint = TextSecondary) },
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent),
                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp)
            )
        }
        if (conns.isEmpty()) {
            Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                Icon(Icons.Filled.Dns, null, tint = TextSecondary, modifier = Modifier.size(48.dp))
                Spacer(Modifier.height(12.dp))
                Text("还没有连接，点右下角 + 新建", color = TextSecondary, fontSize = 14.sp)
            }
            return
        }
        val q = search.trim()
        val shown = if (q.isEmpty()) conns else conns.filter {
            it.name.contains(q, true) || it.host.contains(q, true) || it.user.contains(q, true) || it.group.contains(q, true)
        }
        val grouped = shown.groupBy { it.group }
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            grouped.forEach { (group, list) ->
                if (group.isNotEmpty()) item { Text(group, fontSize = 12.sp, color = TextSecondary, modifier = Modifier.padding(top = 14.dp, bottom = 2.dp)) }
                items(list, key = { it.id }) { conn ->
                    ServerCard(conn, reachMap[conn.id], probing, onClick = { onOpen(conn) }, onEdit = { onEdit(conn) }, onDelete = { onDelete(conn) })
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ServerCard(conn: ServerConn, reachable: Boolean?, probing: Boolean, onClick: () -> Unit, onEdit: () -> Unit, onDelete: () -> Unit) {
    var menu by remember { mutableStateOf(false) }
    // A-Reach：在线绿 / 离线灰 / 探测中黄
    val dotColor = when {
        reachable == true -> Success
        reachable == false -> Danger
        probing -> Warning
        else -> TextSecondary
    }
    Card(
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = SurfaceLight.copy(alpha = 0.5f)),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            // A-Tags：颜色标签色条
            conn.colorTag.hex?.let { Box(Modifier.width(4.dp).height(34.dp).clip(RoundedCornerShape(2.dp)).background(Color(it))); Spacer(Modifier.width(10.dp)) }
            Icon(Icons.Filled.Circle, null, tint = dotColor, modifier = Modifier.size(10.dp))
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(conn.name, color = TextPrimary, fontWeight = FontWeight.Medium, fontSize = 15.sp)
                Text("${conn.user}@${conn.host}:${conn.port}", color = TextSecondary, fontSize = 12.sp, fontFamily = FontFamily.Monospace)
                if (conn.note.isNotEmpty()) Text("📝 ${conn.note}", color = TextSecondary.copy(alpha = 0.85f), fontSize = 11.sp)
            }
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, "更多", tint = TextSecondary) }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text("编辑") }, onClick = { menu = false; onEdit() })
                    DropdownMenuItem(text = { Text("删除") }, onClick = { menu = false; onDelete() })
                }
            }
        }
    }
}

@Composable
fun AIAssistantScreen(onGoSettings: () -> Unit, profile: ServerProfile? = null) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    // A-Convos / A-ConvoPersist：多对话（从 store 加载，变更后持久化）
    val convos = remember {
        mutableStateListOf<SnapshotStateList<Pair<String, String>>>().apply {
            ConvoStore.load(ctx).forEach { add(it.toMutableStateList()) }
            if (isEmpty()) add(mutableStateListOf())
        }
    }
    var curIdx by remember { mutableStateOf(0) }
    val messages = convos[curIdx.coerceIn(0, convos.size - 1)]
    var convoMenu by remember { mutableStateOf(false) }
    fun persistConvos() = ConvoStore.save(ctx, convos.map { it.toList() })
    fun convoTitle(c: List<Pair<String, String>>, i: Int) =
        c.firstOrNull { it.first == "user" }?.second?.take(16) ?: "新对话 ${i + 1}"
    // A-ConvoExport：当前对话导出 Markdown 并分享
    fun exportConvo() {
        if (messages.isEmpty()) return
        val md = buildString {
            append("# Termind AI 对话\n\n")
            messages.forEach { (role, content) ->
                append(if (role == "user") "## 🧑 用户\n\n" else "## 🤖 AI 助手\n\n")
                append(content); append("\n\n")
            }
        }
        runCatching {
            ctx.startActivity(android.content.Intent.createChooser(
                android.content.Intent(android.content.Intent.ACTION_SEND)
                    .setType("text/markdown").putExtra(android.content.Intent.EXTRA_TEXT, md)
                    .putExtra(android.content.Intent.EXTRA_TITLE, "Termind 对话.md"),
                "导出对话"
            ))
        }
    }
    var input by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }
    var searchActive by remember { mutableStateOf(false) }   // A-ConvoSearch
    var search by remember { mutableStateOf("") }
    val suggestions = listOf("帮我查看为什么网站打不开", "解释这条命令：docker system prune -a", "分析这段报错并给修复", "一键初始化 Ubuntu Web 服务器")

    fun send(text: String, basePrompt: String = AiClient.SYSTEM_PROMPT) {
        val t = text.trim(); if (t.isEmpty() || sending) return
        if (!SettingsStore.isConfigured(ctx)) { onGoSettings(); return }
        messages.add("user" to t); input = ""; sending = true
        // A-Env：把当前服务器环境摘要注入系统提示，让 AI 结合真实环境回答（对齐 apple Z3）
        val sys = profile?.aiSummary?.takeIf { it.isNotEmpty() }?.let {
            "$basePrompt\n\n$it\n请结合以上真实服务器环境给出针对性、可直接执行的回答。"
        } ?: basePrompt
        // A-Stream：流式逐字显示。先放一个空 assistant 消息，delta 时追加到它
        val history = messages.toList()
        val aiIndex = messages.size
        messages.add("assistant" to "")
        scope.launch {
            val r = AiClient.chatStream(SettingsStore.loadApiKey(ctx), SettingsStore.loadModel(ctx), history, sys) { delta ->
                messages[aiIndex] = "assistant" to (messages[aiIndex].second + delta)
            }
            r.onFailure { messages[aiIndex] = "assistant" to "⚠️ ${it.message ?: "请求失败"}" }
            sending = false
            persistConvos()   // A-ConvoPersist：回复完成后持久化
        }
    }

    Column {
        // A-Convos：顶栏带对话切换 + 新建
        Surface(color = Surface) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.AutoAwesome, null, tint = Accent)
                Spacer(Modifier.width(8.dp))
                Box {
                    Row(Modifier.clickable { convoMenu = true }, verticalAlignment = Alignment.CenterVertically) {
                        Text(convoTitle(messages, curIdx), fontWeight = FontWeight.Bold, color = TextPrimary, maxLines = 1)
                        Icon(Icons.Filled.ArrowDropDown, null, tint = TextSecondary)
                    }
                    DropdownMenu(expanded = convoMenu, onDismissRequest = { convoMenu = false }) {
                        convos.forEachIndexed { i, c ->
                            DropdownMenuItem(text = { Text(convoTitle(c, i), color = if (i == curIdx) Accent else TextPrimary) },
                                onClick = { curIdx = i; convoMenu = false })
                        }
                        HorizontalDivider()
                        DropdownMenuItem(text = { Text("📤 导出当前(Markdown)", color = TextPrimary) },
                            onClick = { convoMenu = false; exportConvo() })
                        DropdownMenuItem(text = { Text("➕ 新建对话", color = Accent) },
                            onClick = { convos.add(mutableStateListOf()); curIdx = convos.size - 1; convoMenu = false; persistConvos() })
                        if (convos.size > 1) DropdownMenuItem(text = { Text("🗑 删除当前", color = Danger) },
                            onClick = { convos.removeAt(curIdx); curIdx = curIdx.coerceIn(0, convos.size - 1); convoMenu = false; persistConvos() })
                    }
                }
                if (profile?.aiSummary?.isNotEmpty() == true) {
                    Spacer(Modifier.width(8.dp)); Text("已感知环境", fontSize = 12.sp, color = TextSecondary)
                }
                Spacer(Modifier.weight(1f))
                IconButton(onClick = { searchActive = !searchActive; if (!searchActive) search = "" }, enabled = messages.isNotEmpty()) {
                    Icon(Icons.Filled.Search, "搜索对话", tint = if (searchActive) Accent else TextSecondary)
                }
                IconButton(onClick = { convos.add(mutableStateListOf()); curIdx = convos.size - 1; persistConvos() }) {
                    Icon(Icons.Filled.Add, "新建对话", tint = TextSecondary)
                }
            }
        }
        // A-ConvoSearch：搜索框
        if (searchActive) {
            OutlinedTextField(
                search, { search = it }, placeholder = { Text("搜索当前对话…", color = TextSecondary) }, singleLine = true,
                leadingIcon = { Icon(Icons.Filled.Search, null, tint = TextSecondary) },
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent),
                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp)
            )
        }
        if (messages.isEmpty()) {
            Column(Modifier.weight(1f).fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("让 AI 结合服务器真实环境帮你运维", color = TextSecondary, fontSize = 13.sp)
                suggestions.forEach { s ->
                    Card(onClick = { send(s) }, colors = CardDefaults.cardColors(containerColor = SurfaceLight.copy(alpha = 0.45f)), shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
                        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.AutoAwesome, null, tint = Accent, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(10.dp))
                            Text(s, color = TextPrimary, fontSize = 13.sp)
                        }
                    }
                }
            }
        } else {
            // A-ConvoSearch：搜索时只显匹配的消息
            val q = search.trim()
            val shown = if (q.isEmpty()) messages.toList() else messages.filter { it.second.contains(q, ignoreCase = true) }
            LazyColumn(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (q.isNotEmpty()) item { Text("${shown.size} 条匹配", color = TextSecondary, fontSize = 11.sp, modifier = Modifier.padding(4.dp)) }
                items(shown.size) { i -> ChatBubble(shown[i].first, shown[i].second) }
                if (sending && q.isEmpty()) item { Text("AI 思考中…", color = TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(8.dp)) }
            }
        }
        // A-AIActions：命令解释 / 报错分析 快捷入口（对齐 apple AIAgentView）
        Row(Modifier.padding(horizontal = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            AssistChip(
                onClick = { send(input, AiClient.EXPLAIN_PROMPT) },
                label = { Text("解释命令", fontSize = 12.sp) },
                leadingIcon = { Icon(Icons.Filled.Lightbulb, null, tint = Warning, modifier = Modifier.size(16.dp)) },
                colors = AssistChipDefaults.assistChipColors(containerColor = SurfaceLight.copy(alpha = 0.45f), labelColor = TextPrimary)
            )
            AssistChip(
                onClick = { send(input, AiClient.ERROR_PROMPT) },
                label = { Text("分析报错", fontSize = 12.sp) },
                leadingIcon = { Icon(Icons.Filled.BugReport, null, tint = Danger, modifier = Modifier.size(16.dp)) },
                colors = AssistChipDefaults.assistChipColors(containerColor = SurfaceLight.copy(alpha = 0.45f), labelColor = TextPrimary)
            )
        }
        // 输入栏
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                input, { input = it }, placeholder = { Text("用自然语言描述运维任务…", color = TextSecondary) }, singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent),
                modifier = Modifier.weight(1f)
            )
            FilledIconButton(onClick = { send(input) }, colors = IconButtonDefaults.filledIconButtonColors(containerColor = Accent)) {
                if (sending) CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                else Icon(Icons.Filled.ArrowUpward, "发送", tint = Color.White)
            }
        }
    }
}

@Composable
private fun ChatBubble(role: String, content: String) {
    val isUser = role == "user"
    val clipboard = LocalClipboardManager.current
    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start) {
        Surface(
            color = if (isUser) Accent.copy(alpha = 0.25f) else SurfaceLight.copy(alpha = 0.5f),
            shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth(0.85f)
        ) {
            // A-Md：按 ``` 围栏拆出代码块，单独渲染等宽深色框（便于看/复制运维命令）
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                val parts = content.split("```")
                parts.forEachIndexed { i, part ->
                    if (i % 2 == 1) {
                        // 代码块：去掉可能的语言行
                        val code = part.trimStart().substringAfter('\n', part).ifBlank { part.trim() }
                        // A-Copy：点击代码块复制到剪贴板
                        Surface(color = Color(0xFF0D0D1A), shape = RoundedCornerShape(8.dp), modifier = Modifier.fillMaxWidth()) {
                            Box {
                                Text(code.trim(), color = Success, fontSize = 12.sp, fontFamily = FontFamily.Monospace,
                                    modifier = Modifier.padding(10.dp).horizontalScroll(rememberScrollState()))
                                Icon(Icons.Filled.ContentCopy, "复制",
                                    tint = TextSecondary,
                                    modifier = Modifier.align(Alignment.TopEnd).padding(4.dp).size(16.dp)
                                        .clickable { clipboard.setText(androidx.compose.ui.text.AnnotatedString(code.trim())) })
                            }
                        }
                    } else if (part.isNotBlank()) {
                        Text(part.trim(), color = TextPrimary, fontSize = 13.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun SettingsScreen() {
    val ctx = LocalContext.current
    var apiKey by remember { mutableStateOf(SettingsStore.loadApiKey(ctx)) }
    var editingKey by remember { mutableStateOf(false) }
    var keyInput by remember { mutableStateOf("") }
    var pickingTheme by remember { mutableStateOf(false) }

    // A-Themes：主题选择
    if (pickingTheme) {
        AlertDialog(
            onDismissRequest = { pickingTheme = false },
            title = { Text("配色主题", color = TextPrimary) },
            text = {
                Column {
                    ThemeScheme.builtins.forEach { th ->
                        Row(
                            Modifier.fillMaxWidth().clickable {
                                activeTheme = th; SettingsStore.saveTheme(ctx, th.id); pickingTheme = false
                            }.padding(vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            // 配色预览点
                            listOf(th.bg, th.surface, th.accent, th.success).forEach {
                                Box(Modifier.size(14.dp).clip(androidx.compose.foundation.shape.CircleShape).background(it))
                                Spacer(Modifier.width(3.dp))
                            }
                            Spacer(Modifier.width(8.dp))
                            Text(th.name, color = TextPrimary, fontSize = 14.sp, modifier = Modifier.weight(1f))
                            if (activeTheme.id == th.id) Icon(Icons.Filled.Check, null, tint = Accent, modifier = Modifier.size(18.dp))
                        }
                    }
                }
            },
            confirmButton = { TextButton(onClick = { pickingTheme = false }) { Text("关闭", color = Accent) } },
            containerColor = Surface
        )
    }

    if (editingKey) {
        AlertDialog(
            onDismissRequest = { editingKey = false },
            title = { Text("配置 API Key", color = TextPrimary) },
            text = {
                OutlinedTextField(keyInput, { keyInput = it }, placeholder = { Text("sk-ant-…", color = TextSecondary) }, singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent))
            },
            confirmButton = { TextButton(onClick = { SettingsStore.saveApiKey(ctx, keyInput); apiKey = keyInput.trim(); editingKey = false }) { Text("保存", color = Accent) } },
            dismissButton = { TextButton(onClick = { editingKey = false }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
    }

    Column {
        TopBar("设置")
        Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SettingRow(Icons.Filled.Palette, "配色主题", activeTheme.name) { pickingTheme = true }
            SettingRow(Icons.Filled.SmartToy, "AI 服务商", "Anthropic Claude")
            SettingRow(Icons.Filled.Key, "API Key", if (apiKey.isBlank()) "未配置（点击设置）" else "已配置 ••••${apiKey.takeLast(4)}") { keyInput = apiKey; editingKey = true }
            // N-CronAuto：定时后台巡检开关
            var autoInspect by remember { mutableStateOf(SettingsStore.loadAutoInspect(ctx)) }
            val notifPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }
            Surface(color = SurfaceLight.copy(alpha = 0.4f), shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.MonitorHeart, null, tint = Accent, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text("定时后台巡检", color = TextPrimary, fontSize = 14.sp)
                        Text("每 15 分钟探测服务器在线，离线通知", color = TextSecondary, fontSize = 11.sp)
                    }
                    Switch(checked = autoInspect, onCheckedChange = { on ->
                        autoInspect = on; SettingsStore.saveAutoInspect(ctx, on)
                        if (on) {
                            if (android.os.Build.VERSION.SDK_INT >= 33) notifPerm.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                            InspectWorker.enable(ctx)
                        } else InspectWorker.disable(ctx)
                    }, colors = SwitchDefaults.colors(checkedThumbColor = Accent, checkedTrackColor = Accent.copy(alpha = 0.4f)))
                }
            }
            SettingRow(Icons.Filled.Info, "关于 Termind", "智能 SSH 运维工作台 v1.0")
        }
    }
}

@Composable
private fun SettingRow(icon: ImageVector, title: String, value: String, onClick: (() -> Unit)? = null) {
    Surface(
        color = SurfaceLight.copy(alpha = 0.4f), shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().let { if (onClick != null) it.clickable { onClick() } else it }
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = Accent, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(12.dp))
            Text(title, color = TextPrimary, fontSize = 14.sp, modifier = Modifier.weight(1f))
            Text(value, color = TextSecondary, fontSize = 12.sp)
        }
    }
}

/** 连接状态（A1b 交互式 PTY 终端） */
enum class ConnState { DISCONNECTED, CONNECTING, CONNECTED, ERROR }

/** 连接后「工作区」：交互式 PTY shell + 终端输出 + 状态面板 + AI 入口（A1b） */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ServerWorkspace(conn: ServerConn, onBack: () -> Unit, onProfile: (ServerProfile) -> Unit = {}) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var password by remember { mutableStateOf("") }       // 密码认证
    var privateKey by remember { mutableStateOf("") }      // A-KeyAuth 私钥（PEM，临时输入不持久化）
    fun keyArg(): String? = if (conn.authType == AuthType.KEY) privateKey.takeIf { it.isNotBlank() } else null
    var command by remember { mutableStateOf("") }
    var output by remember { mutableStateOf("提示：输入密码后点「连接」建立交互式 SSH 会话。\n") }
    var state by remember { mutableStateOf(ConnState.DISCONNECTED) }
    var pendingConfirm by remember { mutableStateOf<String?>(null) }  // 高危命令二次确认
    var shellSession by remember { mutableStateOf<SshShellSession?>(null) }
    var status by remember { mutableStateOf(ServerStatus()) }  // A-Status 真实状态
    var refreshing by remember { mutableStateOf(false) }
    var showFiles by remember { mutableStateOf(false) }  // A-SFTP 文件浏览
    var pendingTemplate by remember { mutableStateOf<SetupTemplate?>(null) }  // A-Tpl-Exec 待确认模板
    val opTimeline = remember { mutableStateListOf<OpTimelineEntry>() }  // A-Rollback 操作时间线
    var showTimeline by remember { mutableStateOf(false) }
    var showHealthAI by remember { mutableStateOf(false) }  // A-HealthAI 状态↔AI 联动
    var showForward by remember { mutableStateOf(false) }   // A-Forward 端口转发对话框
    var forwardHandle by remember { mutableStateOf<PortForwardHandle?>(null) }
    var forwardLabel by remember { mutableStateOf<String?>(null) }
    var showHistory by remember { mutableStateOf(false) }   // N-History 命令历史
    val cmdHistory = remember { mutableStateListOf<String>().apply { addAll(CommandHistory.load(ctx)) } }
    var termFont by remember { mutableStateOf(SettingsStore.loadTermFont(ctx)) }   // A-FontSize 终端字号

    // 采集服务器状态（CPU/内存/磁盘）
    fun refreshStatus() {
        if ((password.isBlank() && keyArg() == null) || refreshing) return
        refreshing = true
        scope.launch {
            SshClient.fetchStatus(conn.host, conn.port, conn.user, password, keyArg())
                .onSuccess { status = it }
            refreshing = false
        }
    }

    // 建立交互式 shell 会话
    fun connect() {
        if (state == ConnState.CONNECTING || state == ConnState.CONNECTED) return
        if (password.isBlank() && keyArg() == null) { output += "⚠️ 请先输入${if (conn.authType == AuthType.KEY) "私钥" else "密码"}\n"; return }
        state = ConnState.CONNECTING
        output += "正在连接 ${conn.user}@${conn.host}:${conn.port} …\n"
        scope.launch {
            runCatching {
                SshClient.openShell(conn.host, conn.port, conn.user, password, scope, keyArg()) { chunk ->
                    output += Redactor.redact(chunk)   // A3：输出脱敏
                }
            }.onSuccess {
                shellSession = it; state = ConnState.CONNECTED
                refreshStatus()   // 连接成功后采集状态
                // A-Env：探测环境画像 → 上报给 AI
                scope.launch {
                    SshClient.fetchEnv(conn.host, conn.port, conn.user, password, keyArg()).onSuccess { p ->
                        onProfile(p)
                        if (p.aiSummary.isNotEmpty()) output += "🔎 ${p.aiSummary}\n"
                    }
                }
            }.onFailure {
                output += "⚠️ 连接失败：${it.message}\n"; state = ConnState.ERROR
            }
        }
    }
    // 断开
    fun disconnect() {
        shellSession?.close(); shellSession = null; state = ConnState.DISCONNECTED
        output += "\n[已断开连接]\n"
    }
    // 发送命令到交互 shell（A-Rollback：改关键配置前自动备份+记时间线）
    fun send(cmd: String) {
        val s = shellSession ?: return
        // N-History：记录命令历史
        if (cmd.trim().isNotEmpty()) { cmdHistory.clear(); cmdHistory.addAll(CommandHistory.add(ctx, cmd)) }
        val targets = OpRollback.criticalTargets(cmd)
        if (targets.isNotEmpty()) {
            val stamp = backupStamp()
            OpRollback.backupCommands(cmd, stamp).forEach { s.write(it + "\n") }
            targets.forEach { t ->
                opTimeline.add(0, OpTimelineEntry(nowLabel(), "改关键配置：$t", cmd, true, "$t.bak-$stamp"))
            }
            output += "⚠️ 检测到改动关键配置，已先备份（可在「时间线」回滚）\n"
        }
        s.write(cmd + "\n")
        command = ""
    }
    // 回滚一条时间线操作（注入还原命令到 shell）
    fun rollback(entry: OpTimelineEntry) {
        val rb = entry.rollbackCommand ?: return
        shellSession?.write(rb + "\n")
        output += "↩️ 已注入回滚命令：$rb\n"
    }
    // 提交：未连先连；已连则高危确认后发送
    fun submit() {
        if (state != ConnState.CONNECTED) { connect(); return }
        val cmd = command.trim(); if (cmd.isEmpty()) return
        if (CommandRisk.riskLevel(cmd).needsConfirm) pendingConfirm = cmd else send(cmd)
    }

    // 排障工作流：真实执行各诊断命令 → AI 总结结论（A3b 升级）
    fun runDiagnostic(wf: DiagnosticWorkflow) {
        if (password.isBlank() && keyArg() == null) { output += "⚠️ 请先输入登录凭据（排障需连接执行）\n"; return }
        output += "\n🩺 执行排障「${wf.name}」…\n"
        scope.launch {
            // 一次性跑所有命令（用分隔符串起），按分隔符拆回各命令输出
            val joined = wf.joinedCommand(DiagnosticWorkflow.SEP)
            val r = SshClient.connectAndExec(conn.host, conn.port, conn.user, password, joined, timeoutMs = 30_000, privateKey = keyArg())
            r.onSuccess { raw ->
                val outs = raw.split(DiagnosticWorkflow.SEP)
                output += Redactor.redact(raw.replace(DiagnosticWorkflow.SEP, "──────")) + "\n"
                if (SettingsStore.isConfigured(ctx)) {
                    output += "\n🤖 AI 分析中…\n"
                    val sys = wf.summaryPrompt
                    val ai = AiClient.chat(SettingsStore.loadApiKey(ctx), SettingsStore.loadModel(ctx),
                        listOf("user" to wf.composeForAI(outs)), sys)
                    output += "【AI 结论】\n" + ai.getOrElse { "⚠️ ${it.message}" } + "\n"
                } else {
                    output += "（配置 API Key 后可由 AI 自动总结结论）\n"
                }
            }.onFailure { output += "⚠️ 排障执行失败：${it.message}\n" }
        }
    }

    // 初始化模板真执行：按步骤逐条跑命令 + 终端逐步反馈（A-Tpl-Exec，对齐 apple U-Z8）
    fun runSetupTemplate(tpl: SetupTemplate) {
        if (password.isBlank() && keyArg() == null) { output += "⚠️ 请先输入登录凭据（模板需连接执行）\n"; return }
        output += "\n📦 执行模板「${tpl.name}」（${tpl.steps.size} 步）…\n"
        scope.launch {
            for ((i, step) in tpl.steps.withIndex()) {
                val cmds = step.commands.filterNot { it.trimStart().startsWith("#") }
                if (cmds.isEmpty()) { output += "\n▶ ${i + 1}. ${step.title}（跳过：仅注释）\n"; continue }
                output += "\n▶ ${i + 1}. ${step.title}\n"
                // sudo/交互 MVP 直接跑（TODO：sudo 密码/交互处理）
                val r = SshClient.connectAndExec(conn.host, conn.port, conn.user, password, cmds.joinToString(" && "), timeoutMs = 60_000, privateKey = keyArg())
                output += Redactor.redact(r.getOrElse { "⚠️ ${it.message}" }).trim().ifBlank { "(完成)" } + "\n"
            }
            output += "\n✅ 模板「${tpl.name}」执行完毕\n"
            refreshStatus()
        }
    }

    // A-Tpl-Exec：模板执行前确认（显示 previewText + 风险）
    pendingTemplate?.let { tpl ->
        AlertDialog(
            onDismissRequest = { pendingTemplate = null },
            icon = { Icon(Icons.Filled.Dns, null, tint = tpl.risk.color) },
            title = { Text(tpl.name, color = TextPrimary) },
            text = {
                Column(Modifier.heightIn(max = 360.dp).verticalScroll(rememberScrollState())) {
                    Text(tpl.previewText(), color = TextSecondary, fontSize = 12.sp, fontFamily = FontFamily.Monospace)
                }
            },
            confirmButton = { TextButton(onClick = { val t = tpl; pendingTemplate = null; runSetupTemplate(t) }) { Text("执行", color = tpl.risk.color) } },
            dismissButton = { TextButton(onClick = { pendingTemplate = null }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
    }

    // A-SFTP 文件浏览 sheet
    if (showFiles) {
        SftpBrowser(conn, password, keyArg(), onClose = { showFiles = false })
    }

    // A-Rollback 操作时间线 sheet
    if (showTimeline) {
        ModalBottomSheet(onDismissRequest = { showTimeline = false }, containerColor = Bg) {
            Column(Modifier.fillMaxWidth().padding(16.dp).heightIn(min = 200.dp, max = 480.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.History, null, tint = Accent)
                    Spacer(Modifier.width(8.dp))
                    Text("操作时间线", color = TextPrimary, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.height(8.dp))
                if (opTimeline.isEmpty()) {
                    Text("暂无关键操作。改动 nginx/sshd/mysql 等关键配置时会自动备份并记录于此，可一键回滚。", color = TextSecondary, fontSize = 13.sp)
                } else {
                    LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(opTimeline.size) { i ->
                            val e = opTimeline[i]
                            Surface(color = SurfaceLight.copy(alpha = 0.4f), shape = RoundedCornerShape(10.dp), modifier = Modifier.fillMaxWidth()) {
                                Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Column(Modifier.weight(1f)) {
                                        Text("${e.time} · ${e.action}", color = TextPrimary, fontSize = 13.sp)
                                        Text(e.command, color = TextSecondary, fontSize = 11.sp, fontFamily = FontFamily.Monospace, maxLines = 1)
                                    }
                                    if (e.rollbackable && state == ConnState.CONNECTED) {
                                        TextButton(onClick = { rollback(e) }) { Text("回滚", color = Accent, fontSize = 12.sp) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // A-HealthAI：状态↔AI 联动 sheet（流式分析当前服务器状态）
    if (showHealthAI) {
        HealthAISheet(status, onClose = { showHealthAI = false })
    }

    // A-Forward：端口转发对话框
    if (showForward) {
        PortForwardDialog(
            existing = forwardLabel,
            onClose = { showForward = false },
            onStop = { forwardHandle?.close(); forwardHandle = null; forwardLabel = null; showForward = false },
            onStart = { lp, rh, rp ->
                if (password.isBlank() && keyArg() == null) { output += "⚠️ 请先输入登录凭据\n"; showForward = false; return@PortForwardDialog }
                scope.launch {
                    runCatching {
                        SshClient.openForward(conn.host, conn.port, conn.user, password, lp, rh, rp, scope, keyArg())
                    }.onSuccess { forwardHandle = it; forwardLabel = "127.0.0.1:$lp → $rh:$rp"; output += "🔀 端口转发已建立：$forwardLabel\n" }
                        .onFailure { output += "⚠️ 端口转发失败：${it.message}\n" }
                    showForward = false
                }
            }
        )
    }

    // N-History：命令历史 sheet
    if (showHistory) {
        ModalBottomSheet(onDismissRequest = { showHistory = false }, containerColor = Bg) {
            Column(Modifier.fillMaxWidth().padding(16.dp).heightIn(min = 200.dp, max = 520.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.History, null, tint = Accent)
                    Spacer(Modifier.width(8.dp))
                    Text("命令历史", color = TextPrimary, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    TextButton(onClick = { CommandHistory.clear(ctx); cmdHistory.clear(); showHistory = false }) { Text("清空", color = Danger, fontSize = 12.sp) }
                }
                Spacer(Modifier.height(8.dp))
                LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    items(cmdHistory.size) { i ->
                        val h = cmdHistory[i]
                        val risk = CommandRisk.riskLevel(h)
                        Row(
                            Modifier.fillMaxWidth().clickable { command = h; showHistory = false }.padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Filled.Circle, null, tint = risk.color, modifier = Modifier.size(8.dp))
                            Spacer(Modifier.width(10.dp))
                            Text(h, color = TextPrimary, fontSize = 13.sp, fontFamily = FontFamily.Monospace, modifier = Modifier.weight(1f), maxLines = 1)
                            IconButton(onClick = { cmdHistory.clear(); cmdHistory.addAll(CommandHistory.remove(ctx, h)) }, modifier = Modifier.size(28.dp)) {
                                Icon(Icons.Filled.Close, "删除", tint = TextSecondary, modifier = Modifier.size(14.dp))
                            }
                        }
                    }
                }
            }
        }
    }

    // 离开工作区时关闭会话/转发，避免泄漏
    DisposableEffect(Unit) { onDispose { shellSession?.close(); forwardHandle?.close() } }

    // 高危二次确认弹窗
    pendingConfirm?.let { cmd ->
        val risk = CommandRisk.riskLevel(cmd)
        AlertDialog(
            onDismissRequest = { pendingConfirm = null },
            icon = { Icon(Icons.Filled.Warning, null, tint = risk.color) },
            title = { Text("${risk.label}命令", color = TextPrimary) },
            text = { Text("即将执行：\n$cmd\n\n该命令为${risk.label}操作，确认执行？", color = TextSecondary) },
            confirmButton = { TextButton(onClick = { pendingConfirm = null; send(cmd) }) { Text("确认执行", color = risk.color) } },
            dismissButton = { TextButton(onClick = { pendingConfirm = null }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
    }

    val termColors = OutlinedTextFieldDefaults.colors(
        focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight,
        focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent,
        focusedLabelColor = Accent, unfocusedLabelColor = TextSecondary
    )

    Scaffold(
        containerColor = Bg,
        topBar = {
            TopAppBar(
                title = { Column { Text(conn.name, color = TextPrimary, fontSize = 16.sp, fontWeight = FontWeight.Bold); Text("${conn.user}@${conn.host}:${conn.port}", color = TextSecondary, fontSize = 11.sp, fontFamily = FontFamily.Monospace) } },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, null, tint = TextPrimary) } },
                actions = {
                    // A-Forward：端口转发（有活动转发则高亮）
                    IconButton(onClick = { showForward = true }) {
                        Icon(Icons.Filled.SwapHoriz, "端口转发", tint = if (forwardHandle != null) Accent else TextSecondary)
                    }
                    // A-Rollback：操作时间线（有记录才高亮）
                    IconButton(onClick = { showTimeline = true }) {
                        Icon(Icons.Filled.History, "时间线", tint = if (opTimeline.isEmpty()) TextSecondary.copy(alpha = 0.5f) else Accent)
                    }
                    // A-SFTP：文件浏览（仅已连接可用）
                    IconButton(onClick = { if (state == ConnState.CONNECTED) showFiles = true }, enabled = state == ConnState.CONNECTED) {
                        Icon(Icons.Filled.Folder, "文件", tint = if (state == ConnState.CONNECTED) TextSecondary else TextSecondary.copy(alpha = 0.3f))
                    }
                    // A3b：一键排障
                    var diagMenu by remember { mutableStateOf(false) }
                    Box {
                        IconButton(onClick = { diagMenu = true }) { Icon(Icons.Filled.MonitorHeart, "排障", tint = TextSecondary) }
                        DropdownMenu(expanded = diagMenu, onDismissRequest = { diagMenu = false }) {
                            DropdownMenuItem(enabled = false, text = { Text("一键排障（真跑+AI总结）", color = TextSecondary, fontSize = 12.sp) }, onClick = {})
                            DiagnosticWorkflow.builtins.forEach { wf ->
                                DropdownMenuItem(text = { Text(wf.name) }, onClick = { diagMenu = false; runDiagnostic(wf) })
                            }
                        }
                    }
                    // A3b：初始化模板
                    var tplMenu by remember { mutableStateOf(false) }
                    Box {
                        IconButton(onClick = { tplMenu = true }) { Icon(Icons.Filled.Dns, "初始化模板", tint = TextSecondary) }
                        DropdownMenu(expanded = tplMenu, onDismissRequest = { tplMenu = false }) {
                            DropdownMenuItem(enabled = false, text = { Text("初始化模板（确认后真执行）", color = TextSecondary, fontSize = 12.sp) }, onClick = {})
                            SetupTemplate.builtins.forEach { tpl ->
                                DropdownMenuItem(text = { Text(tpl.name) }, onClick = { tplMenu = false; pendingTemplate = tpl })
                            }
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Surface)
            )
        }
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize().padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // 连接状态条
            Surface(color = SurfaceLight.copy(alpha = 0.5f), shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
                Row(Modifier.padding(14.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    val (dot, label) = when (state) {
                        ConnState.CONNECTED -> Success to "已连接 · 交互式 shell"
                        ConnState.CONNECTING -> Warning to "连接中…"
                        ConnState.ERROR -> Danger to "连接失败"
                        ConnState.DISCONNECTED -> TextSecondary to "未连接"
                    }
                    Icon(Icons.Filled.Circle, null, tint = dot, modifier = Modifier.size(9.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(label, color = TextPrimary, fontSize = 13.sp, modifier = Modifier.weight(1f))
                    if (state == ConnState.CONNECTED) {
                        TextButton(onClick = { disconnect() }) { Text("断开", color = Danger, fontSize = 12.sp) }
                    }
                }
            }
            // A-Status：真实状态面板（连接后采集 top/free/df）
            if (state == ConnState.CONNECTED) {
                Surface(color = SurfaceLight.copy(alpha = 0.5f), shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
                    Row(Modifier.padding(14.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                        StatCell("CPU", status.cpu, if ((status.cpuPercent ?: 0) > 85) Danger else Success)
                        StatCell("内存", status.mem, Warning)
                        StatCell("磁盘", status.disk, if ((status.diskPercent ?: 0) > 85) Danger else Success)
                        // A-HealthAI：问 AI（有告警高亮）
                        IconButton(onClick = { if (status.healthSummary.isNotEmpty()) showHealthAI = true }) {
                            Icon(if (status.hasWarning) Icons.Filled.Warning else Icons.Filled.AutoAwesome,
                                "问 AI", tint = if (status.hasWarning) Danger else Accent, modifier = Modifier.size(18.dp))
                        }
                        IconButton(onClick = { refreshStatus() }, enabled = !refreshing) {
                            if (refreshing) CircularProgressIndicator(Modifier.size(16.dp), color = Accent, strokeWidth = 2.dp)
                            else Icon(Icons.Filled.Refresh, "刷新状态", tint = Accent, modifier = Modifier.size(18.dp))
                        }
                    }
                }
            }
            // 登录凭据（仅未连接时显示；A-KeyAuth：按 authType 显密码或私钥框）
            if (state != ConnState.CONNECTED) {
                if (conn.authType == AuthType.KEY) {
                    val keyPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
                        if (uri != null) runCatching {
                            privateKey = ctx.contentResolver.openInputStream(uri)!!.bufferedReader().use { it.readText() }
                        }
                    }
                    Column {
                        OutlinedTextField(
                            privateKey, { privateKey = it },
                            label = { Text("SSH 私钥（PEM，临时输入不保存）") },
                            colors = termColors, modifier = Modifier.fillMaxWidth().heightIn(max = 120.dp),
                            textStyle = androidx.compose.ui.text.TextStyle(fontFamily = FontFamily.Monospace, fontSize = 11.sp)
                        )
                        TextButton(onClick = { keyPicker.launch("*/*") }) {
                            Icon(Icons.Filled.AttachFile, null, tint = Accent, modifier = Modifier.size(14.dp))
                            Spacer(Modifier.width(4.dp)); Text("从文件选择私钥", color = Accent, fontSize = 12.sp)
                        }
                    }
                } else {
                    OutlinedTextField(
                        password, { password = it }, label = { Text("SSH 密码") }, singleLine = true,
                        visualTransformation = androidx.compose.ui.text.input.PasswordVisualTransformation(),
                        colors = termColors, modifier = Modifier.fillMaxWidth()
                    )
                }
            }
            // 终端输出区（A-Ansi 彩色 + A-FontSize 可调字号）
            Surface(color = Color(0xFF0D0D1A), shape = RoundedCornerShape(12.dp), modifier = Modifier.weight(1f).fillMaxWidth()) {
                Box {
                    Text(
                        AnsiParser.parse(output), fontSize = termFont.sp, fontFamily = FontFamily.Monospace,
                        modifier = Modifier.padding(14.dp).verticalScroll(rememberScrollState())
                    )
                    // A-FontSize：字号 +/-
                    Row(Modifier.align(Alignment.TopEnd).padding(4.dp)) {
                        IconButton(onClick = { termFont = (termFont - 1).coerceIn(8, 22); SettingsStore.saveTermFont(ctx, termFont) }, modifier = Modifier.size(28.dp)) {
                            Icon(Icons.Filled.Remove, "缩小", tint = TextSecondary, modifier = Modifier.size(16.dp))
                        }
                        IconButton(onClick = { termFont = (termFont + 1).coerceIn(8, 22); SettingsStore.saveTermFont(ctx, termFont) }, modifier = Modifier.size(28.dp)) {
                            Icon(Icons.Filled.Add, "放大", tint = TextSecondary, modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }
            // A-Keys：终端控制键栏（已连接时显示，移动端无 Ctrl/Tab/方向键，直发控制字符到 PTY）
            if (state == ConnState.CONNECTED) {
                val keys = listOf(
                    "Tab" to "\t", "Esc" to "", "Ctrl+C" to "", "Ctrl+D" to "",
                    "Ctrl+L" to "", "Ctrl+Z" to "", "↑" to "[A", "↓" to "[B",
                    "←" to "[D", "→" to "[C", "Ctrl+A" to "", "Ctrl+E" to ""
                )
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    keys.forEach { (label, seq) ->
                        AssistChip(
                            onClick = { shellSession?.write(seq) },
                            label = { Text(label, fontSize = 11.sp, fontFamily = FontFamily.Monospace) },
                            colors = AssistChipDefaults.assistChipColors(containerColor = Surface, labelColor = Accent)
                        )
                    }
                }
            }
            // A-Snippets：快捷命令横滑 Chip（已连接时显示，点击填入命令框，带风险色）
            if (state == ConnState.CONNECTED) {
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    CommandSnippet.defaults.forEach { sn ->
                        AssistChip(
                            onClick = { command = sn.command },
                            label = { Text(sn.title, fontSize = 11.sp) },
                            leadingIcon = { Icon(Icons.Filled.Circle, null, tint = sn.risk.color, modifier = Modifier.size(8.dp)) },
                            colors = AssistChipDefaults.assistChipColors(containerColor = SurfaceLight.copy(alpha = 0.45f), labelColor = TextPrimary)
                        )
                    }
                }
            }
            // A3：命令实时风险徽章
            if (command.trim().isNotEmpty()) {
                val risk = CommandRisk.riskLevel(command.trim())
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.Filled.Circle, null, tint = risk.color, modifier = Modifier.size(9.dp))
                    Text("风险：${risk.label}", color = risk.color, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                    if (risk.needsConfirm) Text("· 执行前需确认", color = TextSecondary, fontSize = 11.sp)
                }
            }
            // 命令输入 + 执行（已连接才可输命令；未连接显示「连接」）
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (state == ConnState.CONNECTED) {
                    // N-History：调出历史
                    IconButton(onClick = { showHistory = true }, enabled = cmdHistory.isNotEmpty()) {
                        Icon(Icons.Filled.History, "命令历史", tint = if (cmdHistory.isEmpty()) TextSecondary.copy(alpha = 0.4f) else Accent)
                    }
                    OutlinedTextField(
                        command, { command = it }, label = { Text("命令") }, singleLine = true,
                        colors = termColors, modifier = Modifier.weight(1f)
                    )
                    FilledIconButton(
                        onClick = { submit() },
                        colors = IconButtonDefaults.filledIconButtonColors(containerColor = Accent)
                    ) { Icon(Icons.Filled.ArrowUpward, "发送", tint = Color.White) }
                } else {
                    Button(
                        onClick = { connect() },
                        enabled = state != ConnState.CONNECTING,
                        colors = ButtonDefaults.buttonColors(containerColor = Accent),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        if (state == ConnState.CONNECTING) CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                        else Text("连接", color = Color.White)
                    }
                }
            }
        }
    }
}

/** A-Forward：本地端口转发对话框（已有活动转发则可停止，否则输入参数建立） */
@Composable
fun PortForwardDialog(existing: String?, onClose: () -> Unit, onStop: () -> Unit, onStart: (Int, String, Int) -> Unit) {
    var localPort by remember { mutableStateOf("8080") }
    var remoteHost by remember { mutableStateOf("127.0.0.1") }
    var remotePort by remember { mutableStateOf("80") }
    val colors = OutlinedTextFieldDefaults.colors(
        focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight,
        focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent,
        focusedLabelColor = Accent, unfocusedLabelColor = TextSecondary
    )
    AlertDialog(
        onDismissRequest = onClose,
        icon = { Icon(Icons.Filled.SwapHoriz, null, tint = Accent) },
        title = { Text("本地端口转发", color = TextPrimary) },
        text = {
            if (existing != null) {
                Text("当前转发：\n$existing\n\n本机访问 127.0.0.1 即经 SSH 转发到远端。", color = TextSecondary, fontSize = 13.sp)
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(localPort, { localPort = it.filter { c -> c.isDigit() } }, label = { Text("本地端口") }, singleLine = true, colors = colors)
                    OutlinedTextField(remoteHost, { remoteHost = it }, label = { Text("远程主机（从服务器视角）") }, singleLine = true, colors = colors)
                    OutlinedTextField(remotePort, { remotePort = it.filter { c -> c.isDigit() } }, label = { Text("远程端口") }, singleLine = true, colors = colors)
                    Text("例：本地 8080 → 服务器上的 127.0.0.1:80", color = TextSecondary, fontSize = 11.sp)
                }
            }
        },
        confirmButton = {
            if (existing != null) TextButton(onClick = onStop) { Text("停止转发", color = Danger) }
            else TextButton(onClick = {
                val lp = localPort.toIntOrNull(); val rp = remotePort.toIntOrNull()
                if (lp != null && rp != null && remoteHost.isNotBlank()) onStart(lp, remoteHost.trim(), rp)
            }) { Text("建立", color = Accent) }
        },
        dismissButton = { TextButton(onClick = onClose) { Text("取消", color = TextSecondary) } },
        containerColor = Surface
    )
}

/** A-HealthAI：状态↔AI 联动——把当前状态摘要发给 AI 流式分析（对齐 apple Z6b） */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HealthAISheet(status: ServerStatus, onClose: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var content by remember { mutableStateOf("") }
    var done by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        if (!SettingsStore.isConfigured(ctx)) { content = "请先在设置中配置 API Key。"; done = true; return@LaunchedEffect }
        val msg = "${status.healthSummary}\n请分析有无异常并给排查/优化建议。"
        AiClient.chatStream(SettingsStore.loadApiKey(ctx), SettingsStore.loadModel(ctx),
            listOf("user" to msg), AiClient.HEALTH_PROMPT) { delta -> content += delta }
            .onFailure { content = "⚠️ ${it.message}" }
        done = true
    }

    ModalBottomSheet(onDismissRequest = onClose, containerColor = Bg) {
        Column(Modifier.fillMaxWidth().padding(16.dp).heightIn(min = 240.dp, max = 540.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(if (status.hasWarning) Icons.Filled.Warning else Icons.Filled.AutoAwesome,
                    null, tint = if (status.hasWarning) Danger else Accent)
                Spacer(Modifier.width(8.dp))
                Text("AI 健康分析", color = TextPrimary, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                if (!done) CircularProgressIndicator(Modifier.size(18.dp), color = Accent, strokeWidth = 2.dp)
            }
            Spacer(Modifier.height(6.dp))
            Text(status.healthSummary, color = TextSecondary, fontSize = 12.sp, fontFamily = FontFamily.Monospace)
            Spacer(Modifier.height(10.dp))
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
                Text(content.ifEmpty { "分析中…" }, color = TextPrimary, fontSize = 13.sp)
            }
        }
    }
}

/** A-SFTP：远程文件浏览（全屏 sheet：路径栏 + 列表 + 进入/上级） */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SftpBrowser(conn: ServerConn, password: String, privateKey: String?, onClose: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var path by remember { mutableStateOf(".") }
    var files by remember { mutableStateOf<List<RemoteFile>>(emptyList()) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var viewing by remember { mutableStateOf<Pair<String, String>?>(null) }  // A-FileView：文件名→内容
    var toast by remember { mutableStateOf<String?>(null) }                  // A-Upload 下载提示

    fun load(p: String) {
        loading = true; error = null
        scope.launch {
            SshClient.listDir(conn.host, conn.port, conn.user, password, p, privateKey)
                .onSuccess { files = it; path = p }
                .onFailure { error = it.message }
            loading = false
        }
    }

    // 下载远程文件到 app 外部文件目录
    fun download(f: RemoteFile) {
        loading = true
        scope.launch {
            val dir = ctx.getExternalFilesDir("Downloads") ?: ctx.cacheDir
            val local = java.io.File(dir, f.name)
            SshClient.downloadFile(conn.host, conn.port, conn.user, password, f.path, local.absolutePath, privateKey)
                .onSuccess { toast = "已下载到 ${local.absolutePath}" }
                .onFailure { error = it.message }
            loading = false
        }
    }

    // A-Upload：选本地文件→复制到临时文件→上传到当前目录
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        loading = true
        scope.launch {
            runCatching {
                // 查文件名
                val name = ctx.contentResolver.query(uri, null, null, null, null)?.use { c ->
                    val idx = c.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (c.moveToFirst() && idx >= 0) c.getString(idx) else null
                } ?: ("upload-" + uri.lastPathSegment?.substringAfterLast('/'))
                val tmp = java.io.File(ctx.cacheDir, name)
                ctx.contentResolver.openInputStream(uri)!!.use { input -> tmp.outputStream().use { input.copyTo(it) } }
                val remote = (if (path == "." || path == "/") path else path.trimEnd('/')) + "/" + name
                SshClient.uploadFile(conn.host, conn.port, conn.user, password, tmp.absolutePath, remote, privateKey).getOrThrow()
                name
            }.onSuccess { toast = "已上传 $it"; load(path) }
                .onFailure { error = it.message }
            loading = false
        }
    }

    // 查看文本文件内容
    fun openFile(f: RemoteFile) {
        loading = true
        scope.launch {
            SshClient.readFile(conn.host, conn.port, conn.user, password, f.path, privateKey = privateKey)
                .onSuccess { viewing = f.name to Redactor.redact(it).ifBlank { "(空文件)" } }
                .onFailure { error = it.message }
            loading = false
        }
    }
    LaunchedEffect(Unit) { load(".") }

    // 文件内容查看弹窗
    viewing?.let { (name, content) ->
        AlertDialog(
            onDismissRequest = { viewing = null },
            title = { Text(name, color = TextPrimary, fontSize = 15.sp, maxLines = 1) },
            text = {
                Column(Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState())) {
                    Text(content, color = TextPrimary, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                }
            },
            confirmButton = { TextButton(onClick = { viewing = null }) { Text("关闭", color = Accent) } },
            containerColor = Surface
        )
    }

    ModalBottomSheet(onDismissRequest = onClose, containerColor = Bg) {
        Column(Modifier.fillMaxWidth().padding(16.dp).heightIn(min = 300.dp, max = 560.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Folder, null, tint = Accent)
                Spacer(Modifier.width(8.dp))
                Text("文件浏览", color = TextPrimary, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                if (loading) CircularProgressIndicator(Modifier.size(18.dp), color = Accent, strokeWidth = 2.dp)
                IconButton(onClick = { picker.launch("*/*") }, enabled = !loading) {
                    Icon(Icons.Filled.Upload, "上传文件", tint = Accent, modifier = Modifier.size(18.dp))
                }
            }
            Spacer(Modifier.height(6.dp))
            Text(path, color = TextSecondary, fontSize = 12.sp, fontFamily = FontFamily.Monospace, maxLines = 1)
            Spacer(Modifier.height(8.dp))
            // 上级目录
            TextButton(onClick = {
                val parent = path.trimEnd('/').substringBeforeLast('/', "").ifEmpty { "/" }
                load(if (path == "." || path == "/") "/" else parent)
            }) { Icon(Icons.Filled.ArrowUpward, null, tint = Accent, modifier = Modifier.size(16.dp)); Spacer(Modifier.width(4.dp)); Text("上级目录", color = Accent, fontSize = 12.sp) }
            error?.let { Text("⚠️ $it", color = Danger, fontSize = 12.sp) }
            toast?.let { Text("✅ $it", color = Success, fontSize = 11.sp, maxLines = 2) }
            LazyColumn(Modifier.weight(1f)) {
                items(files.size) { i ->
                    val f = files[i]
                    Row(
                        Modifier.fillMaxWidth().clickable { if (f.isDir) load(f.path) else openFile(f) }.padding(vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(if (f.isDir) Icons.Filled.Folder else Icons.Filled.Description, null,
                            tint = if (f.isDir) Accent else TextSecondary, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(12.dp))
                        Text(f.name, color = TextPrimary, fontSize = 14.sp, modifier = Modifier.weight(1f), maxLines = 1)
                        Text(f.sizeLabel, color = TextSecondary, fontSize = 11.sp)
                        if (!f.isDir) {
                            IconButton(onClick = { download(f) }, modifier = Modifier.size(28.dp)) {
                                Icon(Icons.Filled.Download, "下载", tint = Accent, modifier = Modifier.size(16.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RowScope.StatCell(label: String, value: String, color: Color) {
    Column(Modifier.weight(1f)) {
        Text(label, color = TextSecondary, fontSize = 11.sp)
        Text(value, color = color, fontSize = 14.sp, fontWeight = FontWeight.Medium)
    }
}

// ServerConn + 持久化在 ConnectionStore.kt
