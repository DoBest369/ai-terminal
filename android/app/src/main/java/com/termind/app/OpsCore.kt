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
