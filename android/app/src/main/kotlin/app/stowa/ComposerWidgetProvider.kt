package app.stowa

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

/**
 * Виджет-строка на рабочем столе: «Закинь что угодно», камера и микрофон.
 * Данных не показывает, поэтому обновлять его не нужно — только раздать касания.
 * Касание открывает прозрачное окно QuickActivity поверх рабочего стола, не главную.
 */
class ComposerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.composer_widget)
            views.setOnClickPendingIntent(R.id.widget_line, open(context, "compose", 1))
            views.setOnClickPendingIntent(R.id.widget_mic, open(context, "voice", 2))
            views.setOnClickPendingIntent(R.id.widget_camera, open(context, "camera", 3))
            manager.updateAppWidget(id, views)
        }
    }

    private fun open(context: Context, action: String, code: Int): PendingIntent {
        // прошлое окно виджета, если ещё живо, уступает новому: у каждой кнопки свой запуск
        val intent = Intent(context, QuickActivity::class.java)
            .setAction(Intent.ACTION_VIEW)
            .setData(Uri.parse("stowa://$action"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        return PendingIntent.getActivity(context, code, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }
}
