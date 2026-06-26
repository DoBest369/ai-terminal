package com.termind.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.material.icons.automirrored.filled.AltRoute
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.automirrored.filled.Sort
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
    var activeConnId by remember { mutableStateOf("") }                     // 当前关联连接 id（喂知识卡片给 AI）
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
        ServerWorkspace(conn, onBack = { detail = null }, onProfile = { activeProfile = it; activeConnId = conn.id })
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
                        val fresh = imported.filter { "${it.user}@${it.host}:${it.port}" !in existing }
                        fresh.forEach { conns.add(it) }
                        persist()
                        // 导入数量反馈（对齐 apple）
                        val skipped = imported.size - fresh.size
                        val msg = if (fresh.isEmpty()) "无新连接（${imported.size} 个已存在或为空）"
                                  else "已导入 ${fresh.size} 个连接" + if (skipped > 0) "（跳过 $skipped 个已存在）" else ""
                        android.widget.Toast.makeText(ctx, msg, android.widget.Toast.LENGTH_SHORT).show()
                    },
                    onOpen = { c ->
                        val i = conns.indexOfFirst { it.id == c.id }; if (i >= 0) { conns[i] = conns[i].copy(lastUsed = System.currentTimeMillis()); persist() }
                        detail = c
                    },
                    onEdit = { editing = it; showEditor = true },
                    onDelete = { conns.remove(it); persist() },
                    // A-Clone：复制连接（新 id + 名称加副本），立即打开编辑
                    onClone = { c ->
                        val copy = c.copy(id = java.util.UUID.randomUUID().toString(), name = "${c.name} 副本", lastUsed = 0L)
                        conns.add(copy); persist(); editing = copy; showEditor = true
                    },
                    // 批量改分组
                    onBatchGroup = { ids, group ->
                        ids.forEach { id -> val i = conns.indexOfFirst { it.id == id }; if (i >= 0) conns[i] = conns[i].copy(group = group) }
                        persist()
                    },
                    onBatchColor = { ids, tag ->
                        ids.forEach { id -> val i = conns.indexOfFirst { it.id == id }; if (i >= 0) conns[i] = conns[i].copy(colorTag = tag) }
                        persist()
                    },
                    onBatchDelete = { ids -> conns.removeAll { it.id in ids }; persist() }
                )
                Tab.AI -> AIAssistantScreen(onGoSettings = { tab = Tab.Settings }, profile = activeProfile, connId = activeConnId)
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
    onDelete: (ServerConn) -> Unit,
    onClone: (ServerConn) -> Unit = {},
    onBatchGroup: (List<String>, String) -> Unit = { _, _ -> },   // 批量改分组
    onBatchColor: (List<String>, ColorTag) -> Unit = { _, _ -> }, // 批量改颜色标签
    onBatchDelete: (List<String>) -> Unit = {}                    // 批量删除
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
    var showConfigImport by remember { mutableStateOf(false) }   // SSH config 文本导入
    var searchActive by remember { mutableStateOf(false) }   // A-Filter
    var search by remember { mutableStateOf("") }
    var sortMenu by remember { mutableStateOf(false) }       // A-Sort
    var sortMode by remember { mutableStateOf(0) }           // 0=名称 1=最近 2=在线
    val collapsedGroups = remember { mutableStateListOf<String>() }   // A-GroupFold 折叠的分组
    val selectedIds = remember { mutableStateListOf<String>() }        // 批量编辑：多选连接 id
    var selectMode by remember { mutableStateOf(false) }
    var showBatchGroup by remember { mutableStateOf(false) }
    var showBatchColor by remember { mutableStateOf(false) }
    var showBatchDelete by remember { mutableStateOf(false) }
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
                Box {
                    IconButton(onClick = { sortMenu = true }, enabled = conns.isNotEmpty()) {
                        Icon(Icons.AutoMirrored.Filled.Sort, "排序", tint = TextSecondary, modifier = Modifier.size(18.dp))
                    }
                    DropdownMenu(expanded = sortMenu, onDismissRequest = { sortMenu = false }) {
                        listOf("名称", "最近使用", "在线优先").forEachIndexed { i, label ->
                            DropdownMenuItem(text = { Text(label, color = if (sortMode == i) Accent else TextPrimary) }, onClick = { sortMode = i; sortMenu = false })
                        }
                    }
                }
                IconButton(onClick = { searchActive = !searchActive; if (!searchActive) search = "" }, enabled = conns.isNotEmpty()) {
                    Icon(Icons.Filled.Search, "搜索连接", tint = if (searchActive) Accent else TextSecondary, modifier = Modifier.size(18.dp))
                }
                Box {
                    IconButton(onClick = { overflow = true }) { Icon(Icons.Filled.MoreVert, "更多", tint = TextSecondary) }
                    DropdownMenu(expanded = overflow, onDismissRequest = { overflow = false }) {
                        DropdownMenuItem(text = { Text("📤 导出连接") }, onClick = { overflow = false; onExport() })
                        DropdownMenuItem(text = { Text("📥 导入连接") }, onClick = { overflow = false; importPicker.launch("application/json") })
                        DropdownMenuItem(text = { Text("📋 从 SSH config 导入") }, onClick = { overflow = false; showConfigImport = true })
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
        // 批量编辑操作栏（多选模式时）
        if (selectMode) {
            Surface(color = Accent.copy(alpha = 0.12f)) {
                Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("已选 ${selectedIds.size}", color = Accent, fontSize = 13.sp, modifier = Modifier.weight(1f))
                    TextButton(onClick = { showBatchGroup = true }, enabled = selectedIds.isNotEmpty()) { Text("分组", color = Accent, fontSize = 13.sp) }
                    TextButton(onClick = { showBatchColor = true }, enabled = selectedIds.isNotEmpty()) { Text("标签", color = Accent, fontSize = 13.sp) }
                    TextButton(onClick = { showBatchDelete = true }, enabled = selectedIds.isNotEmpty()) { Text("删除", color = Danger, fontSize = 13.sp) }
                    TextButton(onClick = { selectMode = false; selectedIds.clear() }) { Text("取消", color = TextSecondary, fontSize = 13.sp) }
                }
            }
        }
        // 批量改分组对话框
        if (showBatchGroup) {
            var g by remember { mutableStateOf("") }
            AlertDialog(
                onDismissRequest = { showBatchGroup = false },
                title = { Text("批量改分组（${selectedIds.size} 台）", color = TextPrimary) },
                text = { OutlinedTextField(g, { g = it }, label = { Text("分组名（留空=移出分组）") }, singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent)) },
                confirmButton = { TextButton(onClick = { onBatchGroup(selectedIds.toList(), g.trim()); showBatchGroup = false; selectMode = false; selectedIds.clear() }) { Text("确定", color = Accent) } },
                dismissButton = { TextButton(onClick = { showBatchGroup = false }) { Text("取消", color = TextSecondary) } },
                containerColor = Surface
            )
        }
        // 批量改颜色标签对话框
        if (showBatchColor) {
            AlertDialog(
                onDismissRequest = { showBatchColor = false },
                title = { Text("批量颜色标签（${selectedIds.size} 台）", color = TextPrimary) },
                text = {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        ColorTag.values().forEach { tag ->
                            Box(Modifier.size(28.dp).clip(androidx.compose.foundation.shape.CircleShape)
                                .background(tag.hex?.let { Color(it) } ?: SurfaceLight)
                                .clickable { onBatchColor(selectedIds.toList(), tag); showBatchColor = false; selectMode = false; selectedIds.clear() },
                                contentAlignment = Alignment.Center) {
                                if (tag == ColorTag.NONE) Icon(Icons.Filled.Block, null, tint = TextSecondary, modifier = Modifier.size(16.dp))
                            }
                        }
                    }
                },
                confirmButton = { TextButton(onClick = { showBatchColor = false }) { Text("取消", color = TextSecondary) } },
                containerColor = Surface
            )
        }
        // 批量删除二次确认
        if (showBatchDelete) {
            AlertDialog(
                onDismissRequest = { showBatchDelete = false },
                icon = { Icon(Icons.Filled.Warning, null, tint = Danger) },
                title = { Text("删除 ${selectedIds.size} 台连接？", color = TextPrimary) },
                text = { Text("将删除选中的连接，此操作不可撤销。", color = TextSecondary) },
                confirmButton = { TextButton(onClick = { onBatchDelete(selectedIds.toList()); showBatchDelete = false; selectMode = false; selectedIds.clear() }) { Text("删除", color = Danger) } },
                dismissButton = { TextButton(onClick = { showBatchDelete = false }) { Text("取消", color = TextSecondary) } },
                containerColor = Surface
            )
        }
        // SSH config 文本导入对话框（粘贴 ~/.ssh/config 内容→解析批量添加连接）
        if (showConfigImport) {
            var cfgText by remember { mutableStateOf("") }
            AlertDialog(
                onDismissRequest = { showConfigImport = false },
                title = { Text("从 SSH config 导入", color = TextPrimary) },
                text = {
                    Column {
                        Text("粘贴 ~/.ssh/config 内容，自动解析为连接（密码认证）。", color = TextSecondary, fontSize = 12.sp)
                        Spacer(Modifier.height(8.dp))
                        OutlinedTextField(cfgText, { cfgText = it }, placeholder = { Text("Host myserver\n  HostName 1.2.3.4\n  User root\n  Port 22", color = TextSecondary) },
                            minLines = 4, maxLines = 8,
                            textStyle = androidx.compose.ui.text.TextStyle(fontFamily = FontFamily.Monospace, fontSize = 12.sp),
                            colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent),
                            modifier = Modifier.fillMaxWidth())
                    }
                },
                confirmButton = { TextButton(onClick = { val parsed = SshConfigParser.parse(cfgText); if (parsed.isNotEmpty()) onImport(parsed); showConfigImport = false }) { Text("导入", color = Accent) } },
                dismissButton = { TextButton(onClick = { showConfigImport = false }) { Text("取消", color = TextSecondary) } },
                containerColor = Surface
            )
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
        val filtered = if (q.isEmpty()) conns.toList() else conns.filter {
            it.name.contains(q, true) || it.host.contains(q, true) || it.user.contains(q, true) || it.group.contains(q, true)
        }
        // A-Sort：名称/最近使用/在线优先
        val shown = when (sortMode) {
            1 -> filtered.sortedByDescending { it.lastUsed }
            2 -> filtered.sortedByDescending { reachMap[it.id] == true }
            else -> filtered.sortedBy { it.name.lowercase() }
        }
        val grouped = shown.groupBy { it.group }
        // 最近使用：横滑快速访问（非多选/非搜索时显，取 lastUsed>0 倒序前 5）
        val recent = if (!selectMode && q.isEmpty()) conns.filter { it.lastUsed > 0 }.sortedByDescending { it.lastUsed }.take(5) else emptyList()
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (recent.isNotEmpty()) {
                item(key = "recent-hdr") { Text("最近使用", fontSize = 12.sp, color = TextSecondary, modifier = Modifier.padding(top = 8.dp)) }
                item(key = "recent-row") {
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        recent.forEach { c ->
                            Surface(onClick = { onOpen(c) }, color = SurfaceLight.copy(alpha = 0.5f), shape = RoundedCornerShape(12.dp)) {
                                Row(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Filled.Circle, null, tint = if (reachMap[c.id] == true) Success else TextSecondary, modifier = Modifier.size(8.dp))
                                    Spacer(Modifier.width(6.dp))
                                    Text(c.name.ifEmpty { c.host }, color = TextPrimary, fontSize = 12.sp, maxLines = 1)
                                }
                            }
                        }
                    }
                }
            }
            grouped.forEach { (group, list) ->
                // A-GroupFold：分组标题可点折叠/展开（仅有组名时）
                if (group.isNotEmpty()) item(key = "hdr-$group") {
                    val folded = group in collapsedGroups
                    Row(
                        Modifier.fillMaxWidth().clickable { if (folded) collapsedGroups.remove(group) else collapsedGroups.add(group) }.padding(top = 14.dp, bottom = 2.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(if (folded) Icons.Filled.ChevronRight else Icons.Filled.ExpandMore, null, tint = TextSecondary, modifier = Modifier.size(16.dp))
                        Text("$group (${list.size})", fontSize = 12.sp, color = TextSecondary)
                    }
                }
                if (group !in collapsedGroups) {
                    items(list, key = { it.id }) { conn ->
                        ServerCard(conn, reachMap[conn.id], probing,
                            selectMode = selectMode, selected = conn.id in selectedIds,
                            onClick = { if (selectMode) { if (conn.id in selectedIds) selectedIds.remove(conn.id) else selectedIds.add(conn.id) } else onOpen(conn) },
                            onLongPress = { selectMode = true; if (conn.id !in selectedIds) selectedIds.add(conn.id) },
                            onEdit = { onEdit(conn) }, onDelete = { onDelete(conn) }, onClone = { onClone(conn) })
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class, androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun ServerCard(conn: ServerConn, reachable: Boolean?, probing: Boolean, onClick: () -> Unit, onEdit: () -> Unit, onDelete: () -> Unit, onClone: () -> Unit = {}, selectMode: Boolean = false, selected: Boolean = false, onLongPress: () -> Unit = {}) {
    var menu by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }   // 删除连接二次确认
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("删除连接「${conn.name.ifEmpty { conn.host }}」？", color = TextPrimary) },
            text = { Text("将移除此连接配置（不影响远程主机），此操作不可撤销。", color = TextSecondary) },
            confirmButton = { TextButton(onClick = { confirmDelete = false; onDelete() }) { Text("删除", color = Danger) } },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
    }
    // A-Reach：在线绿 / 离线灰 / 探测中黄
    val dotColor = when {
        reachable == true -> Success
        reachable == false -> Danger
        probing -> Warning
        else -> TextSecondary
    }
    Card(
        colors = CardDefaults.cardColors(containerColor = if (selected) Accent.copy(alpha = 0.2f) else SurfaceLight.copy(alpha = 0.5f)),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth().combinedClickable(onClick = onClick, onLongClick = onLongPress)
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            // 批量编辑：多选勾选框
            if (selectMode) {
                Icon(if (selected) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked, null, tint = if (selected) Accent else TextSecondary, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(10.dp))
            }
            // A-Tags：颜色标签色条
            conn.colorTag.hex?.let { Box(Modifier.width(4.dp).height(34.dp).clip(RoundedCornerShape(2.dp)).background(Color(it))); Spacer(Modifier.width(10.dp)) }
            Icon(Icons.Filled.Circle, null, tint = dotColor, modifier = Modifier.size(10.dp))
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                // A-CardBadge：名称 + 特性小图标（跳板/启动命令/私钥认证）
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(conn.name, color = TextPrimary, fontWeight = FontWeight.Medium, fontSize = 15.sp)
                    if (conn.hasJump) Icon(Icons.AutoMirrored.Filled.AltRoute, "经跳板机", tint = TextSecondary, modifier = Modifier.size(13.dp))
                    if (conn.startupCommand.isNotEmpty()) Icon(Icons.Filled.Bolt, "有启动命令", tint = TextSecondary, modifier = Modifier.size(13.dp))
                    if (conn.authType == AuthType.KEY) Icon(Icons.Filled.VpnKey, "私钥认证", tint = TextSecondary, modifier = Modifier.size(13.dp))
                }
                Text("${conn.user}@${conn.host}:${conn.port}", color = TextSecondary, fontSize = 12.sp, fontFamily = FontFamily.Monospace)
                if (conn.note.isNotEmpty()) Text("📝 ${conn.note}", color = TextSecondary.copy(alpha = 0.85f), fontSize = 11.sp)
                // A-LastUsed：上次使用相对时间
                if (conn.lastUsed > 0) Text("上次使用 · ${relativeTime(conn.lastUsed)}", color = TextSecondary.copy(alpha = 0.7f), fontSize = 10.sp)
            }
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, "更多", tint = TextSecondary) }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text("编辑") }, onClick = { menu = false; onEdit() })
                    DropdownMenuItem(text = { Text("复制") }, onClick = { menu = false; onClone() })
                    DropdownMenuItem(text = { Text("删除", color = Danger) }, onClick = { menu = false; confirmDelete = true })
                }
            }
        }
    }
}

