package com.termind.app

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Check
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
                                group = group.trim(), note = note.trim(),
                                authType = authType, colorTag = colorTag
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
