package app.stowa.edge

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Канал `stowa/edge` главного окна: право «Поверх других приложений», включить и выключить
 * корешки, перечитать их настройки. Полка говорит со службой по своему каналу в [EdgePanel].
 */
fun registerEdgeChannel(engine: FlutterEngine, activity: Activity) {
    MethodChannel(engine.dartExecutor.binaryMessenger, "stowa/edge").setMethodCallHandler { call, result ->
        when (call.method) {
            "canDraw" -> result.success(Settings.canDrawOverlays(activity))
            "askDraw" -> {
                // свой экран системы для одного приложения; вернувшись, Dart спросит canDraw заново
                activity.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${activity.packageName}")))
                result.success(null)
            }
            "start" -> {
                EdgeService.start(activity)
                result.success(null)
            }
            "stop" -> {
                EdgeService.stop(activity)
                result.success(null)
            }
            "apply" -> {
                EdgeService.apply(activity)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
