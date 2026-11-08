import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/image_colors.dart';

void main() {
  test('семья цвета у чистых цветов', () {
    final samples = {
      (220, 30, 30): ColorFamily.red,
      (240, 140, 20): ColorFamily.orange,
      (240, 220, 40): ColorFamily.yellow,
      (40, 170, 60): ColorFamily.green,
      (30, 170, 170): ColorFamily.teal,
      (90, 180, 240): ColorFamily.sky,
      (30, 60, 200): ColorFamily.blue,
      (130, 50, 190): ColorFamily.purple,
      (240, 120, 180): ColorFamily.pink,
      (120, 70, 30): ColorFamily.brown,
      (250, 250, 250): ColorFamily.white,
      (128, 128, 128): ColorFamily.gray,
      (15, 15, 15): ColorFamily.black,
    };
    for (final MapEntry(key: (r, g, b), value: family) in samples.entries) {
      expect(colorFamilyOf(r, g, b), family, reason: '($r, $g, $b)');
    }
  });

  Uint8List image(List<(int count, (int, int, int, int) rgba)> parts) {
    final bytes = <int>[];
    for (final (count, (r, g, b, a)) in parts) {
      for (var index = 0; index < count; index++) {
        bytes.addAll([r, g, b, a]);
      }
    }
    return Uint8List.fromList(bytes);
  }

  test('главные цвета по доле площади, крошки меньше 12% не считаются', () {
    final colors = mainColors(image([(65, (30, 60, 200, 255)), (30, (250, 250, 250, 255)), (5, (220, 30, 30, 255))]));
    expect(colors.map((one) => one.family), [ColorFamily.blue, ColorFamily.white]);
    expect(colors.first.share, closeTo(0.65, 0.001));
    expect(colors.first.hex, '#1E3CC8');
  });

  test('прозрачное не считается; ничего крупного — один самый частый цвет', () {
    expect(mainColors(image([(90, (0, 0, 0, 0)), (10, (240, 220, 40, 255))])).single.family, ColorFamily.yellow);
    final mixed = mainColors(image([for (final rgb in [(220, 30, 30), (240, 140, 20), (240, 220, 40), (40, 170, 60), (30, 170, 170), (90, 180, 240), (30, 60, 200), (130, 50, 190), (240, 120, 180)]) (11, (rgb.$1, rgb.$2, rgb.$3, 255))]));
    expect(mixed, hasLength(1));
    expect(mainColors(Uint8List(0)), isEmpty);
  });

  test('не больше пяти цветов', () {
    final colors = mainColors(image([
      for (final rgb in [(220, 30, 30), (240, 220, 40), (40, 170, 60), (30, 60, 200), (250, 250, 250), (15, 15, 15)]) (16, (rgb.$1, rgb.$2, rgb.$3, 255)),
    ]));
    expect(colors, hasLength(5));
  });

  test('оттенок для доски: цветное по кругу, серое в конце', () {
    expect(boardHue('#DC1E1E'), lessThan(boardHue('#28AA3C')));
    // красный с синевой (тон 356°) — тоже красный, в начале круга, а не после синего
    expect(boardHue('#C81E28'), lessThan(boardHue('#1E3CC8')));
    expect(boardHue('#C81E28'), lessThan(boardHue('#F08C14')));
    expect(boardHue('#28AA3C'), lessThan(boardHue('#1E3CC8')));
    expect(boardHue('#808080'), greaterThan(boardHue('#F078B4')));
    expect(boardHue(null), greaterThan(boardHue('#808080')));
  });
}
