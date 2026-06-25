package com.termind.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color

/** 配色方案（A-Themes）：对齐 apple 5 套主题。 */
data class ThemeScheme(
    val id: String,
    val name: String,
    val bg: Color,
    val surface: Color,
    val surfaceLight: Color,
    val accent: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val success: Color,
    val warning: Color,
    val danger: Color
) {
    companion object {
        val builtins = listOf(
            ThemeScheme("midnight", "午夜",
                Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460), Color(0xFFE94560),
                Color(0xFFEEEEEE), Color(0xFFA0A0A0), Color(0xFF2ECC71), Color(0xFFF39C12), Color(0xFFE74C3C)),
            ThemeScheme("onedark", "One Dark",
                Color(0xFF282C34), Color(0xFF21252B), Color(0xFF3A3F4B), Color(0xFF61AFEF),
                Color(0xFFABB2BF), Color(0xFF7F848E), Color(0xFF98C379), Color(0xFFE5C07B), Color(0xFFE06C75)),
            ThemeScheme("dracula", "Dracula",
                Color(0xFF282A36), Color(0xFF21222C), Color(0xFF44475A), Color(0xFFBD93F9),
                Color(0xFFF8F8F2), Color(0xFF9CA0B0), Color(0xFF50FA7B), Color(0xFFF1FA8C), Color(0xFFFF5555)),
            ThemeScheme("solarized", "Solarized",
                Color(0xFF002B36), Color(0xFF073642), Color(0xFF0E4B59), Color(0xFF268BD2),
                Color(0xFF93A1A1), Color(0xFF657B83), Color(0xFF859900), Color(0xFFB58900), Color(0xFFDC322F)),
            ThemeScheme("nord", "Nord",
                Color(0xFF2E3440), Color(0xFF3B4252), Color(0xFF434C5E), Color(0xFF88C0D0),
                Color(0xFFECEFF4), Color(0xFF9AA3B2), Color(0xFFA3BE8C), Color(0xFFEBCB8B), Color(0xFFBF616A))
        )
        fun byId(id: String): ThemeScheme = builtins.firstOrNull { it.id == id } ?: builtins[0]
    }
}

/** 全局当前主题（mutableStateOf，切换即触发所有读取处 recompose）。 */
var activeTheme by mutableStateOf(ThemeScheme.builtins[0])
