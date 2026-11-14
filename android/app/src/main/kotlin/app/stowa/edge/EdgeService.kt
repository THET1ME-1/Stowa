package app.stowa.edge

import android.animation.ValueAnimator
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.graphics.PointF
import android.graphics.RectF
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.view.animation.PathInterpolator
import io.flutter.embedding.engine.FlutterEngineGroup

/**
 * «Под рукой»: хозяин окон поверх других приложений — корешков у края и полки.
 * Обычная служба, без уведомления: процесс с видимыми корешками Android держит как
 * «заметный» (has-overlay-ui), убитый — поднимает службу сам (эмулятор 14.11.2026).
 * Без права «Поверх других приложений» сразу останавливается.
 */
class EdgeService : Service() {
    private lateinit var windows: WindowManager
    private lateinit var panel: EdgePanel
    private var handle: EdgeHandle? = null
    private var handleParams: WindowManager.LayoutParams? = null
    private var prefs: EdgePrefs? = null
    private var move: ValueAnimator? = null
    private var leaving = false

    /** Движки стикеров из одной группы: каждый следующий почти бесплатен. */
    private lateinit var stickerEngines: FlutterEngineGroup
    private val stickers = mutableListOf<EdgeSticker>()

    override fun onCreate() {
        super.onCreate()
        windows = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        panel = EdgePanel(
            this,
            windows,
            onSpines = { spines -> handle?.spines = spines },
            onShown = ::spinesAway,
            onClosing = ::spinesBack,
            onApply = { applyPrefs(animated = true) },
            onStop = ::hideHandle,
            onPinSticker = ::pinSticker,
        )
        stickerEngines = FlutterEngineGroup(this)
    }

    /**
     * Стикер заметки: уже висит — новый не заводится; четвёртый снимает самый старый.
     * Принесли карточку — встаёт там ([at]); кнопкой — у края корешков, под висящими.
     */
    private fun pinSticker(noteId: String, at: PointF?) {
        if (stickers.any { it.noteId == noteId }) return
        if (stickers.size >= MAX_STICKERS) stickers.first().remove()
        if (at != null) {
            val start = RectF(at.x, at.y, at.x + STICKER_WIDTH_DP, at.y + STICKER_START_HEIGHT_DP)
            stickers += EdgeSticker(this, windows, stickerEngines, noteId, start) { gone -> stickers.remove(gone) }
            return
        }
        val area = EdgeSticker.usableArea(this, windows)
        val width = area.width() / density()
        val height = area.height() / density()
        // у края корешков стикер отступает на их ширину с полосой касания: круг не закрывает корешки
        val settings = prefs ?: EdgePrefs.read(this)
        val gap = STICKER_MARGIN_DP + settings.shelfWidthDp + EdgePrefs.TOUCH_EXTRA_DP
        val left = if (settings.rightSide) width - gap - STICKER_WIDTH_DP else gap
        // под нижним из висящих, с зазором; внизу места нет — лесенкой от верха
        val first = height * 0.16f
        val below = stickers.maxOfOrNull { it.bottomDp() }?.plus(STICKER_GAP_DP) ?: first
        val top = if (below + STICKER_START_HEIGHT_DP <= height - STICKER_MARGIN_DP) below else first + 28f * stickers.size
        val start = RectF(left, top, left + STICKER_WIDTH_DP, top + STICKER_START_HEIGHT_DP)
        stickers += EdgeSticker(this, windows, stickerEngines, noteId, start) { gone -> stickers.remove(gone) }
    }

    /** Полка выезжает: корешки уходят за свой край, 200 мс, emphasizedAccelerate. */
    private fun spinesAway() {
        val view = handle ?: return
        val settings = prefs ?: return
        if (leaving) return
        view.animate().translationX(outside(view, settings)).setDuration(200).setInterpolator(ACCELERATE).start()
    }

    /** Полка уезжает: корешки выезжают обратно, 350 мс, emphasizedDecelerate. */
    private fun spinesBack() {
        val view = handle ?: return
        if (leaving || view.translationX == 0f) return
        view.animate().translationX(0f).setDuration(350).setInterpolator(DECELERATE).start()
    }

