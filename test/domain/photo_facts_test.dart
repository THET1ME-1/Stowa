import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/photo_facts.dart';

/// JPEG с блоком EXIF: камера, дата съёмки, место. Остальное содержимое файла парсеру не нужно.
List<int> jpegWithExif({String? make, String? model, String? taken, (double, double)? place}) {
  final data = ByteData(1024);
  var end = 8;
  // заголовок TIFF, байты по возрастанию
  data
    ..setUint8(0, 0x49)
    ..setUint8(1, 0x49)
    ..setUint16(2, 42, Endian.little)
    ..setUint32(4, 8, Endian.little);

  // где лежат длинные значения: после всех трёх каталогов
  var dataAt = 400;
  int text(String value) {
    final bytes = [...ascii.encode(value), 0];
    for (var index = 0; index < bytes.length; index++) {
      data.setUint8(dataAt + index, bytes[index]);
    }
    final at = dataAt;
    dataAt += bytes.length + (bytes.length.isOdd ? 1 : 0);
    return at;
  }

  int rationals(List<(int, int)> values) {
    final at = dataAt;
    for (final (top, bottom) in values) {
      data
        ..setUint32(dataAt, top, Endian.little)
        ..setUint32(dataAt + 4, bottom, Endian.little);
      dataAt += 8;
    }
    return at;
  }

  void directory(int at, List<(int, int, int, int Function())> entries) {
    data.setUint16(at, entries.length, Endian.little);
    for (final (index, (tag, type, count, value)) in entries.indexed) {
      final entry = at + 2 + index * 12;
      data
        ..setUint16(entry, tag, Endian.little)
        ..setUint16(entry + 2, type, Endian.little)
        ..setUint32(entry + 4, count, Endian.little)
        ..setUint32(entry + 8, value(), Endian.little);
    }
    data.setUint32(at + 2 + entries.length * 12, 0, Endian.little);
    end = at + 6 + entries.length * 12;
  }

  (int, int) degrees(double value) => ((value.abs() * 1000000).round(), 1000000);
  const exifAt = 100;
  const gpsAt = 200;
  directory(8, [
    if (make != null) (0x010F, 2, make.length + 1, () => text(make)),
    if (model != null) (0x0110, 2, model.length + 1, () => text(model)),
    if (taken != null) (0x8769, 4, 1, () => exifAt),
    if (place != null) (0x8825, 4, 1, () => gpsAt),
  ]);
  if (taken != null) directory(exifAt, [(0x9003, 2, 20, () => text(taken))]);
  if (place != null) {
    directory(gpsAt, [
      (1, 2, 2, () => (place.$1 < 0 ? 'S' : 'N').codeUnitAt(0)),
      (2, 5, 3, () => rationals([degrees(place.$1), (0, 1), (0, 1)])),
      (3, 2, 2, () => (place.$2 < 0 ? 'W' : 'E').codeUnitAt(0)),
      (4, 5, 3, () => rationals([degrees(place.$2), (0, 1), (0, 1)])),
    ]);
  }
  final tiff = data.buffer.asUint8List(0, end > dataAt ? end : dataAt);
  final length = tiff.length + 8;
  return [0xFF, 0xD8, 0xFF, 0xE1, length >> 8, length & 0xFF, ...ascii.encode('Exif'), 0, 0, ...tiff, 0xFF, 0xD9];
}

void main() {
  test('камера, дата съёмки и место из EXIF', () {
    final facts = photoFactsOf(jpegWithExif(make: 'Google', model: 'Pixel 8', taken: '2024:05:03 18:42:10', place: (47.0245, 28.8323)))!;
    expect(facts.camera, 'Google Pixel 8');
    expect(facts.takenAt, DateTime(2024, 5, 3, 18, 42, 10));
    expect(facts.latitude, closeTo(47.0245, 0.0001));
    expect(facts.longitude, closeTo(28.8323, 0.0001));
  });

  test('марка не повторяется в модели, юг и запад со знаком минус', () {
    final facts = photoFactsOf(jpegWithExif(make: 'Apple', model: 'Apple iPhone 15', place: (-33.86, -70.65)))!;
    expect(facts.camera, 'Apple iPhone 15');
    expect(facts.latitude, closeTo(-33.86, 0.0001));
    expect(facts.longitude, closeTo(-70.65, 0.0001));
  });

  test('без EXIF и с битым файлом — null', () {
    expect(photoFactsOf([0xFF, 0xD8, 0xFF, 0xD9]), isNull);
    expect(photoFactsOf([1, 2, 3]), isNull);
  });

  group('скриншот или фото', () {
    test('по имени файла на любом языке', () {
      for (final name in ['Screenshot_20261104-103000.png', 'Снимок экрана 2026-11-04.png', 'Bildschirmfoto 2026.png', 'Captura de pantalla.png', 'zrzut ekranu.png', 'Скриншот.jpg']) {
        expect(looksLikeScreenshot(fileName: name, mime: 'image/png'), isTrue, reason: name);
      }
    });

    test('PNG без камеры с пропорциями экрана — скриншот, снимок с камеры — нет', () {
      expect(looksLikeScreenshot(fileName: 'IMG_0042.PNG', mime: 'image/png', width: 1179, height: 2556), isTrue);
      expect(looksLikeScreenshot(fileName: 'IMG_0042.PNG', mime: 'image/png', width: 800, height: 800), isFalse);
      expect(looksLikeScreenshot(fileName: 'IMG_0042.jpg', mime: 'image/jpeg', width: 1179, height: 2556, camera: 'Apple iPhone 15'), isFalse);
      expect(looksLikeScreenshot(fileName: 'photo.jpg', mime: 'image/jpeg', width: 3000, height: 4000), isFalse);
    });
  });
}
