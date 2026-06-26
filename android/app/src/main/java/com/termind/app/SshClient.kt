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
import java.io.OutputStream
import java.util.concurrent.TimeUnit

/** 跳板机配置（A-Jump）：经 bastion 连目标。密码运行时输入，不持久化。 */
data class JumpConfig(val host: String, val port: Int, val user: String, val password: String)

/** 安卓真实 SSH（sshj，纯 Java，适合 Android）。A1：先做 exec 命令+输出，交互式 PTY 留 A1b。 */
object SshClient {

    /**
     * 建立到目标的已连接+已认证 SSHClient（A-Jump：jump 非空时经 bastion 用 sshj connectVia）。
     * 返回 (target, bastion?)；bastion 需与 target 一起关闭。
     */
    private fun connectClient(
        host: String, port: Int, user: String, password: String, privateKey: String?, jump: JumpConfig?
    ): Pair<SSHClient, SSHClient?> {
        if (jump != null && jump.host.isNotBlank()) {
            // 先连跳板机（密码认证），再经 direct-tcpip 通道连目标
            val bastion = SSHClient()
            bastion.addHostKeyVerifier(TofuVerifier())
            bastion.connectTimeout = 10_000
            bastion.connect(jump.host, jump.port)
            authenticate(bastion, jump.user, jump.password, null)
            val dc = bastion.newDirectConnection(host, port)
            val target = SSHClient()
            target.addHostKeyVerifier(TofuVerifier())
            target.connectVia(dc)
            authenticate(target, user, password, privateKey)
            return target to bastion
        }
        val ssh = SSHClient()
        ssh.addHostKeyVerifier(TofuVerifier())
        ssh.connectTimeout = 10_000
        ssh.connect(host, port)
        authenticate(ssh, user, password, privateKey)
        return ssh to null
    }

