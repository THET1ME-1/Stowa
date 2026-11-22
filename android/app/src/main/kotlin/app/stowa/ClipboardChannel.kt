package app.stowa

import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Картинка в буфере Android: «Копировать изображение» в Chrome, «Копировать» в галерее.
 * Flutter берёт из буфера только текст: у картинки он пытается достать текст по её адресу,
 * не может — и «Вставить» молча ничего не делает. Здесь картинку отдаём байтами.
 *
 * `hasImage` смотрит только описание буфера: содержимое не читается, и Android 12+ не
 * показывает «Вставлено из буфера». `image` читает картинку — только по нажатию «Вставить».
 * Канал есть в окнах со строкой: главное, «Поделиться», виджет.
 */
fun registerClipboardChannel(engine: FlutterEngine, context: Context) {
    val worker = Executors.newSingleThreadExecutor()
    val main = Handler(Looper.getMainLooper())
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    MethodChannel(engine.dartExecutor.binaryMessenger, "stowa/clipboard").setMethodCallHandler { call, result ->
        when (call.method) {
            "hasImage" -> result.success(runCatching { hasImage(clipboard) }.getOrDefault(false))
            "image" -> {
                // буфер читается в главном потоке (так требует Android), файл — в своём
                val clip = runCatching { clipboard.primaryClip }.getOrNull()
                if (clip == null) {
                    result.success(null)
                } else {
                    worker.execute {
                        val image = runCatching { readImage(context, clip) }.getOrNull()
                        main.post { result.success(image) }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }
}

private fun hasImage(clipboard: ClipboardManager): Boolean {
    if (!clipboard.hasPrimaryClip()) return false
    val description = clipboard.primaryClipDescription ?: return false
    if (description.hasMimeType("text/plain") || description.hasMimeType("text/html")) return false
    return (0 until description.mimeTypeCount).any { description.getMimeType(it).startsWith("image/") }
}

/** Первая картинка буфера; есть в нём текст — это вставка текста, картинку не берём. */
private fun readImage(context: Context, clip: android.content.ClipData): Map<String, Any>? {
    val resolver = context.contentResolver
    for (index in 0 until clip.itemCount) {
        val item = clip.getItemAt(index)
        if (!item.text.isNullOrBlank()) return null
        val uri = item.uri ?: continue
        if (uri.scheme != "content" && uri.scheme != "file") continue
        val mime = resolver.getType(uri) ?: clip.description.let { description ->
            (0 until description.mimeTypeCount).map { description.getMimeType(it) }.firstOrNull { it.startsWith("image/") }
        } ?: continue
        if (!mime.startsWith("image/")) continue
        val bytes = resolver.openInputStream(uri)?.use { it.readBytes() } ?: continue
        if (bytes.isEmpty()) continue
        return mapOf("mime" to mime, "name" to (displayName(context, uri) ?: ""), "bytes" to bytes)
    }
    return null
}

private fun displayName(context: Context, uri: Uri): String? = runCatching {
    context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
        if (cursor.moveToFirst()) cursor.getString(0) else null
    }
}.getOrNull()