@Composable
fun AIAssistantScreen(onGoSettings: () -> Unit, profile: ServerProfile? = null, connId: String = "") {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    // A-Convos / A-ConvoPersist：多对话（从 store 加载，变更后持久化）
    val convos = remember {
        mutableStateListOf<SnapshotStateList<ChatMsg>>().apply {
            ConvoStore.load(ctx).forEach { add(it.toMutableStateList()) }
            if (isEmpty()) add(mutableStateListOf())
        }
    }
    var curIdx by remember { mutableStateOf(0) }
    val messages = convos[curIdx.coerceIn(0, convos.size - 1)]
    // 各对话自定义标题（平行列表，空=自动标题）
    val convoTitles = remember {
        mutableStateListOf<String>().apply { addAll(ConvoStore.loadTitles(ctx)); while (size < convos.size) add(""); }
    }
    var convoMenu by remember { mutableStateOf(false) }
    var showClearConfirm by remember { mutableStateOf(false) }   // 清空消息二次确认
    var showDeleteConvoConfirm by remember { mutableStateOf(false) }   // 删除对话二次确认
    var showRenameConvo by remember { mutableStateOf(false) }   // 重命名对话
    fun persistConvos() { ConvoStore.save(ctx, convos.map { it.toList() }); ConvoStore.saveTitles(ctx, convoTitles.toList()) }
    fun convoTitle(c: List<ChatMsg>, i: Int) =
        convoTitles.getOrNull(i)?.takeIf { it.isNotBlank() }
            ?: c.firstOrNull { it.role == "user" }?.content?.take(16) ?: "新对话 ${i + 1}"
    // A-ConvoExport：当前对话导出 Markdown 并分享
    fun exportConvo() {
        if (messages.isEmpty()) return
        val md = buildString {
            append("# Termind AI 对话\n\n")
            messages.forEach { m ->
                append(if (m.role == "user") "## 🧑 用户\n\n" else "## 🤖 AI 助手\n\n")
                append(m.content); append("\n\n")
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
    var sendJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }   // A-Stop 当前流式任务
    var lastSent by remember { mutableStateOf<Pair<String, String>?>(null) }   // A-Regen 上次(text,basePrompt)
    var searchActive by remember { mutableStateOf(false) }   // A-ConvoSearch
    var search by remember { mutableStateOf("") }
    // A-Prompts：分类运维提示词库（覆盖排障/部署/安全/性能/日志）
    val promptGroups = listOf(
        "排障" to listOf("帮我查看为什么网站打不开", "分析这段报错并给修复", "服务突然 502，怎么排查？", "数据库连接不上，帮我排查", "某个端口被占用，怎么定位是哪个进程？"),
        "部署" to listOf("一键初始化 Ubuntu Web 服务器", "用 Docker 部署一个 Nginx + 静态站点", "配置 Let's Encrypt 免费 HTTPS 证书", "帮我写一个 Nginx 反向代理配置", "用 systemd 把我的程序配成开机自启服务"),
        "安全" to listOf("检查这台服务器有哪些安全风险", "怎么加固 SSH 登录安全？", "查看最近的登录失败记录并判断是否被爆破", "配置防火墙只放行 22/80/443 端口", "排查是否有可疑的定时任务或异常进程"),
        "性能" to listOf("服务器很卡，帮我找出占用资源最高的进程", "磁盘快满了，怎么安全清理？", "分析内存占用是否正常", "分析这个进程为什么 CPU 占用高", "磁盘 I/O 很高，帮我定位原因"),
        "日志" to listOf("怎么查看 Nginx 最近的错误日志？", "用一条命令统计访问量 Top 10 IP", "解释这条命令：docker system prune -a", "从日志里找出最近的报错并归类", "实时跟踪某个服务的日志输出")
    )
    var promptGroupIdx by remember { mutableStateOf(0) }

    fun send(text: String, basePrompt: String = AiClient.SYSTEM_PROMPT) {
        val t = text.trim(); if (t.isEmpty() || sending) return
        if (!SettingsStore.isConfigured(ctx)) { onGoSettings(); return }
        lastSent = t to basePrompt   // A-Regen 记录
        messages.add(ChatMsg("user", t, System.currentTimeMillis())); input = ""; sending = true
        // A-Env：把当前服务器环境摘要注入系统提示，让 AI 结合真实环境回答（对齐 apple Z3）
        var sys = profile?.aiSummary?.takeIf { it.isNotEmpty() }?.let {
            "$basePrompt\n\n$it\n请结合以上真实服务器环境给出针对性、可直接执行的回答。"
        } ?: basePrompt
        // 知识卡片注入：AI 对话(含报错分析)也结合这台机历史记录（知识沉淀闭环扩展到对话/报错路径）
        if (connId.isNotEmpty()) {
            val notebook = ServerNotebook.composeForAI(ServerNotebook.load(ctx, connId))
            if (notebook.isNotEmpty()) sys += "\n\n$notebook\n如与本次问题相关，请结合上述历史运维记录。"
        }
        // A-Stream：流式逐字显示。先放一个空 assistant 消息，delta 时追加到它
        val history = messages.map { it.role to it.content }   // chatStream 需 (role,content)
        val aiIndex = messages.size
        messages.add(ChatMsg("assistant", "", System.currentTimeMillis()))
        sendJob = scope.launch {
            val r = AiClient.chatStream(SettingsStore.loadApiKey(ctx), SettingsStore.loadModel(ctx), history, sys) { delta ->
                messages[aiIndex] = messages[aiIndex].copy(content = messages[aiIndex].content + delta)
            }
            r.onFailure { messages[aiIndex] = messages[aiIndex].copy(content = "⚠️ ${it.message ?: "请求失败"}") }
            sending = false
            persistConvos()   // A-ConvoPersist：回复完成后持久化
        }
    }
    // A-Stop：停止当前流式生成（保留已生成内容）
    fun stop() {
        sendJob?.cancel(); sendJob = null; sending = false
        messages.lastOrNull()?.let { if (it.role == "assistant") messages[messages.size - 1] = it.copy(content = it.content + "\n[已停止]") }
        persistConvos()
    }
    // A-Regen：重新生成上一条 AI 回复
    fun regenerate() {
        if (sending) return
        val (txt, prompt) = lastSent ?: return
        // 移除末尾的 assistant + 对应 user（send 会重新加 user）
        if (messages.lastOrNull()?.role == "assistant") messages.removeAt(messages.size - 1)
        if (messages.lastOrNull()?.role == "user") messages.removeAt(messages.size - 1)
        send(txt, prompt)
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
                        // A-AIClear：清空当前对话消息（保留对话）——二次确认防误删
                        if (messages.isNotEmpty()) DropdownMenuItem(text = { Text("🧹 清空当前消息", color = TextPrimary) },
                            onClick = { convoMenu = false; showClearConfirm = true })
                        DropdownMenuItem(text = { Text("✏️ 重命名对话", color = TextPrimary) },
                            onClick = { convoMenu = false; showRenameConvo = true })
                        DropdownMenuItem(text = { Text("➕ 新建对话", color = Accent) },
                            onClick = { convos.add(mutableStateListOf()); convoTitles.add(""); curIdx = convos.size - 1; convoMenu = false; persistConvos() })
                        if (convos.size > 1) DropdownMenuItem(text = { Text("🗑 删除当前", color = Danger) },
                            onClick = { convoMenu = false; showDeleteConvoConfirm = true })
                    }
                }
                if (profile?.aiSummary?.isNotEmpty() == true) {
                    Spacer(Modifier.width(8.dp)); Text("已感知环境", fontSize = 12.sp, color = TextSecondary)
                }
                // 清空当前消息二次确认（对齐 apple）
                if (showClearConfirm) {
                    AlertDialog(
                        onDismissRequest = { showClearConfirm = false },
                        title = { Text("清空当前对话？", color = TextPrimary) },
                        text = { Text("将清除当前对话的所有消息（保留对话本身），此操作不可撤销。", color = TextSecondary) },
                        confirmButton = { TextButton(onClick = { messages.clear(); lastSent = null; persistConvos(); showClearConfirm = false }) { Text("清空", color = Danger) } },
                        dismissButton = { TextButton(onClick = { showClearConfirm = false }) { Text("取消", color = TextSecondary) } },
                        containerColor = Surface
                    )
                }
                // 重命名对话（对齐 apple，空=恢复自动标题）
                if (showRenameConvo) {
                    var nm by remember { mutableStateOf(convoTitles.getOrNull(curIdx)?.takeIf { it.isNotBlank() } ?: "") }
                    AlertDialog(
                        onDismissRequest = { showRenameConvo = false },
                        title = { Text("重命名对话", color = TextPrimary) },
                        text = { OutlinedTextField(nm, { nm = it }, placeholder = { Text("对话名称（留空恢复自动）", color = TextSecondary) }, singleLine = true,
                            colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent)) },
                        confirmButton = { TextButton(onClick = {
                            while (convoTitles.size <= curIdx) convoTitles.add("")
                            convoTitles[curIdx] = nm.trim(); persistConvos(); showRenameConvo = false
                        }) { Text("保存", color = Accent) } },
                        dismissButton = { TextButton(onClick = { showRenameConvo = false }) { Text("取消", color = TextSecondary) } },
                        containerColor = Surface
                    )
                }
                // 删除当前对话二次确认（对齐 apple）
                if (showDeleteConvoConfirm) {
                    AlertDialog(
                        onDismissRequest = { showDeleteConvoConfirm = false },
                        title = { Text("删除当前对话？", color = TextPrimary) },
                        text = { Text("将删除当前整段对话，此操作不可撤销。", color = TextSecondary) },
                        confirmButton = { TextButton(onClick = {
                            convos.removeAt(curIdx); if (curIdx < convoTitles.size) convoTitles.removeAt(curIdx); curIdx = curIdx.coerceIn(0, convos.size - 1); persistConvos(); showDeleteConvoConfirm = false
                        }) { Text("删除", color = Danger) } },
                        dismissButton = { TextButton(onClick = { showDeleteConvoConfirm = false }) { Text("取消", color = TextSecondary) } },
                        containerColor = Surface
                    )
                }
                Spacer(Modifier.weight(1f))
                IconButton(onClick = { searchActive = !searchActive; if (!searchActive) search = "" }, enabled = messages.isNotEmpty()) {
                    Icon(Icons.Filled.Search, "搜索对话", tint = if (searchActive) Accent else TextSecondary)
                }
                IconButton(onClick = { convos.add(mutableStateListOf()); convoTitles.add(""); curIdx = convos.size - 1; persistConvos() }) {
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
            Column(Modifier.weight(1f).fillMaxWidth().padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("让 AI 结合服务器真实环境帮你运维", color = TextSecondary, fontSize = 13.sp)
                // A-Prompts：分类提示词 — 分类选择行
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    promptGroups.forEachIndexed { i, (cat, _) ->
                        FilterChip(selected = promptGroupIdx == i, onClick = { promptGroupIdx = i },
                            label = { Text(cat, fontSize = 12.sp) },
                            colors = FilterChipDefaults.filterChipColors(selectedContainerColor = Accent.copy(alpha = 0.3f), selectedLabelColor = Accent, labelColor = TextSecondary))
                    }
                }
                promptGroups[promptGroupIdx].second.forEach { s ->
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
            val shown = if (q.isEmpty()) messages.toList() else messages.filter { it.content.contains(q, ignoreCase = true) }
            LazyColumn(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (q.isNotEmpty()) item { Text("${shown.size} 条匹配", color = TextSecondary, fontSize = 11.sp, modifier = Modifier.padding(4.dp)) }
                items(shown.size) { i -> ChatBubble(shown[i].role, shown[i].content, shown[i].time, connId, onResend = { if (!sending) send(it) }) }
                if (sending && q.isEmpty()) item { Text("AI 思考中…", color = TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(8.dp)) }
            }
        }
        // A-Regen：重新生成 + 快捷追问（末条是 assistant 且未生成中）
        if (!sending && messages.lastOrNull()?.role == "assistant" && lastSent != null) {
            Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 12.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                AssistChip(onClick = { regenerate() }, label = { Text("重新生成", fontSize = 12.sp) },
                    leadingIcon = { Icon(Icons.Filled.Refresh, null, tint = Accent, modifier = Modifier.size(16.dp)) },
                    colors = AssistChipDefaults.assistChipColors(containerColor = SurfaceLight.copy(alpha = 0.45f), labelColor = TextPrimary))
                // 知识沉淀闭环：把 AI 结论一键存为方案卡片（有关联连接时）
                if (connId.isNotEmpty()) {
                    AssistChip(onClick = {
                        val text = messages.lastOrNull()?.content?.trim().orEmpty()
                        if (text.isNotEmpty()) {
                            ServerNotebook.add(ctx, connId, ServerNote(kind = NoteKind.SOLUTION, text = text))
                            android.widget.Toast.makeText(ctx, "已存为方案到知识卡片", android.widget.Toast.LENGTH_SHORT).show()
                        }
                    }, label = { Text("存为方案", fontSize = 12.sp) },
                        leadingIcon = { Icon(Icons.Filled.BookmarkAdd, null, tint = Success, modifier = Modifier.size(16.dp)) },
                        colors = AssistChipDefaults.assistChipColors(containerColor = Success.copy(alpha = 0.12f), labelColor = Success))
                }
                // 快捷追问：点击直接发该追问（走 send，自动带环境+知识卡片上下文）
                listOf("给我具体命令", "换个思路", "解释原理", "有什么风险").forEach { q ->
                    AssistChip(onClick = { send(q) }, label = { Text(q, fontSize = 12.sp) },
                        colors = AssistChipDefaults.assistChipColors(containerColor = SurfaceLight.copy(alpha = 0.45f), labelColor = TextSecondary))
                }
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
        // 输入栏（A-Multiline：支持多行，粘贴报错日志/长指令）
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                input, { input = it }, placeholder = { Text("用自然语言描述运维任务…（可多行）", color = TextSecondary) },
                singleLine = false, minLines = 1, maxLines = 5,
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent),
                modifier = Modifier.weight(1f)
            )
            // A-Stop：生成中显示停止按钮
            FilledIconButton(onClick = { if (sending) stop() else send(input) },
                colors = IconButtonDefaults.filledIconButtonColors(containerColor = if (sending) Danger else Accent)) {
                if (sending) Icon(Icons.Filled.Stop, "停止", tint = Color.White)
                else Icon(Icons.Filled.ArrowUpward, "发送", tint = Color.White)
            }
        }
    }
}

