package app.stowa.edge

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.RectF
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Choreographer
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.ImageView
import app.stowa.MainActivity
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
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
    /** Где поставить стикер, в точках свободной части экрана; свёрнутый — размером с круг. */
    start: RectF,
    /** Высота раскрытого стикера, если помнится: свёрнутый раскроется на неё. */
    private var stickerHeight: Float?,
    /** Окно встало на новое место или поменяло вид: список стикеров пора записать. */
    private val onChanged: () -> Unit,
    /** Стикер сняли насовсем: «×», вытеснен четвёртым, заметки больше нет. */
    private val onRemoved: (EdgeSticker) -> Unit,
) {
    private val density = context.resources.displayMetrics.density
    private val engine: FlutterEngine
    private val channel: MethodChannel
    private val texture = FlutterTextureView(context)
    private val view = FlutterView(context, texture)
    private val frame: StickerFrame
    private val params: WindowManager.LayoutParams
    private var removed = false

    /**
     * Окно-призрак со снимком прежней картинки на время смены окна: стоит на старом месте,
     * пока вид Flutter спрятан, и уходит, когда Dart нарисовал кадр в новом размере (`shown`).
     * Снимок внутри самого окна не спасал: окно, которое растёт и сдвигается разом, система
     * на кадр показывает на новом месте без картинки, и круг мигал (эмулятор, 3 раскрытия из
     * 8 у правого края, 0 из 8 у левого, где окно не сдвигается; 15.11.2026). Удержание через
     * `setTransform` тоже ломалось: опоздавший кадр старого размера мелькал сплющенным кругом.
     */
    private var ghost: ImageView? = null

    /** Смена окна ждёт, пока призрак встанет на экран. */
    private var pending: (() -> Unit)? = null
    private val main = Handler(Looper.getMainLooper())
    private val uncoverLate = Runnable { uncover() }

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
                    val rect = rectOf(call.arguments)
                    remember(rect)
                    place(rect)
                    onChanged()
                    result.success(null)
                }
                // кадр в новом размере ушёл на отрисовку: через два такта он на экране и
                // призрак можно убирать; Dart слышит ответ, когда призрака уже нет
                "shown" -> afterFrames(2) { uncover { result.success(null) } }
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
            noMoveAnimation(this)
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
    private fun placement(): Map<String, Double?> {
        val area = usableArea(context, windows)
        return mapOf(
            "x" to dp(params.x - area.left).toDouble(),
            "y" to dp(params.y - area.top).toDouble(),
            "w" to dp(params.width).toDouble(),
            "h" to dp(params.height).toDouble(),
            "screenW" to dp(area.width()).toDouble(),
            "screenH" to dp(area.height()).toDouble(),
            "stickerH" to stickerHeight?.toDouble(),
        )
    }

    /** Что помнить между перезапусками: заметка, окно в точках, высота раскрытого. */
    fun state(): JSONObject {
        val area = usableArea(context, windows)
        return JSONObject()
            .put("id", noteId)
            .put("x", dp(params.x - area.left).toDouble())
            .put("y", dp(params.y - area.top).toDouble())
            .put("w", dp(params.width).toDouble())
            .put("h", dp(params.height).toDouble())
            .put("stickerH", stickerHeight?.toDouble() ?: JSONObject.NULL)
    }

    /** Конечный размер раскрытого стикера (не круга и не кадра движения) — его высоту и помним. */
    private fun remember(rect: RectF) {
        if (rect.width() > STICKER_MIN_WIDTH_DP) stickerHeight = rect.height()
    }

    /**
     * Окно — в [rect] одним шагом. Само сворачивание Dart рисует внутри окна, поэтому размер
     * меняется только на краю движения. Смена размера идёт под призраком: см. [ghost].
     */
    private fun place(rect: RectF) {
        if (removed) return
        val area = usableArea(context, windows)
        val x = area.left + px(rect.left)
        val y = area.top + px(rect.top)
        val width = px(rect.width())
        val height = px(rect.height())
        val resized = (width != params.width || height != params.height) && params.width > 0 && params.height > 0
        val apply = {
            params.x = x
            params.y = y
            params.width = width
            params.height = height
            windows.updateViewLayout(frame, params)
        }
        if (resized) underGhost(apply) else apply()
    }

    /**
     * Поставить призрака со снимком нынешней картинки на место окна и, когда он нарисован,
     * спрятать вид Flutter и сделать [apply]. Dart промолчал — через 700 мс открываем сами,
     * снимок не должен висеть.
     */
    private fun underGhost(apply: () -> Unit) {
        // прежняя смена ещё ждёт своего призрака — доделать её сразу
        swapNow()
        val shot = texture.bitmap
        if (shot == null) {
            apply()
            return
        }
        dropGhost()
        val image = ImageView(context)
        image.setImageBitmap(shot)
        val ghostParams = WindowManager.LayoutParams(
            params.width,
            params.height,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = params.x
            y = params.y
        }
        noMoveAnimation(ghostParams)
        pending = apply
        // первый кадр призрака нарисован — ещё два такта, и он на экране
        var drawn = false
        image.viewTreeObserver.addOnDrawListener {
            if (!drawn) {
                drawn = true
                afterFrames(2) { swapNow() }
            }
        }
        windows.addView(image, ghostParams)
        ghost = image
        // призрак так и не нарисовался — окно не ждёт дольше
        main.postDelayed({ swapNow() }, 120)
    }

    /** Призрак на экране: вид Flutter прячется, окно меняется под ним. */
    private fun swapNow() {
        val apply = pending ?: return
        pending = null
        if (removed) return
        texture.alpha = 0f
        apply()
        main.removeCallbacks(uncoverLate)
        main.postDelayed(uncoverLate, 700)
    }

    /** Показать вид Flutter и через два такта, когда он нарисован, убрать призрака; потом [done]. */
    private fun uncover(done: () -> Unit = {}) {
        main.removeCallbacks(uncoverLate)
        if (removed || pending != null) {
            done()
            return
        }
        texture.alpha = 1f
        val old = ghost
        if (old == null) {
            done()
            return
        }
        afterFrames(2) {
            if (ghost === old) dropGhost()
            done()
        }
    }

    private fun dropGhost() {
        ghost?.let { windows.removeView(it) }
        ghost = null
    }

    private fun afterFrames(count: Int, block: () -> Unit) {
        if (count == 0) return block()
        Choreographer.getInstance().postFrameCallback { afterFrames(count - 1, block) }
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

    /** Снять насовсем: стикер уходит и из памяти. */
    fun remove() {
        if (removed) return
        dispose()
        onRemoved(this)
        Log.d(EdgeHandle.TAG, "sticker removed")
    }

    /** Убрать окно и движок, не забывая стикер: служба останавливается, после поднимет. */
    fun dispose() {
        if (removed) return
        removed = true
        main.removeCallbacks(uncoverLate)
        pending = null
        dropGhost()
        view.detachFromFlutterEngine()
        windows.removeView(frame)
        engine.destroy()
    }

    /** Окно за пальцем, зажатое в экран; отпустил — Dart узнаёт новое место. */
    private inner class Dragger : StickerFrame.Mover {
        // границы экрана снимаются раз на перетаскивание, а не на каждый сдвиг пальца
        private var area = Rect()

        override fun start() {
            area = usableArea(context, windows)
        }

        override fun move(dx: Float, dy: Float) {
            if (removed) return
            val margin = px(8f)
            params.x = max(area.left + margin, min(params.x + dx.roundToInt(), area.right - margin - params.width))
            params.y = max(area.top + margin, min(params.y + dy.roundToInt(), area.bottom - margin - params.height))
            windows.updateViewLayout(frame, params)
        }

        override fun end() {
            val area = usableArea(context, windows)
            channel.invokeMethod("moved", mapOf("x" to dp(params.x - area.left).toDouble(), "y" to dp(params.y - area.top).toDouble()))
            onChanged()
        }
    }

    companion object {
        /** Окно шире этого — раскрытый стикер (236), уже — круг (52) или середина движения. */
        private const val STICKER_MIN_WIDTH_DP = 200f

        /** `WindowManager.LayoutParams.PRIVATE_FLAG_NO_MOVE_ANIMATION`, скрытый флаг окна. */
        private const val NO_MOVE_ANIMATION = 1 shl 6

        /**
         * Без системной анимации сдвига. Android плавно ведёт сдвинутое окно к новому месту,
         * а рисунок Flutter в нём уже стоит в конечной точке: круг после сворачивания ехал
         * через пол-экрана к своему месту (видео с телефона, 15.11.2026). Флаг скрытый: не
         * вышло — окно остаётся с анимацией, как было.
         */
        fun noMoveAnimation(params: WindowManager.LayoutParams) {
            try {
                val field = WindowManager.LayoutParams::class.java.getField("privateFlags")
                field.setInt(params, field.getInt(params) or NO_MOVE_ANIMATION)
            } catch (error: Throwable) {
                Log.w(EdgeHandle.TAG, "no-move flag: $error")
            }
        }

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
