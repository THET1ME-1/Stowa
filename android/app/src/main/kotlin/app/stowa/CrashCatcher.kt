package app.stowa

import android.content.Context
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

/**
 * Падения на стороне Android: то, что случилось в Kotlin и плагинах и до Dart не дошло.
 *
 * Сам ничего не отправляет: кладёт запись в ту же очередь `files/crashes`, что и Dart
 * (`lib/services/crash_reporter.dart`), а уходит она при следующем запуске. В записи вид
 * ошибки и место в коде; текста исключения нет — в нём бывают пути и куски заметок.
 */
object CrashCatcher {
    private const val FLUTTER = "FlutterSharedPreferences"
    private const val ENABLED = "flutter.crash_reports"
    private const val MOST_WAITING = 20
    private const val MOST_FRAMES = 50

    fun install(context: Context) {
        // в отладке ошибки и так в консоли; пробная profile-сборка ловит, как настоящая
        if (BuildConfig.BUILD_TYPE == "debug") return
        val folder = File(context.filesDir, "crashes")
        val about = runCatching { describe(context) }.getOrNull() ?: return
        runCatching { writeAbout(folder, about) }
        val before = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            runCatching {
                val prefs = context.getSharedPreferences(FLUTTER, Context.MODE_PRIVATE)
                if (prefs.getBoolean(ENABLED, true)) write(folder, about, error)
            }
            // дальше как обычно: система закрывает приложение
            before?.uncaughtException(thread, error)
        }
    }

    /** Версия приложения и телефон: этим же файлом Dart подписывает свои записи. */
    private fun describe(context: Context): JSONObject {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        // сборка под отдельную архитектуру прибавляет к номеру тысячи: в отчёте номер из pubspec
        val build = info.longVersionCode % 1000
        return JSONObject()
            .put("release", "${context.packageName}@${info.versionName}+$build")
            .put("environment", if (BuildConfig.BUILD_TYPE == "release") "production" else BuildConfig.BUILD_TYPE)
            .put("os", Build.VERSION.RELEASE)
            .put("model", Build.MODEL)
            .put("maker", Build.MANUFACTURER)
    }

    private fun writeAbout(folder: File, about: JSONObject) {
        folder.mkdirs()
        val file = File(folder, "about.json")
        val text = about.toString()
        if (!file.exists() || file.readText() != text) file.writeText(text)
    }

    private fun write(folder: File, about: JSONObject, error: Throwable) {
        // обёртки вроде RuntimeException называют только место, где ошибку переложили: нужна первая
        val wrappers = mutableListOf<String>()
        var cause = error
        while (cause.cause != null && cause.cause !== cause && wrappers.size < 8) {
            wrappers += cause.javaClass.name
            cause = cause.cause!!
        }
        val frames = JSONArray()
        for (frame in cause.stackTrace.take(MOST_FRAMES)) {
            val line = JSONObject().put("file", frame.className).put("function", frame.methodName)
            if (frame.lineNumber > 0) line.put("line", frame.lineNumber)
            frames.put(line)
        }
        val id = UUID.randomUUID().toString().replace("-", "")
        val record = JSONObject()
            .put("id", id)
            .put("at", Instant.now().truncatedTo(ChronoUnit.MILLIS).toString())
            .put("platform", "java")
            .put("type", cause.javaClass.name)
            .put("frames", frames)
            .put("window", "android")
            .put("fatal", true)
        if (wrappers.isNotEmpty()) record.put("message", "wrapped in ${wrappers.joinToString()}")
        for (key in about.keys()) record.put(key, about.get(key))

        folder.mkdirs()
        // место под новую запись: самые старые уходят
        val waiting = folder.listFiles { file -> file.name.endsWith(".json") && file.name != "about.json" }.orEmpty().sortedBy { it.name }
        for (old in waiting.take((waiting.size - MOST_WAITING + 1).coerceAtLeast(0))) old.delete()
        File(folder, "${System.currentTimeMillis()}-$id.json").writeText(record.toString())
    }
}
