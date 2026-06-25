package com.termind.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// Termind 品牌配色（呼应 apple 端：午夜深蓝 + 珊瑚红 accent）
private val Bg = Color(0xFF1A1A2E)
private val Surface = Color(0xFF16213E)
private val SurfaceLight = Color(0xFF0F3460)
private val Accent = Color(0xFFE94560)
private val TextPrimary = Color(0xFFEEEEEE)
private val TextSecondary = Color(0xFFA0A0A0)
private val Success = Color(0xFF2ECC71)
private val Danger = Color(0xFFE74C3C)

/** 占位 SSH 连接（后续接入真实连接管理 + dartssh 替代物 sshj/JSch） */
data class ServerConn(
    val name: String,
    val host: String,
    val user: String,
    val port: Int,
    val group: String,
    val online: Boolean,
    val note: String = ""
)

private val demoConns = listOf(
    ServerConn("生产 Web 01", "web01.example.com", "deploy", 22, "生产环境", true, "官网 + API"),
    ServerConn("数据库主机", "db.internal.net", "admin", 22, "生产环境", true, "MySQL 主库"),
    ServerConn("开发机", "dev.example.com", "deploy", 2222, "开发环境", false),
    ServerConn("香港节点", "hk.example.com", "root", 22, "海外", false, "SSL 7 天后过期")
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            TermindTheme {
                ServerListScreen(demoConns)
            }
        }
    }
}

@Composable
fun TermindTheme(content: @Composable () -> Unit) {
    val colors = darkColorScheme(
        primary = Accent,
        background = Bg,
        surface = Surface,
        onPrimary = Color.White,
        onBackground = TextPrimary,
        onSurface = TextPrimary
    )
    MaterialTheme(colorScheme = colors, content = content)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ServerListScreen(conns: List<ServerConn>) {
    Scaffold(
        containerColor = Bg,
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.Bolt, contentDescription = null, tint = Accent)
                        Spacer(Modifier.width(8.dp))
                        Text("Termind", fontWeight = FontWeight.Bold, color = TextPrimary)
                        Spacer(Modifier.width(8.dp))
                        Text("智能 SSH 运维", fontSize = 12.sp, color = TextSecondary)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Surface)
            )
        }
    ) { padding ->
        // 按分组展示连接（运维工作台：服务器资产列表）
        val grouped = conns.groupBy { it.group }
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            grouped.forEach { (group, list) ->
                item {
                    Text(
                        group,
                        fontSize = 12.sp,
                        color = TextSecondary,
                        modifier = Modifier.padding(top = 14.dp, bottom = 2.dp)
                    )
                }
                items(list) { conn -> ServerCard(conn) }
            }
        }
    }
}

@Composable
fun ServerCard(conn: ServerConn) {
    Surface(
        color = SurfaceLight.copy(alpha = 0.5f),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.Filled.Circle,
                contentDescription = null,
                tint = if (conn.online) Success else TextSecondary,
                modifier = Modifier.size(10.dp)
            )
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(conn.name, color = TextPrimary, fontWeight = FontWeight.Medium, fontSize = 15.sp)
                Text(
                    "${conn.user}@${conn.host}:${conn.port}",
                    color = TextSecondary, fontSize = 12.sp, fontFamily = FontFamily.Monospace
                )
                if (conn.note.isNotEmpty()) {
                    Text("📝 ${conn.note}", color = TextSecondary.copy(alpha = 0.85f), fontSize = 11.sp)
                }
            }
        }
    }
}
