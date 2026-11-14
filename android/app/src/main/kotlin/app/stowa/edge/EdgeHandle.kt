package app.stowa.edge

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.view.VelocityTracker
import android.view.ViewConfiguration
import kotlin.math.abs

/**
 * Корешки у края: тёмная подложка и столбик цветных отрезков — закреплённые заметки цветом
 * их папок. Подложка прижата к краю экрана, слева от неё (справа у левого края) — запас
 * для пальца, невидимый. Касание открывает полку, свайп внутрь ведёт её за пальцем.
 */
@SuppressLint("ViewConstructor")
class EdgeHandle(context: Context, private val gestures: Gestures) : View(context) {
    /** Касание и свайп корешков: полку ведёт Dart, сюда только расстояния в точках экрана. */
    interface Gestures {
        fun onTap()

        fun onDragStart()

        /** Палец ушёл от края внутрь экрана на [distanceDp] с начала свайпа. */
        fun onDrag(distanceDp: Float)

        /** Отпустили; [velocityDp] — точек в секунду, плюс — внутрь экрана. */
        fun onDragEnd(velocityDp: Float)
    }

    private val density = resources.displayMetrics.density

    /** Корешки у правого края экрана; у левого всё зеркально. */
    var rightSide = true
        set(value) {
            field = value
            invalidate()
        }

    /** Ширина подложки в точках экрана; остальное до ширины окна — запас для пальца. */
    var shelfWidth = 15f * density
        set(value) {
            field = value
            invalidate()
        }

    /** Цвета корешков сверху вниз и их доли по высоте. */
    var spines: List<Pair<Int, Float>> = listOf(
        0xFFFEC766.toInt() to 3f,
        0xFF76D5A4.toInt() to 2f,
        0xFF5FCDF5.toInt() to 2.4f,
        0xFFBCB1FF.toInt() to 1.6f,
    )
        set(value) {
            field = value
            invalidate()
        }

    /** Заметность подложки и корешков, 0,4…1. */
    var shelfAlpha = 0.86f
        set(value) {
            field = value
            invalidate()
        }

    /** Край, ширина и заметность из настроек — сразу, без движения. */
    fun apply(settings: EdgePrefs) {
        rightSide = settings.rightSide
        shelfWidth = settings.shelfWidthDp * density
        shelfAlpha = settings.alpha
    }

    private val backing = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(0x14, 0x15, 0x17) }
    private val spinePaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val path = Path()
    private val rect = RectF()
    private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop
    private var downX = 0f
    private var downY = 0f
    private var dragging = false
    private var velocity: VelocityTracker? = null

    /** Насколько палец ушёл от края внутрь экрана, в пикселях. */
    private fun inward(event: MotionEvent) = if (rightSide) downX - event.rawX else event.rawX - downX

    // при навигации жестами свайп от края забирает себе системное «назад»: касание корешков
    // приходило и тут же отменялось. Корешки исключены из зоны жеста (система даёт до 200 dp
    // на край, крупные корешки — 168), эмулятор 14.11.2026
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        systemGestureExclusionRects = listOf(Rect(0, 0, width, height))
    }

    override fun onDraw(canvas: Canvas) {
        val outer = 10f * density
        val left = if (rightSide) width - shelfWidth else 0f
        rect.set(left, 0f, left + shelfWidth, height.toFloat())
        // скругление только со стороны экрана: к краю подложка прижата плоской стороной
        val radii = if (rightSide) {
            floatArrayOf(outer, outer, 0f, 0f, 0f, 0f, outer, outer)
        } else {
            floatArrayOf(0f, 0f, outer, outer, outer, outer, 0f, 0f)
        }
        path.reset()
        path.addRoundRect(rect, radii, Path.Direction.CW)
        backing.alpha = (shelfAlpha * 0.86f * 255).toInt()
        canvas.drawPath(path, backing)

        val padX = 5f * density
        val padY = 7f * density
        val gap = 4f * density
        val inner = 4f * density
        val total = spines.sumOf { it.second.toDouble() }.toFloat().coerceAtLeast(0.001f)
        val room = height - padY * 2 - gap * (spines.size - 1)
        var top = padY
        for ((color, weight) in spines) {
            val length = room * weight / total
            rect.set(left + padX, top, left + shelfWidth - padX, top + length)
            spinePaint.color = color
            spinePaint.alpha = (shelfAlpha * 255).toInt()
            canvas.drawRoundRect(rect, inner, inner, spinePaint)
            top += length + gap
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        // скорость по экранным координатам: окно корешков само не двигается, но так надёжнее
        val screen = MotionEvent.obtain(event).apply { setLocation(event.rawX, event.rawY) }
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = event.rawX
                downY = event.rawY
                dragging = false
                velocity?.recycle()
                velocity = VelocityTracker.obtain().also { it.addMovement(screen) }
            }
            MotionEvent.ACTION_MOVE -> {
                velocity?.addMovement(screen)
                val inward = inward(event)
                // свайп внутрь, а не вдоль края: полка выходит и дальше идёт за пальцем
                if (!dragging && inward > touchSlop && inward > abs(event.rawY - downY)) {
                    dragging = true
                    Log.d(TAG, "drag")
                    gestures.onDragStart()
                }
                if (dragging) gestures.onDrag(inward.coerceAtLeast(0f) / density)
            }
            MotionEvent.ACTION_UP -> {
                velocity?.addMovement(screen)
                if (dragging) {
                    val tracker = velocity
                    tracker?.computeCurrentVelocity(1000)
                    val dx = tracker?.xVelocity ?: 0f
                    gestures.onDragEnd((if (rightSide) -dx else dx) / density)
                } else if (abs(event.rawX - downX) < touchSlop && abs(event.rawY - downY) < touchSlop) {
                    Log.d(TAG, "tap")
                    gestures.onTap()
                }
                dragging = false
            }
            MotionEvent.ACTION_CANCEL -> {
                // система забрала жест — полка возвращается туда, откуда её тянули
                if (dragging) gestures.onDragEnd(0f)
                dragging = false
            }
        }
        screen.recycle()
        return true
    }

    companion object {
        const val TAG = "StowaEdge"
    }
}
