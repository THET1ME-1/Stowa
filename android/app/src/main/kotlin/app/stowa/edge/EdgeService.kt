package app.stowa.edge

import android.animation.ValueAnimator
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.graphics.PointF
import android.graphics.RectF
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.PathInterpolator
import io.flutter.embedding.engine.FlutterEngineGroup
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.min

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
        running = this
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
        stickerPrefs().registerOnSharedPreferenceChangeListener(vaultWatch)
    }

    /**
     * В приложении открыли другое хранилище: стикеры прежнего уходят (они помнятся за ним),
     * встают стикеры нового, полка — с новым движком на его базе. Пересобрать сессию в старом
     * движке нельзя: закрытая полка кадров не рисует, а пересборка ждёт кадра — полка висла
     * невидимым окном (эмулятор 14.11.2026). Новый движок рисует: хранилище меняют в самой
     * Stowa, она в это время на экране (см. риск 4а).
     */
    private val vaultWatch = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key != "flutter.vault_db") return@OnSharedPreferenceChangeListener
        Log.d(EdgeHandle.TAG, "vault changed")
        panel.destroy()
        panel.warmUp()
        stickers.toList().forEach { it.dispose() }
        stickers.clear()
        restoreStickers()
    }

    /**
     * Стикер заметки: уже висит — новый не заводится; четвёртый снимает самый старый.
     * Принесли карточку — встаёт там ([at]); кнопкой — у края корешков, под висящими.
     */
    private fun pinSticker(noteId: String, at: PointF?) {
        if (stickers.any { it.noteId == noteId }) return
        if (stickers.size >= MAX_STICKERS) stickers.first().remove()
        if (at != null) {
            addSticker(noteId, RectF(at.x, at.y, at.x + STICKER_WIDTH_DP, at.y + STICKER_START_HEIGHT_DP), null)
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
        addSticker(noteId, RectF(left, top, left + STICKER_WIDTH_DP, top + STICKER_START_HEIGHT_DP), null)
    }

    private fun addSticker(noteId: String, start: RectF, stickerHeight: Float?) {
        stickers += EdgeSticker(this, windows, stickerEngines, noteId, start, stickerHeight, onChanged = ::saveStickers) { gone ->
            stickers.remove(gone)
            saveStickers()
        }
        saveStickers()
    }

    /** Список стикеров в prefs (`flutter.edge_stickers`): у каждого хранилища свой. */
    private fun stickerPrefs() = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    // база открытого хранилища — его имя; заметки другого хранилища в этой базе не найдутся
    private fun vaultKey() = stickerPrefs().getString("flutter.vault_db", null) ?: "stowa.sqlite"

    private fun saveStickers() {
        val all = runCatching { JSONObject(stickerPrefs().getString(STICKERS_KEY, null) ?: "{}") }.getOrDefault(JSONObject())
        all.put(vaultKey(), JSONArray(stickers.map { it.state() }))
        stickerPrefs().edit().putString(STICKERS_KEY, all.toString()).apply()
    }

    /** Служба поднялась: стикеры этого хранилища — на свои места и в свой вид. */
    private fun restoreStickers() {
        val all = runCatching { JSONObject(stickerPrefs().getString(STICKERS_KEY, null) ?: "{}") }.getOrNull() ?: return
        val saved = all.optJSONArray(vaultKey()) ?: return
        for (index in 0 until min(saved.length(), MAX_STICKERS)) {
            val sticker = saved.optJSONObject(index) ?: continue
            val noteId = sticker.optString("id").takeIf { it.isNotEmpty() } ?: continue
            if (stickers.any { it.noteId == noteId }) continue
            val x = sticker.optDouble("x").toFloat()
            val y = sticker.optDouble("y").toFloat()
            val start = RectF(x, y, x + sticker.optDouble("w").toFloat(), y + sticker.optDouble("h").toFloat())
            if (start.isEmpty) continue
            val height = if (sticker.isNull("stickerH")) null else sticker.optDouble("stickerH").toFloat()
            addSticker(noteId, start, height)
        }
        // стикеры встали у края экрана другого размера — внутрь
        stickers.forEach { it.screenChanged() }
        Log.d(EdgeHandle.TAG, "stickers restored: ${stickers.size}")
    }

    /** Сработало напоминание по месту: корешки мягко пульсируют, пока полку не открыли. */
    fun pulse() {
        handle?.pulse(true)
    }

    /** Полка выезжает: корешки уходят за свой край, 200 мс, emphasizedAccelerate. */
    private fun spinesAway() {
        val view = handle ?: return
        val settings = prefs ?: return
        // заметку «рядом» увидели — пульс больше не нужен
        view.pulse(false)
        if (leaving) return
        view.animate().translationX(outside(view, settings)).setDuration(200).setInterpolator(ACCELERATE).start()
    }

    /** Другое приложение показывает что-то на весь экран (видео, игра): строки состояния нет. */
    private var fullscreen = false

    /**
     * Полноэкранное видео: корешки уезжают за край и не ловят касания — невидимая полоса
     * у края не должна мешать ни видео, ни жесту «назад». Строка вернулась — выезжают.
     */
    private fun watchFullscreen(view: EdgeHandle) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        view.setOnApplyWindowInsetsListener { target, insets ->
            val full = !insets.isVisible(WindowInsets.Type.statusBars())
            if (full != fullscreen) {
                fullscreen = full
                applyFullscreen()
            }
            target.onApplyWindowInsets(insets)
        }
    }

    private fun applyFullscreen() {
        val view = handle ?: return
        val settings = prefs ?: return
        val params = handleParams ?: return
        val hide = fullscreen && settings.hideInFullscreen && !leaving
        if (hide == view.hidden) return
        view.hidden = hide
        params.flags = touchable(params.flags, !hide)
        windows.updateViewLayout(view, params)
        Log.d(EdgeHandle.TAG, if (hide) "fullscreen: spines hidden" else "fullscreen over: spines back")
        if (hide) {
            view.animate().translationX(outside(view, settings)).setDuration(200).setInterpolator(ACCELERATE).start()
        } else if (!panel.isShown) {
            view.animate().translationX(0f).setDuration(350).setInterpolator(DECELERATE).start()
        }
    }

    private fun touchable(flags: Int, on: Boolean) =
        if (on) flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv() else flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE

    /** Полка уезжает: корешки выезжают обратно, 350 мс, emphasizedDecelerate. */
    private fun spinesBack() {
        val view = handle ?: return
        if (leaving || view.hidden || view.translationX == 0f) return
        view.animate().translationX(0f).setDuration(350).setInterpolator(DECELERATE).start()
    }

    private val gestures = object : EdgeHandle.Gestures {
        override fun onTap() = panel.open()

        override fun onDragStart() = panel.dragStart()

        override fun onDrag(distanceDp: Float) = panel.drag(distanceDp)

        override fun onDragEnd(velocityDp: Float) = panel.dragEnd(velocityDp)

        override fun onSwipeDown() = panel.gesture("type")

        override fun onHoldStart() = panel.gesture("voiceStart")

        override fun onHoldEnd() = panel.gesture("voiceStop")

        override fun onDoubleTap() = panel.gesture("openLast")
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
            // спрятанные под полноэкранным видео не ловят касаний и после правки настроек
            touchable(
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                handle?.hidden != true,
            ),
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
        watchFullscreen(view)
        val params = paramsFor(settings)
        // выезжает из-за своего края, 350 мс, emphasizedDecelerate
        view.translationX = outside(view, settings)
        windows.addView(view, params)
        view.animate().translationX(0f).setDuration(350).setInterpolator(DECELERATE).start()
        handle = view
        handleParams = params
        prefs = settings
        Log.d(EdgeHandle.TAG, "handle shown")
        if (stickers.isEmpty()) restoreStickers()
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
        // «Прятать в полноэкранном видео» могли выключить прямо во время видео
        applyFullscreen()
        if (old.rightSide != next.rightSide) {
            view.animate().translationX(outside(view, old)).setDuration(200).setInterpolator(ACCELERATE).withEndAction {
                view.apply(next)
                val params = paramsFor(next)
                windows.updateViewLayout(view, params)
                handleParams = params
                view.translationX = outside(view, next)
                // край сменили в открытой полке: корешки ждут за новым краем и выедут, когда она уйдёт
                if (!panel.isShown && !view.hidden) view.animate().translationX(0f).setDuration(350).setInterpolator(DECELERATE).start()
            }.start()
            return
        }
        val from = handleParams ?: return
        val to = paramsFor(next)
        val fromAlpha = view.shelfAlpha
        view.rightSide = next.rightSide
        view.useGestures(next)
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
        running = null
        stickerPrefs().unregisterOnSharedPreferenceChangeListener(vaultWatch)
        handle?.pulse(false)
        move?.cancel()
        // служба уходит — стикеры помнятся и встанут на место при следующем запуске
        stickers.toList().forEach { it.dispose() }
        stickers.clear()
        panel.destroy()
        handle?.let { windows.removeView(it) }
        handle = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val STICKERS_KEY = "flutter.edge_stickers"

        /** Живая служба этого процесса: приёмник мест зовёт пульс прямо, он в том же процессе. */
        @Volatile
        var running: EdgeService? = null
            private set

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
