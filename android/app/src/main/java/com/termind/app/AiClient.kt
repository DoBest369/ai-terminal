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
}
