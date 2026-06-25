package com.termind.app

import android.content.Context
import android.util.Base64
import net.schmizz.sshj.transport.verification.HostKeyVerifier
import java.security.MessageDigest
import java.security.PublicKey

/**
 * TOFU 主机密钥校验（A-TOFU）：首次连接信任并记录指纹，后续比对，不一致拒绝（防 MITM）。
 * 替代原先的 PromiscuousVerifier（无脑跳过校验）。指纹存 SharedPreferences。
 */
object KnownHosts {
    private const val PREF = "termind_knownhosts"
    private var prefs: android.content.SharedPreferences? = null

    /** App 启动时注入 applicationContext（避免 Activity 泄漏）。 */
    fun init(ctx: Context) {
        prefs = ctx.applicationContext.getSharedPreferences(PREF, Context.MODE_PRIVATE)
    }

    private fun key(host: String, port: Int) = "$host:$port"

    /** 公钥 SHA-256 指纹（Base64）。 */
    fun fingerprint(pubKey: PublicKey): String {
        val sha = MessageDigest.getInstance("SHA-256").digest(pubKey.encoded)
        return Base64.encodeToString(sha, Base64.NO_WRAP)
    }

    /** 校验结果：NEW=首次已信任并记录；MATCH=已知且一致；MISMATCH=指纹变了（可能 MITM）。 */
    enum class Result { NEW, MATCH, MISMATCH }

    fun check(host: String, port: Int, fp: String): Result {
        val p = prefs ?: return Result.NEW   // 未 init 时退化为信任（不应发生）
        val k = key(host, port)
        val saved = p.getString(k, null)
        return when {
            saved == null -> { p.edit().putString(k, fp).apply(); Result.NEW }
            saved == fp -> Result.MATCH
            else -> Result.MISMATCH
        }
    }

    /** 忘记某主机指纹（用户确认变更后可重新信任）。 */
    fun forget(host: String, port: Int) {
        prefs?.edit()?.remove(key(host, port))?.apply()
    }
}

/** sshj HostKeyVerifier 实现：TOFU 策略。 */
class TofuVerifier : HostKeyVerifier {
    override fun verify(hostname: String, port: Int, key: PublicKey): Boolean {
        val fp = KnownHosts.fingerprint(key)
        return when (KnownHosts.check(hostname, port, fp)) {
            KnownHosts.Result.NEW, KnownHosts.Result.MATCH -> true
            KnownHosts.Result.MISMATCH -> false  // 指纹不一致→拒绝，sshj 抛异常
        }
    }

    override fun findExistingAlgorithms(hostname: String, port: Int): List<String> = emptyList()
}
