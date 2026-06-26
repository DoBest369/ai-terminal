package com.termind.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** 一条 AI 对话消息（role/content + 发送时间，对齐 apple ChatMessage.createdAt）。 */
data class ChatMsg(val role: String, val content: String, val time: Long = 0L)

/**
 * AI 多对话持久化（A-ConvoPersist）：SharedPreferences 存对话列表 JSON。
 * 每个对话 = 消息数组 [{role, content, time}]。time 向后兼容（旧数据缺失=0）。对齐 apple AIConversation 持久化。
 */
object ConvoStore {
    private const val PREF = "termind_convos"
    private const val KEY = "conversations"

    /** 保存：对话列表（每个对话是 ChatMsg 列表） */
    fun save(ctx: Context, convos: List<List<ChatMsg>>) {
        val arr = JSONArray()
        convos.forEach { msgs ->
            val mArr = JSONArray()
            msgs.forEach { m ->
                mArr.put(JSONObject().put("role", m.role).put("content", m.content).put("time", m.time))
            }
            arr.put(mArr)
        }
        ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
    }

    /** 加载：返回对话列表；无数据则返回单个空对话 */
    fun load(ctx: Context): List<List<ChatMsg>> {
        val raw = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString(KEY, null)
            ?: return listOf(emptyList())
        return runCatching {
            val arr = JSONArray(raw)
            val out = (0 until arr.length()).map { i ->
                val mArr = arr.getJSONArray(i)
                (0 until mArr.length()).map { j ->
                    val o = mArr.getJSONObject(j)
                    ChatMsg(o.optString("role"), o.optString("content"), o.optLong("time", 0L))
                }
            }
            out.ifEmpty { listOf(emptyList()) }
        }.getOrElse { listOf(emptyList()) }
    }

    /** 各对话自定义标题（平行于对话列表，空=用自动标题）。 */
    fun saveTitles(ctx: Context, titles: List<String>) {
        val arr = JSONArray(); titles.forEach { arr.put(it) }
        ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().putString("conv_titles", arr.toString()).apply()
    }

    fun loadTitles(ctx: Context): List<String> {
        val raw = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString("conv_titles", null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw); (0 until arr.length()).map { arr.getString(it) }
        }.getOrDefault(emptyList())
    }
}
