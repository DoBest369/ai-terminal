package com.termind.app

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp

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

    val canSave = host.trim().isNotEmpty() && user.trim().isNotEmpty()

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
                navigationIcon = { IconButton(onClick = onCancel) { Icon(Icons.Filled.ArrowBack, null, tint = TextPrimary) } },
                actions = {
                    TextButton(onClick = {
                        onSave(
                            (existing ?: ServerConn(name = "", host = "", user = "")).copy(
                                name = name.trim().ifEmpty { "$user@$host" },
                                host = host.trim(), user = user.trim(),
                                port = port.toIntOrNull() ?: 22,
                                group = group.trim(), note = note.trim()
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
                OutlinedTextField(port, { port = it.filter { c -> c.isDigit() } }, label = { Text("端口") }, singleLine = true, keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = KeyboardType.Number), colors = fieldColors, modifier = Modifier.weight(1f))
            }
            OutlinedTextField(group, { group = it }, label = { Text("分组（可选）") }, singleLine = true, colors = fieldColors, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(note, { note = it }, label = { Text("备注（可选）") }, singleLine = true, colors = fieldColors, modifier = Modifier.fillMaxWidth())
            Text("提示：SSH 密钥/密码将在连接时配置（敏感信息不入普通存储）。", color = TextSecondary, style = MaterialTheme.typography.bodySmall)
        }
    }
}
