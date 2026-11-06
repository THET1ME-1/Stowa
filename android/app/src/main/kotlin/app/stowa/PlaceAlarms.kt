package app.stowa

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

/**
 * Напоминания по месту без сервисов Google: круг на карте — `LocationManager.addProximityAlert`,
 * сеть дома и работы — `ConnectivityManager.registerNetworkCallback` с `PendingIntent`.
 * Обе тревоги будят [PlaceReceiver] даже у выгруженного приложения; текст уведомления Dart
 * готовит заранее и присылает в `sync`, приёмник показывает его сам.
 *
 * Сработавшее приёмник кладёт в общие настройки Flutter (`flutter.place_fired`): их читает
 * Dart и в приложении, и в фоновой задаче, где этого канала нет. Там же бюджет дня
 * (`flutter.return_day`): покупки у магазина — не чаще одного возвращающего уведомления в день.
 */
object PlaceAlarms {
    const val ACTION_PLACE = "app.stowa.PLACE"
    const val ACTION_WIFI = "app.stowa.WIFI"
    private const val PREFS = "stowa_places"
    private const val FLUTTER = "FlutterSharedPreferences"
    private const val FIRED = "flutter.place_fired"
    private const val BUDGET_DAY = "flutter.return_day"
    private const val CHANNEL_ID = "places"

