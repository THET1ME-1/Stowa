import 'package:flutter/painting.dart';

/// Цвета тёмной графитовой темы, сняты с макета (design/mockup/template.html).
///
/// Глубина строится ступенями поверхности, а не тенями: чем выше блок, тем
/// светлее его графит. Акцент один, матовый белый.
abstract final class Tokens {
  static const background = Color(0xFF141517);
  static const containerLowest = Color(0xFF101113);
  static const containerLow = Color(0xFF1A1B1E);
  static const container = Color(0xFF1F2023);
  static const containerHigh = Color(0xFF26272B);
  static const containerHighest = Color(0xFF2E2F33);

  /// Тональные кнопки и фигуры значков.
  static const graphite = Color(0xFF333438);

  /// Разделители и дорожки, рамок в приложении нет.
  static const outline = Color(0xFF3A3B40);

  static const onSurface = Color(0xFFF2F2F0);
  static const onSurfaceVariant = Color(0xFFB0B1B6);
  static const muted = Color(0xFF96979D);

  static const accent = Color(0xFFF4F4F2);
  static const onAccent = Color(0xFF141517);
  static const onAccentVariant = Color(0xFF56575C);

  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
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
