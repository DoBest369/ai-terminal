package com.termind.app

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.launch

/** 单个连接的群发结果 */
data class BatchResult(val conn: ServerConn, val running: Boolean, val output: String, val ok: Boolean)

/**
 * 批量群发命令（N-Multi）：选多台服务器，并发执行同一命令，汇总输出。
 * 运维工作台杀手级差异化——一条命令打到一批机器。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BatchScreen(conns: List<ServerConn>, onBack: () -> Unit) {
    val ctx = androidx.compose.ui.platform.LocalContext.current
    val scope = rememberCoroutineScope()
    val selected = remember { mutableStateListOf<String>() }   // 选中连接 id
    var command by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var running by remember { mutableStateOf(false) }
    var pendingConfirm by remember { mutableStateOf(false) }
    val results = remember { mutableStateListOf<BatchResult>() }
    var aiSummary by remember { mutableStateOf<String?>(null) }   // N-Multi-AI 群发结果 AI 汇总
    val allDone = results.isNotEmpty() && results.none { it.running }

    // N-Multi-AI：把各结果拼给 AI 汇总
    fun summarize() {
        if (!SettingsStore.isConfigured(ctx)) { aiSummary = "请先在「设置」配置 API Key 以使用 AI 汇总。"; return }
        aiSummary = ""
        val material = buildString {
            append("对 ${results.size} 台服务器执行了同一命令：`$command`\n各自结果如下：\n")
            results.forEach { append("\n【${it.conn.name}】${if (it.ok) "成功" else "失败"}\n${it.output.take(500)}\n") }
        }
        scope.launch {
            AiClient.chatStream(SettingsStore.loadApiKey(ctx), SettingsStore.loadModel(ctx),
                listOf("user" to material),
                "你是运维助手。这是一批服务器执行同一命令的结果，请：① 总览(成功/失败台数) ② 失败的机器及原因 ③ 共性问题或差异 ④ 后续建议。精炼中文。"
            ) { delta -> aiSummary = (aiSummary ?: "") + delta }.onFailure { aiSummary = "⚠️ ${it.message}" }
        }
    }

    fun exec() {
        val cmd = command.trim()
        val targets = conns.filter { selected.contains(it.id) }
        if (cmd.isEmpty() || targets.isEmpty() || running) return
        running = true
        results.clear()
        targets.forEach { results.add(BatchResult(it, true, "", false)) }
        scope.launch {
            targets.map { conn ->
                async {
                    val r = SshClient.connectAndExec(conn.host, conn.port, conn.user, password, cmd, timeoutMs = 30_000)
                    val idx = results.indexOfFirst { it.conn.id == conn.id }
                    if (idx >= 0) results[idx] = BatchResult(conn, false,
                        Redactor.redact(r.getOrElse { "⚠️ ${it.message}" }).trim().ifBlank { "(无输出)" },
                        r.isSuccess)
                }
            }.awaitAll()
            running = false
        }
    }
    fun submit() {
        if (CommandRisk.riskLevel(command).needsConfirm) pendingConfirm = true else exec()
    }

    if (pendingConfirm) {
        val risk = CommandRisk.riskLevel(command)
        AlertDialog(
            onDismissRequest = { pendingConfirm = false },
            icon = { Icon(Icons.Filled.Warning, null, tint = risk.color) },
            title = { Text("${risk.label}命令 · 群发 ${selected.size} 台", color = TextPrimary) },
            text = { Text("即将对 ${selected.size} 台服务器执行：\n$command\n\n群发${risk.label}命令影响面更大，确认？", color = TextSecondary) },
            confirmButton = { TextButton(onClick = { pendingConfirm = false; exec() }) { Text("确认群发", color = risk.color) } },
            dismissButton = { TextButton(onClick = { pendingConfirm = false }) { Text("取消", color = TextSecondary) } },
            containerColor = Surface
        )
    }

    // N-Multi-AI 汇总弹窗
    aiSummary?.let { sum ->
        AlertDialog(
            onDismissRequest = { aiSummary = null },
            icon = { Icon(Icons.Filled.AutoAwesome, null, tint = Accent) },
            title = { Text("AI 群发汇总", color = TextPrimary) },
            text = { Column(Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState())) { Text(sum.ifEmpty { "分析中…" }, color = TextPrimary, fontSize = 13.sp) } },
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
                title = { Text("批量群发 · ${selected.size} 台", color = TextPrimary, fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = TextPrimary) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Surface)
            )
        }
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize().padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            // 选服务器（横向 chips）
            Text("选择服务器", color = TextSecondary, fontSize = 12.sp)
            Column(Modifier.heightIn(max = 160.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                conns.forEach { c ->
                    val on = selected.contains(c.id)
                    Row(
                        Modifier.fillMaxWidth().clickable { if (on) selected.remove(c.id) else selected.add(c.id) }
                            .background(if (on) Accent.copy(alpha = 0.15f) else Color.Transparent, RoundedCornerShape(8.dp))
                            .padding(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(if (on) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked, null,
                            tint = if (on) Accent else TextSecondary, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(10.dp))
                        Text(c.name, color = TextPrimary, fontSize = 13.sp, modifier = Modifier.weight(1f))
                        Text("${c.user}@${c.host}", color = TextSecondary, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                    }
                }
            }
            OutlinedTextField(password, { password = it }, label = { Text("统一 SSH 密码") }, singleLine = true,
                visualTransformation = PasswordVisualTransformation(), colors = fieldColors, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(command, { command = it }, label = { Text("要群发的命令") }, singleLine = true, colors = fieldColors, modifier = Modifier.fillMaxWidth())
            if (command.trim().isNotEmpty()) {
                val risk = CommandRisk.riskLevel(command.trim())
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.Filled.Circle, null, tint = risk.color, modifier = Modifier.size(9.dp))
                    Text("风险：${risk.label}", color = risk.color, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                }
            }
            Button(onClick = { submit() }, enabled = !running && selected.isNotEmpty() && command.isNotBlank() && password.isNotBlank(),
                colors = ButtonDefaults.buttonColors(containerColor = Accent), modifier = Modifier.fillMaxWidth()) {
                if (running) CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                else Text("群发执行（${selected.size} 台）", color = Color.White)
            }
            // N-Multi-AI：全部完成后可一键 AI 汇总
            if (allDone) {
                OutlinedButton(onClick = { summarize() }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Filled.AutoAwesome, null, tint = Accent, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(8.dp)); Text("AI 汇总这批结果", color = Accent, fontSize = 13.sp)
                }
            }
            // 结果
            LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(results.size) { i ->
                    val r = results[i]
                    Surface(color = SurfaceLight.copy(alpha = 0.5f), shape = RoundedCornerShape(10.dp), modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(12.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(if (r.running) Icons.Filled.Sync else if (r.ok) Icons.Filled.CheckCircle else Icons.Filled.Error,
                                    null, tint = if (r.running) Warning else if (r.ok) Success else Danger, modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(8.dp))
                                Text(r.conn.name, color = TextPrimary, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                            }
                            if (!r.running) {
                                Spacer(Modifier.height(4.dp))
                                Text(r.output, color = TextSecondary, fontSize = 11.sp, fontFamily = FontFamily.Monospace, maxLines = 8)
                            }
                        }
                    }
                }
            }
        }
    }
}
