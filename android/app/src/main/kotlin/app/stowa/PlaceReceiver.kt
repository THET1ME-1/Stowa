package app.stowa

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.location.LocationManager

/**
 * Будит Stowa у точки, при подключении к сети дома или работы и после загрузки телефона.
 * Приложение при этом может быть выгружено: текст уведомления уже лежит в [PlaceAlarms].
 */
class PlaceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            PlaceAlarms.ACTION_PLACE -> {
                // тревога зовёт и на выходе из круга: напоминаем только на входе
                if (!intent.getBooleanExtra(LocationManager.KEY_PROXIMITY_ENTERING, false)) return
                val id = intent.getStringExtra("id") ?: return
                PlaceAlarms.fire(context, id)
            }
            PlaceAlarms.ACTION_WIFI -> PlaceAlarms.wifiConnected(context)
            // после загрузки и обновления Android тревоги забывает
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> PlaceAlarms.apply(context)
        }
    }
}
