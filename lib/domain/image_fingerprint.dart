import 'dart:typed_data';

/// Отпечатки, которые разнятся не больше чем на столько бит из 64, — одна и та же картинка:
/// пересжатая, уменьшенная, с другой яркостью.
const repeatDistance = 6;

/// Отпечаток из 64 бит: картинка, уже сжатая до 9×8 в RGBA, и в каждой строке яркость
/// соседей — светлеет ли вправо. Арифметика, не нейросеть.
int fingerprintOf(Uint8List rgba) {
  int brightness(int x, int y) {
    final at = (y * 9 + x) * 4;
    return rgba[at] * 299 + rgba[at + 1] * 587 + rgba[at + 2] * 114;
  }

  var print = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      print = (print << 1) | (brightness(x, y) < brightness(x + 1, y) ? 1 : 0);
    }
  }
  return print;
}

/// Сколько бит из 64 разные.
int fingerprintDistance(int a, int b) {
  var rest = a ^ b;
  var count = 0;
  while (rest != 0) {
    rest &= rest - 1;
    count++;
  }
  return count;
}

/// Отпечаток строкой из 16 знаков: так он лежит в фактах.
String fingerprintText(int print) => [print >> 32 & 0xffffffff, print & 0xffffffff].map((half) => half.toRadixString(16).padLeft(8, '0')).join();

// по половинам: шестнадцать знаков больше наибольшего числа со знаком
int parseFingerprint(String text) => (int.parse(text.substring(0, 8), radix: 16) << 32) | int.parse(text.substring(8), radix: 16);
