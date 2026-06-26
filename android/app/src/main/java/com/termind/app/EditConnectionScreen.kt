package com.termind.app

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.NetworkCheck
import kotlinx.coroutines.launch
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** 新建/编辑连接表单（existing 为空=新建）。保存回调给上层写 store。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditConnectionScreen(existing: ServerConn?, onCancel: () -> Unit, onSave: (ServerConn) -> Unit) {
    var name by remember { mutableStateOf(existing?.name ?: "") }
    var host by remember { mutableStateOf(existing?.host ?: "") }
    var user by remember { mutableStateOf(existing?.user ?: "") }
    var port by remember { mutableStateOf((existing?.port ?: 22).toString()) }
    var group by remember { mutableStateOf(existing?.group ?: "") }
    var note by remember { mutableStateOf(existing?.note ?: "") }
    var authType by remember { mutableStateOf(existing?.authType ?: AuthType.PASSWORD) }
    var colorTag by remember { mutableStateOf(existing?.colorTag ?: ColorTag.NONE) }
    var startup by remember { mutableStateOf(existing?.startupCommand ?: "") }
    // A-Jump 跳板机
    var jumpHost by remember { mutableStateOf(existing?.jumpHost ?: "") }
    var jumpUser by remember { mutableStateOf(existing?.jumpUser ?: "") }
    var jumpPort by remember { mutableStateOf((existing?.jumpPort ?: 22).toString()) }
    // A-TestConn 测试连接
    val scope = rememberCoroutineScope()
    var testing by remember { mutableStateOf(false) }
    var testResult by remember { mutableStateOf<Boolean?>(null) }

    // A-FormValid：表单校验
    val portOk = port.isEmpty() || (port.toIntOrNull()?.let { it in 1..65535 } == true)
    val jumpPortOk = jumpPort.isEmpty() || (jumpPort.toIntOrNull()?.let { it in 1..65535 } == true)
    val jumpOk = jumpHost.trim().isEmpty() || jumpUser.trim().isNotEmpty()  // 填了跳板机主机则需跳板用户
    val canSave = host.trim().isNotEmpty() && user.trim().isNotEmpty() && portOk && jumpPortOk && jumpOk

    val fieldColors = OutlinedTextFieldDefaults.colors(
        focusedBorderColor = Accent, unfocusedBorderColor = SurfaceLight,
        focusedTextColor = TextPrimary, unfocusedTextColor = TextPrimary,
        focusedLabelColor = Accent, unfocusedLabelColor = TextSecondary,
        cursorColor = Accent
    )

    Scaffold(
        containerColor = Bg,
        topBar = {
            TopAppBar(
                title = { Text(if (existing == null) "新建连接" else "编辑连接", color = TextPrimary) },
                navigationIcon = { IconButton(onClick = onCancel) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = TextPrimary) } },
                actions = {
                    TextButton(onClick = {
                        onSave(
                            (existing ?: ServerConn(name = "", host = "", user = "")).copy(
                                name = name.trim().ifEmpty { "$user@$host" },
                                host = host.trim(), user = user.trim(),
                                port = port.toIntOrNull() ?: 22,
                                group = group.trim(), note = note.trim(),
                                authType = authType, colorTag = colorTag, startupCommand = startup.trim(),
                                jumpHost = jumpHost.trim(), jumpPort = jumpPort.toIntOrNull() ?: 22, jumpUser = jumpUser.trim()
                            )
                        )
                    }, enabled = canSave) {
                        Text("保存", color = if (canSave) Accent else TextSecondary)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Surface)
            )
        }
    ) { padding ->
        Column(
            Modifier.padding(padding).fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OutlinedTextField(name, { name = it }, label = { Text("名称（可选）") }, singleLine = true, colors = fieldColors, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(host, { host = it }, label = { Text("主机地址 *") }, singleLine = true, colors = fieldColors, modifier = Modifier.fillMaxWidth())
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(user, { user = it }, label = { Text("用户名 *") }, singleLine = true, colors = fieldColors, modifier = Modifier.weight(2f))
                OutlinedTextField(port, { port = it.filter { c -> c.isDigit() } }, label = { Text("端口") }, singleLine = true, isError = !portOk, keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = KeyboardType.Number), colors = fieldColors, modifier = Modifier.weight(1f))
            }
            if (!portOk) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Filled.Warning, null, tint = Danger, modifier = Modifier.size(13.dp))
                Text("端口需在 1–65535 之间", color = Danger, fontSize = 11.sp)
            }
            // A-TestConn：测试连接（TCP 可达性）
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = {
                    if (host.isBlank() || testing) return@OutlinedButton
                    testing = true; testResult = null
                    scope.launch {
                        testResult = Reachability.probe(host.trim(), port.toIntOrNull() ?: 22)
                        testing = false
                    }
                }, enabled = host.isNotBlank() && !testing) {
                    if (testing) CircularProgressIndicator(Modifier.size(14.dp), color = Accent, strokeWidth = 2.dp)
                    else Icon(Icons.Filled.NetworkCheck, null, tint = Accent, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp)); Text("测试连接", color = Accent, fontSize = 13.sp)
                }
                testResult?.let {
                    Text(if (it) "✅ 可达" else "❌ 不可达", color = if (it) Success else Danger, fontSize = 13.sp)
                }
            }
            OutlinedTextField(group, { group = it }, label = { Text("分组（可选）") }, singleLine = true, colors = fieldColors, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(note, { note = it }, label = { Text("备注（可选）") }, singleLine = true, colors = fieldColors, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(startup, { startup = it }, label = { Text("启动命令（连上自动执行，可选）") }, singleLine = true, colors = fieldColors, modifier = Modifier.fillMaxWidth())
            // A-Jump：跳板机（ProxyJump，可选；填了主机即启用，密码连接时输入）
            Text("跳板机 / 堡垒机（可选，经其转连目标）", color = TextSecondary, fontSize = 12.sp)
            OutlinedTextField(jumpHost, { jumpHost = it }, label = { Text("跳板机主机") }, singleLine = true, colors = fieldColors, modifier = Modifier.fillMaxWidth())
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(jumpUser, { jumpUser = it }, label = { Text("跳板用户名") }, singleLine = true, isError = !jumpOk, colors = fieldColors, modifier = Modifier.weight(2f))
                OutlinedTextField(jumpPort, { jumpPort = it.filter { c -> c.isDigit() } }, label = { Text("跳板端口") }, singleLine = true, isError = !jumpPortOk, keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = KeyboardType.Number), colors = fieldColors, modifier = Modifier.weight(1f))
            }
            if (!jumpOk) Text("填了跳板机主机，请补跳板用户名", color = Danger, fontSize = 11.sp)
            if (!jumpPortOk) Text("跳板端口需在 1–65535 之间", color = Danger, fontSize = 11.sp)
            // A-KeyAuth：认证方式
            Text("认证方式", color = TextSecondary, fontSize = 12.sp)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(AuthType.PASSWORD to "密码", AuthType.KEY to "私钥").forEach { (t, label) ->
                    FilterChip(
                        selected = authType == t,
                        onClick = { authType = t },
                        label = { Text(label) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = Accent.copy(alpha = 0.25f),
                            selectedLabelColor = Accent, labelColor = TextSecondary
                        )
                    )
                }
            }
            // A-Tags：颜色标签
            Text("颜色标签", color = TextSecondary, fontSize = 12.sp)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                ColorTag.values().forEach { tag ->
                    val sel = colorTag == tag
                    Box(
                        Modifier.size(28.dp).clip(androidx.compose.foundation.shape.CircleShape)
                            .background(tag.hex?.let { Color(it) } ?: SurfaceLight)
                            .border(if (sel) 2.dp else 0.dp, if (sel) Accent else Color.Transparent, androidx.compose.foundation.shape.CircleShape)
                            .clickable { colorTag = tag },
                        contentAlignment = Alignment.Center
                    ) {
                        if (tag == ColorTag.NONE) Icon(Icons.Filled.Block, null, tint = TextSecondary, modifier = Modifier.size(16.dp))
                        else if (sel) Icon(Icons.Filled.Check, null, tint = Color.White, modifier = Modifier.size(16.dp))
                    }
                }
            }
            Text("提示：密码/私钥在连接时输入，敏感信息不入普通存储。", color = TextSecondary, style = MaterialTheme.typography.bodySmall)
        }
    }
}
