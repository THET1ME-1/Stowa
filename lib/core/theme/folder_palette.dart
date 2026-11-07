import 'package:flutter/painting.dart';

import 'tokens.dart';

/// Цвета папок: двенадцать оттенков одной светлоты (OKLCH 0,80–0,86), поэтому ни
/// один не кричит громче соседей на графите. Тёмный текст на любом читается
/// с запасом, контраст от 9:1.
abstract final class FolderPalette {
  static const colors = <String, Color>{
    'coral': Color(0xFFFFA098),
    'tangerine': Color(0xFFF7A974),
    'amber': Color(0xFFFEC766),
    'lemon': Color(0xFFE1D569),
    'lime': Color(0xFFB5E285),
    'mint': Color(0xFF76D5A4),
    'teal': Color(0xFF51D5CE),
    'sky': Color(0xFF5FCDF5),
    'blue': Color(0xFF92BFFF),
    'violet': Color(0xFFBCB1FF),
    'orchid': Color(0xFFDFA5EC),
    'rose': Color(0xFFF89EC1),
  };

  /// Цвет, выбранный человеком, а без выбора — по месту папки в списке:
  /// соседние папки не сливаются.
  static Color of(String? key, int order) => colors[key] ?? colors.values.elementAt(order % colors.length);

  /// Подложка в цвет папки на поверхности темы: сам цвет приглушён до тени.
  static Color tint(Color color, [double strength = 0.16]) => Color.alphaBlend(color.withValues(alpha: strength), Tokens.container);

  /// Цвет папки как знак или линия на поверхности. В тёмной теме пастель
  /// видна как есть, в светлой её темнеет тот же оттенок, пока не выйдет
  /// контраст 4 к фону (на плитках выходит больше 3): пастель на белом не видна.
  static Color ink(Color color) {
    if (Tokens.palette.isDark) return color;
    final background = Tokens.background.computeLuminance();
    var hsl = HSLColor.fromColor(color);
    while (hsl.lightness > 0.05 && (background + 0.05) / (hsl.toColor().computeLuminance() + 0.05) < 4) {
      hsl = hsl.withLightness(hsl.lightness - 0.02);
    }
    return hsl.toColor();
  }
}
