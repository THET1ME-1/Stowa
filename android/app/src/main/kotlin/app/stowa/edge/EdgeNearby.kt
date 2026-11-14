package app.stowa.edge

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * «Рядом»: заметки, чьё напоминание по месту сработало за последние полчаса.
 * Пишет приёмник мест ([app.stowa.PlaceAlarms.fire]), читает полка по каналу.
 * Отдельно от `flutter.place_fired`: тот главное окно забирает и стирает, времени в нём нет.
 */
object EdgeNearby {
    private const val KEY = "flutter.edge_nearby"
    private const val WINDOW_MS = 30 * 60 * 1000L

    private fun prefs(context: Context) = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    /** Сработало напоминание заметки [noteId]: запомнить и мягко подсветить корешки. */
    fun record(context: Context, noteId: String) {
        val now = System.currentTimeMillis()
        val kept = entries(context, now).filter { it.first != noteId }
        val all = JSONArray(listOf(JSONObject().put("id", noteId).put("at", now)) + kept.map { JSONObject().put("id", it.first).put("at", it.second) })
        prefs(context).edit().putString(KEY, all.toString()).apply()
        EdgeService.running?.pulse()
    }

    /** Свежие первыми, только за последние полчаса. */
    fun recent(context: Context): List<String> = entries(context, System.currentTimeMillis()).map { it.first }

    private fun entries(context: Context, now: Long): List<Pair<String, Long>> {
        val raw = prefs(context).getString(KEY, null) ?: return emptyList()
        val list = runCatching { JSONArray(raw) }.getOrNull() ?: return emptyList()
        return (0 until list.length())
            .mapNotNull { list.optJSONObject(it) }
            .map { it.optString("id") to it.optLong("at") }
            .filter { it.first.isNotEmpty() && now - it.second in 0..WINDOW_MS }
            .sortedByDescending { it.second }
    }
}
