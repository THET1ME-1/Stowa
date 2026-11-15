package app.stowa.edge

import android.content.Context
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.view.Choreographer
import android.view.Gravity
import android.view.TextureView
import android.view.View
import android.view.WindowManager
import android.widget.ImageView

/**
 * Смена размера окна поверх без мигания: окно-призрак со снимком прежней картинки стоит на
 * старом месте, пока вид Flutter спрятан, и уходит, когда Dart нарисовал кадр в новом
 * размере (`shown`).
 *
 * Снимок внутри самого окна не спасал: окно, которое растёт и сдвигается разом, система на
 * кадр показывает на новом месте без картинки, и круг мигал (эмулятор, 3 раскрытия стикера
 * из 8 у правого края, 0 из 8 у левого, где окно не сдвигается; 15.11.2026). Удержание
 * через `setTransform` тоже ломалось: опоздавший кадр старого размера мелькал сплющенным.
 *
 * Призрак принимает касания: окно поверх, которое их пропускает (`FLAG_NOT_TOUCHABLE`),
 * Android 12+ рисует не плотнее 0,8 — круг на кадр тускнел (замер зелёным призраком,
 * 15.11.2026). Живёт он доли секунды и стоит там же, где окно.
 *
 * [root] — то, что стоит в окне; [texture] — вид Flutter в нём.
 */
class WindowSwap(
    private val context: Context,
    private val windows: WindowManager,
    private val root: View,
    private val texture: TextureView,
) {
    private var ghost: ImageView? = null

    /** Смена окна ждёт, пока призрак встанет на экран. */
    private var pending: (() -> Unit)? = null
    private var gone = false
    private val main = Handler(Looper.getMainLooper())
    private val uncoverLate = Runnable { uncover() }

    // призрак так и не нарисовался — окно не ждёт дольше
    private val swapLate = Runnable { swapNow() }

    /**
     * Поставить призрака со снимком нынешней картинки на место окна и, когда он нарисован,
     * спрятать вид Flutter и сделать [apply]. Dart промолчал — через 700 мс открываем сами,
     * снимок не должен висеть.
     */
    fun resize(apply: () -> Unit) {
        if (gone) return
        // прежняя смена ещё ждёт своего призрака — доделать её сразу
        swapNow()
        val shot = texture.bitmap
        if (shot == null) {
            apply()
            return
        }
        dropGhost()
        val at = IntArray(2)
        root.getLocationOnScreen(at)
        val image = ImageView(context)
        image.setImageBitmap(shot)
        val params = WindowManager.LayoutParams(
            shot.width,
            shot.height,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = at[0]
            y = at[1]
            title = "Stowa ghost"
        }
        EdgeSticker.noMoveAnimation(params)
        pending = apply
        // первый кадр призрака нарисован — ещё два такта, и он на экране
        var drawn = false
        image.viewTreeObserver.addOnDrawListener {
            if (!drawn) {
                drawn = true
                afterFrames(2) { swapNow() }
            }
        }
        windows.addView(image, params)
        ghost = image
        main.removeCallbacks(swapLate)
        main.postDelayed(swapLate, 120)
    }

    /** Dart нарисовал кадр в новом размере: через два такта он на экране, призрак уходит; потом [done]. */
    fun shown(done: () -> Unit) = afterFrames(2) { uncover(done) }

    fun dispose() {
        gone = true
        main.removeCallbacks(uncoverLate)
        main.removeCallbacks(swapLate)
        pending = null
        dropGhost()
    }

    /** Призрак на экране: вид Flutter прячется, окно меняется под ним. */
    private fun swapNow() {
        main.removeCallbacks(swapLate)
        val apply = pending ?: return
        pending = null
        if (gone) return
        texture.alpha = 0f
        apply()
        main.removeCallbacks(uncoverLate)
        main.postDelayed(uncoverLate, 700)
    }

    /** Показать вид Flutter и через два такта, когда он нарисован, убрать призрака; потом [done]. */
    private fun uncover(done: () -> Unit = {}) {
        main.removeCallbacks(uncoverLate)
        if (gone || pending != null) {
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
}
