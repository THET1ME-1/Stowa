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
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.embedding.engine.FlutterEngine
import app.stowa.edge.EdgeNearby
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.util.concurrent.TimeUnit

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

    // последняя сеть, которую видели: приход — смена её на сеть дома или работы
    private const val LAST_SSID = "last_ssid"
    private const val WIFI_CHECK = "stowa-wifi-check"

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
        val inside = mutableSetOf<String>()
        if (hasBackground(context)) {
            val fired = fired(context)
            val here = lastKnown(locations)
            for (alarm in alarms(context)) {
                val id = alarm.getString("id")
                // своё напоминание срабатывает один раз; покупки — каждый день, бюджет решит
                if (!alarm.optBoolean("budget") && fired.any { noteKey(it) == noteKey(id) }) continue
                val latitude = alarm.getDouble("latitude")
                val longitude = alarm.getDouble("longitude")
                val radius = alarm.optInt("radius", 150).toFloat()
                // уже внутри круга — «когда буду здесь» значит в следующий приход: ждём выхода
                if (here != null && distance(here, latitude, longitude) < radius) inside += id
                try {
                    locations.addProximityAlert(latitude, longitude, radius, -1, pending(context, id))
                    registered += id
                } catch (denied: SecurityException) {
                    // разрешение отозвали: тревоги встанут, когда его вернут и приложение откроют
                }
            }
        }
        stored.edit().putStringSet("registered", registered).putStringSet("inside", inside).apply()
        // новое напоминание «дома», поставленное дома, ждёт следующего прихода, а не звенит сразу;
        // а вне сети дома следующее подключение к ней — приход
        stored.edit().putString(LAST_SSID, currentWifi(context) ?: "").apply()
        val wanted = wifiTargets(context).isNotEmpty() && hasBackground(context)
        planWifiCheck(context, wanted)
        if (wanted) armWifi(context)
    }

    /** Вход в круг: тревога, поставленная внутри него, ждёт сперва выхода. */
    fun entered(context: Context, id: String) {
        val inside = prefs(context).getStringSet("inside", emptySet()) ?: emptySet()
        if (id in inside) return
        fire(context, id)
    }

    /**
     * Выход из круга: теперь следующий вход — настоящий приход. Пока телефон в сети дома, слежения
     * за сетью нет, а об уходе из неё Android не сообщает: выход из круга дома и ставит его снова.
     */
    fun left(context: Context, id: String) {
        val stored = prefs(context)
        val inside = stored.getStringSet("inside", emptySet()) ?: emptySet()
        if (id in inside) stored.edit().putStringSet("inside", inside - id).apply()
        val alarm = alarms(context).firstOrNull { it.getString("id") == id } ?: return
        if (alarm.optString("wifi").isEmpty()) return
        stored.edit().putString(LAST_SSID, currentWifi(context) ?: "").apply()
        if (hasBackground(context)) armWifi(context)
    }

    /**
     * Сеть сменилась или пора проверить: приход — это смена сети на сеть дома или работы.
     * Ту же сеть, о которой Android сообщает сразу после постановки слежения, приходом не считаем.
     * Зовут приёмник (слежение сработало) и проверка раз в 15 минут.
     */
    fun checkWifi(context: Context) {
        val stored = prefs(context)
        val ssid = currentWifi(context) ?: ""
        val last = stored.getString(LAST_SSID, "") ?: ""
        if (ssid != last) {
            stored.edit().putString(LAST_SSID, ssid).apply()
            if (ssid.isNotEmpty()) {
                for (alarm in alarms(context)) {
                    if (alarm.optString("wifi") == ssid) fire(context, alarm.getString("id"))
                }
            }
        }
        if (wifiTargets(context).isNotEmpty() && hasBackground(context)) armWifi(context)
    }

    // сети, при подключении к которым есть что напомнить: сработавшее ждёт только, пока его снимет приложение
    private fun wifiTargets(context: Context): Set<String> {
        val fired = fired(context).map(::noteKey).toSet()
        return alarms(context)
            .filter { it.optBoolean("budget") || noteKey(it.getString("id")) !in fired }
            .mapNotNull { it.optString("wifi").takeIf { wifi -> wifi.isNotEmpty() } }
            .toSet()
    }

    private fun lastKnown(locations: LocationManager): android.location.Location? = try {
        listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
            .mapNotNull { provider -> runCatching { locations.getLastKnownLocation(provider) }.getOrNull() }
            .maxByOrNull { it.time }
    } catch (denied: SecurityException) {
        null
    }

    private fun distance(from: android.location.Location, latitude: Double, longitude: Double): Float {
        val result = FloatArray(1)
        android.location.Location.distanceBetween(from.latitude, from.longitude, latitude, longitude, result)
        return result[0]
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
            // полка «Под рукой» покажет заметку в «Рядом», корешки мягко запульсируют
            if (noteKey(id).startsWith("note:")) EdgeNearby.record(context, noteKey(id).removePrefix("note:"))
            // одно напоминание — одна тревога на все магазины: остальные снимаются
            val locations = context.getSystemService(LocationManager::class.java)
            for (other in alarms(context)) {
                val otherId = other.getString("id")
                if (noteKey(otherId) == noteKey(id)) locations?.removeProximityAlert(pending(context, otherId))
            }
        }
        show(context, alarm)
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

    /**
     * Слежение за подключением к Wi-Fi через `PendingIntent` одноразовое: система шлёт сигнал один раз
     * и через несколько секунд снимает запрос (`ConnectivityService.onSendFinished`). Ставим его, только
     * пока телефон не в нужной сети, — иначе каждая постановка тут же давала бы эхо по кругу.
     */
    private fun armWifi(context: Context) {
        val ssid = currentWifi(context)
        if (ssid != null && ssid in wifiTargets(context)) return
        val connectivity = context.getSystemService(ConnectivityManager::class.java) ?: return
        val request = NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build()
        try {
            connectivity.registerNetworkCallback(request, wifiIntent(context))
        } catch (failed: Exception) {
            // лимит запросов или нет разрешения: проверка раз в 15 минут поймает приход позже
        }
    }

    private fun wifiIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        4813,
        Intent(context, PlaceReceiver::class.java).setAction(ACTION_WIFI),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
    )

    /** Проверка сети раз в 15 минут: страховка, если приход пришёлся на время без слежения. */
    private fun planWifiCheck(context: Context, wanted: Boolean) {
        val work = WorkManager.getInstance(context)
        if (!wanted) {
            work.cancelUniqueWork(WIFI_CHECK)
            return
        }
        work.enqueueUniquePeriodicWork(WIFI_CHECK, ExistingPeriodicWorkPolicy.KEEP, PeriodicWorkRequestBuilder<WifiCheckWorker>(15, TimeUnit.MINUTES).build())
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

/** Раз в 15 минут: сменилась ли сеть и стоит ли слежение. */
class WifiCheckWorker(context: Context, parameters: WorkerParameters) : Worker(context, parameters) {
    override fun doWork(): Result {
        PlaceAlarms.checkWifi(applicationContext)
        return Result.success()
    }
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
