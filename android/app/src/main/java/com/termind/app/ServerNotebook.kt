package com.termind.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** 知识卡片记录类型（对齐 apple ServerNote.Kind） */
enum class NoteKind(val label: String) {
    ISSUE("问题"), SOLUTION("方案"), NOTE("笔记")
}

/** 服务器知识卡片的一条记录：每台机沉淀历史问题/解决方案/运维笔记（PRODUCT 护城河 知识沉淀）。 */
data class ServerNote(
    val id: String = UUID.randomUUID().toString(),
    val kind: NoteKind = NoteKind.NOTE,
    val text: String,
    val createdAt: Long = System.currentTimeMillis(),
    val tags: List<String> = emptyList()   // 自由标签（归类/筛选），旧卡片缺失=空
)

/** 服务器知识卡片持久化（按连接 id 存 JSON，对齐 apple ServerNotebook）。 */
object ServerNotebook {
    private const val PREF = "termind_notebook"
    private fun key(connId: String) = "notes_$connId"

    fun load(ctx: Context, connId: String): List<ServerNote> {
        val raw = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString(key(connId), null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                ServerNote(
                    id = o.optString("id", UUID.randomUUID().toString()),
                    kind = runCatching { NoteKind.valueOf(o.optString("kind", "NOTE")) }.getOrDefault(NoteKind.NOTE),
                    text = o.optString("text"),
                    createdAt = o.optLong("createdAt", 0L),
                    tags = o.optJSONArray("tags")?.let { ja -> (0 until ja.length()).map { ja.getString(it) } } ?: emptyList()
                )
            }
        }.getOrDefault(emptyList())
    }

    private fun save(ctx: Context, connId: String, notes: List<ServerNote>) {
        val arr = JSONArray()
        notes.forEach { arr.put(JSONObject().put("id", it.id).put("kind", it.kind.name).put("text", it.text).put("createdAt", it.createdAt).put("tags", JSONArray(it.tags))) }
        ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().putString(key(connId), arr.toString()).apply()
    }

    /** 新增一条（置顶最新，空忽略）。 */
    fun add(ctx: Context, connId: String, note: ServerNote): List<ServerNote> {
        if (note.text.trim().isEmpty()) return load(ctx, connId)
        val next = listOf(note) + load(ctx, connId)
        save(ctx, connId, next)
        return next
    }

    /** 删除一条。 */
    fun remove(ctx: Context, connId: String, id: String): List<ServerNote> {
        val next = load(ctx, connId).filterNot { it.id == id }
        save(ctx, connId, next)
        return next
    }

    /** 拼接成给 AI 的上下文素材（让 AI 排障参考这台机历史，对齐 apple composeForAI）。 */
    fun composeForAI(notes: List<ServerNote>): String {
        if (notes.isEmpty()) return ""
        val lines = notes.joinToString("\n") { "· [${it.kind.label}] ${it.text}" }
        return "这台服务器的历史运维记录：\n$lines"
    }

    /** 导出为 Markdown（按 问题/方案/笔记 分组），便于团队共享运维经验（对齐 apple exportMarkdown）。 */
    fun exportMarkdown(notes: List<ServerNote>, serverName: String = ""): String {
        val title = if (serverName.isEmpty()) "服务器知识卡片" else "知识卡片 · $serverName"
        val sb = StringBuilder("# $title\n")
        NoteKind.values().forEach { kind ->
            val group = notes.filter { it.kind == kind }
            if (group.isNotEmpty()) {
                sb.append("\n## ${kind.label}\n")
                group.forEach { sb.append("- ${it.text}\n") }
            }
        }
        return sb.toString()
    }

    /** 解析导出的 Markdown→知识卡片（与 exportMarkdown 对称，对齐 apple parseImport）。 */
    fun parseImport(text: String): List<ServerNote> {
        val out = ArrayList<ServerNote>()
        var kind = NoteKind.NOTE
        text.split("\n").forEach { raw ->
            val line = raw.trim()
            when {
                line.startsWith("## ") -> {
                    val label = line.removePrefix("## ").trim()
                    kind = NoteKind.values().firstOrNull { it.label == label } ?: NoteKind.NOTE
                }
                line.startsWith("- ") -> {
                    val t = line.removePrefix("- ").trim()
                    if (t.isNotEmpty()) out.add(ServerNote(kind = kind, text = t))
                }
            }
        }
        return out
    }
}
