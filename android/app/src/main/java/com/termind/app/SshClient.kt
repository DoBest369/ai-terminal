package com.termind.app

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import net.schmizz.sshj.SSHClient
import net.schmizz.sshj.transport.verification.PromiscuousVerifier
import java.util.concurrent.TimeUnit

/** 安卓真实 SSH（sshj，纯 Java，适合 Android）。A1：先做 exec 命令+输出，交互式 PTY 留 A1b。 */
object SshClient {

    /**
     * 连接并执行一条命令，返回合并的 stdout+stderr。
     * 在 IO 线程跑，带超时。host key 暂用 Promiscuous（仅 MVP，TODO: 后续做 TOFU/known_hosts，对齐 apple 端 R20）。
     */
    suspend fun connectAndExec(
        host: String,
        port: Int,
        user: String,
        password: String,
        command: String,
        timeoutMs: Long = 15_000
    ): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            withTimeout(timeoutMs) {
                val ssh = SSHClient()
                // TODO(TOFU)：MVP 先跳过 host key 校验，后续实现首次信任 + known_hosts（对齐 apple R20）
                ssh.addHostKeyVerifier(PromiscuousVerifier())
                ssh.connectTimeout = 10_000
                ssh.timeout = 10_000
                ssh.connect(host, port)
                try {
                    ssh.authPassword(user, password)
                    ssh.startSession().use { session ->
                        val cmd = session.exec(command)
                        val out = cmd.inputStream.bufferedReader().readText()
                        val err = cmd.errorStream.bufferedReader().readText()
                        cmd.join(10, TimeUnit.SECONDS)
                        val status = cmd.exitStatus
                        buildString {
                            append(out)
                            if (err.isNotBlank()) { if (out.isNotEmpty()) append("\n"); append(err) }
                            if (status != null && status != 0) append("\n[退出码 $status]")
                        }.ifBlank { "(命令无输出)" }
                    }
                } finally {
                    runCatching { ssh.disconnect() }
                }
            }
        }
    }
}
