import 'package:flutter/material.dart';

import '../core/theme/folder_palette.dart';
import '../core/theme/palette.dart';

/// Режим темы: как выбрано, как в системе или по времени суток.
enum ThemeChoice { light, dark, system, byTime }

/// Цвета на выбор: восемь оттенков палитры папок.
final kThemeSeeds = [
  for (final key in ['coral', 'amber', 'lime', 'mint', 'teal', 'blue', 'violet', 'rose']) FolderPalette.colors[key]!,
];

/// Выбор человека в «Оформлении». По умолчанию — Stowa как была: тёмный графит.
class Appearance {
  const Appearance({this.choice = ThemeChoice.dark, this.seed, this.vibrant = true, this.wallpaper = false, this.amoled = false});

  final ThemeChoice choice;

  /// Цвет ARGB; пусто — графит.
  final int? seed;

  /// «Сочно» — схема от цвета с подкрашенными поверхностями; иначе «точь-в-точь».
  final bool vibrant;

  /// Цвета из обоев (Android 12+).
  final bool wallpaper;

  /// Чистый чёрный фон в тёмной теме.
  final bool amoled;

  Appearance copyWith({ThemeChoice? choice, int? Function()? seed, bool? vibrant, bool? wallpaper, bool? amoled}) => Appearance(
    choice: choice ?? this.choice,
    seed: seed == null ? this.seed : seed(),
    vibrant: vibrant ?? this.vibrant,
    wallpaper: wallpaper ?? this.wallpaper,
    amoled: amoled ?? this.amoled,
  );

  @override
  bool operator ==(Object other) =>
      other is Appearance && other.choice == choice && other.seed == seed && other.vibrant == vibrant && other.wallpaper == wallpaper && other.amoled == amoled;

  @override
  int get hashCode => Object.hash(choice, seed, vibrant, wallpaper, amoled);
}

/// Ночь для «по времени»: с 20:00 до 7:00.
bool _night(DateTime now) => now.hour >= 20 || now.hour < 7;

Brightness brightnessFor(Appearance appearance, Brightness platform, DateTime now) => switch (appearance.choice) {
  ThemeChoice.light => Brightness.light,
  ThemeChoice.dark => Brightness.dark,
  ThemeChoice.system => platform,
  ThemeChoice.byTime => _night(now) ? Brightness.dark : Brightness.light,
};

/// Когда «по времени» сменит тему в следующий раз: в 7:00 или в 20:00.
DateTime nextThemeSwitch(DateTime now) {
  final morning = DateTime(now.year, now.month, now.day, 7);
  final evening = DateTime(now.year, now.month, now.day, 20);
  if (now.isBefore(morning)) return morning;
  if (now.isBefore(evening)) return evening;
  return DateTime(now.year, now.month, now.day + 1, 7);
}

/// Палитра для выбора и яркости. [wallpaper] — схема системы из обоев, если она есть.
StowaPalette paletteFor(Appearance appearance, Brightness brightness, {ColorScheme? wallpaper}) {
  final graphite = brightness == Brightness.dark ? StowaPalette.graphiteDark : StowaPalette.graphiteLight;
  final seed = appearance.seed;
  final StowaPalette palette;
  if (appearance.wallpaper && wallpaper != null) {
    palette = _fromScheme(wallpaper);
  } else if (seed == null) {
    palette = graphite;
  } else if (appearance.vibrant) {
    palette = _fromScheme(ColorScheme.fromSeed(seedColor: Color(seed), brightness: brightness));
  } else {
    // точь-в-точь: поверхности прежние, акцент — ровно выбранный цвет
    final accent = Color(seed);
    final onAccent = _pureInk(accent);
    palette = graphite.copyWith(accent: accent, onAccent: onAccent, onAccentVariant: Color.lerp(accent, onAccent, 0.6));
  }
  return appearance.amoled ? palette.amoled() : palette;
}

/// Схема M3 в роли палитры Stowa. Приглушённый и вторичный текст доводятся
/// до контраста 4,5 к самой тёмной (или светлой) ступени.
StowaPalette _fromScheme(ColorScheme s) {
  final dark = s.brightness == Brightness.dark;
  final onAccent = _contrast(s.onPrimary, s.primary) >= 4.5 ? s.onPrimary : _pureInk(s.primary);
  return StowaPalette(
    brightness: s.brightness,
    background: s.surface,
    containerLowest: s.surfaceContainerLowest,
    containerLow: s.surfaceContainerLow,
    container: s.surfaceContainer,
    containerHigh: s.surfaceContainerHigh,
    containerHighest: s.surfaceContainerHighest,
    graphite: s.secondaryContainer,
    outline: s.outlineVariant,
    onSurface: s.onSurface,
    onSurfaceVariant: _readable(s.onSurfaceVariant, s.surfaceContainerHighest, s.onSurface),
    muted: _readable(s.outline, s.surfaceContainerHighest, s.onSurface),
    accent: s.primary,
    onAccent: onAccent,
    onAccentVariant: Color.lerp(s.primary, onAccent, 0.6)!,
    error: s.error,
    onError: s.onError,
    scrim: dark ? const Color(0xB80C0D0E) : const Color(0x8A1B1C1E),
  );
}

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

/// Двигает [color] к [toward], пока контраст к [against] не станет 4,5.
Color _readable(Color color, Color against, Color toward) {
  var result = color;
  for (var step = 1; step <= 20 && _contrast(result, against) < 4.5; step++) {
    result = Color.lerp(color, toward, step / 20)!;
  }
  return result;
}

/// Чёрный или белый — что контрастнее: на любом цвете даёт не меньше 4,58.
Color _pureInk(Color fill) =>
    _contrast(const Color(0xFF000000), fill) >= _contrast(const Color(0xFFFFFFFF), fill) ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
