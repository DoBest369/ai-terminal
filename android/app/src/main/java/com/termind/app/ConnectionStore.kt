package com.termind.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** 认证方式（A-KeyAuth） */
enum class AuthType { PASSWORD, KEY }

/** 连接颜色标签（A-Tags）：一眼区分环境 */
enum class ColorTag(val hex: Long?) {
    NONE(null), RED(0xFFE74C3C), ORANGE(0xFFF39C12), GREEN(0xFF2ECC71), BLUE(0xFF3498DB), PURPLE(0xFF9B59B6)
}

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
    val colorTag: ColorTag = ColorTag.NONE,
    val startupCommand: String = "",
    val online: Boolean = false
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id); put("name", name); put("host", host); put("user", user)
        put("port", port); put("group", group); put("note", note)
        put("authType", authType.name); put("colorTag", colorTag.name)
        put("startupCommand", startupCommand)
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
                    authType = runCatching { AuthType.valueOf(o.optString("authType", "PASSWORD")) }.getOrDefault(AuthType.PASSWORD),
                    colorTag = runCatching { ColorTag.valueOf(o.optString("colorTag", "NONE")) }.getOrDefault(ColorTag.NONE),
                    startupCommand = o.optString("startupCommand")
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

    /** 导出连接列表为 JSON（不含密码/私钥，敏感信息不导出） */
    fun exportJson(conns: List<ServerConn>): String {
        val arr = JSONArray(); conns.forEach { arr.put(it.toJson()) }
        return JSONObject().put("termind_connections", arr).put("version", 1).toString(2)
    }

    /** 从 JSON 导入连接（解析 termind_connections 数组，生成新 id 避免冲突） */
    fun importJson(json: String): List<ServerConn> {
        return runCatching {
            val arr = JSONObject(json).getJSONArray("termind_connections")
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                ServerConn(
                    name = o.optString("name"), host = o.optString("host"), user = o.optString("user"),
                    port = o.optInt("port", 22), group = o.optString("group"), note = o.optString("note"),
                    authType = runCatching { AuthType.valueOf(o.optString("authType", "PASSWORD")) }.getOrDefault(AuthType.PASSWORD),
                    colorTag = runCatching { ColorTag.valueOf(o.optString("colorTag", "NONE")) }.getOrDefault(ColorTag.NONE),
                    startupCommand = o.optString("startupCommand")
                )
            }
        }.getOrElse { emptyList() }
    }

    /** 首次启动的示例连接（用户可删改） */
    private fun seedDefaults() = listOf(
        ServerConn(name = "生产 Web 01", host = "web01.example.com", user = "deploy", port = 22, group = "生产环境", note = "官网 + API"),
        ServerConn(name = "数据库主机", host = "db.internal.net", user = "admin", port = 22, group = "生产环境", note = "MySQL 主库"),
        ServerConn(name = "开发机", host = "dev.example.com", user = "deploy", port = 2222, group = "开发环境")
    )
}
