package com.termind.app

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import net.schmizz.sshj.SSHClient
import net.schmizz.sshj.connection.channel.direct.Session
import net.schmizz.sshj.sftp.FileMode
import net.schmizz.sshj.transport.verification.PromiscuousVerifier
import java.io.OutputStream
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

    /**
     * 建立交互式 PTY shell 会话（A1b）。在 IO 线程连接 + 起读循环，输出经 onOutput 回调。
     * 返回 SshShellSession（write 发命令、close 断开）；失败抛异常由调用方 catch。
     */
    suspend fun openShell(
        host: String, port: Int, user: String, password: String,
        scope: CoroutineScope,
        onOutput: (String) -> Unit
    ): SshShellSession = withContext(Dispatchers.IO) {
        val ssh = SSHClient()
        ssh.addHostKeyVerifier(PromiscuousVerifier())  // MVP，TODO TOFU
        ssh.connectTimeout = 10_000
        ssh.connect(host, port)
        ssh.authPassword(user, password)
        val session = ssh.startSession()
        session.allocateDefaultPTY()
        val shell = session.startShell()
        val out = shell.outputStream
        // 持续读 shell 输出 → 回调（去 ANSI）
        scope.launch(Dispatchers.IO) {
            val buf = ByteArray(4096)
            val input = shell.inputStream
            try {
                while (isActive) {
                    val n = input.read(buf)
                    if (n < 0) break
                    if (n > 0) {
                        val chunk = String(buf, 0, n, Charsets.UTF_8)
                        withContext(Dispatchers.Main) { onOutput(stripAnsi(chunk)) }
                    }
                }
            } catch (_: Exception) { /* 会话关闭/断开，正常退出 */ }
        }
        SshShellSession(ssh, session, out)
    }

    /** 采集服务器状态（A-Status）：一次性跑 top/free/df 取回原始输出，由 ServerStatus.parse 解析。 */
    suspend fun fetchStatus(
        host: String, port: Int, user: String, password: String
    ): Result<ServerStatus> {
        val cmd = "top -bn1 2>/dev/null | grep -i '%Cpu'; echo '---'; free -m 2>/dev/null; echo '---'; df -h / 2>/dev/null"
        return connectAndExec(host, port, user, password, cmd).map { ServerStatus.parse(it) }
    }

    /** 列远程目录（A-SFTP）：sshj SFTPClient ls，返回文件列表（文件夹优先、按名排序）。 */
    suspend fun listDir(
        host: String, port: Int, user: String, password: String, path: String
    ): Result<List<RemoteFile>> = withContext(Dispatchers.IO) {
        runCatching {
            withTimeout(15_000) {
                val ssh = SSHClient()
                ssh.addHostKeyVerifier(PromiscuousVerifier())  // MVP，TODO TOFU
                ssh.connectTimeout = 10_000
                ssh.connect(host, port)
                try {
                    ssh.authPassword(user, password)
                    ssh.newSFTPClient().use { sftp ->
                        sftp.ls(path).mapNotNull { info ->
                            val name = info.name
                            if (name == "." || name == "..") return@mapNotNull null
                            val isDir = info.attributes.type == FileMode.Type.DIRECTORY
                            RemoteFile(name, isDir, info.attributes.size, info.path)
                        }.sortedWith(compareByDescending<RemoteFile> { it.isDir }.thenBy { it.name.lowercase() })
                    }
                } finally {
                    runCatching { ssh.disconnect() }
                }
            }
        }
    }

    /** 读取远程文本文件内容（A-FileView）：head -c 限制大小，避免大文件/二进制卡顿。 */
    suspend fun readFile(
        host: String, port: Int, user: String, password: String, path: String, maxBytes: Int = 200_000
    ): Result<String> {
        val safe = path.replace("'", "'\\''")
        return connectAndExec(host, port, user, password, "head -c $maxBytes '$safe'")
    }

    /** 探测服务器环境（A-Env）：跑 EnvDetector.detectCommand → ServerProfile。 */
    suspend fun fetchEnv(
        host: String, port: Int, user: String, password: String
    ): Result<ServerProfile> =
        connectAndExec(host, port, user, password, EnvDetector.detectCommand).map { EnvDetector.parse(it) }

    /** 去除常见 ANSI 转义序列（颜色/光标控制），MVP 简化处理 */
    fun stripAnsi(s: String): String =
        s.replace(Regex("\\[[0-9;?]*[a-zA-Z]"), "")
         .replace(Regex("[()][AB0-2]"), "")
         .replace("]0;", "").replace("", "")
}

/** 远程文件（A-SFTP） */
data class RemoteFile(val name: String, val isDir: Boolean, val size: Long, val path: String) {
    /** 人类可读大小 */
    val sizeLabel: String
        get() = when {
            isDir -> ""
            size < 1024 -> "$size B"
            size < 1024 * 1024 -> "%.1f KB".format(size / 1024.0)
            size < 1024 * 1024 * 1024 -> "%.1f MB".format(size / 1024.0 / 1024.0)
            else -> "%.1f GB".format(size / 1024.0 / 1024.0 / 1024.0)
        }
}

/** 交互式 shell 会话句柄：write 发命令到 PTY，close 断开。 */
class SshShellSession(
    private val ssh: SSHClient,
    private val session: Session,
    private val out: OutputStream
) {
    fun write(text: String) {
        runCatching {
            out.write(text.toByteArray(Charsets.UTF_8))
            out.flush()
        }
    }
    fun close() {
        runCatching { session.close() }
        runCatching { ssh.disconnect() }
    }
}
