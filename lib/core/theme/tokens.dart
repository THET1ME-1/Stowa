import 'package:flutter/painting.dart';

import 'palette.dart';

/// Цвета текущей темы. Читают выбранную палитру: светлую, тёмную, цветную.
/// Тему меняет только `StowaApp` через [use] и тут же перестраивает экраны.
abstract final class Tokens {
  static StowaPalette _palette = StowaPalette.graphiteDark;

  static StowaPalette get palette => _palette;

  static void use(StowaPalette palette) => _palette = palette;

  static Color get background => _palette.background;
  static Color get containerLowest => _palette.containerLowest;
  static Color get containerLow => _palette.containerLow;
  static Color get container => _palette.container;
  static Color get containerHigh => _palette.containerHigh;
  static Color get containerHighest => _palette.containerHighest;

  /// Тональные кнопки и фигуры значков.
  static Color get graphite => _palette.graphite;

  /// Разделители и дорожки, рамок в приложении нет.
  static Color get outline => _palette.outline;

  static Color get onSurface => _palette.onSurface;
  static Color get onSurfaceVariant => _palette.onSurfaceVariant;
  static Color get muted => _palette.muted;

  static Color get accent => _palette.accent;
  static Color get onAccent => _palette.onAccent;
  static Color get onAccentVariant => _palette.onAccentVariant;

  /// Кнопка на акцентной плашке: акцент, чуть сдвинутый к своей надписи.
  static Color get accentTonal => Color.alphaBlend(_palette.onAccent.withValues(alpha: 0.08), _palette.accent);

  static Color get error => _palette.error;
  static Color get onError => _palette.onError;
}

/// Отступы и радиусы макета.
abstract final class Space {
  /// Поле экрана и внутренний отступ большой карточки.
  static const screen = 16.0;

  /// Внутренний отступ плитки.
  static const tile = 12.0;
}

abstract final class Radii {
  static const card = 28.0;
  static const tile = 20.0;
  static const photo = 16.0;
}
