package com.termind.app

import android.content.Context

/**
 * 应用设置持久化（API Key / 模型 等）。
 * MVP 用 SharedPreferences；TODO: API Key 属敏感信息，后续迁 EncryptedSharedPreferences/Keystore（对齐 apple Keychain）。
 */
object SettingsStore {
    private const val PREF = "termind_settings"
    private const val K_API_KEY = "ai_api_key"
    private const val K_MODEL = "ai_model"
    const val DEFAULT_MODEL = "claude-opus-4-8"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE)

    fun loadApiKey(ctx: Context): String = prefs(ctx).getString(K_API_KEY, "") ?: ""
    fun saveApiKey(ctx: Context, key: String) = prefs(ctx).edit().putString(K_API_KEY, key.trim()).apply()

    fun loadModel(ctx: Context): String = prefs(ctx).getString(K_MODEL, DEFAULT_MODEL) ?: DEFAULT_MODEL
    fun saveModel(ctx: Context, model: String) = prefs(ctx).edit().putString(K_MODEL, model.trim()).apply()

    fun isConfigured(ctx: Context): Boolean = loadApiKey(ctx).isNotBlank()
}
