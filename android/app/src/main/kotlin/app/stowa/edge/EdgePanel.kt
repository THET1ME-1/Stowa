package app.stowa.edge

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.PixelFormat
import android.graphics.PointF
import android.net.Uri
import android.os.Build
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.WindowManager
import app.stowa.MainActivity
import app.stowa.QuickActivity
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Окно полки поверх других приложений. Внутри — FlutterView своего движка с точкой входа
 * `edgeMain`. Движок заводится при запуске службы и остаётся тёплым, пока она жива:
 * открытие — без холодного старта. Окно стоит во весь экран только пока полка открыта;
 * выезд, затемнение и уход полки рисует Dart, сюда приходят касания и свайп корешков.
 */
class EdgePanel(
    private val context: Context,
    private val windows: WindowManager,
    /** Движок полки прислал цвета корешков: закреплённые заметки цветом их папок. */
    private val onSpines: (List<Pair<Int, Float>>) -> Unit,
    /** Окно полки встало: корешкам уйти за край. */
    private val onShown: () -> Unit,
    /** Полка начала уезжать или окно убрано: корешкам вернуться. */
    private val onClosing: () -> Unit,
    /** Настройку корешков поменяли в самой полке: край, высота, размер, заметность. */
    private val onApply: () -> Unit,
    /** «Под рукой» выключили в самой полке. */
    private val onStop: () -> Unit,
    /** Кнопка на карточке полки или карточка, вынесенная за полку: повесить заметку стикером. */
    private val onPinSticker: (String, PointF?) -> Unit,
) {
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var view: FlutterView? = null

    val isShown: Boolean get() = view != null

    /** Завести движок заранее, без окна: следующее открытие полки — без холодного старта. */
    fun warmUp() {
        if (engine == null) engine = createEngine()
    }

    /** Касание корешков: окно встаёт, полка выезжает (движение — в Dart). */
    fun open() {
        show()
        channel?.invokeMethod("open", null)
    }

    /** Свайп корешков внутрь: окно встаёт, дальше полка идёт за пальцем. */
    fun dragStart() {
        show()
        channel?.invokeMethod("dragStart", null)
    }

    fun drag(distanceDp: Float) {
        if (view != null) channel?.invokeMethod("drag", distanceDp.toDouble())
    }

    fun dragEnd(velocityDp: Float) {
        if (view != null) channel?.invokeMethod("dragEnd", velocityDp.toDouble())
    }

    /** «Назад» с пустым навигатором полки: пусть уедет плавно, окно Dart уберёт сам. */
    fun dismiss() {
        if (view != null) channel?.invokeMethod("dismiss", null)
    }

    private fun show() {
        if (view != null) return
        val engine = engine ?: createEngine().also { engine = it }
        // TextureView, не SurfaceView: отдельная поверхность SurfaceView в окне поверх так и не
        // показала кадр (SurfaceSyncGroup ждал её и сдавался, эмулятор 14.11.2026). Прозрачна сама:
        // за полкой — затемнение, его рисует Dart вместе с выездом полки
        val flutterView = object : FlutterView(context, FlutterTextureView(context)) {
            // «назад» в окно без Activity приходит голой клавишей, Flutter о ней не знает. Отдаём его
            // как системное: строка снимается, заметка в полке закрывается, потом уезжает сама полка
            override fun dispatchKeyEvent(event: KeyEvent): Boolean {
                if (event.keyCode != KeyEvent.KEYCODE_BACK) return super.dispatchKeyEvent(event)
                if (event.action == KeyEvent.ACTION_UP && !event.isCanceled) engine.navigationChannel.popRoute()
                return true
            }
        }
        // окно во весь экран, пока полка открыта: касание мимо полки — по затемнению, оно её убирает.
        // Фокус у окна всё время: «назад» и клавиатура — полке, приложение под ней всё равно закрыто
        val layout = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            // окно во весь экран и не ужимается ни под полосы, ни под клавиатуру: их Flutter получает
            // отступами и поднимает строку сам, кадр в кадр. Иначе система ужимала окно под
            // клавиатуру (даже с ADJUST_NOTHING), а Flutter вычитал её ещё раз — полка сжималась
            // до строки наверху (эмулятор 14.11.2026)
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) fitInsetsTypes = 0
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
            title = "Stowa shelf"
        }
        // сперва движок, потом окно: поверхность становится доступной при показе окна и
        // должна уже знать свой движок
        flutterView.attachToFlutterEngine(engine)
        windows.addView(flutterView, layout)
        engine.lifecycleChannel.appIsResumed()
        view = flutterView
        onShown()
        Log.d(EdgeHandle.TAG, "shelf shown")
    }

    /** Убрать окно сразу. Полка к этому времени уже уехала за край (или её выключили). */
    fun close() {
        val flutterView = view ?: return
        engine?.lifecycleChannel?.appIsInactive()
        flutterView.detachFromFlutterEngine()
        windows.removeView(flutterView)
        view = null
        onClosing()
        Log.d(EdgeHandle.TAG, "shelf closed")
    }

    fun destroy() {
        close()
        channel?.setMethodCallHandler(null)
        channel = null
        engine?.destroy()
        engine = null
    }

    /** Открыть Stowa тем же адресом, что уведомление по месту и окно виджета. */
    private fun openApp(noteId: String?) {
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (noteId != null) {
            intent.setAction(Intent.ACTION_VIEW).setData(Uri.parse("stowa://open?payload=${Uri.encode("note:$noteId")}"))
        }
        close()
        context.startActivity(intent)
    }

    /** Окно виджета с нужной кнопкой и набранным в полке: stowa://attach?text=… */
    private fun handOff(action: String, text: String) {
        val address = Uri.Builder().scheme("stowa").authority(action)
        if (text.isNotEmpty()) address.appendQueryParameter("text", text)
        val intent = Intent(context, QuickActivity::class.java)
            .setData(address.build())
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        close()
        context.startActivity(intent)
        Log.d(EdgeHandle.TAG, "hand off $action")
    }

    private fun createEngine(): FlutterEngine {
        val engine = FlutterEngine(context)
        // буфер, вибрация и звук нажатия: в окне без Activity их некому обслужить
        engine.platformChannel.setPlatformMessageHandler(EdgePlatform(context, { view }, ::dismiss))
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "stowa/edge")
        this.channel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                // полка поехала за край: корешки возвращаются в такт, окно уберёт "close"
                "closing" -> {
                    onClosing()
                    result.success(null)
                }
                "close" -> {
                    close()
                    result.success(null)
                }
                // id заметки или null — главная; полка уходит, человек оказывается в Stowa
                "openApp" -> {
                    openApp(call.arguments as String?)
                    result.success(null)
                }
                // {action, text}: камера, файлы и запрос микрофона — в окне виджета, у него есть Activity
                "handOff" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as Map<String, Any?>
                    handOff(args["action"] as String, args["text"] as String? ?: "")
                    result.success(null)
                }
                // настройка корешков открыта прямо в полке: она зовёт те же команды, что главное окно.
                // Без них смена края в полке двигала саму полку, а корешки оставались на старом краю
                "apply" -> {
                    onApply()
                    result.success(null)
                }
                "stop" -> {
                    onStop()
                    result.success(null)
                }
                "start" -> result.success(null)
                "canDraw" -> result.success(true)
                // плагин записи без Activity право не видит: проверяем сами, писать он может
                "micGranted" -> result.success(
                    context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED,
                )
                // {id, x?, y?}: место — куда принесли карточку, в точках свободной части экрана
                "pinSticker" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as Map<String, Any?>
                    val x = (args["x"] as Number?)?.toFloat()
                    val y = (args["y"] as Number?)?.toFloat()
                    onPinSticker(args["id"] as String, if (x != null && y != null) PointF(x, y) else null)
                    result.success(null)
                }
                // [{color: ARGB, weight: доля}, …] сверху вниз
                "spines" -> {
                    @Suppress("UNCHECKED_CAST")
                    val list = call.arguments as List<Map<String, Any>>
                    onSpines(list.map { (it["color"] as Number).toInt() to (it["weight"] as Number).toFloat() })
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
