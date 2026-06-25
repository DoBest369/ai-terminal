package com.termind.app

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle

/**
 * ANSI 终端转义解析（A-Ansi）：把 SGR 颜色码渲染成 Compose AnnotatedString，
 * 替代原先「直接删颜色码」的 stripAnsi，让终端输出保留高亮。
 * 支持：前景色 30-37/90-97、粗体 1、重置 0；其它光标/控制序列剥离。
 */
object AnsiParser {
    // 标准 8 色（前景 30-37）—— 取终端常见配色，深色背景可读
    private val basic = mapOf(
        30 to Color(0xFF555555), // 黑（提亮，避免不可见）
        31 to Color(0xFFE74C3C), // 红
        32 to Color(0xFF2ECC71), // 绿
        33 to Color(0xFFF39C12), // 黄
        34 to Color(0xFF3498DB), // 蓝
        35 to Color(0xFF9B59B6), // 品红
        36 to Color(0xFF1ABC9C), // 青
        37 to Color(0xFFDDDDDD), // 白
    )
    // 亮色（90-97）
    private val bright = mapOf(
        90 to Color(0xFF888888), 91 to Color(0xFFFF6B6B), 92 to Color(0xFF55EFC4),
        93 to Color(0xFFFFD93D), 94 to Color(0xFF74B9FF), 95 to Color(0xFFD980FA),
        96 to Color(0xFF81ECEC), 97 to Color(0xFFFFFFFF),
    )

    private val defaultColor = Color(0xFF2ECC71)  // 终端默认绿（与原终端区一致）

    /** 把含 ANSI 的文本解析成带颜色/粗体的 AnnotatedString */
    fun parse(text: String): AnnotatedString = buildAnnotatedString {
        var color: Color = defaultColor
        var bold = false
        var i = 0
        val n = text.length
        val plain = StringBuilder()

        fun flush() {
            if (plain.isEmpty()) return
            withStyle(SpanStyle(color = color, fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal)) {
                append(plain.toString())
            }
            plain.clear()
        }

        while (i < n) {
            val c = text[i]
            if (c == '' && i + 1 < n && text[i + 1] == '[') {
                // 找到 ESC[ … 终止字母
                var j = i + 2
                while (j < n && text[j] !in '@'..'~') j++
                if (j < n) {
                    val final = text[j]
                    val params = text.substring(i + 2, j)
                    if (final == 'm') {
                        flush()
                        applySgr(params, get = { color }, getBold = { bold },
                            setColor = { color = it }, setBold = { bold = it },
                            reset = { color = defaultColor; bold = false })
                    }
                    // 非 SGR（光标/清屏等）直接丢弃
                    i = j + 1
                    continue
                }
            }
            plain.append(c)
            i++
        }
        flush()
    }

    private inline fun applySgr(
        params: String,
        get: () -> Color, getBold: () -> Boolean,
        setColor: (Color) -> Unit, setBold: (Boolean) -> Unit, reset: () -> Unit
    ) {
        val codes = if (params.isEmpty()) listOf(0) else params.split(';').mapNotNull { it.toIntOrNull() }
        for (code in codes) {
            when (code) {
                0 -> reset()
                1 -> setBold(true)
                22 -> setBold(false)
                39 -> setColor(defaultColor)
                in 30..37 -> basic[code]?.let(setColor)
                in 90..97 -> bright[code]?.let(setColor)
                else -> {} // 背景色/256色等暂忽略
            }
        }
    }
}
