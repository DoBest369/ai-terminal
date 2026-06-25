package com.termind.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** 快捷命令片段（A-Snippets）：常用运维命令一键填入命令框，仿 apple SnippetsView。 */
data class CommandSnippet(val title: String, val command: String, val group: String = "") {
    val risk: CommandRisk get() = CommandRisk.riskLevel(command)

    companion object {
        val defaults = listOf(
            CommandSnippet("磁盘占用", "df -h", "系统"),
            CommandSnippet("内存使用", "free -m", "系统"),
            CommandSnippet("进程 Top", "top -bn1 | head -20", "系统"),
            CommandSnippet("系统信息", "uname -a", "系统"),
            CommandSnippet("占用端口", "ss -tlnp", "网络"),
            CommandSnippet("Nginx 状态", "systemctl status nginx --no-pager", "服务"),
            CommandSnippet("Nginx 配置检查", "nginx -t", "服务"),
            CommandSnippet("重载 Nginx", "systemctl reload nginx", "服务"),
            CommandSnippet("Docker 容器", "docker ps -a", "Docker"),
            CommandSnippet("Docker 占用", "docker system df", "Docker"),
            CommandSnippet("系统日志", "journalctl -n 50 --no-pager", "日志"),
            CommandSnippet("登录失败记录", "grep -i 'failed password' /var/log/auth.log | tail -20", "安全")
        )
    }
}

/** 用户自定义快捷命令持久化（A-SnippetCRUD）。 */
object SnippetStore {
    private const val PREF = "termind_snippets"
    private const val KEY = "custom"

    fun load(ctx: Context): List<CommandSnippet> {
        val raw = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString(KEY, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                CommandSnippet(o.optString("title"), o.optString("command"), o.optString("group"))
            }
        }.getOrDefault(emptyList())
    }

    fun save(ctx: Context, list: List<CommandSnippet>) {
        val arr = JSONArray()
        list.forEach { arr.put(JSONObject().put("title", it.title).put("command", it.command).put("group", it.group)) }
        ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
    }

    fun add(ctx: Context, s: CommandSnippet): List<CommandSnippet> {
        val list = ArrayList(load(ctx)); list.add(s); save(ctx, list); return list
    }
    fun remove(ctx: Context, s: CommandSnippet): List<CommandSnippet> {
        val list = ArrayList(load(ctx)); list.remove(s); save(ctx, list); return list
    }
}
