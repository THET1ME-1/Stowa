package app.stowa

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File
import java.util.Calendar
import java.util.TimeZone

/**
 * Виджет-заметка (STOWA-8): выбранная заметка или случайная, новая каждый день; у
 * случайной кружок «другая». Касание открывает заметку. Данные — `widget.json` в папке
 * приложения: его пишет Dart (`WidgetSync`, канал `stowa/widget`), в нём нет скрытых и
 * 18+, а под «Кодом на вход» нет текста вовсе. Как виджет iPhone (`ios/StowaWidget`).
 */
class NoteWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) render(context, manager, id)
        scheduleMidnight(context)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        val edit = prefs(context).edit()
        for (id in ids) edit.remove(noteKey(id)).remove(shiftKey(id))
        edit.apply()
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_SHUFFLE) {
            val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
            val prefs = prefs(context)
            prefs.edit().putInt(shiftKey(id), prefs.getInt(shiftKey(id), 0) + 1).apply()
            render(context, AppWidgetManager.getInstance(context), id)
            return
        }
        super.onReceive(context, intent)
    }

    data class Line(val text: String, val done: Boolean?)

    data class Note(val id: String, val title: String, val lines: List<Line>, val color: Int?, val pinned: Boolean)

    /** Что лежит в `widget.json`; null — приложение ещё не писало его. */
    data class Snapshot(val locked: Boolean, val notes: List<Note>)

    companion object {
        const val ACTION_SHUFFLE = "app.stowa.NOTE_SHUFFLE"
        private const val FILE = "widget.json"
        private const val PREFS = "note_widget"

        // цвета графитовой темы Stowa, как у виджета-строки
        private const val CONTAINER = 0xFF1F2023.toInt()
        private const val TINT = 0.16

        fun noteKey(id: Int) = "note_$id"
        fun shiftKey(id: Int) = "shift_$id"
        fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        /** Dart прислал свежий `widget.json`: записать целиком и перерисовать все виджеты. */
        fun write(context: Context, text: String) {
            val target = File(context.filesDir, FILE)
            val temp = File(context.filesDir, "$FILE.part")
            temp.writeText(text)
            temp.renameTo(target)
            updateAll(context)
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, NoteWidgetProvider::class.java))
            for (id in ids) render(context, manager, id)
        }

        fun load(context: Context): Snapshot? = try {
            val json = JSONObject(File(context.filesDir, FILE).readText())
            val notes = json.optJSONArray("notes")
            Snapshot(
                locked = json.optBoolean("locked"),
                notes = List(notes?.length() ?: 0) { index ->
                    val note = notes!!.getJSONObject(index)
                    val lines = note.optJSONArray("lines")
                    Note(
                        id = note.getString("id"),
                        title = note.optString("title"),
                        lines = List(lines?.length() ?: 0) { at ->
                            val line = lines!!.getJSONObject(at)
                            Line(line.optString("text"), if (line.has("done")) line.getBoolean("done") else null)
                        },
                        color = if (note.has("color")) note.getLong("color").toInt() else null,
                        pinned = note.optBoolean("pinned"),
                    )
                },
            )
        } catch (_: Exception) {
            null
        }

        /**
         * Заметка дня: соседние дни разбросаны по списку, а не идут подряд; [shift] —
         * сколько раз нажали «другая». Та же формула, что `DailyPick` на iPhone.
         */
        fun pick(notes: List<Note>, day: Calendar, shift: Int): Note? {
            if (notes.isEmpty()) return null
            val start = day.clone() as Calendar
            start.set(Calendar.HOUR_OF_DAY, 0)
            start.set(Calendar.MINUTE, 0)
            start.set(Calendar.SECOND, 0)
            start.set(Calendar.MILLISECOND, 0)
            val offset = TimeZone.getDefault().getOffset(start.timeInMillis)
            val days = (start.timeInMillis + offset) / 86_400_000L
            val mixed = (days * 2_654_435_761L + shift).toULong()
            return notes[(mixed % notes.size.toULong()).toInt()]
        }

        fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.note_widget)
            val snapshot = load(context)
            val chosen = prefs(context).getString(noteKey(id), null)
            // выбранную удалили или спрятали — показываем случайную, а не пустоту
            val picked = snapshot?.notes?.firstOrNull { it.id == chosen }
            val note = when {
                snapshot == null || snapshot.locked -> null
                picked != null -> picked
                else -> pick(snapshot.notes, Calendar.getInstance(), prefs(context).getInt(shiftKey(id), 0))
            }
            val random = note != null && picked == null
            if (note == null) {
                val message = when {
                    snapshot == null -> R.string.note_widget_open
                    snapshot.locked -> R.string.note_widget_locked
                    else -> R.string.note_widget_empty
                }
                views.setTextViewText(R.id.note_title, context.getString(message))
                views.setViewVisibility(R.id.note_lines, View.GONE)
                views.setInt(R.id.note_bg, "setColorFilter", CONTAINER)
                views.setOnClickPendingIntent(R.id.note_root, open(context, "stowa://home", id))
            } else {
                views.setTextViewText(R.id.note_title, note.title.ifBlank { context.getString(R.string.note_widget_untitled) })
                val lines = note.lines.joinToString("\n") { line ->
                    when (line.done) {
                        true -> "☑ ${line.text}"
                        false -> "☐ ${line.text}"
                        null -> line.text
                    }
                }
                views.setTextViewText(R.id.note_lines, lines)
                views.setViewVisibility(R.id.note_lines, if (lines.isBlank()) View.GONE else View.VISIBLE)
                views.setInt(R.id.note_bg, "setColorFilter", note.color?.let { tint(it) } ?: CONTAINER)
                val link = Uri.Builder().scheme("stowa").authority("open").appendQueryParameter("payload", "note:${note.id}").build()
                views.setOnClickPendingIntent(R.id.note_root, open(context, link.toString(), id))
            }
            views.setViewVisibility(R.id.note_shuffle, if (random) View.VISIBLE else View.GONE)
            if (random) {
                val shuffle = Intent(context, NoteWidgetProvider::class.java)
                    .setAction(ACTION_SHUFFLE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                views.setOnClickPendingIntent(
                    R.id.note_shuffle,
                    PendingIntent.getBroadcast(context, id, shuffle, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT),
                )
            }
            manager.updateAppWidget(id, views)
        }

        // подложка карточки в цвет папки, как на главной: 16% цвета поверх контейнера
        private fun tint(color: Int): Int {
            fun mix(shift: Int): Int {
                val top = (color shr shift) and 0xFF
                val bottom = (CONTAINER shr shift) and 0xFF
                return (top * TINT + bottom * (1 - TINT)).toInt() and 0xFF
            }
            return (0xFF shl 24) or (mix(16) shl 16) or (mix(8) shl 8) or mix(0)
        }

        private fun open(context: Context, link: String, id: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_VIEW)
                .setData(Uri.parse(link))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            return PendingIntent.getActivity(context, 1000 + id, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }

        /** Случайная заметка меняется в полночь: будильник без пробуждения, телефон не будит. */
        fun scheduleMidnight(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, NoteWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val midnight = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5)
            }
            val update = Intent(context, NoteWidgetProvider::class.java)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            val pending = PendingIntent.getBroadcast(context, 0, update, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).set(AlarmManager.RTC, midnight.timeInMillis, pending)
        }
    }
}
