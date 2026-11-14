package app.stowa.edge

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.view.HapticFeedbackConstants
import android.view.SoundEffectConstants
import android.view.View
import io.flutter.embedding.engine.systemchannels.PlatformChannel

/**
 * Системный помощник Flutter для окон поверх. В обычном окне его создаёт сам Flutter
 * (PlatformPlugin), но тот требует Activity; без помощника буфер, отдача вибрацией и звук
 * нажатия в полке висят без ответа: «Вставить» в поле не работало бы (эмулятор 14.11.2026).
 * Системные полосы, поворот и прочее окно поверх не трогает — эти вызовы пустые.
 */
class EdgePlatform(
    private val context: Context,
    private val view: () -> View?,
    private val onBack: () -> Unit,
) : PlatformChannel.PlatformMessageHandler {
    private val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    override fun playSystemSound(soundType: PlatformChannel.SoundType) {
        if (soundType == PlatformChannel.SoundType.CLICK) view()?.playSoundEffect(SoundEffectConstants.CLICK)
    }

    override fun vibrateHapticFeedback(feedbackType: PlatformChannel.HapticFeedbackType) {
        val constant = when (feedbackType) {
            PlatformChannel.HapticFeedbackType.LIGHT_IMPACT -> HapticFeedbackConstants.VIRTUAL_KEY
            PlatformChannel.HapticFeedbackType.MEDIUM_IMPACT -> HapticFeedbackConstants.KEYBOARD_TAP
            PlatformChannel.HapticFeedbackType.HEAVY_IMPACT -> HapticFeedbackConstants.CONTEXT_CLICK
            PlatformChannel.HapticFeedbackType.SELECTION_CLICK -> HapticFeedbackConstants.CLOCK_TICK
            else -> HapticFeedbackConstants.VIRTUAL_KEY
        }
        view()?.performHapticFeedback(constant)
    }

    // окно поверх не управляет поворотом, системными полосами и списком недавних
    override fun setPreferredOrientations(androidOrientation: Int) {}

    override fun setApplicationSwitcherDescription(description: PlatformChannel.AppSwitcherDescription) {}

    override fun showSystemOverlays(overlays: MutableList<PlatformChannel.SystemUiOverlay>) {}

    override fun showSystemUiMode(mode: PlatformChannel.SystemUiMode) {}

    override fun setSystemUiChangeListener() {}

    override fun restoreSystemUiOverlays() {}

    override fun setSystemUiOverlayStyle(systemUiOverlayStyle: PlatformChannel.SystemChromeStyle) {}

    /** `SystemNavigator.pop` из Dart: у полки это «закрыть». */
    override fun popSystemNavigator() = onBack()

    override fun getClipboardData(format: PlatformChannel.ClipboardContentFormat?): CharSequence? {
        val clip = clipboard.primaryClip ?: return null
        if (clip.itemCount == 0) return null
        return clip.getItemAt(0).coerceToText(context)
    }

    override fun setClipboardData(text: String) {
        clipboard.setPrimaryClip(ClipData.newPlainText("Stowa", text))
    }

    override fun clipboardHasStrings(): Boolean {
        val description = clipboard.primaryClipDescription ?: return false
        return description.hasMimeType(ClipDescription.MIMETYPE_TEXT_PLAIN) || description.hasMimeType(ClipDescription.MIMETYPE_TEXT_HTML)
    }

    override fun share(text: String) {
        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
        context.startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