    /**
     * 认证（A-KeyAuth）：privateKey 非空走公钥认证（PEM 字符串），否则密码认证。
     * sshj: loadKeys(privateKeyContent, publicKeyOrNull, passwordFinderOrNull) 把字符串当密钥内容。
     */
    private fun authenticate(ssh: SSHClient, user: String, password: String, privateKey: String?) {
        if (!privateKey.isNullOrBlank()) {
            val keyProvider = ssh.loadKeys(privateKey, null, null)
            ssh.authPublickey(user, keyProvider)
        } else {
            ssh.authPassword(user, password)
        }
    }

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
        timeoutMs: Long = 15_000,
        privateKey: String? = null,
        jump: JumpConfig? = null
    ): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            withTimeout(timeoutMs) {
                val (ssh, bastion) = connectClient(host, port, user, password, privateKey, jump)
                ssh.timeout = 10_000
                try {
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
                    runCatching { bastion?.disconnect() }
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
        privateKey: String? = null,
        jump: JumpConfig? = null,
        onOutput: (String) -> Unit
    ): SshShellSession = withContext(Dispatchers.IO) {
        val (ssh, bastion) = connectClient(host, port, user, password, privateKey, jump)
        ssh.connection.keepAlive.keepAliveInterval = 30   // A-KeepAlive：30s 心跳防 NAT/服务器超时断连
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
                        // 保留原始 ANSI（含颜色码），由 UI 的 AnsiParser 渲染彩色（A-Ansi）
                        withContext(Dispatchers.Main) { onOutput(chunk) }
                    }
                }
            } catch (_: Exception) { /* 会话关闭/断开，正常退出 */ }
        }
        SshShellSession(ssh, session, out, bastion)
    }

    /** 采集服务器状态（A-Status）：一次性跑 top/free/df 取回原始输出，由 ServerStatus.parse 解析。 */
    suspend fun fetchStatus(
        host: String, port: Int, user: String, password: String, privateKey: String? = null, jump: JumpConfig? = null
    ): Result<ServerStatus> {
        val cmd = "top -bn1 2>/dev/null | grep -i '%Cpu'; echo '---'; free -m 2>/dev/null; echo '---'; df -h / 2>/dev/null; echo '---'; uptime 2>/dev/null; echo '---'; for s in nginx docker mysql redis sshd; do echo \"SVC@@\$s:\$(systemctl is-active \$s 2>/dev/null || echo unknown)\"; done"
        return connectAndExec(host, port, user, password, cmd, privateKey = privateKey, jump = jump).map { ServerStatus.parse(it) }
    }

    /** 列远程目录（A-SFTP）：sshj SFTPClient ls，返回文件列表（文件夹优先、按名排序）。 */
    suspend fun listDir(
        host: String, port: Int, user: String, password: String, path: String, privateKey: String? = null, jump: JumpConfig? = null
    ): Result<List<RemoteFile>> = withContext(Dispatchers.IO) {
        runCatching {
            withTimeout(15_000) {
                val (ssh, bastion) = connectClient(host, port, user, password, privateKey, jump)
                try {
                    ssh.newSFTPClient().use { sftp ->
                        sftp.ls(path).mapNotNull { info ->
                            val name = info.name
                            if (name == "." || name == "..") return@mapNotNull null
                            val isDir = info.attributes.type == FileMode.Type.DIRECTORY
                            RemoteFile(name, isDir, info.attributes.size, info.path, info.attributes.mtime)
                        }.sortedWith(compareByDescending<RemoteFile> { it.isDir }.thenBy { it.name.lowercase() })
                    }
                } finally {
                    runCatching { ssh.disconnect() }
                    runCatching { bastion?.disconnect() }
                }
            }
        }
    }

    /** 下载远程文件到本地路径（A-Upload）：sshj SFTPClient.get。 */
    suspend fun downloadFile(
        host: String, port: Int, user: String, password: String,
        remotePath: String, localPath: String, privateKey: String? = null, jump: JumpConfig? = null
    ): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            withTimeout(60_000) {
                val (ssh, bastion) = connectClient(host, port, user, password, privateKey, jump)
                try {
                    ssh.newSFTPClient().use { it.get(remotePath, localPath) }
                } finally {
                    runCatching { ssh.disconnect() }
                    runCatching { bastion?.disconnect() }
                }
            }
        }
    }

    /** 上传本地文件到远程路径（A-Upload）：sshj SFTPClient.put。 */
    suspend fun uploadFile(
        host: String, port: Int, user: String, password: String,
        localPath: String, remotePath: String, privateKey: String? = null, jump: JumpConfig? = null
    ): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            withTimeout(60_000) {
                val (ssh, bastion) = connectClient(host, port, user, password, privateKey, jump)
                try {
                    ssh.newSFTPClient().use { it.put(localPath, remotePath) }
                } finally {
                    runCatching { ssh.disconnect() }
                    runCatching { bastion?.disconnect() }
                }
            }
        }
    }

    /** 新建远程目录（A-SftpEdit）：sshj SFTPClient.mkdir。 */
    suspend fun makeDir(
        host: String, port: Int, user: String, password: String, path: String, privateKey: String? = null, jump: JumpConfig? = null
    ): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            withTimeout(15_000) {
                val (ssh, bastion) = connectClient(host, port, user, password, privateKey, jump)
                try {
                    ssh.newSFTPClient().use { it.mkdir(path) }
                } finally { runCatching { ssh.disconnect() }; runCatching { bastion?.disconnect() } }
            }
        }
    }

    /** 删除远程文件/空目录（A-SftpEdit）：文件用 rm、目录用 rmdir。 */
    suspend fun deletePath(
        host: String, port: Int, user: String, password: String, path: String, isDir: Boolean, privateKey: String? = null, jump: JumpConfig? = null
    ): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            withTimeout(15_000) {
                val (ssh, bastion) = connectClient(host, port, user, password, privateKey, jump)
                try {
                    ssh.newSFTPClient().use { if (isDir) it.rmdir(path) else it.rm(path) }
                } finally { runCatching { ssh.disconnect() }; runCatching { bastion?.disconnect() } }
            }
        }
    }

    /** 重命名/移动远程文件或目录（A-SftpRename）：sshj SFTPClient.rename。 */
    suspend fun renamePath(
        host: String, port: Int, user: String, password: String, oldPath: String, newPath: String, privateKey: String? = null, jump: JumpConfig? = null
    ): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            withTimeout(15_000) {
                val (ssh, bastion) = connectClient(host, port, user, password, privateKey, jump)
                try {
                    ssh.newSFTPClient().use { it.rename(oldPath, newPath) }
                } finally { runCatching { ssh.disconnect() }; runCatching { bastion?.disconnect() } }
            }
        }
    }

    /** 读取远程文本文件内容（A-FileView）：head -c 限制大小，避免大文件/二进制卡顿。 */
    suspend fun readFile(
        host: String, port: Int, user: String, password: String, path: String, maxBytes: Int = 200_000, privateKey: String? = null, jump: JumpConfig? = null
    ): Result<String> {
        val safe = path.replace("'", "'\\''")
        return connectAndExec(host, port, user, password, "head -c $maxBytes '$safe'", privateKey = privateKey, jump = jump)
    }

    /**
     * 本地端口转发（A-Forward）：本机 localPort → 经 SSH → remoteHost:remotePort。
     * 在传入 scope 的 IO 协程里 listen()（阻塞），返回可关闭句柄。
     */
    suspend fun openForward(
        host: String, port: Int, user: String, password: String,
        localPort: Int, remoteHost: String, remotePort: Int,
        scope: CoroutineScope, privateKey: String? = null, jump: JumpConfig? = null
    ): PortForwardHandle = withContext(Dispatchers.IO) {
        val (ssh, bastion) = connectClient(host, port, user, password, privateKey, jump)
        val ss = java.net.ServerSocket()
        ss.reuseAddress = true
        ss.bind(java.net.InetSocketAddress("127.0.0.1", localPort))
        val params = net.schmizz.sshj.connection.channel.direct.Parameters(
            "127.0.0.1", localPort, remoteHost, remotePort
        )
        val forwarder = ssh.newLocalPortForwarder(params, ss)
        // listen() 阻塞直到 ServerSocket 关闭
        val job = scope.launch(Dispatchers.IO) {
            runCatching { forwarder.listen() }
        }
        PortForwardHandle(ssh, ss, job, bastion)
    }

    /** 探测服务器环境（A-Env）：跑 EnvDetector.detectCommand → ServerProfile。 */
    suspend fun fetchEnv(
        host: String, port: Int, user: String, password: String, privateKey: String? = null, jump: JumpConfig? = null
    ): Result<ServerProfile> =
        connectAndExec(host, port, user, password, EnvDetector.detectCommand, privateKey = privateKey, jump = jump).map { EnvDetector.parse(it) }

    /** 去除常见 ANSI 转义序列（颜色/光标控制），MVP 简化处理 */
    fun stripAnsi(s: String): String =
        s.replace(Regex("\\[[0-9;?]*[a-zA-Z]"), "")
         .replace(Regex("[()][AB0-2]"), "")
         .replace("]0;", "").replace("", "")
}

