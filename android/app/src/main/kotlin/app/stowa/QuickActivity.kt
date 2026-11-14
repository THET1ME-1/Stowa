package app.stowa

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Окно виджета: прозрачное, одна строка поверх рабочего стола, главная не открывается.
 * Виджет зовёт его адресом stowa://compose (строка с клавиатурой), stowa://voice
 * (сразу запись) или stowa://camera (снимок), полка «Под рукой» — stowa://attach (лоток)
 * или stowa://voice с `?text=` набранного. Dart спрашивает кнопку через `initial`, текст — `text`.
 */
class QuickActivity : FlutterActivity() {
    private var window: MethodChannel? = null
    private var pending: String? = null

    /** Набранное в полке «Под рукой», которая передала дело сюда (stowa://attach?text=…). */
    private var pendingText: String? = null

    override fun getDartEntrypointFunctionName(): String = "quickMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    // камера и выбор файла уводят окно в фон: Dart узнаёт заранее и не закрывает его как брошенное.
    // Плагин камеры зовёт это с рабочего потока, а канал живёт только на главном
    @Deprecated("startActivityForResult зовут плагины; переопределение ловит их все разом")
    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        if (requestCode >= 0) runOnUiThread { window?.invokeMethod("ownWindow", null) }
        @Suppress("DEPRECATION")
        super.startActivityForResult(intent, requestCode, options)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val address = intent?.data?.takeIf { it.scheme == "stowa" }
        pending = address?.host
        pendingText = address?.getQueryParameter("text")
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerVaultChannel(flutterEngine, this)
        registerMediaChannel(flutterEngine)
        window = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stowa/window")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stowa/launch").setMethodCallHandler { call, result ->
            when (call.method) {
                "initial" -> {
                    result.success(pending)
                    pending = null
                }
                "text" -> {
                    result.success(pendingText)
                    pendingText = null
                }
                "openNote" -> {
                    openInApp(call.arguments as String)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // заметка, найденная строкой, открывается в самом приложении тем же адресом, что уведомление по месту
    private fun openInApp(id: String) {
        val intent = Intent(this, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW)
            .setData(Uri.parse("stowa://open?payload=${Uri.encode("note:$id")}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        startActivity(intent)
    }
}
