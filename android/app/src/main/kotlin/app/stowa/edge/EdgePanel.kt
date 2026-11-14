package app.stowa.edge

import android.content.Context
import android.graphics.PixelFormat
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Окно полки поверх других приложений. Внутри — FlutterView своего движка с точкой входа
 * `edgeMain`. Движок создаётся при первом открытии и остаётся тёплым, пока жива служба:
 * второе открытие — без холодного старта. Окно не берёт фокус, пока Dart не попросит
 * (`setFocusable`): иначе у приложения под полкой пропала бы клавиатура.
 */
class EdgePanel(private val context: Context, private val windows: WindowManager) {
    private var engine: FlutterEngine? = null
    private var view: FlutterView? = null
    private var params: WindowManager.LayoutParams? = null

    val isShown: Boolean get() = view != null

    /** Завести движок заранее, без окна: следующее открытие полки — без холодного старта. */
    fun warmUp() {
        if (engine == null) engine = createEngine()
    }

    fun show() {
        if (view != null) return
        val engine = engine ?: createEngine().also { engine = it }
        val density = context.resources.displayMetrics.density
        // TextureView, не SurfaceView: отдельная поверхность SurfaceView в окне поверх так и не
        // показала кадр (SurfaceSyncGroup ждал её и сдавался, эмулятор 14.11.2026). Прозрачна сама:
        // вне скруглённой полки видно приложение под ней
        val flutterView = FlutterView(context, FlutterTextureView(context))
        val layout = WindowManager.LayoutParams(
            ((312 + 8) * density).toInt(),
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
            title = "Stowa shelf"
        }
        // сперва движок, потом окно: поверхность становится доступной при показе окна и
        // должна уже знать свой движок
        flutterView.attachToFlutterEngine(engine)
        windows.addView(flutterView, layout)
        engine.lifecycleChannel.appIsResumed()
        view = flutterView
        params = layout
        Log.d(EdgeHandle.TAG, "shelf shown")
    }

    fun close() {
        val flutterView = view ?: return
        setFocusable(false)
        engine?.lifecycleChannel?.appIsInactive()
        flutterView.detachFromFlutterEngine()
        windows.removeView(flutterView)
        view = null
        params = null
        Log.d(EdgeHandle.TAG, "shelf closed")
    }

    /** Фокус для набора: окно берёт клавиатуру, пока поле полки в фокусе. */
    fun setFocusable(on: Boolean) {
        val flutterView = view ?: return
        val layout = params ?: return
        val flags = if (on) {
            layout.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()
        } else {
            layout.flags or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        }
        if (flags == layout.flags) return
        layout.flags = flags
        windows.updateViewLayout(flutterView, layout)
        Log.d(EdgeHandle.TAG, "shelf focusable=$on")
    }

    fun destroy() {
        close()
        engine?.destroy()
        engine = null
    }

    private fun createEngine(): FlutterEngine {
        val engine = FlutterEngine(context)
        MethodChannel(engine.dartExecutor.binaryMessenger, "stowa/edge").setMethodCallHandler { call, result ->
            when (call.method) {
                "setFocusable" -> {
                    setFocusable(call.arguments as Boolean)
                    result.success(null)
                }
                "close" -> {
                    close()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        val bundle = FlutterInjector.instance().flutterLoader().findAppBundlePath()
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(bundle, "edgeMain"))
        return engine
    }
}
