package app.stowa.edge

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.WindowManager

/**
 * «Под рукой»: хозяин окон поверх других приложений. Пока здесь только корешки у края
 * (этап 1 плана docs/plans/2026-11-14-edge-panel-plan.md). Без права «Поверх других
 * приложений» служба сразу останавливается.
 */
class EdgeService : Service() {
    private lateinit var windows: WindowManager
    private var handle: EdgeHandle? = null

    override fun onCreate() {
        super.onCreate()
        windows = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!Settings.canDrawOverlays(this)) {
            Log.d(EdgeHandle.TAG, "no overlay permission")
            stopSelf()
            return START_NOT_STICKY
        }
        if (handle == null) showHandle()
        return START_STICKY
    }

    private fun showHandle() {
        val density = resources.displayMetrics.density
        val view = EdgeHandle(this) { Log.d(EdgeHandle.TAG, "open shelf") }
        // подложка 15 × 128 точек, запас для пальца 18; треть высоты экрана сверху
        val height = (128 * density).toInt()
        val width = ((15 + 18) * density).toInt()
        val screen = resources.displayMetrics.heightPixels
        val margin = (80 * density).toInt()
        val params = WindowManager.LayoutParams(
            width,
            height,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            y = margin + ((screen - margin * 2 - height) * 0.34f).toInt()
            title = "Stowa edge"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        windows.addView(view, params)
        handle = view
        Log.d(EdgeHandle.TAG, "handle shown")
    }

    override fun onDestroy() {
        handle?.let { windows.removeView(it) }
        handle = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
