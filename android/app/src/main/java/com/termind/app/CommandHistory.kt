package com.termind.app

import android.content.Context
import org.json.JSONArray

/**
 * 命令历史（N-History）：SharedPreferences 存最近执行命令（去重、限 50、最新在前）。
 * 运维高频刚需——快速调出重用历史命令。
 */
object CommandHistory {
    private const val PREF = "termind_cmd_history"
    private const val KEY = "history"
    private const val LIMIT = 50

    fun load(ctx: Context): List<String> {
        val raw = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString(KEY, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getString(it) }
        }.getOrDefault(emptyList())
    }

    /** 记录一条命令：去重后置顶，超限截断。 */
    fun add(ctx: Context, cmd: String): List<String> {
        val c = cmd.trim()
        if (c.isEmpty()) return load(ctx)
        val list = ArrayList(load(ctx))
        list.remove(c)              // 去重
        list.add(0, c)              // 最新置顶
        while (list.size > LIMIT) list.removeAt(list.size - 1)
        save(ctx, list)
        return list
    }

    fun remove(ctx: Context, cmd: String): List<String> {
        val list = ArrayList(load(ctx)); list.remove(cmd); save(ctx, list); return list
    }

    fun clear(ctx: Context) = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().remove(KEY).apply()

    private fun save(ctx: Context, list: List<String>) {
        val arr = JSONArray(); list.forEach { arr.put(it) }
        ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
    }
}
