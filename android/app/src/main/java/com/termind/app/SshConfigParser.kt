package com.termind.app

/** 解析 OpenSSH ~/.ssh/config 文本，把每个具体 Host 块转成 ServerConn（对齐 apple SSHConfigParser）。
 * 支持 Host / HostName / Port / User；忽略通配 Host（含 * ?）。私钥路径移动端无意义，按密码认证导入。 */
object SshConfigParser {

    private data class Block(var alias: String, var hostName: String? = null, var port: Int? = null, var user: String? = null)

    fun parse(text: String): List<ServerConn> {
        val result = mutableListOf<ServerConn>()
        var current: Block? = null

        fun flush() {
            val b = current ?: return
            val host = if (!b.hostName.isNullOrEmpty()) b.hostName!! else b.alias
            if (host.isEmpty()) return
            result.add(ServerConn(name = b.alias, host = host, user = b.user ?: "", port = b.port ?: 22))
        }

        for (rawLine in text.split('\n', '\r')) {
            val line = rawLine.trim()
            if (line.isEmpty() || line.startsWith("#")) continue
            // 拆 key/value（分隔符 空白或 =）
            val sepIdx = line.indexOfFirst { it == ' ' || it == '\t' || it == '=' }
            if (sepIdx < 0) continue
            val key = line.substring(0, sepIdx).lowercase()
            var value = line.substring(sepIdx + 1).trim().trim(' ', '\t', '=')
            if (value.length >= 2 && value.startsWith("\"") && value.endsWith("\"")) value = value.substring(1, value.length - 1)

            when (key) {
                "host" -> {
                    flush()
                    val firstPattern = value.split(" ").firstOrNull() ?: value
                    current = if (firstPattern.isEmpty() || firstPattern.contains("*") || firstPattern.contains("?")) null
                              else Block(alias = firstPattern)
                }
                "hostname" -> current?.hostName = value
                "port" -> current?.port = value.toIntOrNull()
                "user" -> current?.user = value
            }
        }
        flush()
        return result.filter { it.host.isNotEmpty() }
    }
}
