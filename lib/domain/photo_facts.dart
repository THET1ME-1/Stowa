/// Что фото знает о себе: когда и чем снято, где. Из EXIF, без декодирования картинки.
/// И скриншот это или снимок камеры.
library;

/// Сведения из EXIF. Чего в файле нет — null.
class PhotoFacts {
  const PhotoFacts({this.takenAt, this.camera, this.latitude, this.longitude});

  final DateTime? takenAt;

  /// «Google Pixel 8»: марка и модель без повтора.
  final String? camera;
  final double? latitude;
  final double? longitude;

  bool get isEmpty => takenAt == null && camera == null && latitude == null;
}

/// EXIF из начала JPEG: хватает первых 256 КБ. Нет EXIF или файл битый — null.
PhotoFacts? photoFactsOf(List<int> bytes) {
  try {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
    var at = 2;
    while (at + 4 < bytes.length) {
      if (bytes[at] != 0xFF) return null;
      final marker = bytes[at + 1];
      if (marker == 0xD9 || marker == 0xDA) return null;
      final length = bytes[at + 2] << 8 | bytes[at + 3];
      if (marker == 0xE1 && String.fromCharCodes(bytes.sublist(at + 4, at + 8)) == 'Exif') {
        final facts = _Tiff(bytes, at + 10).facts();
        return facts.isEmpty ? null : facts;
      }
      at += 2 + length;
    }
  } on RangeError {
    // файл оборвался посреди заголовка
  } on FormatException {
    // в тексте EXIF мусор
  }
  return null;
}

class _Tiff {
  _Tiff(this.bytes, this.start) : little = bytes[start] == 0x49;

  final List<int> bytes;
  final int start;
  final bool little;

  int u16(int at) => little ? bytes[at] | bytes[at + 1] << 8 : bytes[at] << 8 | bytes[at + 1];
  int u32(int at) => little
      ? bytes[at] | bytes[at + 1] << 8 | bytes[at + 2] << 16 | bytes[at + 3] << 24
      : bytes[at] << 24 | bytes[at + 1] << 16 | bytes[at + 2] << 8 | bytes[at + 3];

  /// Записи каталога: метка → место записи.
  Map<int, int> directory(int offset) {
    final at = start + offset;
    final count = u16(at);
    return {for (var index = 0; index < count; index++) u16(at + 2 + index * 12): at + 2 + index * 12};
  }

  String? text(Map<int, int> entries, int tag) {
    final entry = entries[tag];
    if (entry == null) return null;
    final count = u32(entry + 4);
    final at = count <= 4 ? entry + 8 : start + u32(entry + 8);
    final value = String.fromCharCodes(bytes.sublist(at, at + count)).replaceAll('\u0000', '').trim();
    return value.isEmpty ? null : value;
  }

  int? long(Map<int, int> entries, int tag) {
    final entry = entries[tag];
    return entry == null ? null : u32(entry + 8);
  }

  // градусы, минуты, секунды тремя дробями
  double? degrees(Map<int, int> entries, int tag) {
    final entry = entries[tag];
    if (entry == null) return null;
    final at = start + u32(entry + 8);
    double part(int index) {
      final bottom = u32(at + index * 8 + 4);
      return bottom == 0 ? 0 : u32(at + index * 8) / bottom;
    }

    return part(0) + part(1) / 60 + part(2) / 3600;
  }

  PhotoFacts facts() {
    final main = directory(u32(start + 4));
    final make = text(main, 0x010F);
    final model = text(main, 0x0110);
    final camera = switch ((make, model)) {
      (null, null) => null,
      (final make?, null) => make,
      (null, final model?) => model,
      (final make?, final model?) => model.toLowerCase().startsWith(make.toLowerCase()) ? model : '$make $model',
    };
    final exifAt = long(main, 0x8769);
    final exif = exifAt == null ? const <int, int>{} : directory(exifAt);
    final taken = _date(text(exif, 0x9003) ?? text(main, 0x0132));
    double? latitude;
    double? longitude;
    final gpsAt = long(main, 0x8825);
    if (gpsAt != null) {
      final gps = directory(gpsAt);
      final north = degrees(gps, 2);
      final east = degrees(gps, 4);
      if (north != null && east != null && (north != 0 || east != 0)) {
        latitude = text(gps, 1) == 'S' ? -north : north;
        longitude = text(gps, 3) == 'W' ? -east : east;
      }
    }
    return PhotoFacts(takenAt: taken, camera: camera, latitude: latitude, longitude: longitude);
  }
}

// «2024:05:03 18:42:10» — время телефона, без пояса
DateTime? _date(String? value) {
  final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})').firstMatch(value ?? '');
  if (match == null) return null;
  final parts = [for (var index = 1; index <= 6; index++) int.parse(match.group(index)!)];
  if (parts[0] < 1990) return null;
  return DateTime(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
}

final _screenshotName = RegExp(
  r'screen ?shot|screen_shot|скриншот|снимок экрана|знімок екрана|скріншот|bildschirmfoto|captura de pantalla|captură de ecran|captura|zrzut ekranu',
  caseSensitive: false,
);

/// Скриншот, а не снимок камеры: по имени файла на любом языке, или PNG без камеры
/// с пропорциями экрана телефона.
bool looksLikeScreenshot({required String fileName, required String mime, int? width, int? height, String? camera}) {
  if (_screenshotName.hasMatch(fileName)) return true;
  if (camera != null || mime != 'image/png' || width == null || height == null) return false;
  final long = width > height ? width : height;
  final short = width > height ? height : width;
  return short >= 640 && long / short >= 1.6;
}