    fun hasFine(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    /** Место «всегда»: без него Android не будит у точки и не отдаёт имя сети в фоне. */
    fun hasBackground(context: Context): Boolean =
        hasFine(context) && (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            context.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED)

    /** Сначала место «пока открыто», потом «всегда»: Android 11+ сам ведёт на экран настроек. */
    fun askBackground(activity: Activity) {
        if (!hasFine(activity)) {
            activity.requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), 4811)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            activity.requestPermissions(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), 4812)
        }
    }

    /** Имя сети Wi-Fi без кавычек; без разрешения на место Android прячет его за `<unknown ssid>`. */
    @Suppress("DEPRECATION")
    fun currentWifi(context: Context): String? {
        if (!hasFine(context)) return null
        val wifi = context.applicationContext.getSystemService(WifiManager::class.java) ?: return null
        val ssid = wifi.connectionInfo?.ssid?.trim('"') ?: return null
        return if (ssid.isEmpty() || ssid == "<unknown ssid>") null else ssid
    }

    /** Новые тревоги от Dart: запомнить и поставить вместо прежних. */
    fun save(context: Context, alarms: List<Map<String, Any?>>, channelName: String) {
        val json = JSONArray(alarms.map { JSONObject(it) })
        prefs(context).edit().putString("alarms", json.toString()).putString("channel", channelName).apply()
        apply(context)
    }

    /** Поставить тревоги из сохранённого списка: после `sync`, загрузки телефона и обновления. */
    fun apply(context: Context) {
        val locations = context.getSystemService(LocationManager::class.java) ?: return
        val stored = prefs(context)
        for (id in stored.getStringSet("registered", emptySet()) ?: emptySet()) {
            locations.removeProximityAlert(pending(context, id))
        }
        val registered = mutableSetOf<String>()
        if (hasBackground(context)) {
            val fired = fired(context)
            for (alarm in alarms(context)) {
                val id = alarm.getString("id")
                // своё напоминание срабатывает один раз; покупки — каждый день, бюджет решит
                if (!alarm.optBoolean("budget") && fired.any { noteKey(it) == noteKey(id) }) continue
                try {
                    locations.addProximityAlert(alarm.getDouble("latitude"), alarm.getDouble("longitude"), alarm.optInt("radius", 150).toFloat(), -1, pending(context, id))
                    registered += id
                } catch (denied: SecurityException) {
                    // разрешение отозвали: тревоги встанут, когда его вернут и приложение откроют
                }
            }
        }
        stored.edit().putStringSet("registered", registered).apply()
        watchWifi(context, alarms(context).any { it.has("wifi") } && hasBackground(context))
    }

    /** Сработала точка или подключилась сеть: показать уведомление, если пора. */
    fun fire(context: Context, id: String) {
        val alarm = alarms(context).firstOrNull { it.getString("id") == id } ?: return
        val flutter = context.getSharedPreferences(FLUTTER, Context.MODE_PRIVATE)
        val budget = alarm.optBoolean("budget")
        if (budget) {
            val today = LocalDate.now().toString()
            if (flutter.getString(BUDGET_DAY, null) == today) return
            flutter.edit().putString(BUDGET_DAY, today).apply()
        } else {
            val fired = fired(context)
            if (fired.any { noteKey(it) == noteKey(id) }) return
            flutter.edit().putString(FIRED, JSONArray(fired + id).toString()).apply()
            // одно напоминание — одна тревога на все магазины: остальные снимаются
            val locations = context.getSystemService(LocationManager::class.java)
            for (other in alarms(context)) {
                val otherId = other.getString("id")
                if (noteKey(otherId) == noteKey(id)) locations?.removeProximityAlert(pending(context, otherId))
            }
        }
        show(context, alarm)
    }

    /** Подключился Wi-Fi: тревоги с этой сетью срабатывают, даже если GPS ещё не понял, где ты. */
    fun wifiConnected(context: Context) {
        val ssid = currentWifi(context) ?: return
        for (alarm in alarms(context)) {
            if (alarm.optString("wifi") == ssid) fire(context, alarm.getString("id"))
        }
    }

    private fun show(context: Context, alarm: JSONObject) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val name = prefs(context).getString("channel", null)?.takeIf { it.isNotEmpty() } ?: "Places"
        manager.createNotificationChannel(NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_DEFAULT))
        val payload = alarm.getString("payload")
        val open = Intent(context, MainActivity::class.java)
            .setData(Uri.parse("stowa://open?payload=${Uri.encode(payload)}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = PendingIntent.getActivity(context, payload.hashCode(), open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val body = alarm.optString("body")
        val notification = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_reminder)
            .setContentTitle(alarm.getString("title"))
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_REMINDER)
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        try {
            manager.notify(alarm.getString("id").hashCode(), notification)
        } catch (denied: SecurityException) {
            // уведомления запрещены: сработавшее всё равно снимется в приложении
        }
    }

    private fun watchWifi(context: Context, wanted: Boolean) {
        val connectivity = context.getSystemService(ConnectivityManager::class.java) ?: return
        val intent = PendingIntent.getBroadcast(
            context,
            4813,
            Intent(context, PlaceReceiver::class.java).setAction(ACTION_WIFI),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
        try {
            connectivity.unregisterNetworkCallback(intent)
        } catch (notRegistered: Exception) {
            // ещё не ставили
        }
        if (!wanted) return
        val request = NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build()
        connectivity.registerNetworkCallback(request, intent)
    }

    private fun pending(context: Context, id: String): PendingIntent = PendingIntent.getBroadcast(
        context,
        id.hashCode(),
        // адрес делает намерения разными: иначе Android сочтёт тревоги одной
        Intent(context, PlaceReceiver::class.java).setAction(ACTION_PLACE).setData(Uri.parse("stowa-place://${Uri.encode(id)}")).putExtra("id", id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
    )

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun alarms(context: Context): List<JSONObject> {
        val raw = prefs(context).getString("alarms", null) ?: return emptyList()
        val array = JSONArray(raw)
        return (0 until array.length()).map { array.getJSONObject(it) }
    }

    private fun fired(context: Context): List<String> {
        val raw = context.getSharedPreferences(FLUTTER, Context.MODE_PRIVATE).getString(FIRED, null) ?: return emptyList()
        val array = JSONArray(raw)
        return (0 until array.length()).map { array.getString(it) }
    }

    // «note:<id>@<магазин>» и «note:<id>» — одно напоминание
    private fun noteKey(id: String): String = id.substringBefore('@')
}

/** Канал `stowa/places` главного окна. */
fun registerPlaceChannel(engine: FlutterEngine, activity: Activity) {
    MethodChannel(engine.dartExecutor.binaryMessenger, "stowa/places").setMethodCallHandler { call, result ->
        when (call.method) {
            "hasBackground" -> result.success(PlaceAlarms.hasBackground(activity))
            "askBackground" -> {
                PlaceAlarms.askBackground(activity)
                result.success(null)
            }
            "currentWifi" -> result.success(PlaceAlarms.currentWifi(activity))
            "sync" -> {
                val arguments = call.arguments as? Map<*, *>
                @Suppress("UNCHECKED_CAST")
                val alarms = (arguments?.get("alarms") as? List<Map<String, Any?>>) ?: emptyList()
                PlaceAlarms.save(activity, alarms, arguments?.get("channel") as? String ?: "")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
