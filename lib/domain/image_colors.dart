/// Главные цвета картинки без нейросети: пиксели раскладываются по семьям цвета,
/// крупные семьи — главные цвета. По ним ищется «синее» и строится доска «по цвету».
library;

import 'dart:math';
import 'dart:typed_data';

/// Семьи цвета, как их называет человек: «голубое» и «синее» — разные слова.
enum ColorFamily { red, orange, yellow, green, teal, sky, blue, purple, pink, brown, white, gray, black }

/// Цвет, который занимает заметную часть картинки.
class MainColor {
  const MainColor(this.family, this.share, this.hex);

  final ColorFamily family;

  /// Доля площади от 0 до 1.
  final double share;

  /// Средний цвет семьи на картинке: «#1E3CC8».
  final String hex;
}

/// Меньше этой доли площади цвет не главный: крошка на фоне.
const _minShare = 0.12;
const _maxColors = 5;

/// Тон в градусах, насыщенность и яркость по HSV.
(double hue, double saturation, double value) _hsv(int r, int g, int b) {
  final red = r / 255;
  final green = g / 255;
  final blue = b / 255;
  final high = max(red, max(green, blue));
  final low = min(red, min(green, blue));
  final delta = high - low;
  var hue = 0.0;
  if (delta > 0) {
    if (high == red) {
      hue = 60 * (((green - blue) / delta) % 6);
    } else if (high == green) {
      hue = 60 * ((blue - red) / delta + 2);
    } else {
      hue = 60 * ((red - green) / delta + 4);
    }
  }
  return (hue < 0 ? hue + 360 : hue, high == 0 ? 0 : delta / high, high);
}

/// Семья цвета одной точки.
ColorFamily colorFamilyOf(int r, int g, int b) {
  final (hue, saturation, value) = _hsv(r, g, b);
  if (value < 0.2) return ColorFamily.black;
  if (saturation < 0.15) return value > 0.85 ? ColorFamily.white : ColorFamily.gray;
  // тёплое и тёмное — коричневое: кофе, дерево, кожа
  if ((hue < 45 || hue >= 345) && value < 0.55) return ColorFamily.brown;
  // красное, но бледное — розовое
  if ((hue < 15 || hue >= 345) && saturation < 0.55) return ColorFamily.pink;
  if (hue < 15 || hue >= 345) return ColorFamily.red;
  if (hue < 40) return ColorFamily.orange;
  if (hue < 68) return ColorFamily.yellow;
  if (hue < 160) return ColorFamily.green;
  if (hue < 190) return ColorFamily.teal;
  if (hue < 215) return ColorFamily.sky;
  if (hue < 255) return ColorFamily.blue;
  if (hue < 290) return ColorFamily.purple;
  return ColorFamily.pink;
}

/// Главные цвета из точек RGBA подряд. Прозрачное не считается. Ничего крупнее
/// [_minShare] нет — один самый частый цвет: у пёстрой картинки он всё равно есть.
List<MainColor> mainColors(Uint8List rgba) {
  final counts = <ColorFamily, int>{};
  final sums = <ColorFamily, List<int>>{};
  var total = 0;
  for (var index = 0; index + 3 < rgba.length; index += 4) {
    if (rgba[index + 3] < 128) continue;
    final r = rgba[index];
    final g = rgba[index + 1];
    final b = rgba[index + 2];
    final family = colorFamilyOf(r, g, b);
    counts[family] = (counts[family] ?? 0) + 1;
    final sum = sums.putIfAbsent(family, () => [0, 0, 0]);
    sum[0] += r;
    sum[1] += g;
    sum[2] += b;
    total++;
  }
  if (total == 0) return const [];
  final ranked = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  MainColor colorOf(MapEntry<ColorFamily, int> entry) {
    final sum = sums[entry.key]!;
    String channel(int value) => (value / entry.value).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    return MainColor(entry.key, entry.value / total, '#${channel(sum[0])}${channel(sum[1])}${channel(sum[2])}');
  }

  final main = [for (final entry in ranked) if (entry.value / total >= _minShare) colorOf(entry)];
  return main.isEmpty ? [colorOf(ranked.first)] : main.take(_maxColors).toList();
}

/// Место на доске «по цвету»: цветное по кругу тонов от красного, потом серое
/// от светлого к тёмному, без цвета — в самом конце.
double boardHue(String? hex) {
  if (hex == null || hex.length != 7) return 1000;
  final value = int.tryParse(hex.substring(1), radix: 16);
  if (value == null) return 1000;
  final (hue, saturation, brightness) = _hsv(value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF);
  if (saturation < 0.15 || brightness < 0.2) return 400 + (1 - brightness) * 100;
  // красный с синевой (345°–360°) — тот же красный: в начало круга
  return hue >= 345 ? hue - 360 : hue;
}
