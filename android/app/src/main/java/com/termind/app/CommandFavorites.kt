package com.termind.app

import android.content.Context

/** 命令收藏夹：把常用命令加星标，跨连接快捷复用（SharedPreferences 存有序列表）。 */
object CommandFavorites {
    private const val PREF = "termind_prefs"
    private const val KEY = "command_favorites"
    private const val SEP = ""   // 不太可能出现在命令里的分隔符

    fun load(ctx: Context): List<String> {
        val raw = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString(KEY, "") ?: ""
        return if (raw.isEmpty()) emptyList() else raw.split(SEP)
    }

    private fun save(ctx: Context, list: List<String>) {
        ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().putString(KEY, list.joinToString(SEP)).apply()
    }

    fun isFavorite(ctx: Context, cmd: String): Boolean = load(ctx).contains(cmd.trim())

    /** 切换收藏（已收藏则取消，否则置顶加入）。 */
    fun toggle(ctx: Context, cmd: String): List<String> {
        val c = cmd.trim(); if (c.isEmpty()) return load(ctx)
        val list = load(ctx).toMutableList()
        if (list.remove(c)) { save(ctx, list); return list }
        list.add(0, c); save(ctx, list); return list
    }
}
