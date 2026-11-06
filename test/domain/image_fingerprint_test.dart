import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/image_fingerprint.dart';

// картинка 9×8 в RGBA из функции яркости по клетке
Uint8List _image(int Function(int x, int y) brightness) {
  final bytes = Uint8List(9 * 8 * 4);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 9; x++) {
      final value = brightness(x, y).clamp(0, 255);
      final at = (y * 9 + x) * 4;
      bytes.setAll(at, [value, value, value, 255]);
    }
  }
  return bytes;
}

void main() {
  test('та же картинка, чуть другая по яркости и шуму, — почти тот же отпечаток', () {
    final picture = fingerprintOf(_image((x, y) => x * 25 + (y.isEven ? 0 : 40)));
    final brighter = fingerprintOf(_image((x, y) => x * 25 + (y.isEven ? 0 : 40) + 12 + (x * y) % 3));
    expect(fingerprintDistance(picture, brighter), lessThanOrEqualTo(repeatDistance));
  });

  test('другая картинка — далеко', () {
    final rising = fingerprintOf(_image((x, y) => x * 25));
    final falling = fingerprintOf(_image((x, y) => 255 - x * 25));
    final stripes = fingerprintOf(_image((x, y) => (x + y).isEven ? 200 : 30));
    expect(fingerprintDistance(rising, falling), 64);
    expect(fingerprintDistance(rising, stripes), greaterThan(repeatDistance));
  });

  test('отпечаток переживает запись в базу строкой', () {
    final print = fingerprintOf(_image((x, y) => (x * 37 + y * 91) % 256));
    expect(parseFingerprint(fingerprintText(print)), print);
    expect(fingerprintText(-1), 'ffffffffffffffff');
    expect(parseFingerprint('ffffffffffffffff'), -1);
  });
}
