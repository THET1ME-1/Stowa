package app.stowa

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import app.stowa.edge.EdgeService

/**
 * Будит Stowa у точки, при подключении к сети дома или работы и после загрузки телефона.
 * Приложение при этом может быть выгружено: текст уведомления уже лежит в [PlaceAlarms].
 */
class PlaceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            PlaceAlarms.ACTION_PLACE -> {
                val id = intent.getStringExtra("id") ?: return
                // тревога зовёт и на входе в круг, и на выходе: напоминаем на входе, выход взводит
                if (intent.getBooleanExtra(LocationManager.KEY_PROXIMITY_ENTERING, false)) PlaceAlarms.entered(context, id) else PlaceAlarms.left(context, id)
            }
            PlaceAlarms.ACTION_WIFI -> PlaceAlarms.checkWifi(context)
            // после загрузки и обновления Android тревоги и слежение за сетью забывает,
            // а корешки «Под рукой» — службу
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                PlaceAlarms.apply(context)
                EdgeService.startIfEnabled(context)
            }
        }
    }
}
