package app.stowa.edge

import android.annotation.SuppressLint
import android.content.Context
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.widget.FrameLayout
import kotlin.math.hypot

/**
 * Рамка окна стикера. Удержание 280 мс без сдвига дальше 8 dp — и окно едет за пальцем:
 * перетаскивание нативное, ровно за пальцем, без подъёма. Касание, отпущенное после
 * удержания, во Flutter не уходит — иначе галочка или «—» сработали бы сами.
 */
@SuppressLint("ViewConstructor")
class StickerFrame(context: Context, private val mover: Mover) : FrameLayout(context) {
    interface Mover {
        fun start()

        /** Палец сдвинулся на столько пикселей с прошлого раза. */
        fun move(dx: Float, dy: Float)

        fun end()
    }

    private val slop = 8 * resources.displayMetrics.density
    private var downX = 0f
    private var downY = 0f
    private var lastX = 0f
    private var lastY = 0f
    private var pressed = false
    private var armed = false
    private var dragging = false

    private val arm = Runnable {
        if (!pressed) return@Runnable
        armed = true
        performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
    }

    override fun onInterceptTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = event.rawX
                downY = event.rawY
                lastX = downX
                lastY = downY
                pressed = true
                armed = false
                dragging = false
                postDelayed(arm, HOLD_MS)
            }
            MotionEvent.ACTION_MOVE -> {
                val far = hypot(event.rawX - downX, event.rawY - downY) > slop
                if (!armed && far) removeCallbacks(arm)
                // удержали и повели — дальше касание наше, Flutter получает отмену
                if (armed && !dragging) {
                    dragging = true
                    lastX = event.rawX
                    lastY = event.rawY
                    mover.start()
                    return true
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                pressed = false
                removeCallbacks(arm)
                // удержали и отпустили, не двигая: это не касание
                if (armed) {
                    armed = false
                    return true
                }
            }
        }
        return dragging
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_MOVE -> if (dragging) {
                mover.move(event.rawX - lastX, event.rawY - lastY)
                lastX = event.rawX
                lastY = event.rawY
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (dragging) mover.end()
                dragging = false
                armed = false
                pressed = false
            }
        }
        return true
    }

    companion object {
        const val HOLD_MS = 280L
    }
}
