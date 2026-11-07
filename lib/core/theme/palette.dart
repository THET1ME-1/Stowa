import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

/// Надпись на заливке любого цвета: из почти чёрной и почти белой та, что
/// контрастнее. Пастель папок в любой теме получает тёмную.
Color inkOn(Color fill) {
  const dark = Color(0xFF141517);
  const light = Color(0xFFF6F6F4);
  final lum = fill.computeLuminance();
  final onDark = (lum + 0.05) / (dark.computeLuminance() + 0.05);
  final onLight = (light.computeLuminance() + 0.05) / (lum + 0.05);
  return onDark >= onLight ? dark : light;
}

/// Цвета одной темы Stowa. Глубина строится ступенями поверхности, а не тенями:
/// чем выше блок, тем дальше его ступень от фона.
class StowaPalette {
  const StowaPalette({
    required this.brightness,
    required this.background,
    required this.containerLowest,
    required this.containerLow,
    required this.container,
    required this.containerHigh,
    required this.containerHighest,
    required this.graphite,
    required this.outline,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.onAccentVariant,
    required this.error,
    required this.onError,
    required this.scrim,
  });

  final Brightness brightness;
  final Color background;
  final Color containerLowest;
  final Color containerLow;
  final Color container;
  final Color containerHigh;
  final Color containerHighest;

  /// Тональные кнопки и фигуры значков.
  final Color graphite;

  /// Разделители и дорожки, рамок в приложении нет.
  final Color outline;

  final Color onSurface;
  final Color onSurfaceVariant;
  final Color muted;

  final Color accent;
  final Color onAccent;

  /// Вторичная надпись на акценте.
  final Color onAccentVariant;

  final Color error;
  final Color onError;

  /// Затемнение под листами.
  final Color scrim;

  bool get isDark => brightness == Brightness.dark;

  /// Тёмный матовый графит — Stowa с первого дня, снят с макета.
  static const graphiteDark = StowaPalette(
    brightness: Brightness.dark,
    background: Color(0xFF141517),
    containerLowest: Color(0xFF101113),
    containerLow: Color(0xFF1A1B1E),
    container: Color(0xFF1F2023),
    containerHigh: Color(0xFF26272B),
    containerHighest: Color(0xFF2E2F33),
    graphite: Color(0xFF333438),
    outline: Color(0xFF3A3B40),
    onSurface: Color(0xFFF2F2F0),
    onSurfaceVariant: Color(0xFFB0B1B6),
    muted: Color(0xFF96979D),
    accent: Color(0xFFF4F4F2),
    onAccent: Color(0xFF141517),
    onAccentVariant: Color(0xFF56575C),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    scrim: Color(0xB80C0D0E),
  );

  /// Светлый графит: белые ступени на тёплом сером фоне, акцент чернильный.
  static const graphiteLight = StowaPalette(
    brightness: Brightness.light,
    background: Color(0xFFF6F6F4),
    containerLowest: Color(0xFFFFFFFF),
    containerLow: Color(0xFFF0F0EE),
    container: Color(0xFFEAEAE7),
    containerHigh: Color(0xFFE4E4E1),
    containerHighest: Color(0xFFDCDCD9),
    graphite: Color(0xFFD3D3CF),
    outline: Color(0xFFC6C6C2),
    onSurface: Color(0xFF1B1C1E),
    onSurfaceVariant: Color(0xFF46474C),
    muted: Color(0xFF5F6066),
    accent: Color(0xFF1B1C1E),
    onAccent: Color(0xFFF6F6F4),
    onAccentVariant: Color(0xFFB4B5BA),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    scrim: Color(0x8A1B1C1E),
  );

  /// Чистый чёрный фон для экранов AMOLED: ступени сдвигаются на одну вниз.
  /// Светлую тему не трогает.
  StowaPalette amoled() {
    if (!isDark) return this;
    const black = Color(0xFF000000);
    return copyWith(
      background: black,
      containerLowest: black,
      containerLow: containerLowest,
      container: containerLow,
      containerHigh: container,
      containerHighest: containerHigh,
      scrim: const Color(0xCC000000),
    );
  }

  StowaPalette copyWith({
    Color? background,
    Color? containerLowest,
    Color? containerLow,
    Color? container,
    Color? containerHigh,
    Color? containerHighest,
    Color? graphite,
    Color? outline,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? muted,
    Color? accent,
    Color? onAccent,
    Color? onAccentVariant,
    Color? error,
    Color? onError,
    Color? scrim,
  }) => StowaPalette(
    brightness: brightness,
    background: background ?? this.background,
    containerLowest: containerLowest ?? this.containerLowest,
    containerLow: containerLow ?? this.containerLow,
    container: container ?? this.container,
    containerHigh: containerHigh ?? this.containerHigh,
    containerHighest: containerHighest ?? this.containerHighest,
    graphite: graphite ?? this.graphite,
    outline: outline ?? this.outline,
    onSurface: onSurface ?? this.onSurface,
    onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
    muted: muted ?? this.muted,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    onAccentVariant: onAccentVariant ?? this.onAccentVariant,
    error: error ?? this.error,
    onError: onError ?? this.onError,
    scrim: scrim ?? this.scrim,
  );

  List<Object> get _values => [
    brightness, background, containerLowest, containerLow, container, containerHigh, containerHighest, graphite, outline,
    onSurface, onSurfaceVariant, muted, accent, onAccent, onAccentVariant, error, onError, scrim,
  ];

  @override
  bool operator ==(Object other) {
    if (other is! StowaPalette) return false;
    final mine = _values;
    final theirs = other._values;
    for (var index = 0; index < mine.length; index++) {
      if (mine[index] != theirs[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_values);
}
