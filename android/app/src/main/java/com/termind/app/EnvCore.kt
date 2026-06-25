package com.termind.app

/**
 * 环境感知（A-Env）：连接后探测服务器真实环境，做成摘要喂给 AI。
 * Kotlin 移植 apple ServerProfile.swift + EnvDetector，规则保持一致（对齐 Z3）。
 */
data class ServerProfile(
    val hostname: String = "",
    val os: String = "",
    val distro: String = "",
    val kernel: String = "",
    val arch: String = "",
    val currentUser: String = "",
    val isRoot: Boolean = false,
    val packageManager: String = "",
    val services: Map<String, Boolean> = emptyMap()
) {
    val installedServices: List<String> get() = services.filter { it.value }.keys.sorted()
    val missingServices: List<String> get() = services.filterNot { it.value }.keys.sorted()

    /** 给 AI 的一行环境摘要（用作上下文） */
    val aiSummary: String
        get() {
            if (distro.isEmpty() && os.isEmpty()) return ""
            val parts = mutableListOf<String>()
            parts.add("系统 ${distro.ifEmpty { os }}${if (arch.isEmpty()) "" else " ($arch)"}")
            if (currentUser.isNotEmpty()) parts.add("用户 $currentUser${if (isRoot) "(root)" else ""}")
            if (packageManager.isNotEmpty()) parts.add("包管理器 $packageManager")
            if (installedServices.isNotEmpty()) parts.add("已装 ${installedServices.joinToString(",")}")
            if (missingServices.isNotEmpty()) parts.add("未装 ${missingServices.joinToString(",")}")
            return "当前服务器环境：" + parts.joinToString(" · ")
        }
}

object EnvDetector {
    val probedServices = listOf("nginx", "docker", "node", "npm", "python3", "mysql", "redis", "pm2", "git", "java")

    /** 一条复合探测命令：各段输出带前缀，便于解析。 */
    val detectCommand: String
        get() {
            val whichLines = probedServices.joinToString("; ") {
                "echo \"SVC:$it:\$(command -v $it >/dev/null 2>&1 && echo 1 || echo 0)\""
            }
            return listOf(
                "echo \"HOST:\$(hostname 2>/dev/null)\"",
                "echo \"UNAME:\$(uname -s) \$(uname -r) \$(uname -m)\"",
                "echo \"USER:\$(id -un 2>/dev/null) \$(id -u 2>/dev/null)\"",
                "( cat /etc/os-release 2>/dev/null | sed 's/^/OSREL:/' )",
                "for pm in apt dnf yum apk pacman; do command -v \$pm >/dev/null 2>&1 && echo \"PM:\$pm\" && break; done",
                whichLines
            ).joinToString("; ")
        }

    /** 解析 detectCommand 输出为 ServerProfile。 */
    fun parse(output: String): ServerProfile {
        var hostname = ""; var os = ""; var kernel = ""; var arch = ""
        var user = ""; var isRoot = false; var distro = ""; var pm = ""
        val services = mutableMapOf<String, Boolean>()
        for (raw in output.split('\n', '\r')) {
            val line = raw.trim()
            when {
                line.startsWith("HOST:") -> hostname = line.removePrefix("HOST:")
                line.startsWith("UNAME:") -> {
                    val parts = line.removePrefix("UNAME:").split(" ")
                    parts.getOrNull(0)?.let { os = it }
                    parts.getOrNull(1)?.let { kernel = it }
                    parts.getOrNull(2)?.let { arch = it }
                }
                line.startsWith("USER:") -> {
                    val parts = line.removePrefix("USER:").split(" ")
                    parts.getOrNull(0)?.let { user = it }
                    parts.getOrNull(1)?.let { isRoot = (it == "0") }
                }
                line.startsWith("OSREL:") -> {
                    val kv = line.removePrefix("OSREL:")
                    if (kv.startsWith("PRETTY_NAME=")) distro = kv.removePrefix("PRETTY_NAME=").trim('"')
                }
                line.startsWith("PM:") -> pm = line.removePrefix("PM:")
                line.startsWith("SVC:") -> {
                    val kv = line.removePrefix("SVC:").split(":")
                    if (kv.size == 2) services[kv[0]] = (kv[1] == "1")
                }
            }
        }
        return ServerProfile(hostname, os, distro, kernel, arch, user, isRoot, pm, services)
    }
}
