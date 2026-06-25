package com.termind.app

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * 应用设置持久化。
 * - API Key 走 EncryptedSharedPreferences（AES256 加密，对齐 apple Keychain 安全标准）。
 * - 模型等非敏感项走普通 SharedPreferences。
 */
object SettingsStore {
    private const val PREF = "termind_settings"           // 普通（模型等）
    private const val SECURE_PREF = "termind_secure"       // 加密（API Key）
    private const val K_API_KEY = "ai_api_key"
    private const val K_MODEL = "ai_model"
    private const val K_THEME = "theme_id"
    const val DEFAULT_MODEL = "claude-opus-4-8"

    fun loadTheme(ctx: Context): String = prefs(ctx).getString(K_THEME, "midnight") ?: "midnight"
    fun saveTheme(ctx: Context, id: String) = prefs(ctx).edit().putString(K_THEME, id).apply()

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE)

    /** 加密 prefs（失败则回退普通 prefs，保证可用） */
    private fun securePrefs(ctx: Context): SharedPreferences = runCatching {
        val masterKey = MasterKey.Builder(ctx)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            ctx, SECURE_PREF, masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }.getOrElse { ctx.getSharedPreferences(SECURE_PREF, Context.MODE_PRIVATE) }

    fun loadApiKey(ctx: Context): String {
        val secure = securePrefs(ctx)
        secure.getString(K_API_KEY, null)?.let { return it }
        // 迁移：旧版本明文存在普通 prefs → 搬进加密后清除
        val legacy = prefs(ctx).getString(K_API_KEY, "") ?: ""
        if (legacy.isNotBlank()) {
            secure.edit().putString(K_API_KEY, legacy).apply()
            prefs(ctx).edit().remove(K_API_KEY).apply()
            return legacy
        }
        return ""
    }

    fun saveApiKey(ctx: Context, key: String) =
        securePrefs(ctx).edit().putString(K_API_KEY, key.trim()).apply()

    fun loadModel(ctx: Context): String = prefs(ctx).getString(K_MODEL, DEFAULT_MODEL) ?: DEFAULT_MODEL
    fun saveModel(ctx: Context, model: String) = prefs(ctx).edit().putString(K_MODEL, model.trim()).apply()

    fun isConfigured(ctx: Context): Boolean = loadApiKey(ctx).isNotBlank()
}
