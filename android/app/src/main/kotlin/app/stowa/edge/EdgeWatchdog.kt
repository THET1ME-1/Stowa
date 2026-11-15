package app.stowa.edge

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Будильник-сторож корешков. Пока служба жива, она каждые 5 секунд переставляет его
 * на [DELAY_MS] вперёд, и он не срабатывает: убитые корешки встают через 5–10 секунд. Убили процесс — будильник
 * остаётся и поднимает корешки сам.
 *
 * Зачем: HyperOS, смахнув Stowa из недавних, убивает процесс (`SwipeUpClean`), а система
 * перезапускает службу всё реже — 16 с, 88 с, почти 6 минут (телефон, 15.11.2026), и после
 * перезапуска иногда не создаёт её вовсе. Смахивание — не принудительная остановка,
 * будильник его переживает. Не будит телефон: корешки на выключенном экране не нужны.
 * Точный будильник даёт право запустить службу из фона.
 */
object EdgeWatchdog {
    private const val DELAY_MS = 10_000L

    fun arm(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val at = System.currentTimeMillis() + DELAY_MS
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
        try {
            if (exact) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC, at, pending(context))
            else alarms.setAndAllowWhileIdle(AlarmManager.RTC, at, pending(context))
        } catch (error: SecurityException) {
            Log.w(EdgeHandle.TAG, "watchdog not armed", error)
        }
    }

    fun disarm(context: Context) {
        context.getSystemService(AlarmManager::class.java)?.cancel(pending(context))
    }

    private fun pending(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, Receiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /**
     * Сработал: служба жива — проверить, что корешки на месте (HyperOS поднимает службу без
     * onStartCommand), и сторожить дальше; службы нет — поднять корешки.
     */
    class Receiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val service = EdgeService.running
            if (service != null) {
                service.ensureShown()
                return arm(context)
            }
            Log.d(EdgeHandle.TAG, "watchdog: spines gone, starting")
            EdgeService.startIfEnabled(context)
        }
    }
}
