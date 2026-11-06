package app.stowa

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Главное окно. Виджет рабочего стола открывает его адресом stowa://compose
 * (строка с клавиатурой) или stowa://voice (сразу запись). Dart спрашивает
 * `initial` при запуске, а касания по живому приложению получает через `open`.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pending = actionOf(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerVaultChannel(flutterEngine, this)
        registerPlaceChannel(flutterEngine, this)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stowa/launch").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "initial") {
                    result.success(pending)
                    pending = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val action = actionOf(intent) ?: return
        channel?.invokeMethod("open", action)
    }

    // stowa://compose, stowa://voice — виджет; stowa://open?payload=note:… — уведомление по месту
    private fun actionOf(intent: Intent?): String? {
        val data = intent?.data?.takeIf { it.scheme == "stowa" } ?: return null
        if (data.host == "open") return data.getQueryParameter("payload")?.let { "open:$it" }
        return data.host
    }
}