    private val gestures = object : EdgeHandle.Gestures {
        override fun onTap() = panel.open()

        override fun onDragStart() = panel.dragStart()

        override fun onDrag(distanceDp: Float) = panel.drag(distanceDp)

        override fun onDragEnd(velocityDp: Float) = panel.dragEnd(velocityDp)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!Settings.canDrawOverlays(this)) {
            Log.d(EdgeHandle.TAG, "no overlay permission")
            stopSelf()
            return START_NOT_STICKY
        }
        when (intent?.action) {
            ACTION_STOP -> {
                hideHandle()
                return START_NOT_STICKY
            }
            ACTION_APPLY -> applyPrefs(animated = true)
            else -> if (handle == null) showHandle()
        }
        // движок полки — сразу и на всё время службы. Impeller (OpenGL) не рисует в окне поверх,
        // если движок заведён, пока свёрнутое главное окно держит свой: кадр так и не появлялся
        // (эмулятор 14.11.2026). Заведённый при запуске службы — рисует и потом, при свёрнутом
        panel.warmUp()
        return START_STICKY
    }

    private fun density() = resources.displayMetrics.density

    private fun screenHeightPx(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) windows.currentWindowMetrics.bounds.height() else resources.displayMetrics.heightPixels

    /** Окно корешков по настройкам: размер, край, место по высоте. */
    private fun paramsFor(settings: EdgePrefs): WindowManager.LayoutParams {
        val density = density()
        val top = settings.topDp(screenHeightPx() / density)
        return WindowManager.LayoutParams(
            ((settings.shelfWidthDp + EdgePrefs.TOUCH_EXTRA_DP) * density).toInt(),
            (settings.shelfHeightDp * density).toInt(),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or (if (settings.rightSide) Gravity.END else Gravity.START)
            y = (top * density).toInt()
            title = "Stowa edge"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
    }

    private fun showHandle() {
        val settings = EdgePrefs.read(this)
        val view = EdgeHandle(this, gestures)
        view.apply(settings)
        val params = paramsFor(settings)
        // выезжает из-за своего края, 350 мс, emphasizedDecelerate
        view.translationX = outside(view, settings)
        windows.addView(view, params)
        view.animate().translationX(0f).setDuration(350).setInterpolator(DECELERATE).start()
        handle = view
        handleParams = params
        prefs = settings
        Log.d(EdgeHandle.TAG, "handle shown")
    }

    /** Сдвиг, при котором корешки целиком за своим краем. */
    private fun outside(view: EdgeHandle, settings: EdgePrefs): Float {
        val width = (settings.shelfWidthDp + EdgePrefs.TOUCH_EXTRA_DP) * density()
        return if (settings.rightSide) width else -width
    }

    /** Настройки поменялись: место, размер и заметность едут плавно; новый край — уехать и выехать. */
    private fun applyPrefs(animated: Boolean) {
        val view = handle ?: return showHandle()
        val old = prefs ?: return
        val next = EdgePrefs.read(this)
        prefs = next
        if (old.rightSide != next.rightSide) {
            view.animate().translationX(outside(view, old)).setDuration(200).setInterpolator(ACCELERATE).withEndAction {
                view.apply(next)
                val params = paramsFor(next)
                windows.updateViewLayout(view, params)
                handleParams = params
                view.translationX = outside(view, next)
                // край сменили в открытой полке: корешки ждут за новым краем и выедут, когда она уйдёт
                if (!panel.isShown) view.animate().translationX(0f).setDuration(350).setInterpolator(DECELERATE).start()
            }.start()
            return
        }
        val from = handleParams ?: return
        val to = paramsFor(next)
        val fromAlpha = view.shelfAlpha
        view.rightSide = next.rightSide
        move?.cancel()
        if (!animated) {
            view.apply(next)
            windows.updateViewLayout(view, to)
            handleParams = to
            return
        }
        val startWidth = view.shelfWidth
        val endWidth = next.shelfWidthDp * density()
        move = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 200
            interpolator = EMPHASIZED
            addUpdateListener { animator ->
                val t = animator.animatedValue as Float
                val params = handleParams ?: return@addUpdateListener
                params.y = lerp(from.y, to.y, t)
                params.width = lerp(from.width, to.width, t)
                params.height = lerp(from.height, to.height, t)
                view.shelfWidth = startWidth + (endWidth - startWidth) * t
                view.shelfAlpha = fromAlpha + (next.alpha - fromAlpha) * t
                windows.updateViewLayout(view, params)
            }
            start()
        }
    }

    /** Выключили: корешки уезжают за край, потом служба останавливается. */
    private fun hideHandle() {
        val view = handle
        val settings = prefs
        if (view == null || settings == null || leaving) return stopSelf()
        leaving = true
        panel.close()
        view.animate().translationX(outside(view, settings)).setDuration(200).setInterpolator(ACCELERATE).withEndAction { stopSelf() }.start()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // поворот, складной экран: корешки на той же доле высоты нового экрана, стикеры внутри
        applyPrefs(animated = false)
        stickers.toList().forEach { it.screenChanged() }
    }

    override fun onDestroy() {
        move?.cancel()
        stickers.toList().forEach { it.remove() }
        panel.destroy()
        handle?.let { windows.removeView(it) }
        handle = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        // как в lib/domain/sticker_geometry.dart
        private const val MAX_STICKERS = 3
        private const val STICKER_WIDTH_DP = 236f
        private const val STICKER_MARGIN_DP = 8f
        private const val STICKER_GAP_DP = 12f

        // до первого кадра: дальше Dart ставит высоту по содержимому
        private const val STICKER_START_HEIGHT_DP = 160f

        private const val ACTION_APPLY = "app.stowa.edge.APPLY"
        private const val ACTION_STOP = "app.stowa.edge.STOP"

        // кривые из lib/core/theme/motion.dart
        private val EMPHASIZED = PathInterpolator(0.2f, 0f, 0f, 1f)
        private val DECELERATE = PathInterpolator(0.05f, 0.7f, 0.1f, 1f)
        private val ACCELERATE = PathInterpolator(0.3f, 0f, 0.8f, 0.15f)

        private fun lerp(from: Int, to: Int, t: Float) = (from + (to - from) * t).toInt()

        fun start(context: Context) {
            context.startService(Intent(context, EdgeService::class.java))
        }

        fun stop(context: Context) {
            context.startService(Intent(context, EdgeService::class.java).setAction(ACTION_STOP))
        }

        fun apply(context: Context) {
            context.startService(Intent(context, EdgeService::class.java).setAction(ACTION_APPLY))
        }

        /** После загрузки и обновления: поднять корешки, если человек их включал и право есть. */
        fun startIfEnabled(context: Context) {
            if (!EdgePrefs.read(context).enabled || !Settings.canDrawOverlays(context)) return
            try {
                start(context)
            } catch (error: IllegalStateException) {
                // система не дала запустить службу из фона — корешки поднимутся при открытии Stowa
                Log.w(EdgeHandle.TAG, "start after boot refused", error)
            }
        }
    }
}
