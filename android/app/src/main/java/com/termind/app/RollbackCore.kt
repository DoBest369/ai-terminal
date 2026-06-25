package com.termind.app

/**
 * 操作回滚 / 可恢复操作链路（A-Rollback）：改关键配置前自动备份、记录时间线、一键回滚。
 * Kotlin 移植 apple OpRollback.swift（Z5），规则一致。
 */
object OpRollback {
    /** 关键配置文件路径前缀（命中即视为高价值、改前应备份） */
    val criticalPrefixes = listOf(
        "/etc/nginx/nginx.conf", "/etc/nginx/sites-", "/etc/nginx/conf.d/",
        "/etc/ssh/sshd_config", "/etc/mysql/", "/etc/my.cnf", "/etc/redis/",
        "/etc/hosts", "/etc/fstab", "/etc/crontab", "/etc/sudoers"
    )

    fun isCriticalConfig(path: String): Boolean {
        val p = path.trim()
        return criticalPrefixes.any { p.startsWith(it) }
    }

    /** 从命令提取它会修改的关键配置路径（写意图关键字 + 命中关键路径 token） */
    fun criticalTargets(command: String): List<String> {
        val writeVerbs = listOf("vim ", "vi ", "nano ", "tee ", "cp ", "mv ", "sed -i", ">", ">>", "echo ")
        if (writeVerbs.none { command.contains(it) }) return emptyList()
        return command.split(' ', '\t', '"', '\'', '>', '<', '|', ';', '&')
            .filter { isCriticalConfig(it) }
            .distinct().sorted()
    }

    /** 备份命令：cp <path> <path>.bak-<stamp> */
    fun backupCommand(path: String, stamp: String): String = "cp $path $path.bak-$stamp"

    /** 给一条会改关键配置的命令生成「先备份」命令组 */
    fun backupCommands(command: String, stamp: String): List<String> =
        criticalTargets(command).map { backupCommand(it, stamp) }

    /** sshd 类操作的自动回滚命令：备份 + N 分钟后未取消则自动还原重启 sshd（防锁门外） */
    fun sshAutoRollbackCommand(minutes: Int, stamp: String): String {
        val cfg = "/etc/ssh/sshd_config"
        val bak = "$cfg.bak-$stamp"
        return "cp $cfg $bak; echo \"cp $bak $cfg && systemctl restart sshd\" | at now + $minutes minutes"
    }
}

/** 操作时间线条目：记录关键操作，便于复盘/回滚。 */
data class OpTimelineEntry(
    val time: String,            // 显示用时间戳
    val action: String,          // 人类可读动作描述
    val command: String,         // 实际命令
    val rollbackable: Boolean = false,
    val backupPath: String? = null
) {
    /** 回滚命令：把备份还原回原路径（backupPath 形如 <orig>.bak-<stamp>） */
    val rollbackCommand: String?
        get() {
            if (!rollbackable || backupPath == null) return null
            val idx = backupPath.indexOf(".bak-")
            if (idx < 0) return null
            val orig = backupPath.substring(0, idx)
            return "cp $backupPath $orig"
        }
}
