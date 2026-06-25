package com.termind.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import kotlinx.coroutines.launch
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// Termind 品牌配色（呼应 apple 端：午夜深蓝 + 珊瑚红 accent）
val Bg = Color(0xFF1A1A2E)
val Surface = Color(0xFF16213E)
val SurfaceLight = Color(0xFF0F3460)
val Accent = Color(0xFFE94560)
val TextPrimary = Color(0xFFEEEEEE)
val TextSecondary = Color(0xFFA0A0A0)
val Success = Color(0xFF2ECC71)
val Warning = Color(0xFFF39C12)
val Danger = Color(0xFFE74C3C)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { TermindTheme { TermindApp() } }
    }
}

@Composable
fun TermindTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Accent, background = Bg, surface = Surface,
            onPrimary = Color.White, onBackground = TextPrimary, onSurface = TextPrimary
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
    var tab by remember { mutableStateOf(Tab.Servers) }
    var detail by remember { mutableStateOf<ServerConn?>(null) }
    // 连接列表：从 store 加载，增删改后持久化
    val conns = remember { mutableStateListOf<ServerConn>().apply { addAll(ConnectionStore.load(ctx)) } }
    var editing by remember { mutableStateOf<ServerConn?>(null) }   // 当前编辑中的连接
    var showEditor by remember { mutableStateOf(false) }
    fun persist() = ConnectionStore.save(ctx, conns)

    // 连接详情「工作区」覆盖在最上层
    detail?.let { conn ->
        ServerWorkspace(conn, onBack = { detail = null })
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
                    onOpen = { detail = it },
                    onEdit = { editing = it; showEditor = true },
                    onDelete = { conns.remove(it); persist() }
                )
                Tab.AI -> AIAssistantScreen()
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
    onOpen: (ServerConn) -> Unit,
    onEdit: (ServerConn) -> Unit,
    onDelete: (ServerConn) -> Unit
) {
    Column {
        TopBar("Termind", "智能 SSH 运维")
        if (conns.isEmpty()) {
            Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                Icon(Icons.Filled.Dns, null, tint = TextSecondary, modifier = Modifier.size(48.dp))
                Spacer(Modifier.height(12.dp))
                Text("还没有连接，点右下角 + 新建", color = TextSecondary, fontSize = 14.sp)
            }
            return
        }
        val grouped = conns.groupBy { it.group }
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            grouped.forEach { (group, list) ->
                if (group.isNotEmpty()) item { Text(group, fontSize = 12.sp, color = TextSecondary, modifier = Modifier.padding(top = 14.dp, bottom = 2.dp)) }
                items(list, key = { it.id }) { conn -> ServerCard(conn, onClick = { onOpen(conn) }, onEdit = { onEdit(conn) }, onDelete = { onDelete(conn) }) }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ServerCard(conn: ServerConn, onClick: () -> Unit, onEdit: () -> Unit, onDelete: () -> Unit) {
    var menu by remember { mutableStateOf(false) }
    Card(
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = SurfaceLight.copy(alpha = 0.5f)),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Circle, null, tint = if (conn.online) Success else TextSecondary, modifier = Modifier.size(10.dp))
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
fun AIAssistantScreen() {
    Column {
        TopBar("AI 运维助手")
        Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("让 AI 结合服务器真实环境帮你运维", color = TextSecondary, fontSize = 13.sp)
            listOf("帮我查看为什么网站打不开", "解释这条命令：docker system prune -a", "分析这段报错并给修复", "一键初始化 Ubuntu Web 服务器").forEach {
                Card(colors = CardDefaults.cardColors(containerColor = SurfaceLight.copy(alpha = 0.45f)), shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.AutoAwesome, null, tint = Accent, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(10.dp))
                        Text(it, color = TextPrimary, fontSize = 13.sp)
                    }
                }
            }
            Spacer(Modifier.weight(1f))
            Surface(color = Surface, shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("用自然语言描述运维任务…", color = TextSecondary, fontSize = 13.sp, modifier = Modifier.weight(1f))
                    Icon(Icons.Filled.ArrowUpward, null, tint = Accent)
                }
            }
        }
    }
}

@Composable
fun SettingsScreen() {
    Column {
        TopBar("设置")
        Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SettingRow(Icons.Filled.Palette, "配色主题", "午夜")
            SettingRow(Icons.Filled.SmartToy, "AI 服务商", "Anthropic Claude")
            SettingRow(Icons.Filled.Key, "API Key", "未配置")
            SettingRow(Icons.Filled.Info, "关于 Termind", "智能 SSH 运维工作台 v1.0")
        }
    }
}

@Composable
private fun SettingRow(icon: ImageVector, title: String, value: String) {
    Surface(color = SurfaceLight.copy(alpha = 0.4f), shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = Accent, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(12.dp))
            Text(title, color = TextPrimary, fontSize = 14.sp, modifier = Modifier.weight(1f))
            Text(value, color = TextSecondary, fontSize = 12.sp)
        }
    }
}

/** 连接后「工作区」：真实 SSH 执行命令 + 终端输出 + 状态面板 + AI 入口（A1） */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ServerWorkspace(conn: ServerConn, onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var password by remember { mutableStateOf("") }
    var command by remember { mutableStateOf("") }
    var output by remember { mutableStateOf("提示：输入密码与命令，点「执行」经 SSH 运行。\n（A1 先支持单条命令 exec；交互式终端 A1b）\n") }
    var running by remember { mutableStateOf(false) }
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
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Surface)
            )
        }
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize().padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // 状态面板占位（A4 接真实采集）
            Surface(color = SurfaceLight.copy(alpha = 0.5f), shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
                Row(Modifier.padding(14.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    StatCell("CPU", "—", Success)
                    StatCell("内存", "—", Warning)
                    StatCell("磁盘", "—", Success)
                }
            }
            // 密码（MVP；后续走 Keystore + 密钥）
            OutlinedTextField(
                password, { password = it }, label = { Text("SSH 密码") }, singleLine = true,
                visualTransformation = androidx.compose.ui.text.input.PasswordVisualTransformation(),
                colors = termColors, modifier = Modifier.fillMaxWidth()
            )
            // 终端输出区
            Surface(color = Color(0xFF0D0D1A), shape = RoundedCornerShape(12.dp), modifier = Modifier.weight(1f).fillMaxWidth()) {
                Text(
                    output, color = Success, fontSize = 12.sp, fontFamily = FontFamily.Monospace,
                    modifier = Modifier.padding(14.dp).verticalScroll(rememberScrollState())
                )
            }
            // 命令输入 + 执行
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    command, { command = it }, label = { Text("命令") }, singleLine = true,
                    colors = termColors, modifier = Modifier.weight(1f)
                )
                FilledIconButton(
                    onClick = {
                        val cmd = command.trim(); if (cmd.isEmpty() || running) return@FilledIconButton
                        running = true
                        output += "\n$ $cmd\n"
                        scope.launch {
                            val r = SshClient.connectAndExec(conn.host, conn.port, conn.user, password, cmd)
                            output += r.getOrElse { "⚠️ ${it.message ?: "连接失败"}" } + "\n"
                            command = ""; running = false
                        }
                    },
                    colors = IconButtonDefaults.filledIconButtonColors(containerColor = Accent)
                ) {
                    if (running) CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                    else Icon(Icons.Filled.ArrowUpward, "执行", tint = Color.White)
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