@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
private fun ChatBubble(role: String, content: String, time: Long = 0L, connId: String = "", onResend: (String) -> Unit = {}) {
    val isUser = role == "user"
    val clipboard = LocalClipboardManager.current
    val ctx = LocalContext.current
    var menu by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start, verticalAlignment = Alignment.Top) {
        // A-Avatar：AI 角色头像（assistant 消息左侧小圆图标，一眼区分角色）
        if (!isUser) {
            Box(Modifier.padding(top = 2.dp, end = 6.dp).size(26.dp).clip(androidx.compose.foundation.shape.CircleShape).background(Accent.copy(alpha = 0.2f)), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.AutoAwesome, "AI", tint = Accent, modifier = Modifier.size(15.dp))
            }
        }
        Column(horizontalAlignment = if (isUser) Alignment.End else Alignment.Start) {
        // 发送时间（time>0 时显 HH:mm，对齐 apple）
        if (time > 0L) {
            Text(java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault()).format(java.util.Date(time)),
                color = TextSecondary.copy(alpha = 0.7f), fontSize = 9.sp, modifier = Modifier.padding(bottom = 2.dp, start = 4.dp, end = 4.dp))
        }
        Box {
        Surface(
            color = if (isUser) Accent.copy(alpha = 0.25f) else SurfaceLight.copy(alpha = 0.5f),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth(if (isUser) 0.85f else 0.78f).combinedClickable(
                onClick = {},
                onLongClick = {
                    // AI 消息(有连接)弹 复制/存笔记/存方案；user 消息弹 复制/重发；否则直接复制
                    if ((!isUser && connId.isNotEmpty()) || isUser) menu = true
                    else {
                        clipboard.setText(androidx.compose.ui.text.AnnotatedString(content))
                        android.widget.Toast.makeText(ctx, "已复制整条消息", android.widget.Toast.LENGTH_SHORT).show()
                    }
                }
            )
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
        // 长按菜单：user→复制/重发；AI→复制/存笔记/存方案（知识沉淀入口）
        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }, modifier = Modifier.background(Surface)) {
            DropdownMenuItem(text = { Text("复制", color = TextPrimary) }, onClick = {
                menu = false; clipboard.setText(androidx.compose.ui.text.AnnotatedString(content))
                android.widget.Toast.makeText(ctx, "已复制整条消息", android.widget.Toast.LENGTH_SHORT).show()
            })
            if (isUser) {
                DropdownMenuItem(text = { Text("重发", color = Accent) }, onClick = { menu = false; onResend(content) })
            } else {
                DropdownMenuItem(text = { Text("存为笔记", color = TextPrimary) }, onClick = {
                    menu = false; ServerNotebook.add(ctx, connId, ServerNote(kind = NoteKind.NOTE, text = content.trim()))
                    android.widget.Toast.makeText(ctx, "已存为知识卡片（笔记）", android.widget.Toast.LENGTH_SHORT).show()
                })
                DropdownMenuItem(text = { Text("存为方案", color = Success) }, onClick = {
                    menu = false; ServerNotebook.add(ctx, connId, ServerNote(kind = NoteKind.SOLUTION, text = content.trim()))
                    android.widget.Toast.makeText(ctx, "已存为方案", android.widget.Toast.LENGTH_SHORT).show()
                })
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
    var model by remember { mutableStateOf(SettingsStore.loadModel(ctx)) }   // A-Model
    var pickingModel by remember { mutableStateOf(false) }

    // A-Model：AI 模型选择
    if (pickingModel) {
        val models = listOf(
            "claude-opus-4-8" to "Opus 4.8（最强）",
            "claude-sonnet-4-6" to "Sonnet 4.6（均衡）",
            "claude-haiku-4-5-20251001" to "Haiku 4.5（快速）"
        )
        AlertDialog(
            onDismissRequest = { pickingModel = false },
            title = { Text("AI 模型", color = TextPrimary) },
            text = {
                Column {
                    models.forEach { (id, label) ->
                        Row(
                            Modifier.fillMaxWidth().clickable { model = id; SettingsStore.saveModel(ctx, id); pickingModel = false }.padding(vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(label, color = TextPrimary, fontSize = 14.sp)
                                Text(id, color = TextSecondary, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                            }
                            if (model == id) Icon(Icons.Filled.Check, null, tint = Accent, modifier = Modifier.size(18.dp))
                        }
                    }
                }
            },
            confirmButton = { TextButton(onClick = { pickingModel = false }) { Text("关闭", color = Accent) } },
            containerColor = Surface
        )
    }

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
            // A-Model：模型选择
            SettingRow(Icons.Filled.Memory, "AI 模型", model.substringBefore("-20")) { pickingModel = true }
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
            SettingRow(Icons.Filled.Info, "关于 Termind", "智能 SSH 运维工作台 v${BuildConfig.VERSION_NAME}")
            // A-About：开源仓库链接（点击浏览器打开）
            SettingRow(Icons.Filled.Code, "开源仓库", "github.com/DoBest369/ai-terminal · MIT") {
                runCatching {
                    ctx.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse("https://github.com/DoBest369/ai-terminal")))
                }
            }
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
@OptIn(ExperimentalMaterial3Api::class, androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun ServerWorkspace(conn: ServerConn, onBack: () -> Unit, onProfile: (ServerProfile) -> Unit = {}) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var password by remember { mutableStateOf("") }       // 密码认证
    var privateKey by remember { mutableStateOf("") }      // A-KeyAuth 私钥（PEM，临时输入不持久化）
    var jumpPassword by remember { mutableStateOf("") }    // A-Jump 跳板机密码（临时输入不持久化）
    fun keyArg(): String? = if (conn.authType == AuthType.KEY) privateKey.takeIf { it.isNotBlank() } else null
    fun jumpCfg(): JumpConfig? = if (conn.hasJump) JumpConfig(conn.jumpHost, conn.jumpPort, conn.jumpUser, jumpPassword) else null
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
    var diagSaveable by remember { mutableStateOf<String?>(null) }  // 排障结论可存为方案
    var showForward by remember { mutableStateOf(false) }   // A-Forward 端口转发对话框
    var forwardHandle by remember { mutableStateOf<PortForwardHandle?>(null) }
    var forwardLabel by remember { mutableStateOf<String?>(null) }
    var showHistory by remember { mutableStateOf(false) }   // N-History 命令历史
    val cmdHistory = remember { mutableStateListOf<String>().apply { addAll(CommandHistory.load(ctx)) } }
    var showNotebook by remember { mutableStateOf(false) }  // 服务器知识卡片
    var quickNote by remember { mutableStateOf<String?>(null) }  // 快速记录知识卡片（预填文本）
    var termFont by remember { mutableStateOf(SettingsStore.loadTermFont(ctx)) }   // A-FontSize 终端字号
    var termSearch by remember { mutableStateOf("") }          // A-TermSearch 终端搜索
    var termSearchOn by remember { mutableStateOf(false) }
    var connectedAt by remember { mutableStateOf(0L) }         // A-Duration 连接时刻
    var durTick by remember { mutableStateOf(0) }              // 每秒 tick 触发重组
    val customSnippets = remember { mutableStateListOf<CommandSnippet>().apply { addAll(SnippetStore.load(ctx)) } }  // A-SnippetCRUD
    val favorites = remember { mutableStateListOf<String>().apply { addAll(CommandFavorites.load(ctx)) } }  // 命令收藏夹
    var showNewSnippet by remember { mutableStateOf(false) }
    var editingSnippet by remember { mutableStateOf<CommandSnippet?>(null) }   // 正在编辑的自定义片段
    var showSnippetImport by remember { mutableStateOf(false) }   // 快捷命令导入粘贴

    // 采集服务器状态（CPU/内存/磁盘）
    fun refreshStatus() {
        if ((password.isBlank() && keyArg() == null) || refreshing) return
        refreshing = true
        scope.launch {
            SshClient.fetchStatus(conn.host, conn.port, conn.user, password, keyArg(), jumpCfg())
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
                SshClient.openShell(conn.host, conn.port, conn.user, password, scope, keyArg(), jumpCfg()) { chunk ->
                    output += Redactor.redact(chunk)   // A3：输出脱敏
                }
            }.onSuccess {
                shellSession = it; state = ConnState.CONNECTED
                connectedAt = System.currentTimeMillis()   // A-Duration
                // A-Startup：连接成功后自动执行启动命令
                if (conn.startupCommand.isNotBlank()) it.write(conn.startupCommand + "\n")
                refreshStatus()   // 连接成功后采集状态
                // A-Env：探测环境画像 → 上报给 AI
                scope.launch {
                    SshClient.fetchEnv(conn.host, conn.port, conn.user, password, keyArg(), jumpCfg()).onSuccess { p ->
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
        connectedAt = 0L   // A-Duration
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
            val r = SshClient.connectAndExec(conn.host, conn.port, conn.user, password, joined, timeoutMs = 30_000, privateKey = keyArg(), jump = jumpCfg())
            r.onSuccess { raw ->
                val outs = raw.split(DiagnosticWorkflow.SEP)
                output += Redactor.redact(raw.replace(DiagnosticWorkflow.SEP, "──────")) + "\n"
                if (SettingsStore.isConfigured(ctx)) {
                    output += "\n🤖 AI 分析中…\n"
                    // 知识卡片注入：让 AI 结合这台机的历史问题/方案排障（知识沉淀闭环）
                    val notebook = ServerNotebook.composeForAI(ServerNotebook.load(ctx, conn.id))
                    val sys = if (notebook.isNotEmpty()) "${wf.summaryPrompt}\n\n$notebook\n请结合以上历史运维记录给出针对性结论。" else wf.summaryPrompt
                    if (notebook.isNotEmpty()) output += "📓 已结合本机知识卡片\n"
                    val ai = AiClient.chat(SettingsStore.loadApiKey(ctx), SettingsStore.loadModel(ctx),
                        listOf("user" to wf.composeForAI(outs)), sys)
                    val conclusion = ai.getOrNull()
                    output += "【AI 结论】\n" + (conclusion ?: "⚠️ ${ai.exceptionOrNull()?.message}") + "\n"
                    // 排障结论可一键存为方案卡片（知识沉淀闭环覆盖排障路径）
                    if (!conclusion.isNullOrBlank()) diagSaveable = "排障「${wf.name}」结论：\n$conclusion"
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
                val r = SshClient.connectAndExec(conn.host, conn.port, conn.user, password, cmds.joinToString(" && "), timeoutMs = 60_000, privateKey = keyArg(), jump = jumpCfg())
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
        SftpBrowser(conn, password, keyArg(), jumpCfg(), onClose = { showFiles = false })
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
        HealthAISheet(status, conn.id, onClose = { showHealthAI = false })
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
                        SshClient.openForward(conn.host, conn.port, conn.user, password, lp, rh, rp, scope, keyArg(), jumpCfg())
                    }.onSuccess { forwardHandle = it; forwardLabel = "127.0.0.1:$lp → $rh:$rp"; output += "🔀 端口转发已建立：$forwardLabel\n" }
                        .onFailure { output += "⚠️ 端口转发失败：${it.message}\n" }
                    showForward = false
                }
            }
        )
    }

    // 服务器知识卡片 sheet（每台机沉淀历史问题/方案/笔记）
    if (showNotebook) {
        NotebookSheet(conn.id, onClose = { showNotebook = false })
    }
    // 随手记：快速存为知识卡片（命令历史/排障后一键沉淀）
    quickNote?.let { prefill ->
        var noteText by remember { mutableStateOf(prefill) }
        var noteKind by remember { mutableStateOf(NoteKind.NOTE) }
        AlertDialog(
            onDismissRequest = { quickNote = null },
            title = { Text("存为知识卡片", color = TextPrimary) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        NoteKind.values().forEach { k ->
                            val c = when (k) { NoteKind.ISSUE -> Danger; NoteKind.SOLUTION -> Success; NoteKind.NOTE -> Accent }
                            FilterChip(selected = noteKind == k, onClick = { noteKind = k }, label = { Text(k.label, fontSize = 12.sp) },
                                colors = FilterChipDefaults.filterChipColors(selectedContainerColor = c.copy(alpha = 0.25f), selectedLabelColor = c, labelColor = TextSecondary))
                        }
                    }
                    OutlinedTextField(noteText, { noteText = it }, minLines = 2, maxLines = 4,
                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent),
                        modifier = Modifier.fillMaxWidth())
                }
            },
            confirmButton = { TextButton(onClick = {
                if (noteText.trim().isNotEmpty()) { ServerNotebook.add(ctx, conn.id, ServerNote(kind = noteKind, text = noteText.trim())) }
                quickNote = null
            }) { Text("保存", color = Accent) } },
            dismissButton = { TextButton(onClick = { quickNote = null }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
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
                            // 命令收藏夹：星标收藏
                            val fav = favorites.contains(h)
                            IconButton(onClick = { favorites.clear(); favorites.addAll(CommandFavorites.toggle(ctx, h)) }, modifier = Modifier.size(28.dp)) {
                                Icon(if (fav) Icons.Filled.Star else Icons.Filled.StarBorder, "收藏", tint = if (fav) Warning else TextSecondary, modifier = Modifier.size(15.dp))
                            }
                            // 随手记：把命令存为知识卡片
                            IconButton(onClick = { quickNote = h; showHistory = false }, modifier = Modifier.size(28.dp)) {
                                Icon(Icons.Filled.BookmarkAdd, "存为知识卡片", tint = TextSecondary, modifier = Modifier.size(14.dp))
                            }
                            IconButton(onClick = { cmdHistory.clear(); cmdHistory.addAll(CommandHistory.remove(ctx, h)) }, modifier = Modifier.size(28.dp)) {
                                Icon(Icons.Filled.Close, "删除", tint = TextSecondary, modifier = Modifier.size(14.dp))
                            }
                        }
                    }
                }
            }
        }
    }

    // A-SnippetCRUD：新建快捷命令对话框
    if (showNewSnippet) {
        var t by remember { mutableStateOf("") }
        var c by remember { mutableStateOf(command) }
        AlertDialog(
            onDismissRequest = { showNewSnippet = false },
            title = { Text("新建快捷命令", color = TextPrimary) },
            text = {
                val dlgColors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight,
                    focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent,
                    focusedLabelColor = Accent, unfocusedLabelColor = TextSecondary)
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(t, { t = it }, label = { Text("名称") }, singleLine = true, colors = dlgColors)
                    OutlinedTextField(c, { c = it }, label = { Text("命令") }, singleLine = true, colors = dlgColors)
                }
            },
            confirmButton = { TextButton(onClick = {
                if (c.isNotBlank()) { customSnippets.clear(); customSnippets.addAll(SnippetStore.add(ctx, CommandSnippet(t.trim().ifEmpty { c.trim() }, c.trim(), "自定义"))) }
                showNewSnippet = false
            }) { Text("保存", color = Accent) } },
            dismissButton = { TextButton(onClick = { showNewSnippet = false }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
    }
    // 快捷命令导入（粘贴导出的 Markdown/宽松文本→解析+去重）
    if (showSnippetImport) {
        var imp by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { showSnippetImport = false },
            title = { Text("导入快捷命令", color = TextPrimary) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("粘贴导出的内容（Markdown）或每行「标题|命令」。", color = TextSecondary, fontSize = 12.sp)
                    OutlinedTextField(imp, { imp = it }, placeholder = { Text("- **磁盘**：`df -h`\n或 磁盘|df -h", color = TextSecondary) },
                        minLines = 3, maxLines = 8,
                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent),
                        modifier = Modifier.fillMaxWidth())
                }
            },
            confirmButton = { TextButton(onClick = {
                val parsed = SnippetStore.parseImport(imp)
                val existing = customSnippets.map { "${it.title}|${it.command}" }.toSet()
                val fresh = parsed.filter { "${it.title}|${it.command}" !in existing }
                fresh.forEach { customSnippets.clear(); customSnippets.addAll(SnippetStore.add(ctx, it)) }
                android.widget.Toast.makeText(ctx, if (fresh.isEmpty()) "无新快捷命令" else "已导入 ${fresh.size} 条", android.widget.Toast.LENGTH_SHORT).show()
                showSnippetImport = false
            }) { Text("导入", color = Accent) } },
            dismissButton = { TextButton(onClick = { showSnippetImport = false }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
    }
    // 编辑自定义快捷命令对话框（长按自定义 Chip 进入；可改 名称/命令/分组）
    editingSnippet?.let { orig ->
        var t by remember { mutableStateOf(orig.title) }
        var c by remember { mutableStateOf(orig.command) }
        var g by remember { mutableStateOf(orig.group) }
        val dlgColors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight,
            focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent,
            focusedLabelColor = Accent, unfocusedLabelColor = TextSecondary)
        AlertDialog(
            onDismissRequest = { editingSnippet = null },
            title = { Text("编辑快捷命令", color = TextPrimary) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(t, { t = it }, label = { Text("名称") }, singleLine = true, colors = dlgColors)
                    OutlinedTextField(c, { c = it }, label = { Text("命令") }, singleLine = true, colors = dlgColors)
                    OutlinedTextField(g, { g = it }, label = { Text("分组（可选）") }, singleLine = true, colors = dlgColors)
                }
            },
            confirmButton = { TextButton(onClick = {
                if (c.isNotBlank()) {
                    val new = CommandSnippet(t.trim().ifEmpty { c.trim() }, c.trim(), g.trim().ifEmpty { "自定义" })
                    customSnippets.clear(); customSnippets.addAll(SnippetStore.update(ctx, orig, new))
                }
                editingSnippet = null
            }) { Text("保存", color = Accent) } },
            dismissButton = { TextButton(onClick = { editingSnippet = null }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
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
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = TextPrimary) } },
                actions = {
                    // A-Forward：端口转发（有活动转发则高亮）
                    IconButton(onClick = { showForward = true }) {
                        Icon(Icons.Filled.SwapHoriz, "端口转发", tint = if (forwardHandle != null) Accent else TextSecondary)
                    }
                    // A-Rollback：操作时间线（有记录才高亮）
                    IconButton(onClick = { showTimeline = true }) {
                        Icon(Icons.Filled.History, "时间线", tint = if (opTimeline.isEmpty()) TextSecondary.copy(alpha = 0.5f) else Accent)
                    }
                    // 知识卡片：每台机沉淀历史问题/方案/笔记
                    IconButton(onClick = { showNotebook = true }) {
                        Icon(Icons.AutoMirrored.Filled.MenuBook, "知识卡片", tint = TextSecondary)
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
                    Text(label, color = TextPrimary, fontSize = 13.sp)
                    // A-Duration：连接时长（每秒刷新）
                    if (state == ConnState.CONNECTED && connectedAt > 0) {
                        LaunchedEffect(connectedAt) { while (true) { kotlinx.coroutines.delay(1000); durTick++ } }
                        durTick // 读一次触发重组
                        Spacer(Modifier.width(8.dp))
                        Text(formatDuration(System.currentTimeMillis() - connectedAt), color = TextSecondary, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                    }
                    Spacer(Modifier.weight(1f))
                    if (state == ConnState.CONNECTED) {
                        TextButton(onClick = { disconnect() }) { Text("断开", color = Danger, fontSize = 12.sp) }
                    }
                }
            }
            // A-Status：真实状态面板（连接后采集 top/free/df）
            if (state == ConnState.CONNECTED) {
                Surface(color = SurfaceLight.copy(alpha = 0.5f), shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp).fillMaxWidth()) {
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
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
                        // 负载 + 运行时长（对齐 apple StatusBar）
                        if (status.load != "—" || status.uptime != "—") {
                            Spacer(Modifier.height(8.dp))
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                                if (status.load != "—") Text("负载 ${status.load}", color = TextSecondary, fontSize = 11.sp)
                                if (status.uptime != "—") Text("运行 ${status.uptime}", color = TextSecondary, fontSize = 11.sp)
                            }
                        }
                    }
                }
            }
            // A-Jump：跳板机密码（未连接 + 配了跳板机时显示，临时输入不持久化）
            if (state != ConnState.CONNECTED && conn.hasJump) {
                OutlinedTextField(
                    jumpPassword, { jumpPassword = it },
                    label = { Text("跳板机密码（${conn.jumpUser}@${conn.jumpHost}:${conn.jumpPort}）") }, singleLine = true,
                    visualTransformation = androidx.compose.ui.text.input.PasswordVisualTransformation(),
                    colors = termColors, modifier = Modifier.fillMaxWidth()
                )
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
            // 排障结论一键存为方案卡片（知识沉淀闭环覆盖排障路径）
            diagSaveable?.let { conclusion ->
                AssistChip(
                    onClick = {
                        ServerNotebook.add(ctx, conn.id, ServerNote(kind = NoteKind.SOLUTION, text = conclusion))
                        android.widget.Toast.makeText(ctx, "排障结论已存为方案", android.widget.Toast.LENGTH_SHORT).show()
                        diagSaveable = null
                    },
                    label = { Text("把排障结论存为方案", fontSize = 12.sp) },
                    leadingIcon = { Icon(Icons.Filled.BookmarkAdd, null, tint = Success, modifier = Modifier.size(16.dp)) },
                    trailingIcon = { Icon(Icons.Filled.Close, "忽略", tint = TextSecondary, modifier = Modifier.size(14.dp).clickable { diagSaveable = null }) },
                    colors = AssistChipDefaults.assistChipColors(containerColor = Success.copy(alpha = 0.12f), labelColor = Success)
                )
            }
            // A-TermSearch：终端搜索框（toggle 显示）
            if (termSearchOn) {
                val matchCount = if (termSearch.isNotEmpty()) SshClient.stripAnsi(output).split(termSearch, ignoreCase = true).size - 1 else 0
                OutlinedTextField(
                    termSearch, { termSearch = it }, placeholder = { Text("搜索终端输出…", color = TextSecondary) }, singleLine = true,
                    leadingIcon = { Icon(Icons.Filled.Search, null, tint = TextSecondary) },
                    trailingIcon = { if (termSearch.isNotEmpty()) Text("$matchCount 处", color = TextSecondary, fontSize = 11.sp, modifier = Modifier.padding(end = 10.dp)) },
                    colors = termColors, modifier = Modifier.fillMaxWidth()
                )
            }
            // 终端输出区（A-Ansi 彩色 + A-FontSize 可调字号 + A-TermSearch 搜索高亮）
            Surface(color = Color(0xFF0D0D1A), shape = RoundedCornerShape(12.dp), modifier = Modifier.weight(1f).fillMaxWidth()) {
                Box {
                    // 搜索激活+有词：渲染去 ANSI 的高亮文本；否则正常 ANSI 彩色
                    val termText = if (termSearchOn && termSearch.isNotEmpty()) highlightMatches(SshClient.stripAnsi(output), termSearch) else AnsiParser.parse(output)
                    // A-AutoScroll：新输出时自动滚到底部（搜索时不强制滚，让用户查看）
                    val termScroll = rememberScrollState()
                    LaunchedEffect(output.length) {
                        if (!termSearchOn) termScroll.scrollTo(termScroll.maxValue)
                    }
                    Text(
                        termText, fontSize = termFont.sp, fontFamily = FontFamily.Monospace,
                        modifier = Modifier.padding(14.dp).verticalScroll(termScroll)
                    )
                    // A-FontSize / A-TermActions / A-TermSearch：搜索 + 字号 +/- + 复制全部 + 清屏
                    val termClip = LocalClipboardManager.current
                    Row(Modifier.align(Alignment.TopEnd).padding(4.dp)) {
                        IconButton(onClick = { termSearchOn = !termSearchOn; if (!termSearchOn) termSearch = "" }, modifier = Modifier.size(28.dp)) {
                            Icon(Icons.Filled.Search, "搜索", tint = if (termSearchOn) Accent else TextSecondary, modifier = Modifier.size(15.dp))
                        }
                        IconButton(onClick = { termClip.setText(androidx.compose.ui.text.AnnotatedString(SshClient.stripAnsi(output))) }, modifier = Modifier.size(28.dp)) {
                            Icon(Icons.Filled.ContentCopy, "复制全部", tint = TextSecondary, modifier = Modifier.size(15.dp))
                        }
                        IconButton(onClick = { output = "" }, modifier = Modifier.size(28.dp)) {
                            Icon(Icons.Filled.ClearAll, "清屏", tint = TextSecondary, modifier = Modifier.size(16.dp))
                        }
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
            // 命令收藏夹：收藏的命令横滑 Chip（⭐ 置顶，点击填入）
            if (state == ConnState.CONNECTED && favorites.isNotEmpty()) {
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    favorites.forEach { fav ->
                        AssistChip(
                            onClick = { command = fav },
                            label = { Text(fav, fontSize = 11.sp, fontFamily = FontFamily.Monospace, maxLines = 1) },
                            leadingIcon = { Icon(Icons.Filled.Star, null, tint = Warning, modifier = Modifier.size(12.dp)) },
                            trailingIcon = { Icon(Icons.Filled.Close, "取消收藏", tint = TextSecondary, modifier = Modifier.size(12.dp).clickable { favorites.clear(); favorites.addAll(CommandFavorites.toggle(ctx, fav)) }) },
                            colors = AssistChipDefaults.assistChipColors(containerColor = Warning.copy(alpha = 0.12f), labelColor = TextPrimary)
                        )
                    }
                }
            }
            // A-Snippets+CRUD：快捷命令横滑 Chip（按分组显示分组标签，点击填入；末尾「+」新建，长按自定义项删除）
            if (state == ConnState.CONNECTED) {
                // 按 group 分组（无分组的归「其他」），保序：默认在前自定义在后
                val grouped = (CommandSnippet.defaults + customSnippets).groupBy { it.group.ifEmpty { "其他" } }
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    grouped.forEach { (group, list) ->
                        // 分组标签（对齐 apple SnippetsView 分组）
                        Text(group, color = TextSecondary, fontSize = 10.sp, fontWeight = FontWeight.Medium, modifier = Modifier.padding(start = 2.dp))
                        list.forEach { sn ->
                            val custom = sn in customSnippets
                            // 自定义片段长按可编辑（combinedClickable 包裹）
                            Box(Modifier.combinedClickable(onClick = { command = sn.command }, onLongClick = { if (custom) editingSnippet = sn })) {
                                AssistChip(
                                    onClick = { command = sn.command },
                                    label = { Text(sn.title, fontSize = 11.sp) },
                                    leadingIcon = { Icon(Icons.Filled.Circle, null, tint = sn.risk.color, modifier = Modifier.size(8.dp)) },
                                    trailingIcon = if (custom) { {
                                        Icon(Icons.Filled.Close, "删除", tint = TextSecondary,
                                            modifier = Modifier.size(14.dp).clickable { customSnippets.clear(); customSnippets.addAll(SnippetStore.remove(ctx, sn)) })
                                    } } else null,
                                    colors = AssistChipDefaults.assistChipColors(containerColor = SurfaceLight.copy(alpha = 0.45f), labelColor = TextPrimary)
                                )
                            }
                        }
                    }
                    AssistChip(onClick = { showNewSnippet = true }, label = { Text("+ 新建", fontSize = 11.sp) },
                        colors = AssistChipDefaults.assistChipColors(containerColor = Accent.copy(alpha = 0.2f), labelColor = Accent))
                    // 快捷命令导出分享（备份/团队共享）
                    AssistChip(onClick = {
                        val md = buildString {
                            append("# Termind 快捷命令\n")
                            (CommandSnippet.defaults + customSnippets).groupBy { it.group.ifEmpty { "其他" } }.forEach { (g, list) ->
                                append("\n## $g\n"); list.forEach { append("- **${it.title}**：`${it.command}`\n") }
                            }
                        }
                        ctx.startActivity(android.content.Intent.createChooser(
                            android.content.Intent(android.content.Intent.ACTION_SEND).setType("text/plain")
                                .putExtra(android.content.Intent.EXTRA_TEXT, md), "导出快捷命令"))
                    }, label = { Text("导出", fontSize = 11.sp) },
                        leadingIcon = { Icon(Icons.Filled.Share, null, tint = TextSecondary, modifier = Modifier.size(12.dp)) },
                        colors = AssistChipDefaults.assistChipColors(containerColor = SurfaceLight.copy(alpha = 0.45f), labelColor = TextSecondary))
                    AssistChip(onClick = { showSnippetImport = true }, label = { Text("导入", fontSize = 11.sp) },
                        leadingIcon = { Icon(Icons.Filled.FileDownload, null, tint = TextSecondary, modifier = Modifier.size(12.dp)) },
                        colors = AssistChipDefaults.assistChipColors(containerColor = SurfaceLight.copy(alpha = 0.45f), labelColor = TextSecondary))
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
            // A-Complete：命令历史补全建议（输入时显匹配的历史命令，点击填入）
            if (state == ConnState.CONNECTED && command.trim().isNotEmpty()) {
                val q = command.trim()
                val matches = cmdHistory.filter { it != q && it.contains(q, ignoreCase = true) }.take(4)
                if (matches.isNotEmpty()) {
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        matches.forEach { h ->
                            AssistChip(
                                onClick = { command = h },
                                label = { Text(h, fontSize = 11.sp, fontFamily = FontFamily.Monospace, maxLines = 1) },
                                leadingIcon = { Icon(Icons.Filled.History, null, tint = TextSecondary, modifier = Modifier.size(12.dp)) },
                                colors = AssistChipDefaults.assistChipColors(containerColor = SurfaceLight.copy(alpha = 0.45f), labelColor = TextPrimary)
                            )
                        }
                    }
                }
            }
            // 命令输入 + 执行（已连接才可输命令；未连接显示「连接」）
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (state == ConnState.CONNECTED) {
                    // N-History：调出历史
                    IconButton(onClick = { showHistory = true }, enabled = cmdHistory.isNotEmpty()) {
                        Icon(Icons.Filled.History, "命令历史", tint = if (cmdHistory.isEmpty()) TextSecondary.copy(alpha = 0.4f) else Accent)
                    }
                    // A-Paste：粘贴剪贴板到命令框
                    val cmdClip = LocalClipboardManager.current
                    IconButton(onClick = { cmdClip.getText()?.text?.let { command = it } }) {
                        Icon(Icons.Filled.ContentPaste, "粘贴", tint = TextSecondary)
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
fun HealthAISheet(status: ServerStatus, connId: String = "", onClose: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var content by remember { mutableStateOf("") }
    var done by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        if (!SettingsStore.isConfigured(ctx)) { content = "请先在设置中配置 API Key。"; done = true; return@LaunchedEffect }
        val msg = "${status.healthSummary}\n请分析有无异常并给排查/优化建议。"
        // 知识卡片注入：结合这台机历史给健康建议（知识沉淀闭环扩展到健康分析）
        val notebook = if (connId.isNotEmpty()) ServerNotebook.composeForAI(ServerNotebook.load(ctx, connId)) else ""
        val sys = if (notebook.isNotEmpty()) "${AiClient.HEALTH_PROMPT}\n\n$notebook\n请结合以上历史运维记录分析。" else AiClient.HEALTH_PROMPT
        AiClient.chatStream(SettingsStore.loadApiKey(ctx), SettingsStore.loadModel(ctx),
            listOf("user" to msg), sys) { delta -> content += delta }
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

/** 服务器知识卡片 sheet：每台机沉淀历史问题/方案/笔记（PRODUCT 护城河 知识沉淀）。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotebookSheet(connId: String, onClose: () -> Unit) {
    val ctx = LocalContext.current
    val notes = remember { mutableStateListOf<ServerNote>().apply { addAll(ServerNotebook.load(ctx, connId)) } }
    var newKind by remember { mutableStateOf(NoteKind.NOTE) }
    var newText by remember { mutableStateOf("") }
    var newTags by remember { mutableStateOf("") }   // 逗号分隔标签
    var filterKind by remember { mutableStateOf<NoteKind?>(null) }   // null=全部
    var noteQuery by remember { mutableStateOf("") }                 // 关键词搜索
    var filterTag by remember { mutableStateOf<String?>(null) }      // 按标签筛选
    var showNoteImport by remember { mutableStateOf(false) }         // 知识卡片导入粘贴

    fun kindColor(k: NoteKind) = when (k) { NoteKind.ISSUE -> Danger; NoteKind.SOLUTION -> Success; NoteKind.NOTE -> Accent }

    ModalBottomSheet(onDismissRequest = onClose, containerColor = Bg) {
        Column(Modifier.fillMaxWidth().padding(16.dp).heightIn(min = 300.dp, max = 560.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.AutoMirrored.Filled.MenuBook, null, tint = Accent)
                Spacer(Modifier.width(8.dp))
                Text("知识卡片", color = TextPrimary, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                // 导出 Markdown 分享（团队共享运维经验）
                if (notes.isNotEmpty()) IconButton(onClick = {
                    val md = ServerNotebook.exportMarkdown(notes)
                    val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                        type = "text/plain"; putExtra(android.content.Intent.EXTRA_TEXT, md)
                    }
                    runCatching { ctx.startActivity(android.content.Intent.createChooser(intent, "导出知识卡片")) }
                }, modifier = Modifier.size(32.dp)) {
                    Icon(Icons.Filled.Share, "导出", tint = Accent, modifier = Modifier.size(18.dp))
                }
                // 导入知识卡片（粘贴 Markdown）
                IconButton(onClick = { showNoteImport = true }, modifier = Modifier.size(32.dp)) {
                    Icon(Icons.Filled.FileDownload, "导入", tint = Accent, modifier = Modifier.size(18.dp))
                }
            }
            Spacer(Modifier.height(10.dp))
            // 新增：类型选择 + 文本 + 添加
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                NoteKind.values().forEach { k ->
                    FilterChip(selected = newKind == k, onClick = { newKind = k },
                        label = { Text(k.label, fontSize = 12.sp) },
                        colors = FilterChipDefaults.filterChipColors(selectedContainerColor = kindColor(k).copy(alpha = 0.25f), selectedLabelColor = kindColor(k), labelColor = TextSecondary))
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(vertical = 8.dp)) {
                OutlinedTextField(
                    newText, { newText = it }, placeholder = { Text("记录问题/解决方案/笔记…", color = TextSecondary) },
                    singleLine = false, minLines = 1, maxLines = 3,
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent),
                    modifier = Modifier.weight(1f)
                )
                FilledIconButton(onClick = {
                    if (newText.trim().isNotEmpty()) {
                        val tags = newTags.split(",", "，").map { it.trim() }.filter { it.isNotEmpty() }
                        notes.clear(); notes.addAll(ServerNotebook.add(ctx, connId, ServerNote(kind = newKind, text = newText.trim(), tags = tags)))
                        newText = ""; newTags = ""
                    }
                }, colors = IconButtonDefaults.filledIconButtonColors(containerColor = Accent)) {
                    Icon(Icons.Filled.Add, "添加", tint = Color.White)
                }
            }
            // 标签输入（逗号分隔，可选）
            OutlinedTextField(
                newTags, { newTags = it }, placeholder = { Text("标签（逗号分隔，可选）", color = TextSecondary) }, singleLine = true,
                leadingIcon = { Icon(Icons.Filled.Sell, null, tint = TextSecondary, modifier = Modifier.size(16.dp)) },
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent),
                modifier = Modifier.fillMaxWidth().padding(bottom = 4.dp)
            )
            HorizontalDivider(color = SurfaceLight)
            // 类型筛选（记录多时按类型找）
            if (notes.isNotEmpty()) {
                Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    FilterChip(selected = filterKind == null, onClick = { filterKind = null }, label = { Text("全部", fontSize = 12.sp) },
                        colors = FilterChipDefaults.filterChipColors(selectedContainerColor = Accent.copy(alpha = 0.25f), selectedLabelColor = Accent, labelColor = TextSecondary))
                    NoteKind.values().forEach { k ->
                        FilterChip(selected = filterKind == k, onClick = { filterKind = k }, label = { Text(k.label, fontSize = 12.sp) },
                            colors = FilterChipDefaults.filterChipColors(selectedContainerColor = kindColor(k).copy(alpha = 0.25f), selectedLabelColor = kindColor(k), labelColor = TextSecondary))
                    }
                }
            }
            // 关键词搜索框（记录多时按词找）
            if (notes.size > 3) {
                OutlinedTextField(noteQuery, { noteQuery = it }, placeholder = { Text("搜索记录…", color = TextSecondary) },
                    singleLine = true, leadingIcon = { Icon(Icons.Filled.Search, null, tint = TextSecondary, modifier = Modifier.size(18.dp)) },
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent),
                    modifier = Modifier.fillMaxWidth().padding(top = 6.dp))
            }
            val shownNotes = notes.filter {
                (filterKind == null || it.kind == filterKind) &&
                (noteQuery.isBlank() || it.text.contains(noteQuery.trim(), ignoreCase = true)) &&
                (filterTag == null || it.tags.contains(filterTag))
            }
            // 标签筛选（卡片有标签时显可点标签 Chip 行）
            val allTags = notes.flatMap { it.tags }.distinct()
            if (allTags.isNotEmpty()) {
                Row(Modifier.horizontalScroll(rememberScrollState()).padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    allTags.forEach { tag ->
                        FilterChip(selected = filterTag == tag, onClick = { filterTag = if (filterTag == tag) null else tag },
                            label = { Text("#$tag", fontSize = 11.sp) },
                            colors = FilterChipDefaults.filterChipColors(selectedContainerColor = Accent.copy(alpha = 0.25f), selectedLabelColor = Accent, labelColor = TextSecondary))
                    }
                }
            }
            if (notes.isEmpty()) {
                Text("还没有记录。把这台机出过的问题、解决方案、注意事项记下来，AI 排障时可参考。", color = TextSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 12.dp))
            } else {
                LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 8.dp)) {
                    items(shownNotes.size) { i ->
                        val n = shownNotes[i]
                        Surface(color = SurfaceLight.copy(alpha = 0.4f), shape = RoundedCornerShape(10.dp), modifier = Modifier.fillMaxWidth()) {
                            Row(Modifier.padding(12.dp), verticalAlignment = Alignment.Top) {
                                Text(n.kind.label, color = kindColor(n.kind), fontSize = 11.sp, fontWeight = FontWeight.Medium, modifier = Modifier.padding(end = 10.dp, top = 1.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(n.text, color = TextPrimary, fontSize = 13.sp)
                                    if (n.tags.isNotEmpty()) {
                                        Row(Modifier.horizontalScroll(rememberScrollState()).padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                            n.tags.forEach { tag ->
                                                Text("#$tag", color = Accent, fontSize = 10.sp, modifier = Modifier.background(Accent.copy(alpha = 0.12f), RoundedCornerShape(4.dp)).padding(horizontal = 5.dp, vertical = 1.dp))
                                            }
                                        }
                                    }
                                }
                                IconButton(onClick = { notes.clear(); notes.addAll(ServerNotebook.remove(ctx, connId, n.id)) }, modifier = Modifier.size(26.dp)) {
                                    Icon(Icons.Filled.Close, "删除", tint = TextSecondary, modifier = Modifier.size(14.dp))
                                }
                            }
                        }
                    }
                }
            }
            // 知识卡片导入（粘贴导出的 Markdown→解析+去重）
            if (showNoteImport) {
                var imp by remember { mutableStateOf("") }
                AlertDialog(
                    onDismissRequest = { showNoteImport = false },
                    title = { Text("导入知识卡片", color = TextPrimary) },
                    text = {
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("粘贴导出的 Markdown（## 类型 + - 内容）。", color = TextSecondary, fontSize = 12.sp)
                            OutlinedTextField(imp, { imp = it }, placeholder = { Text("## 方案\n- 重启 nginx 前先 nginx -t", color = TextSecondary) },
                                minLines = 3, maxLines = 8,
                                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent),
                                modifier = Modifier.fillMaxWidth())
                        }
                    },
                    confirmButton = { TextButton(onClick = {
                        val parsed = ServerNotebook.parseImport(imp)
                        val existing = notes.map { it.text }.toSet()
                        val fresh = parsed.filter { it.text !in existing }
                        fresh.forEach { notes.clear(); notes.addAll(ServerNotebook.add(ctx, connId, it)) }
                        android.widget.Toast.makeText(ctx, if (fresh.isEmpty()) "无新卡片" else "已导入 ${fresh.size} 条", android.widget.Toast.LENGTH_SHORT).show()
                        showNoteImport = false
                    }) { Text("导入", color = Accent) } },
                    dismissButton = { TextButton(onClick = { showNoteImport = false }) { Text("取消", color = TextSecondary) } },
                    containerColor = Surface
                )
            }
        }
    }
}

/** A-SFTP：远程文件浏览（全屏 sheet：路径栏 + 列表 + 进入/上级） */
@OptIn(ExperimentalMaterial3Api::class, androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun SftpBrowser(conn: ServerConn, password: String, privateKey: String?, jump: JumpConfig?, onClose: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var path by remember { mutableStateOf(".") }
    var files by remember { mutableStateOf<List<RemoteFile>>(emptyList()) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var viewing by remember { mutableStateOf<Pair<String, String>?>(null) }  // A-FileView：文件名→内容
    var toast by remember { mutableStateOf<String?>(null) }                  // A-Upload 下载提示
    var showMkdir by remember { mutableStateOf(false) }                      // A-SftpEdit 新建文件夹
    var pendingDelete by remember { mutableStateOf<RemoteFile?>(null) }      // A-SftpEdit 待删除确认
    var pendingRename by remember { mutableStateOf<RemoteFile?>(null) }      // A-SftpRename 待重命名
    var showGoto by remember { mutableStateOf(false) }                       // A-SftpPath 路径直跳
    var sortMenu by remember { mutableStateOf(false) }                       // A-SftpSort 排序
    var sortMode by remember { mutableStateOf(0) }                           // 0=名称 1=大小 2=时间
    var filterOn by remember { mutableStateOf(false) }                       // A-SftpFilter 文件名过滤
    var filter by remember { mutableStateOf("") }
    val selPaths = remember { mutableStateListOf<String>() }                 // SFTP 批量删除多选
    var selMode by remember { mutableStateOf(false) }
    var showBatchDel by remember { mutableStateOf(false) }

    fun load(p: String) {
        loading = true; error = null
        scope.launch {
            SshClient.listDir(conn.host, conn.port, conn.user, password, p, privateKey, jump)
                .onSuccess { files = it; path = p }
                .onFailure { error = it.message }
            loading = false
        }
    }

    // A-SftpEdit：新建文件夹（在当前目录）
    fun mkdir(name: String) {
        val base = if (path == "." || path == "/") path else path.trimEnd('/')
        val target = (if (base == ".") "./" else "$base/") + name
        loading = true
        scope.launch {
            SshClient.makeDir(conn.host, conn.port, conn.user, password, target, privateKey, jump)
                .onSuccess { toast = "已新建文件夹 $name"; load(path) }
                .onFailure { error = it.message; loading = false }
        }
    }
    // A-SftpEdit：删除文件/空目录
    fun delete(f: RemoteFile) {
        loading = true
        scope.launch {
            SshClient.deletePath(conn.host, conn.port, conn.user, password, f.path, f.isDir, privateKey, jump)
                .onSuccess { toast = "已删除 ${f.name}"; load(path) }
                .onFailure { error = it.message; loading = false }
        }
    }
    // SFTP 批量下载：依次下载选中文件到 Downloads 目录（目录已在调用处过滤）
    fun batchDownload(targets: List<RemoteFile>) {
        if (targets.isEmpty()) { toast = "未选中文件（目录不可下载）"; selMode = false; selPaths.clear(); return }
        loading = true
        scope.launch {
            val dir = ctx.getExternalFilesDir("Downloads") ?: ctx.cacheDir
            var ok = 0
            for (f in targets) {
                val local = java.io.File(dir, f.name)
                SshClient.downloadFile(conn.host, conn.port, conn.user, password, f.path, local.absolutePath, privateKey, jump)
                    .onSuccess { ok++ }.onFailure { error = it.message }
            }
            toast = "已下载 $ok/${targets.size} 个到 ${dir.absolutePath}"
            selMode = false; selPaths.clear(); loading = false
        }
    }
    // SFTP 批量删除：依次删选中项，复用单删逻辑
    fun batchDelete(targets: List<RemoteFile>) {
        loading = true
        scope.launch {
            var ok = 0
            for (f in targets) {
                SshClient.deletePath(conn.host, conn.port, conn.user, password, f.path, f.isDir, privateKey, jump)
                    .onSuccess { ok++ }.onFailure { error = it.message }
            }
            toast = "已删除 $ok/${targets.size} 项"
            selMode = false; selPaths.clear(); load(path)
        }
    }
    // A-SftpRename：重命名（同目录新名）
    fun rename(f: RemoteFile, newName: String) {
        val dir = f.path.substringBeforeLast('/', "").ifEmpty { "." }
        val target = (if (dir == ".") "./" else "$dir/") + newName
        loading = true
        scope.launch {
            SshClient.renamePath(conn.host, conn.port, conn.user, password, f.path, target, privateKey, jump)
                .onSuccess { toast = "已重命名为 $newName"; load(path) }
                .onFailure { error = it.message; loading = false }
        }
    }

    // 下载远程文件到 app 外部文件目录
    fun download(f: RemoteFile) {
        loading = true
        scope.launch {
            val dir = ctx.getExternalFilesDir("Downloads") ?: ctx.cacheDir
            val local = java.io.File(dir, f.name)
            SshClient.downloadFile(conn.host, conn.port, conn.user, password, f.path, local.absolutePath, privateKey, jump)
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
                SshClient.uploadFile(conn.host, conn.port, conn.user, password, tmp.absolutePath, remote, privateKey, jump).getOrThrow()
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
            SshClient.readFile(conn.host, conn.port, conn.user, password, f.path, privateKey = privateKey, jump = jump)
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
                // A-SftpFilter：文件名过滤
                IconButton(onClick = { filterOn = !filterOn; if (!filterOn) filter = "" }) {
                    Icon(Icons.Filled.Search, "过滤", tint = if (filterOn) Accent else TextSecondary, modifier = Modifier.size(18.dp))
                }
                // A-SftpSort：排序
                Box {
                    IconButton(onClick = { sortMenu = true }) {
                        Icon(Icons.AutoMirrored.Filled.Sort, "排序", tint = TextSecondary, modifier = Modifier.size(18.dp))
                    }
                    DropdownMenu(expanded = sortMenu, onDismissRequest = { sortMenu = false }) {
                        listOf("名称", "大小", "时间").forEachIndexed { i, label ->
                            DropdownMenuItem(text = { Text(label, color = if (sortMode == i) Accent else TextPrimary) }, onClick = { sortMode = i; sortMenu = false })
                        }
                    }
                }
                // A-SftpEdit：新建文件夹
                IconButton(onClick = { showMkdir = true }, enabled = !loading) {
                    Icon(Icons.Filled.CreateNewFolder, "新建文件夹", tint = Accent, modifier = Modifier.size(18.dp))
                }
                IconButton(onClick = { picker.launch("*/*") }, enabled = !loading) {
                    Icon(Icons.Filled.Upload, "上传文件", tint = Accent, modifier = Modifier.size(18.dp))
                }
            }
            Spacer(Modifier.height(6.dp))
            // A-SftpPath：点路径直接输入跳转
            Row(Modifier.fillMaxWidth().clickable { showGoto = true }, verticalAlignment = Alignment.CenterVertically) {
                Text(path, color = TextSecondary, fontSize = 12.sp, fontFamily = FontFamily.Monospace, maxLines = 1, modifier = Modifier.weight(1f))
                Icon(Icons.Filled.Edit, "输入路径", tint = Accent, modifier = Modifier.size(14.dp))
            }
            Spacer(Modifier.height(8.dp))
            // 上级目录
            TextButton(onClick = {
                val parent = path.trimEnd('/').substringBeforeLast('/', "").ifEmpty { "/" }
                load(if (path == "." || path == "/") "/" else parent)
            }) { Icon(Icons.Filled.ArrowUpward, null, tint = Accent, modifier = Modifier.size(16.dp)); Spacer(Modifier.width(4.dp)); Text("上级目录", color = Accent, fontSize = 12.sp) }
            error?.let { Text("⚠️ $it", color = Danger, fontSize = 12.sp) }
            toast?.let { Text("✅ $it", color = Success, fontSize = 11.sp, maxLines = 2) }
            // A-SftpFilter：文件名过滤框
            if (filterOn) {
                OutlinedTextField(
                    filter, { filter = it }, placeholder = { Text("过滤文件名…", color = TextSecondary) }, singleLine = true,
                    leadingIcon = { Icon(Icons.Filled.Search, null, tint = TextSecondary) },
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent),
                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
                )
            }
            // A-SftpSort + A-SftpFilter：过滤 + 文件夹优先排序
            val shownFiles = remember(files, sortMode, filter) {
                val f = filter.trim()
                val filtered = if (f.isEmpty()) files else files.filter { it.name.contains(f, ignoreCase = true) }
                val cmp = compareByDescending<RemoteFile> { it.isDir }
                when (sortMode) {
                    1 -> filtered.sortedWith(cmp.thenByDescending { it.size })
                    2 -> filtered.sortedWith(cmp.thenByDescending { it.mtime })
                    else -> filtered.sortedWith(cmp.thenBy { it.name.lowercase() })
                }
            }
            // SFTP 批量删除操作栏（多选模式）
            if (selMode) {
                Row(Modifier.fillMaxWidth().background(Accent.copy(alpha = 0.1f)).padding(horizontal = 8.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("已选 ${selPaths.size}", color = Accent, fontSize = 13.sp, modifier = Modifier.weight(1f))
                    TextButton(onClick = { batchDownload(files.filter { it.path in selPaths && !it.isDir }) }, enabled = selPaths.isNotEmpty()) { Text("下载", color = Accent, fontSize = 13.sp) }
                    TextButton(onClick = { showBatchDel = true }, enabled = selPaths.isNotEmpty()) { Text("删除", color = Danger, fontSize = 13.sp) }
                    TextButton(onClick = { selMode = false; selPaths.clear() }) { Text("取消", color = TextSecondary, fontSize = 13.sp) }
                }
            }
            LazyColumn(Modifier.weight(1f)) {
                items(shownFiles.size) { i ->
                    val f = shownFiles[i]
                    val sel = f.path in selPaths
                    Row(
                        Modifier.fillMaxWidth()
                            .combinedClickable(
                                onClick = { if (selMode) { if (sel) selPaths.remove(f.path) else selPaths.add(f.path) } else if (f.isDir) load(f.path) else openFile(f) },
                                onLongClick = { selMode = true; if (!sel) selPaths.add(f.path) }
                            )
                            .background(if (sel) Accent.copy(alpha = 0.12f) else Color.Transparent)
                            .padding(vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        if (selMode) {
                            Icon(if (sel) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked, null,
                                tint = if (sel) Accent else TextSecondary, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(10.dp))
                        }
                        Icon(if (f.isDir) Icons.Filled.Folder else Icons.Filled.Description, null,
                            tint = if (f.isDir) Accent else TextSecondary, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(12.dp))
                        // A-SftpTime：名称 + 修改时间
                        Column(Modifier.weight(1f)) {
                            Text(f.name, color = TextPrimary, fontSize = 14.sp, maxLines = 1)
                            if (f.timeLabel.isNotEmpty()) Text(f.timeLabel, color = TextSecondary.copy(alpha = 0.7f), fontSize = 10.sp)
                        }
                        Text(f.sizeLabel, color = TextSecondary, fontSize = 11.sp)
                        // 多选模式隐藏单项操作图标（用批量栏）
                        if (!selMode) {
                            if (!f.isDir) {
                                IconButton(onClick = { download(f) }, modifier = Modifier.size(28.dp)) {
                                    Icon(Icons.Filled.Download, "下载", tint = Accent, modifier = Modifier.size(16.dp))
                                }
                            }
                            // A-SftpRename：重命名
                            IconButton(onClick = { pendingRename = f }, modifier = Modifier.size(28.dp)) {
                                Icon(Icons.Filled.DriveFileRenameOutline, "重命名", tint = TextSecondary, modifier = Modifier.size(15.dp))
                            }
                            // A-SftpEdit：删除（二次确认）
                            IconButton(onClick = { pendingDelete = f }, modifier = Modifier.size(28.dp)) {
                                Icon(Icons.Filled.DeleteOutline, "删除", tint = Danger, modifier = Modifier.size(16.dp))
                            }
                        }
                    }
                }
            }
        }
    }

    // A-SftpPath：输入路径直跳对话框
    if (showGoto) {
        var p by remember { mutableStateOf(path) }
        AlertDialog(
            onDismissRequest = { showGoto = false },
            title = { Text("跳转到路径", color = TextPrimary) },
            text = { OutlinedTextField(p, { p = it }, placeholder = { Text("如 /var/log", color = TextSecondary) }, singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent)) },
            confirmButton = { TextButton(onClick = { val t = p.trim(); if (t.isNotEmpty()) load(t); showGoto = false }) { Text("跳转", color = Accent) } },
            dismissButton = { TextButton(onClick = { showGoto = false }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
    }
    // SFTP 批量删除二次确认
    if (showBatchDel) {
        AlertDialog(
            onDismissRequest = { showBatchDel = false },
            icon = { Icon(Icons.Filled.Warning, null, tint = Danger) },
            title = { Text("删除 ${selPaths.size} 项？", color = TextPrimary) },
            text = { Text("将删除选中的文件/空文件夹，此操作不可撤销。", color = TextSecondary) },
            confirmButton = { TextButton(onClick = { batchDelete(files.filter { it.path in selPaths }); showBatchDel = false }) { Text("删除", color = Danger) } },
            dismissButton = { TextButton(onClick = { showBatchDel = false }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
    }
    // A-SftpEdit：新建文件夹对话框
    if (showMkdir) {
        var name by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { showMkdir = false },
            title = { Text("新建文件夹", color = TextPrimary) },
            text = { OutlinedTextField(name, { name = it }, label = { Text("文件夹名") }, singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent)) },
            confirmButton = { TextButton(onClick = { val n = name.trim(); if (n.isNotEmpty()) mkdir(n); showMkdir = false }) { Text("创建", color = Accent) } },
            dismissButton = { TextButton(onClick = { showMkdir = false }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
    }
    // A-SftpRename：重命名对话框
    pendingRename?.let { f ->
        var newName by remember { mutableStateOf(f.name) }
        AlertDialog(
            onDismissRequest = { pendingRename = null },
            title = { Text("重命名", color = TextPrimary) },
            text = { OutlinedTextField(newName, { newName = it }, label = { Text("新名称") }, singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight, focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent)) },
            confirmButton = { TextButton(onClick = { val n = newName.trim(); if (n.isNotEmpty() && n != f.name) rename(f, n); pendingRename = null }) { Text("确定", color = Accent) } },
            dismissButton = { TextButton(onClick = { pendingRename = null }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
    }
    // A-SftpEdit：删除二次确认
    pendingDelete?.let { f ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            icon = { Icon(Icons.Filled.Warning, null, tint = Danger) },
            title = { Text("删除${if (f.isDir) "文件夹" else "文件"}", color = TextPrimary) },
            text = { Text("确认删除 ${f.name}？${if (f.isDir) "（仅空文件夹可删）" else ""}此操作不可撤销。", color = TextSecondary) },
            confirmButton = { TextButton(onClick = { val t = f; pendingDelete = null; delete(t) }) { Text("删除", color = Danger) } },
            dismissButton = { TextButton(onClick = { pendingDelete = null }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
    }
}

/** A-LastUsed：毫秒时间戳 → 相对时间（刚刚/N分钟前/N小时前/N天前/日期）。 */
private fun relativeTime(ms: Long): String {
    val diff = System.currentTimeMillis() - ms
    return when {
        diff < 60_000 -> "刚刚"
        diff < 3_600_000 -> "${diff / 60_000} 分钟前"
        diff < 86_400_000 -> "${diff / 3_600_000} 小时前"
        diff < 7 * 86_400_000L -> "${diff / 86_400_000} 天前"
        else -> java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault()).format(java.util.Date(ms))
    }
}

/** A-Duration：毫秒时长 → mm:ss 或 HH:mm:ss。 */
private fun formatDuration(ms: Long): String {
    val s = ms / 1000
    val h = s / 3600; val m = (s % 3600) / 60; val sec = s % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, sec) else "%02d:%02d".format(m, sec)
}

/** A-TermSearch：把文本中匹配 query 的子串高亮（背景色），返回 AnnotatedString。 */
private fun highlightMatches(text: String, query: String): androidx.compose.ui.text.AnnotatedString {
    if (query.isEmpty()) return androidx.compose.ui.text.AnnotatedString(text)
    return androidx.compose.ui.text.buildAnnotatedString {
        var i = 0
        while (i < text.length) {
            val idx = text.indexOf(query, i, ignoreCase = true)
            if (idx < 0) { append(text.substring(i)); break }
            append(text.substring(i, idx))
            pushStyle(androidx.compose.ui.text.SpanStyle(background = Warning, color = Color.Black))
            append(text.substring(idx, idx + query.length))
            pop()
            i = idx + query.length
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
