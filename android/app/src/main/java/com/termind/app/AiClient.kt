package com.termind.app

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** 安卓 AI 助手（A4）：调 Anthropic Messages API（非流式 MVP，流式留后续）。 */
object AiClient {
    /** SSH 运维助手系统提示（参照 apple defaultAgentSystemPrompt 精简版） */
    const val SYSTEM_PROMPT =
        "你是 Termind 的 SSH 运维助手。请结合用户的服务器环境，给出安全、可直接执行的运维建议。" +
        "涉及删除、格式化、重启服务、改防火墙/SSH 等危险操作时，必须明确警示风险并建议先备份。" +
        "回答精炼、用中文，命令用代码块。"

    /** 命令解释（对齐 apple commandExplainPrompt）：只讲解不执行 */
    const val EXPLAIN_PROMPT =
        "你是命令讲解助手。请讲解用户给出的这条命令：① 作用 ② 关键参数含义 ③ 潜在风险 ④ 安全等级（安全/注意/高风险/极高危）。" +
        "高危操作用 ⚠️ 标注。只讲解，不要执行、不要给 [EXECUTE]。精炼中文。"

    /** 服务器健康分析（对齐 apple healthAnalysisPrompt） */
    const val HEALTH_PROMPT =
        "你是服务器健康分析助手。用户给你这台服务器当前状态指标（CPU/内存/磁盘等），请用简洁中文：" +
        "① 总评（是否健康，最值得关注的项）② 异常定位（偏高资源/停止服务的影响与原因）" +
        "③ 处置建议（可执行命令/步骤，高危用 ⚠️ 并建议先备份）④ 验证（如何确认恢复）。" +
        "资源占用 >85% 视为需立即关注；都正常则简短确认并给日常巡检建议。"

    /** 报错分析（对齐 apple errorAnalysisPrompt） */
    const val ERROR_PROMPT =
        "你是运维报错分析助手。请分析用户给出的这段报错：① 含义 ② 最可能的原因 ③ 可执行的修复步骤（命令用代码块）④ 修复后如何验证。" +
        "识别常见错误（502/Permission denied/No space/端口占用/Nginx/SSL 等）。精炼中文。"

    private val http = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    private val JSON = "application/json; charset=utf-8".toMediaType()

    /**
     * @param messages 历史对话（role=user/assistant），按顺序
     * @return 助手回复文本
     */
    suspend fun chat(
        apiKey: String,
        model: String,
        messages: List<Pair<String, String>>,
        systemPrompt: String = SYSTEM_PROMPT
    ): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            val msgArr = JSONArray()
            messages.forEach { (role, content) ->
                msgArr.put(JSONObject().put("role", role).put("content", content))
            }
            val body = JSONObject()
                .put("model", model)
                .put("max_tokens", 1024)
                .put("system", systemPrompt)
                .put("messages", msgArr)
                .toString()

            val req = Request.Builder()
                .url("https://api.anthropic.com/v1/messages")
                .addHeader("x-api-key", apiKey)
                .addHeader("anthropic-version", "2023-06-01")
                .addHeader("content-type", "application/json")
                .post(body.toRequestBody(JSON))
                .build()

            http.newCall(req).execute().use { resp ->
                val raw = resp.body?.string() ?: ""
                if (!resp.isSuccessful) {
                    // 取 API 返回的 error.message（若有）
                    val errMsg = runCatching { JSONObject(raw).getJSONObject("error").getString("message") }
                        .getOrDefault("HTTP ${resp.code}")
                    throw RuntimeException(errMsg)
                }
                // content 是数组，取第一个 text 块
                val content = JSONObject(raw).getJSONArray("content")
                val sb = StringBuilder()
                for (i in 0 until content.length()) {
                    val block = content.getJSONObject(i)
                    if (block.optString("type") == "text") sb.append(block.optString("text"))
                }
                sb.toString().ifBlank { "(无回复)" }
            }
        }
    }

    /**
     * 流式对话（A-Stream）：SSE 逐块回调 onDelta（已切到 Main 线程）。
     * 解析 Anthropic 流事件：content_block_delta 的 delta.text。
     */
    suspend fun chatStream(
        apiKey: String,
        model: String,
        messages: List<Pair<String, String>>,
        systemPrompt: String = SYSTEM_PROMPT,
        onDelta: suspend (String) -> Unit
    ): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            val msgArr = JSONArray()
            messages.forEach { (role, content) -> msgArr.put(JSONObject().put("role", role).put("content", content)) }
            val body = JSONObject()
                .put("model", model).put("max_tokens", 1024)
                .put("system", systemPrompt).put("messages", msgArr)
                .put("stream", true).toString()

            val req = Request.Builder()
                .url("https://api.anthropic.com/v1/messages")
                .addHeader("x-api-key", apiKey)
                .addHeader("anthropic-version", "2023-06-01")
                .addHeader("content-type", "application/json")
                .post(body.toRequestBody(JSON))
                .build()

            http.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) {
                    val raw = resp.body?.string() ?: ""
                    val errMsg = runCatching { JSONObject(raw).getJSONObject("error").getString("message") }
                        .getOrDefault("HTTP ${resp.code}")
                    throw RuntimeException(errMsg)
                }
                val source = resp.body?.source() ?: throw RuntimeException("无响应体")
                // 逐行读 SSE：data: {json}
                while (true) {
                    val line = source.readUtf8Line() ?: break
                    if (!line.startsWith("data:")) continue
                    val payload = line.removePrefix("data:").trim()
                    if (payload.isEmpty()) continue
                    val obj = runCatching { JSONObject(payload) }.getOrNull() ?: continue
                    when (obj.optString("type")) {
                        "content_block_delta" -> {
                            val text = obj.optJSONObject("delta")?.optString("text").orEmpty()
                            if (text.isNotEmpty()) withContext(Dispatchers.Main) { onDelta(text) }
                        }
                        "message_stop" -> return@use
                    }
                }
            }
        }
    }
}
