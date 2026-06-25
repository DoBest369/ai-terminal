package com.termind.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** 认证方式（A-KeyAuth） */
enum class AuthType { PASSWORD, KEY }

/** SSH 连接（含 id，可持久化）。私钥本身不入存储（敏感），运行时输入。 */
data class ServerConn(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val host: String,
    val user: String,
    val port: Int = 22,
    val group: String = "",
    val note: String = "",
    val authType: AuthType = AuthType.PASSWORD,
    val online: Boolean = false
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id); put("name", name); put("host", host); put("user", user)
        put("port", port); put("group", group); put("note", note)
        put("authType", authType.name)
    }
}

/** 连接本地持久化（SharedPreferences 存 JSON 数组，零额外依赖）。 */
object ConnectionStore {
    private const val PREF = "termind_prefs"
    private const val KEY = "connections"

    fun load(ctx: Context): List<ServerConn> {
        val raw = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString(KEY, null)
            ?: return seedDefaults()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                ServerConn(
                    id = o.optString("id", UUID.randomUUID().toString()),
                    name = o.optString("name"), host = o.optString("host"),
                    user = o.optString("user"), port = o.optInt("port", 22),
                    group = o.optString("group"), note = o.optString("note"),
                    authType = runCatching { AuthType.valueOf(o.optString("authType", "PASSWORD")) }.getOrDefault(AuthType.PASSWORD)
                )
            }
        }.getOrElse { seedDefaults() }
    }

    fun save(ctx: Context, conns: List<ServerConn>) {
        val arr = JSONArray()
        conns.forEach { arr.put(it.toJson()) }
        ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit()
            .putString(KEY, arr.toString()).apply()
    }

    /** 首次启动的示例连接（用户可删改） */
    private fun seedDefaults() = listOf(
        ServerConn(name = "生产 Web 01", host = "web01.example.com", user = "deploy", port = 22, group = "生产环境", note = "官网 + API"),
        ServerConn(name = "数据库主机", host = "db.internal.net", user = "admin", port = 22, group = "生产环境", note = "MySQL 主库"),
        ServerConn(name = "开发机", host = "dev.example.com", user = "deploy", port = 2222, group = "开发环境")
    )
}
