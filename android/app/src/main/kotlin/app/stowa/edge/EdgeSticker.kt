package app.stowa.edge

import android.animation.ValueAnimator
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.RectF
import android.net.Uri
import android.os.Build
import android.util.Log
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.PathInterpolator
import app.stowa.MainActivity
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Стикер поверх приложений: окно со своим движком из общей группы (`stickerMain`, аргумент —
 * id заметки). Окно здесь двигается и меняет размер, а куда — решает Dart (канал
 * `stowa/sticker`, координаты в точках от левого верхнего угла свободной части экрана).
 * Окно всегда ровно по видимому: свёрнутое — размером с круг, касания мимо уходят приложению.
 */
class EdgeSticker(
    private val context: Context,
    private val windows: WindowManager,
    group: FlutterEngineGroup,
    val noteId: String,
    /** Где поставить новый стикер, в точках свободной части экрана. */
    start: RectF,
    private val onRemoved: (EdgeSticker) -> Unit,
) {
    private val density = context.resources.displayMetrics.density
    private val engine: FlutterEngine
    private val channel: MethodChannel
    private val view = FlutterView(context, FlutterTextureView(context))
    private val frame: StickerFrame
    private val params: WindowManager.LayoutParams
    private var morph: ValueAnimator? = null
    private var removed = false

    init {
        val bundle = FlutterInjector.instance().flutterLoader().findAppBundlePath()
        engine = group.createAndRunEngine(
            FlutterEngineGroup.Options(context)
                .setDartEntrypoint(DartExecutor.DartEntrypoint(bundle, "stickerMain"))
                .setDartEntrypointArgs(listOf(noteId)),
        )
        engine.platformChannel.setPlatformMessageHandler(EdgePlatform(context, { view }, {}))
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "stowa/sticker")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "placement" -> result.success(placement())
                "frame" -> {
                    morph?.cancel()
                    place(rectOf(call.arguments))
                    result.success(null)
                }
                "morph" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as Map<String, Number>
                    morphTo(rectOf(args), args["ms"]!!.toLong()) { result.success(null) }
                }
                "remove" -> {
                    remove()
                    result.success(null)
                }
                "openApp" -> {
                    val intent = Intent(context, MainActivity::class.java)
                        .setAction(Intent.ACTION_VIEW)
                        .setData(Uri.parse("stowa://open?payload=${Uri.encode("note:$noteId")}"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    context.startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        frame = StickerFrame(context, Dragger())
        frame.addView(view, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        val area = usableArea(context, windows)
        params = WindowManager.LayoutParams(
            px(start.width()),
            px(start.height()),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = area.left + px(start.left)
            y = area.top + px(start.top)
            title = "Stowa sticker"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) fitInsetsTypes = 0
        }
        // сперва движок, потом окно — как у полки
        view.attachToFlutterEngine(engine)
        windows.addView(frame, params)
        engine.lifecycleChannel.appIsResumed()
        Log.d(EdgeHandle.TAG, "sticker shown")
    }

    private fun px(dp: Float) = (dp * density).roundToInt()

    private fun dp(px: Int) = px / density

    @Suppress("UNCHECKED_CAST")
    private fun rectOf(raw: Any?): RectF {
        val map = raw as Map<String, Number>
        val x = map["x"]!!.toFloat()
        val y = map["y"]!!.toFloat()
        return RectF(x, y, x + map["w"]!!.toFloat(), y + map["h"]!!.toFloat())
    }

    /** Окно и свободная часть экрана в точках, для Dart. */
    private fun placement(): Map<String, Double> {
        val area = usableArea(context, windows)
        return mapOf(
            "x" to dp(params.x - area.left).toDouble(),
            "y" to dp(params.y - area.top).toDouble(),
            "w" to dp(params.width).toDouble(),
            "h" to dp(params.height).toDouble(),
            "screenW" to dp(area.width()).toDouble(),
            "screenH" to dp(area.height()).toDouble(),
        )
    }

    private fun place(rect: RectF) {
        if (removed) return
        val area = usableArea(context, windows)
        params.x = area.left + px(rect.left)
        params.y = area.top + px(rect.top)
        params.width = px(rect.width())
        params.height = px(rect.height())
        windows.updateViewLayout(frame, params)
    }

    /** Окно перетекает в [target] по кривой emphasized; Dart рисует стикер по размеру окна. */
    private fun morphTo(target: RectF, ms: Long, done: () -> Unit) {
        morph?.cancel()
        if (ms <= 0) {
            place(target)
            return done()
        }
        val area = usableArea(context, windows)
        val from = RectF(dp(params.x - area.left), dp(params.y - area.top), 0f, 0f).apply {
            right = left + dp(params.width)
            bottom = top + dp(params.height)
        }
        morph = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = ms
            interpolator = EMPHASIZED
            addUpdateListener { animator ->
                val t = animator.animatedValue as Float
                fun lerp(a: Float, b: Float) = a + (b - a) * t
                place(RectF(lerp(from.left, target.left), lerp(from.top, target.top), lerp(from.right, target.right), lerp(from.bottom, target.bottom)))
            }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                // и прерванное, и законченное движение отвечает: Dart ждёт ответа
                private var answered = false

                override fun onAnimationEnd(animation: android.animation.Animator) {
                    if (answered) return
                    answered = true
                    place(target)
                    done()
                }
            })
            start()
        }
    }

    /** Нижний край окна в точках свободной части экрана: под ним встанет следующий стикер. */
    fun bottomDp(): Float = dp(params.y + params.height - usableArea(context, windows).top)

    /** Поворот, складной экран: окно остаётся внутри, Dart узнаёт новый экран. */
    fun screenChanged() {
        if (removed) return
        val area = usableArea(context, windows)
        val margin = px(8f)
        params.x = max(area.left + margin, min(params.x, area.right - margin - params.width))
        params.y = max(area.top + margin, min(params.y, area.bottom - margin - params.height))
        windows.updateViewLayout(frame, params)
        channel.invokeMethod("screen", placement())
    }

    fun remove() {
        if (removed) return
        removed = true
        morph?.cancel()
        view.detachFromFlutterEngine()
        windows.removeView(frame)
        engine.destroy()
        onRemoved(this)
        Log.d(EdgeHandle.TAG, "sticker removed")
    }

    /** Окно за пальцем, зажатое в экран; отпустил — Dart узнаёт новое место. */
    private inner class Dragger : StickerFrame.Mover {
        override fun start() {
            morph?.cancel()
        }

        override fun move(dx: Float, dy: Float) {
            if (removed) return
            val area = usableArea(context, windows)
            val margin = px(8f)
            params.x = max(area.left + margin, min(params.x + dx.roundToInt(), area.right - margin - params.width))
            params.y = max(area.top + margin, min(params.y + dy.roundToInt(), area.bottom - margin - params.height))
            windows.updateViewLayout(frame, params)
        }

        override fun end() {
            val area = usableArea(context, windows)
            channel.invokeMethod("moved", mapOf("x" to dp(params.x - area.left).toDouble(), "y" to dp(params.y - area.top).toDouble()))
        }
    }

    companion object {
        private val EMPHASIZED = PathInterpolator(0.2f, 0f, 0f, 1f)

        /** Экран без строки состояния, панели навигации и выреза, в пикселях. */
        fun usableArea(context: Context, windows: WindowManager): Rect {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val metrics = windows.currentWindowMetrics
                val insets = metrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
                val bounds = metrics.bounds
                return Rect(bounds.left + insets.left, bounds.top + insets.top, bounds.right - insets.right, bounds.bottom - insets.bottom)
            }
            val display = context.resources.displayMetrics
            val res = context.resources
            fun dimension(name: String): Int {
                val id = res.getIdentifier(name, "dimen", "android")
                return if (id > 0) res.getDimensionPixelSize(id) else 0
            }
            return Rect(0, dimension("status_bar_height"), display.widthPixels, display.heightPixels - dimension("navigation_bar_height"))
        }
    }
}
