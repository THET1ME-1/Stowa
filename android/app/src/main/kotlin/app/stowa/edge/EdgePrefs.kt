package app.stowa.edge

import android.content.Context

/**
 * Настройки корешков из prefs Flutter (`flutter.edge_*`, пишет SettingsRepository.setEdge).
 * Числа те же, что в lib/domain/edge_settings.dart: меняешь там — меняй здесь.
 */
data class EdgePrefs(
    val enabled: Boolean,
    val rightSide: Boolean,
    /** Где по высоте, 0–100 %. */
    val height: Int,
    /** Ширина и высота подложки в точках экрана. */
    val shelfWidthDp: Float,
    val shelfHeightDp: Float,
    /** Заметность, 0,4–1. */
    val alpha: Float,
    val hideInFullscreen: Boolean,
) {
    companion object {
        private const val FILE = "FlutterSharedPreferences"

        /** Запас для пальца рядом с подложкой (`spineTouchExtra`). */
        const val TOUCH_EXTRA_DP = 18f

        /** Отступ от верха и низа экрана (`_edgeMargin`). */
        const val MARGIN_DP = 80f

        fun read(context: Context): EdgePrefs {
            val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            val (width, height) = when (prefs.getString("flutter.edge_size", "normal")) {
                "thin" -> 12f to 96f
                "large" -> 18f to 168f
                else -> 15f to 128f
            }
            return EdgePrefs(
                enabled = prefs.getBoolean("flutter.edge_enabled", false),
                rightSide = prefs.getString("flutter.edge_side", "right") != "left",
                height = prefs.getLong("flutter.edge_height", 34L).toInt().coerceIn(0, 100),
                shelfWidthDp = width,
                shelfHeightDp = height,
                alpha = prefs.getLong("flutter.edge_alpha", 86L).toInt().coerceIn(40, 100) / 100f,
                hideInFullscreen = prefs.getBoolean("flutter.edge_hide_fullscreen", true),
            )
        }
    }

    /** Верх окна корешков на экране высотой [screenHeightDp] — как `spineBox` в Dart. */
    fun topDp(screenHeightDp: Float): Float {
        val margin = ((screenHeightDp - shelfHeightDp) / 2).coerceIn(0f, MARGIN_DP)
        val room = (screenHeightDp - margin * 2 - shelfHeightDp).coerceAtLeast(0f)
        return margin + room * height / 100f
    }
}