/** 远程文件（A-SFTP）。mtime 为修改时间（秒，0 表示未知）。 */
data class RemoteFile(val name: String, val isDir: Boolean, val size: Long, val path: String, val mtime: Long = 0) {
    /** 人类可读大小 */
    val sizeLabel: String
        get() = when {
            isDir -> ""
            size < 1024 -> "$size B"
            size < 1024 * 1024 -> "%.1f KB".format(size / 1024.0)
            size < 1024 * 1024 * 1024 -> "%.1f MB".format(size / 1024.0 / 1024.0)
            else -> "%.1f GB".format(size / 1024.0 / 1024.0 / 1024.0)
        }

    /** 修改时间标签（A-SftpTime）：今年显 MM-dd HH:mm，往年显 yyyy-MM-dd */
    val timeLabel: String
        get() {
            if (mtime <= 0) return ""
            val date = java.util.Date(mtime * 1000)
            val cal = java.util.Calendar.getInstance()
            val curYear = cal.get(java.util.Calendar.YEAR)
            cal.time = date
            val fmt = if (cal.get(java.util.Calendar.YEAR) == curYear) "MM-dd HH:mm" else "yyyy-MM-dd"
            return java.text.SimpleDateFormat(fmt, java.util.Locale.getDefault()).format(date)
        }
}

/** 端口转发句柄（A-Forward）：close 关闭 ServerSocket + 断开 SSH。 */
class PortForwardHandle(
    private val ssh: SSHClient,
    private val serverSocket: java.net.ServerSocket,
    private val job: kotlinx.coroutines.Job,
    private val bastion: SSHClient? = null   // A-Jump 跳板机连接
) {
    fun close() {
        runCatching { serverSocket.close() }
        runCatching { job.cancel() }
        runCatching { ssh.disconnect() }
        runCatching { bastion?.disconnect() }
    }
}

/** 交互式 shell 会话句柄：write 发命令到 PTY，close 断开。 */
class SshShellSession(
    private val ssh: SSHClient,
    private val session: Session,
    private val out: OutputStream,
    private val bastion: SSHClient? = null   // A-Jump 跳板机连接，需一并关闭
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
        runCatching { bastion?.disconnect() }
    }
}
