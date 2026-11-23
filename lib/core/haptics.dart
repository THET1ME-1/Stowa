import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Вибрация, которую чувствуешь на любом телефоне.
///
/// Удары Flutter на Android — системные `KEYBOARD_TAP` (`mediumImpact`), `VIRTUAL_KEY`
/// (`lightImpact`) и `CONTEXT_CLICK` (`heavyImpact`): многие телефоны их почти не передают
/// (тестировщик 23.11: «почему вибраций нет при удержании заметки и удалении»). Долгое нажатие
/// и удаление на Android — `LONG_PRESS`, как у долгого нажатия во всех приложениях, на iPhone —
/// удар средний и сильный.
abstract final class Haptics {
  /// Долгое нажатие: меню заметки, выделение, полоса времени.
  static Future<void> longPress() => _android ? HapticFeedback.vibrate() : HapticFeedback.mediumImpact();

  /// Заметку или папку убрали в корзину.
  static Future<void> delete() => _android ? HapticFeedback.vibrate() : HapticFeedback.heavyImpact();

  static bool get _android => defaultTargetPlatform == TargetPlatform.android;
}
