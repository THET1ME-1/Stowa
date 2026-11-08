package app.stowa

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * Свой ролик глазами системы: длина, размер и кадры через `MediaMetadataRetriever`.
 * Работа идёт в своём потоке: кадр длинного ролика достаётся заметное время.
 * Канал есть в главном окне и в окне «Поделиться»; в фоновом движке его нет.
 */
fun registerMediaChannel(engine: FlutterEngine) {
    val worker = Executors.newSingleThreadExecutor()
    val main = Handler(Looper.getMainLooper())
    MethodChannel(engine.dartExecutor.binaryMessenger, "stowa/media").setMethodCallHandler { call, result ->
        when (call.method) {
            "probe" -> {
                val path = call.argument<String>("path")!!
                worker.execute {
                    val info = runCatching { probe(path) }.getOrNull()
                    main.post { result.success(info) }
                }
            }
            "frames" -> {
                val path = call.argument<String>("path")!!
                val times = call.argument<List<Number>>("ms")!!.map { it.toLong() }
                val outs = call.argument<List<String>>("outs")!!
                val maxSide = call.argument<Int>("maxSide") ?: 720
                worker.execute {
                    val written = runCatching { frames(path, times, outs, maxSide) }.getOrDefault(times.map { false })
                    main.post { result.success(written) }
                }
            }
            else -> result.notImplemented()
        }
    }
}

private fun probe(path: String): Map<String, Any>? {
    val retriever = MediaMetadataRetriever()
    try {
        retriever.setDataSource(path)
        val ms = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: return null
        var width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
        var height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
        // снятое вертикально хранится лёжа с поворотом: размер — как видит человек
        val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
        if (rotation == 90 || rotation == 270) width = height.also { height = width }
        return mapOf("ms" to ms, "width" to width, "height" to height)
    } finally {
        retriever.release()
    }
}

// кадры ближайшие к ключевым: точный кадр в середине длинного ролика декодер ищет секундами
private fun frames(path: String, times: List<Long>, outs: List<String>, maxSide: Int): List<Boolean> {
    val retriever = MediaMetadataRetriever()
    try {
        retriever.setDataSource(path)
        return times.mapIndexed { index, ms ->
            val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                retriever.getScaledFrameAtTime(ms * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, maxSide, maxSide)
            } else {
                retriever.getFrameAtTime(ms * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            }
            if (bitmap == null) return@mapIndexed false
            val out = File(outs[index])
            out.parentFile?.mkdirs()
            FileOutputStream(out).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 82, it) }
            bitmap.recycle()
            true
        }
    } finally {
        retriever.release()
    }
}
