package com.termind.app

import androidx.compose.ui.graphics.Color

/**
 * 智能运维核心（A3）：命令风险分级 + 敏感输出脱敏。
 * Kotlin 移植 apple/AITerminalCore CommandRisk.swift + Redactor，规则与配色保持一致。
 */
enum class CommandRisk(val level: Int) {
    LOW(0),       // 只读/查看
    MEDIUM(1),    // 改普通文件/单文件权限
    HIGH(2),      // 重启服务/改配置/重载
    CRITICAL(3);  // 删除/格式化/关 SSH/清防火墙

    /** 中文标签 */
    val label: String
        get() = when (this) {
            LOW -> "安全"; MEDIUM -> "注意"; HIGH -> "高风险"; CRITICAL -> "极高危"
        }

    /** 配色（与 apple 端一致） */
    val color: Color
        get() = when (this) {
            LOW -> Color(0xFF2ECC71)       // 绿
            MEDIUM -> Color(0xFFF39C12)    // 橙
            HIGH -> Color(0xFFE67E22)      // 深橙
            CRITICAL -> Color(0xFFE74C3C)  // 红
        }

    /** 高/极高需二次确认 */
    val needsConfirm: Boolean get() = level >= HIGH.level

    companion object {
        // 极高危：删除/格式化/关 SSH/清防火墙/关机等不可逆或致命操作
        private val criticalPatterns = listOf(
            "rm -rf", "rm -fr", ":(){", "mkfs", "dd if=", "> /dev/", "chmod -r 000",
            "shutdown", "reboot", "halt", "init 0", "forkbomb",
            "iptables -f", "ufw disable", "systemctl stop ssh", "systemctl stop sshd",
            "drop database", "truncate table", "> /etc/", "wipefs"
        )
        // 高风险：重启/重载服务、改配置、改权限递归、改防火墙、kill
        private val highPatterns = listOf(
            "systemctl restart", "systemctl reload", "systemctl stop", "systemctl start",
            "service ", "nginx -s reload", "nginx -s reS", "nginx -s stop",
            "ufw ", "iptables ", "firewall-cmd", "chown -r", "chmod -r", "chmod 777",
            "kill ", "killall", "pkill", "docker rm", "docker rmi", "docker stop",
            "apt remove", "apt purge", "yum remove", "dnf remove", "userdel", "passwd "
        )
        // 中风险：改单个文件/编辑/移动/安装
        private val mediumPatterns = listOf(
            "vim ", "vi ", "nano ", "sed -i", "tee ", "cp ", "mv ", "chmod ", "chown ",
            "mkdir ", "touch ", "ln -s", "apt install", "yum install", "dnf install",
            "npm install", "pip install", "git push", "git reset", "docker run"
        )

        /** 判定风险等级，优先级 critical > high > medium > low */
        fun riskLevel(command: String): CommandRisk {
            val c = command.lowercase()
            if (criticalPatterns.any { c.contains(it) }) return CRITICAL
            if (highPatterns.any { c.contains(it) }) return HIGH
            if (mediumPatterns.any { c.contains(it) }) return MEDIUM
            return LOW
        }
    }
}

