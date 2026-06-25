package com.termind.app

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
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
    val scope = rememberCoroutineScope()
    var password by remember { mutableStateOf("") }
    var running by remember { mutableStateOf(false) }
    val items = remember { mutableStateListOf<InspectItem>() }

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
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, null, tint = TextPrimary) } },
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
                        Text(if (warnCount > 0) "$warnCount 台需关注" else "全部正常",
                            color = if (warnCount > 0) Danger else Success, fontWeight = FontWeight.Medium)
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
