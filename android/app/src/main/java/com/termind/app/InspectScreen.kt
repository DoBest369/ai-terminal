package com.termind.app

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.launch

/** 单台服务器的巡检结果 */
data class InspectItem(val conn: ServerConn, val running: Boolean, val status: ServerStatus?, val error: String?)

/**
 * 批量健康巡检（N-Cron 手动版）：一键并发查所有服务器 CPU/内存/磁盘，
 * 异常（资源>85%）红色置顶。运维巡检刚需——一眼看全部机器健康。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InspectScreen(conns: List<ServerConn>, onBack: () -> Unit) {
    val ctx = androidx.compose.ui.platform.LocalContext.current
    val scope = rememberCoroutineScope()
    var password by remember { mutableStateOf("") }
    var running by remember { mutableStateOf(false) }
    val items = remember { mutableStateListOf<InspectItem>() }
    var aiSummary by remember { mutableStateOf<String?>(null) }   // N-Cron-AI 巡检总结

    // N-Cron-AI：把巡检结果拼给 AI 总结
    fun summarize() {
        if (!SettingsStore.isConfigured(ctx)) { aiSummary = "请先在「设置」配置 API Key。"; return }
        aiSummary = ""
        val material = buildString {
            append("对 ${items.size} 台服务器做了健康巡检，各自状态：\n")
            items.forEach { i ->
                append("\n【${i.conn.name}】")
                if (i.error != null) append("巡检失败：${i.error}")
                else i.status?.let {
                    append("CPU ${it.cpu} 内存 ${it.mem} 磁盘 ${it.disk}")
                    if (it.load != "—") append(" 负载 ${it.load}")
                    if (it.uptime != "—") append(" 运行 ${it.uptime}")
                    if (it.hasWarning) append(" ⚠️资源偏高")
                }
            }
        }
        scope.launch {
            AiClient.chatStream(SettingsStore.loadApiKey(ctx), SettingsStore.loadModel(ctx),
                listOf("user" to material),
                "你是运维助手。这是一批服务器的健康巡检结果，请：① 总览(健康/需关注台数) ② 哪些机器资源紧张或异常及风险 ③ 优先处理建议。精炼中文。"
            ) { delta -> aiSummary = (aiSummary ?: "") + delta }.onFailure { aiSummary = "⚠️ ${it.message}" }
        }
    }

    fun inspect() {
        if (password.isBlank() || running || conns.isEmpty()) return
        running = true
        items.clear()
        conns.forEach { items.add(InspectItem(it, true, null, null)) }
        scope.launch {
            conns.map { c ->
                async {
                    val r = SshClient.fetchStatus(c.host, c.port, c.user, password)
                    val idx = items.indexOfFirst { it.conn.id == c.id }
                    if (idx >= 0) items[idx] = r.fold(
                        onSuccess = { InspectItem(c, false, it, null) },
                        onFailure = { InspectItem(c, false, null, it.message) }
                    )
                }
            }.awaitAll()
            running = false
        }
    }

    // 异常（告警/错误）置顶
    val sorted = items.sortedByDescending { (it.status?.hasWarning == true) || it.error != null }
    val warnCount = items.count { (it.status?.hasWarning == true) || it.error != null }
    val done = items.isNotEmpty() && items.none { it.running }

    // N-Cron-AI 总结弹窗
    aiSummary?.let { sum ->
        AlertDialog(
            onDismissRequest = { aiSummary = null },
            icon = { Icon(Icons.Filled.AutoAwesome, null, tint = Accent) },
            title = { Text("AI 巡检总结", color = TextPrimary) },
            text = { Column(Modifier.heightIn(max = 420.dp).verticalScroll(androidx.compose.foundation.rememberScrollState())) { Text(sum.ifEmpty { "分析中…" }, color = TextPrimary, fontSize = 13.sp) } },
            confirmButton = { TextButton(onClick = { aiSummary = null }) { Text("关闭", color = Accent) } },
            containerColor = Surface
        )
    }

    val fieldColors = OutlinedTextFieldDefaults.colors(
        focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight,
        focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary, cursorColor = Accent,
        focusedLabelColor = Accent, unfocusedLabelColor = TextSecondary
    )

    Scaffold(
        containerColor = Bg,
        topBar = {
            TopAppBar(
                title = { Text("健康巡检 · ${conns.size} 台", color = TextPrimary, fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = TextPrimary) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Surface)
            )
        }
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize().padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(password, { password = it }, label = { Text("统一 SSH 密码") }, singleLine = true,
                visualTransformation = PasswordVisualTransformation(), colors = fieldColors, modifier = Modifier.fillMaxWidth())
            Button(onClick = { inspect() }, enabled = !running && password.isNotBlank(),
                colors = ButtonDefaults.buttonColors(containerColor = Accent), modifier = Modifier.fillMaxWidth()) {
                if (running) CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                else Text("开始巡检（${conns.size} 台）", color = Color.White)
            }
            if (done) {
                Surface(color = (if (warnCount > 0) Danger else Success).copy(alpha = 0.15f), shape = RoundedCornerShape(10.dp), modifier = Modifier.fillMaxWidth()) {
                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(if (warnCount > 0) Icons.Filled.Warning else Icons.Filled.CheckCircle, null,
                            tint = if (warnCount > 0) Danger else Success)
                        Spacer(Modifier.width(8.dp))
                        // 告警/正常/失败 明细统计（对齐群发统计）
                        val failN = items.count { it.error != null }
                        val alertN = items.count { it.error == null && it.status?.hasWarning == true }
                        val okN = items.size - failN - alertN
                        val statTxt = buildList {
                            if (alertN > 0) add("⚠️告警 $alertN")
                            add("✅正常 $okN")
                            if (failN > 0) add("❌失败 $failN")
                        }.joinToString(" · ")
                        Text(statTxt, color = if (warnCount > 0) Danger else Success, fontWeight = FontWeight.Medium, fontSize = 13.sp)
                        Spacer(Modifier.weight(1f))
                        TextButton(onClick = { summarize() }) {
                            Icon(Icons.Filled.AutoAwesome, null, tint = Accent, modifier = Modifier.size(14.dp))
                            Spacer(Modifier.width(4.dp)); Text("AI 总结", color = Accent, fontSize = 12.sp)
                        }
                    }
                }
            }
            LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(sorted.size) { i ->
                    val it = sorted[i]
                    val warn = (it.status?.hasWarning == true) || it.error != null
                    Surface(color = if (warn) Danger.copy(alpha = 0.12f) else SurfaceLight.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(10.dp), modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(12.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(if (it.running) Icons.Filled.Sync else if (warn) Icons.Filled.Error else Icons.Filled.CheckCircle,
                                    null, tint = if (it.running) Warning else if (warn) Danger else Success, modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(8.dp))
                                Text(it.conn.name, color = TextPrimary, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                            }
                            if (!it.running) {
                                Spacer(Modifier.height(4.dp))
                                if (it.error != null) Text("⚠️ ${it.error}", color = Danger, fontSize = 11.sp)
                                else it.status?.let { s ->
                                    Text("CPU ${s.cpu} · 内存 ${s.mem} · 磁盘 ${s.disk}", color = TextSecondary, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
