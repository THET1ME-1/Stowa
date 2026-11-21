package app.stowa

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity

/**
 * Настройка виджета-заметки: при добавлении и по «Настроить» долгим нажатием. Список —
 * «Случайная, новая каждый день» и заметки из `widget.json` (закреплённые первыми, без
 * скрытых и 18+). Окно — системный диалог поверх рабочего стола.
 */
class NoteWidgetConfigureActivity : AppCompatActivity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // закрыли окно, ничего не выбрав, — виджет не ставится (при перенастройке остаётся прежним)
        setResult(Activity.RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        val snapshot = NoteWidgetProvider.load(this)
        // под «Кодом на вход» заметок в файле нет: выбрать можно только случайную
        val notes = if (snapshot == null || snapshot.locked) emptyList() else snapshot.notes
        val chosen = NoteWidgetProvider.prefs(this).getString(NoteWidgetProvider.noteKey(widgetId), null)
        // закреплённые в файле уже первыми
        val titles = arrayOf(getString(R.string.note_widget_random)) + notes.map { note -> note.title.ifBlank { getString(R.string.note_widget_untitled) } }
        val selected = if (chosen == null) 0 else notes.indexOfFirst { it.id == chosen } + 1
        AlertDialog.Builder(this, R.style.NoteWidgetDialog)
            .setTitle(R.string.note_widget_pick)
            .setSingleChoiceItems(titles, selected.coerceAtLeast(0)) { dialog, which ->
                choose(if (which == 0) null else notes[which - 1].id)
                dialog.dismiss()
            }
            .setOnCancelListener { finish() }
            .setOnDismissListener { if (!isFinishing) finish() }
            .show()
    }

    private fun choose(noteId: String?) {
        val prefs = NoteWidgetProvider.prefs(this).edit()
        if (noteId == null) prefs.remove(NoteWidgetProvider.noteKey(widgetId)) else prefs.putString(NoteWidgetProvider.noteKey(widgetId), noteId)
        prefs.apply()
        NoteWidgetProvider.render(this, AppWidgetManager.getInstance(this), widgetId)
        NoteWidgetProvider.scheduleMidnight(this)
        setResult(Activity.RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        finish()
    }
}
