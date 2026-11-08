import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/qr.dart';
import 'package:zxing2/qrcode.dart';

/// QR-код точками RGBA: модуль — [scale] точек, вокруг белое поле в четыре модуля.
({Uint8List rgba, int width, int height}) _qrImage(String text, {int scale = 6, bool inverted = false}) {
  final code = Encoder.encode(text, ErrorCorrectionLevel.m).matrix!;
  final side = (code.width + 8) * scale;
  final rgba = Uint8List(side * side * 4);
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      final moduleX = x ~/ scale - 4;
      final moduleY = y ~/ scale - 4;
      final dark = moduleX >= 0 && moduleY >= 0 && moduleX < code.width && moduleY < code.height && code.get(moduleX, moduleY) == 1;
      final value = dark != inverted ? 20 : 240;
      final offset = (y * side + x) * 4;
      rgba
        ..[offset] = value
        ..[offset + 1] = value
        ..[offset + 2] = value
        ..[offset + 3] = 255;
    }
  }
  return (rgba: rgba, width: side, height: side);
}

void main() {
  test('Wi-Fi: имя, пароль, защита; экранированные знаки', () {
    final wifi = parseQr(r'WIFI:T:WPA;S:Дача\;2;P:pa\:ss\\w;H:false;;');
    expect(wifi.kind, QrKind.wifi);
    expect(wifi.network, 'Дача;2');
    expect(wifi.password, r'pa:ss\w');
    // порядок полей любой, открытая сеть без пароля
    final open = parseQr('WIFI:S:Кафе;T:nopass;;');
    expect((open.network, open.password), ('Кафе', null));
  });

  test('ссылка, почта и просто текст', () {
    expect(parseQr('https://tickets.md/e/42').kind, QrKind.url);
    expect(parseQr('HTTP://EXAMPLE.COM').kind, QrKind.url);
    expect(parseQr('Билет 42, ряд 7').kind, QrKind.text);
    expect(parseQr('WIFI:').kind, QrKind.text, reason: 'без имени сети это не Wi-Fi');
  });

  test('код находится на картинке, и тёмный на светлом, и светлый на тёмном', () {
    for (final inverted in [false, true]) {
      final image = _qrImage('WIFI:T:WPA;S:Home;P:secret123;;', inverted: inverted);
      expect(scanQr(image.rgba, image.width, image.height), 'WIFI:T:WPA;S:Home;P:secret123;;', reason: 'inverted: $inverted');
    }
  });

  test('на картинке без кода — null', () {
    final blank = Uint8List.fromList(List.filled(100 * 100 * 4, 200));
    expect(scanQr(blank, 100, 100), isNull);
  });
}
