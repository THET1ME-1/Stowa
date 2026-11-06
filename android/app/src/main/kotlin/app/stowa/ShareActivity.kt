package app.stowa

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine

// «Поделиться»: прозрачное окно с одним листом поверх приложения, из которого делятся
class ShareActivity : FlutterActivity() {
    override fun getDartEntrypointFunctionName(): String = "shareMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    // окну тоже нужно знать, доступно ли хранилище в памяти устройства
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerVaultChannel(flutterEngine, this)
    }
}
