import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/palette.dart';
import 'package:stowa/core/theme/tokens.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

void main() {
  tearDown(() => Tokens.use(StowaPalette.graphiteDark));

  test('тёмный графит — прежние цвета Stowa', () {
    const dark = StowaPalette.graphiteDark;
    expect(dark.brightness, Brightness.dark);
    expect(dark.background, const Color(0xFF141517));
    expect(dark.containerHigh, const Color(0xFF26272B));
    expect(dark.accent, const Color(0xFFF4F4F2));
  });

  for (final palette in [StowaPalette.graphiteDark, StowaPalette.graphiteLight, StowaPalette.graphiteDark.amoled()]) {
    test('читается: ${palette.brightness.name}${palette.background == const Color(0xFF000000) ? ' AMOLED' : ''}', () {
      for (final surface in [palette.background, palette.containerLow, palette.container, palette.containerHigh]) {
        expect(contrast(palette.onSurface, surface), greaterThanOrEqualTo(7));
        expect(contrast(palette.onSurfaceVariant, surface), greaterThanOrEqualTo(4.5));
        expect(contrast(palette.muted, surface), greaterThanOrEqualTo(4.5));
      }
      expect(contrast(palette.muted, palette.containerHighest), greaterThanOrEqualTo(4.5));
      expect(contrast(palette.onAccent, palette.accent), greaterThanOrEqualTo(4.5));
      expect(contrast(palette.onError, palette.error), greaterThanOrEqualTo(4.5));
    });
  }

  test('светлый графит: белые ступени, чёрный акцент', () {
    const light = StowaPalette.graphiteLight;
    expect(light.brightness, Brightness.light);
    expect(light.containerLowest, const Color(0xFFFFFFFF));
    expect(light.accent.computeLuminance(), lessThan(0.05));
  });

  test('AMOLED: чёрный фон, ступени сдвинуты вниз, светлая не меняется', () {
    const dark = StowaPalette.graphiteDark;
    final black = dark.amoled();
    expect(black.background, const Color(0xFF000000));
    expect(black.containerLowest, const Color(0xFF000000));
    expect(black.containerLow, dark.containerLowest);
    expect(black.containerHigh, dark.container);
    expect(StowaPalette.graphiteLight.amoled(), StowaPalette.graphiteLight);
  });

  test('Tokens читают текущую палитру', () {
    Tokens.use(StowaPalette.graphiteLight);
    expect(Tokens.background, StowaPalette.graphiteLight.background);
    expect(Tokens.palette, StowaPalette.graphiteLight);
    Tokens.use(StowaPalette.graphiteDark);
    expect(Tokens.onSurface, StowaPalette.graphiteDark.onSurface);
  });
}
