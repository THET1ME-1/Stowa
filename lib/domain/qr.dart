/// QR-код на фото без нейросети: поиск кода алгоритмом ZXing и разбор того, что в нём:
/// ссылка с билета, Wi-Fi с паролем, просто текст.
library;

import 'dart:typed_data';

import 'package:zxing2/qrcode.dart';

enum QrKind { url, wifi, text }

class QrPayload {
  const QrPayload(this.kind, this.text, {this.network, this.password});

  final QrKind kind;

  /// Текст кода как есть.
  final String text;

  /// Имя сети и пароль, если это Wi-Fi; открытая сеть — без пароля.
  final String? network;
  final String? password;
}

final _url = RegExp(r'^https?://\S+$', caseSensitive: false);

/// Что лежит в коде. Wi-Fi пишется как `WIFI:T:WPA;S:имя;P:пароль;;`, знаки `;,:\`
/// внутри значений экранированы обратной чертой.
QrPayload parseQr(String text) {
  final trimmed = text.trim();
  if (_url.hasMatch(trimmed)) return QrPayload(QrKind.url, trimmed);
  if (trimmed.toUpperCase().startsWith('WIFI:')) {
    final fields = _wifiFields(trimmed.substring(5));
    final network = fields['S'];
    if (network != null && network.isNotEmpty) {
      final password = fields['P'];
      return QrPayload(QrKind.wifi, trimmed, network: network, password: password == null || password.isEmpty ? null : password);
    }
  }
  return QrPayload(QrKind.text, trimmed);
}

// поля «буква:значение» через «;», с обратной чертой перед служебными знаками
Map<String, String> _wifiFields(String body) {
  final fields = <String, String>{};
  final value = StringBuffer();
  String? key;
  var escaped = false;
  for (final char in body.split('')) {
    if (escaped) {
      value.write(char);
      escaped = false;
    } else if (char == r'\') {
      escaped = true;
    } else if (key == null && char == ':') {
      key = value.toString().toUpperCase();
      value.clear();
    } else if (char == ';') {
      if (key != null) fields[key] = value.toString();
      key = null;
      value.clear();
    } else {
      value.write(char);
    }
  }
  return fields;
}

/// Текст QR-кода на картинке из точек RGBA или null, если кода нет. Пробует два способа
/// отделить тёмное от светлого и светлый код на тёмном фоне.
String? scanQr(Uint8List rgba, int width, int height) {
  final pixels = Int32List(width * height);
  for (var index = 0; index < pixels.length; index++) {
    final offset = index * 4;
    pixels[index] = 0xFF000000 | rgba[offset] << 16 | rgba[offset + 1] << 8 | rgba[offset + 2];
  }
  final source = RGBLuminanceSource(width, height, pixels);
  final reader = QRCodeReader();
  for (final luminance in [source, InvertedLuminanceSource(source)]) {
    for (final bitmap in [BinaryBitmap(HybridBinarizer(luminance)), BinaryBitmap(GlobalHistogramBinarizer(luminance))]) {
      try {
        return reader.decode(bitmap, hints: DecodeHints()..put(DecodeHintType.tryHarder)).text;
      } on ReaderException {
        continue;
      }
    }
  }
  return null;
}
