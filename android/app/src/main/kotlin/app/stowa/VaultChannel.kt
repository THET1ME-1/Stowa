package app.stowa

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Хранилище в памяти устройства: с Android 11 — «Доступ ко всем файлам», как у Obsidian,
 * раньше — обычная запись в память. Dart спрашивает `hasAllFiles` и просит `askAllFiles`,
 * ответ узнаёт при возврате в приложение.
 */
fun registerVaultChannel(engine: FlutterEngine, activity: Activity) {
    MethodChannel(engine.dartExecutor.binaryMessenger, "stowa/vault").setMethodCallHandler { call, result ->
        when (call.method) {
            "hasAllFiles" -> result.success(hasAllFiles(activity))
            "askAllFiles" -> {
                askAllFiles(activity)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}

private fun hasAllFiles(activity: Activity): Boolean =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        Environment.isExternalStorageManager()
    } else {
        activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
    }

private fun askAllFiles(activity: Activity) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        val own = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:${activity.packageName}"))
        try {
            activity.startActivity(own)
        } catch (missing: Exception) {
            // у части прошивок нет экрана для одного приложения — общий список
            activity.startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
        }
    } else {
        activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE, Manifest.permission.READ_EXTERNAL_STORAGE), 4801)
    }
}
