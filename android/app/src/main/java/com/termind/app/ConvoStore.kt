package com.termind.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * AI 多对话持久化（A-ConvoPersist）：SharedPreferences 存对话列表 JSON。
 * 每个对话 = 消息数组 [{role, content}]。对齐 apple AIConversation 持久化。
 */
object ConvoStore {
    private const val PREF = "termind_convos"
    private const val KEY = "conversations"

    /** 保存：对话列表（每个对话是 (role,content) 消息列表） */
    fun save(ctx: Context, convos: List<List<Pair<String, String>>>) {
        val arr = JSONArray()
        convos.forEach { msgs ->
            val mArr = JSONArray()
            msgs.forEach { (role, content) ->
                mArr.put(JSONObject().put("role", role).put("content", content))
            }
            arr.put(mArr)
        }
        ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
    }

    /** 加载：返回对话列表；无数据则返回单个空对话 */
    fun load(ctx: Context): List<List<Pair<String, String>>> {
        val raw = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString(KEY, null)
            ?: return listOf(emptyList())
        return runCatching {
            val arr = JSONArray(raw)
            val out = (0 until arr.length()).map { i ->
                val mArr = arr.getJSONArray(i)
                (0 until mArr.length()).map { j ->
                    val o = mArr.getJSONObject(j)
                    o.optString("role") to o.optString("content")
                }
            }
            out.ifEmpty { listOf(emptyList()) }
        }.getOrElse { listOf(emptyList()) }
    }
}