/** 服务器状态（A-Status）：CPU/内存/磁盘，由 top/free/df 输出解析。 */
data class ServerStatus(
    val cpu: String = "—",
    val mem: String = "—",
    val disk: String = "—",
    val load: String = "—",      // 负载 1/5/15 分钟（对齐 apple loadavg）
    val uptime: String = "—",    // 运行时长（对齐 apple uptime）
    val services: Map<String, Boolean> = emptyMap()   // 关键服务运行状态（对齐 apple services）
) {
    /** 已探测到的未运行服务（unknown 视为未安装，不计） */
    val stoppedServices: List<String> get() = services.filter { !it.value }.keys.sorted()
    /** 从格式化字符串里抽出百分比数值（如 "47%" / "36G/80G (90%)"），无则 null */
    private fun pct(s: String): Int? = Regex("(\\d+)%").find(s)?.groupValues?.get(1)?.toIntOrNull()

    val cpuPercent: Int? get() = pct(cpu)
    val diskPercent: Int? get() = pct(disk)

    /** 有告警：CPU 或 磁盘 >85%，或有关键服务未运行（对齐 apple hasWarning） */
    val hasWarning: Boolean get() = (cpuPercent ?: 0) > 85 || (diskPercent ?: 0) > 85 || stoppedServices.isNotEmpty()

    /** 健康摘要（喂给 AI，对齐 apple SystemInfo.healthSummary） */
    val healthSummary: String
        get() {
            val parts = mutableListOf<String>()
            if (cpu != "—") parts.add("CPU $cpu")
            if (mem != "—") parts.add("内存 $mem")
            if (disk != "—") parts.add("磁盘 $disk")
            if (load != "—") parts.add("负载 $load")
            if (uptime != "—") parts.add("运行 $uptime")
            if (stoppedServices.isNotEmpty()) parts.add("⚠️ 未运行 ${stoppedServices.joinToString(",")}")
            else if (hasWarning) parts.add("⚠️ 资源偏高")
            return if (parts.isEmpty()) "" else "服务器状态：" + parts.joinToString(" · ")
        }

    companion object {
        /** 解析 `top -bn1|grep %Cpu` + `free -m` + `df -h /` 的合并输出（以 --- 分段或全文扫描） */
        fun parse(raw: String): ServerStatus {
            var cpu = "—"; var mem = "—"; var disk = "—"
            // CPU：top 行形如 "%Cpu(s):  3.2 us,  1.1 sy, ... 95.0 id, ..." → 100 - idle
            Regex("([0-9.]+)\\s*id").find(raw)?.let {
                val idle = it.groupValues[1].toDoubleOrNull()
                if (idle != null) cpu = "${(100 - idle).coerceIn(0.0, 100.0).toInt()}%"
            }
            // 内存：free -m 的 "Mem:  total used free ..." → used/total GB
            Regex("(?im)^Mem:\\s+(\\d+)\\s+(\\d+)").find(raw)?.let {
                val total = it.groupValues[1].toIntOrNull(); val used = it.groupValues[2].toIntOrNull()
                if (total != null && used != null && total > 0)
                    mem = "%.1f/%.1f GB".format(used / 1024.0, total / 1024.0)
            }
            // 磁盘：df -h / 的数据行 "/dev/xxx  80G  36G  44G  46% /"
            Regex("(?m)^\\S+\\s+(\\S+)\\s+(\\S+)\\s+\\S+\\s+(\\d+)%\\s+/\\s*$").find(raw)?.let {
                disk = "${it.groupValues[2]}/${it.groupValues[1]} (${it.groupValues[3]}%)"
            }
            // uptime 行形如 " 17:50:01 up 12 days,  3:24,  2 users,  load average: 0.15, 0.10, 0.08"
            var load = "—"; var uptime = "—"
            Regex("load average[s]?:\\s*([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)").find(raw)?.let {
                load = "${it.groupValues[1]} / ${it.groupValues[2]} / ${it.groupValues[3]}"
            }
            Regex("up\\s+(.+?),\\s+\\d+\\s+user").find(raw)?.let {
                uptime = it.groupValues[1].trim()
            }
            // 服务状态：SVC@@nginx:active / inactive / unknown（unknown=未安装，不纳入）
            val services = mutableMapOf<String, Boolean>()
            Regex("SVC@@(\\w+):(\\S+)").findAll(raw).forEach {
                val name = it.groupValues[1]; val state = it.groupValues[2]
                if (state != "unknown") services[name] = (state == "active")
            }
            return ServerStatus(cpu, mem, disk, load, uptime, services)
        }
    }
}

/** 敏感输出脱敏：密钥/密码/Token 打码后再展示（移植 apple Redactor） */
object Redactor {
    private val sensitiveKeys = listOf(
        "password", "passwd", "pwd", "secret", "secret_key", "api_key", "apikey",
        "api_token", "token", "access_key", "access_token", "private_key",
        "db_password", "database_password", "mysql_pwd", "redis_password", "auth"
    )

    fun redact(text: String): String {
        var s = text
        fun replace(pattern: String, replacement: String, ignoreCase: Boolean = true) {
            val opts = if (ignoreCase) setOf(RegexOption.IGNORE_CASE) else emptySet()
            s = Regex(pattern, opts).replace(s, replacement)
        }
        // key=value / key: value（保留键名，值打码）。$1/$2 引用键名+分隔符
        val keysAlt = sensitiveKeys.joinToString("|")
        replace("\\b($keysAlt)(\\s*[=:]\\s*)([^\\s\"']+)", "$1$2******")
        // OpenAI 风格 key、Bearer、AWS AKIA
        replace("sk-[A-Za-z0-9]{12,}", "sk-******", ignoreCase = false)
        replace("Bearer\\s+[A-Za-z0-9._-]{8,}", "Bearer ******")
        replace("AKIA[0-9A-Z]{12,}", "AKIA******", ignoreCase = false)
        // 私钥块
        replace(
            "-----BEGIN [A-Z ]*PRIVATE KEY-----[\\s\\S]*?-----END [A-Z ]*PRIVATE KEY-----",
            "-----BEGIN PRIVATE KEY-----\n******（已脱敏）\n-----END PRIVATE KEY-----"
        )
        return s
    }
}
