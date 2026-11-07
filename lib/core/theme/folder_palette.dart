import 'package:flutter/painting.dart';

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

  /// Подложка в цвет папки на графите: сам цвет приглушён до тени.
  static Color tint(Color color, [double strength = 0.16]) => Color.alphaBlend(color.withValues(alpha: strength), const Color(0xFF1F2023));
}
