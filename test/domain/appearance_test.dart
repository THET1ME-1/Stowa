import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/folder_palette.dart';
import 'package:stowa/core/theme/palette.dart';
import 'package:stowa/domain/appearance.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

void main() {
  group('яркость', () {
    test('светлая и тёмная — как выбрано, «как в системе» — как система', () {
      final now = DateTime(2026, 11, 7, 12);
      expect(brightnessFor(const Appearance(choice: ThemeChoice.light), Brightness.dark, now), Brightness.light);
      expect(brightnessFor(const Appearance(choice: ThemeChoice.dark), Brightness.light, now), Brightness.dark);
      expect(brightnessFor(const Appearance(choice: ThemeChoice.system), Brightness.light, now), Brightness.light);
      expect(brightnessFor(const Appearance(choice: ThemeChoice.system), Brightness.dark, now), Brightness.dark);
    });

    test('по времени: тёмная с 20:00 до 7:00', () {
      const byTime = Appearance(choice: ThemeChoice.byTime);
      Brightness at(int hour, int minute) => brightnessFor(byTime, Brightness.light, DateTime(2026, 11, 7, hour, minute));
      expect(at(19, 59), Brightness.light);
      expect(at(20, 0), Brightness.dark);
      expect(at(0, 30), Brightness.dark);
      expect(at(6, 59), Brightness.dark);
      expect(at(7, 0), Brightness.light);
    });

    test('ближайшая смена по времени', () {
      expect(nextThemeSwitch(DateTime(2026, 11, 7, 10)), DateTime(2026, 11, 7, 20));
      expect(nextThemeSwitch(DateTime(2026, 11, 7, 5)), DateTime(2026, 11, 7, 7));
      expect(nextThemeSwitch(DateTime(2026, 11, 7, 21)), DateTime(2026, 11, 8, 7));
      expect(nextThemeSwitch(DateTime(2026, 11, 7, 20)), DateTime(2026, 11, 8, 7));
    });
  });

  group('палитра', () {
    test('по умолчанию тёмный графит, ничего не меняется', () {
      const appearance = Appearance();
      expect(appearance.choice, ThemeChoice.dark);
      expect(appearance.seed, isNull);
      expect(paletteFor(appearance, Brightness.dark), StowaPalette.graphiteDark);
      expect(paletteFor(appearance, Brightness.light), StowaPalette.graphiteLight);
    });

    test('AMOLED только в тёмной', () {
      const appearance = Appearance(amoled: true);
      expect(paletteFor(appearance, Brightness.dark).background, const Color(0xFF000000));
      expect(paletteFor(appearance, Brightness.light), StowaPalette.graphiteLight);
    });

    final seeds = <Color>[
      ...kThemeSeeds,
      const Color(0xFFFFFFFF),
      const Color(0xFF000000),
      const Color(0xFFFFEB3B),
      const Color(0xFF1A237E),
      const Color(0xFF808080),
    ];
    for (final brightness in Brightness.values) {
      for (final vibrant in [true, false]) {
        test('читается: ${brightness.name}, ${vibrant ? 'сочно' : 'точь-в-точь'}', () {
          for (final seed in seeds) {
            final p = paletteFor(Appearance(seed: seed.toARGB32(), vibrant: vibrant), brightness);
            final name = '#${seed.toARGB32().toRadixString(16)}';
            expect(p.brightness, brightness, reason: name);
            expect(contrast(p.onSurface, p.background), greaterThanOrEqualTo(7), reason: name);
            for (final surface in [p.background, p.container, p.containerHigh, p.containerHighest]) {
              expect(contrast(p.muted, surface), greaterThanOrEqualTo(4.5), reason: name);
              expect(contrast(p.onSurfaceVariant, surface), greaterThanOrEqualTo(4.5), reason: name);
            }
            expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5), reason: name);
          }
        });
      }
    }

    test('точь-в-точь: акцент ровно выбранный цвет, поверхности графитовые', () {
      const coral = Color(0xFFFFA098);
      final p = paletteFor(Appearance(seed: coral.toARGB32(), vibrant: false), Brightness.dark);
      expect(p.accent, coral);
      expect(p.background, StowaPalette.graphiteDark.background);
    });

    test('сочно: поверхности подкрашены цветом', () {
      final blue = FolderPalette.colors['blue']!;
      final p = paletteFor(Appearance(seed: blue.toARGB32()), Brightness.dark);
      expect(p.background, isNot(StowaPalette.graphiteDark.background));
      final hsl = HSLColor.fromColor(p.containerHigh);
      expect(hsl.saturation, greaterThan(0.03));
    });

    test('обои: берётся схема системы, без флага не трогается', () {
      final wallpaper = ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32), brightness: Brightness.dark);
      expect(paletteFor(const Appearance(wallpaper: true), Brightness.dark, wallpaper: wallpaper).accent, wallpaper.primary);
      expect(paletteFor(const Appearance(), Brightness.dark, wallpaper: wallpaper), StowaPalette.graphiteDark);
      // обоев нет (Android до 12) — графит
      expect(paletteFor(const Appearance(wallpaper: true), Brightness.dark), StowaPalette.graphiteDark);
    });
  });
}
