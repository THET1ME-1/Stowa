/// Размер картинки по первым байтам файла, без декодирования: доске нужна
/// пропорция заранее, чтобы колонки сошлись и ничего не прыгало при загрузке.
/// Снимок, повёрнутый в EXIF, отдаёт размер как на экране. Не узнал — null.
({int width, int height})? imageSizeOf(List<int> bytes) {
  try {
    if (_starts(bytes, [0x89, 0x50, 0x4E, 0x47])) return (width: _be32(bytes, 16), height: _be32(bytes, 20));
    if (_starts(bytes, [0x47, 0x49, 0x46, 0x38])) return (width: _le16(bytes, 6), height: _le16(bytes, 8));
    if (_starts(bytes, [0x52, 0x49, 0x46, 0x46]) && String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') return _webp(bytes);
    if (_starts(bytes, [0xFF, 0xD8])) return _jpeg(bytes);
  } on RangeError {
    // файл оборвался посреди заголовка
  }
  return null;
}

bool _starts(List<int> bytes, List<int> magic) {
  if (bytes.length < magic.length) return false;
  for (var index = 0; index < magic.length; index++) {
    if (bytes[index] != magic[index]) return false;
  }
  return true;
}

int _be16(List<int> b, int at) => b[at] << 8 | b[at + 1];
int _be32(List<int> b, int at) => b[at] << 24 | b[at + 1] << 16 | b[at + 2] << 8 | b[at + 3];
int _le16(List<int> b, int at) => b[at] | b[at + 1] << 8;
int _le24(List<int> b, int at) => b[at] | b[at + 1] << 8 | b[at + 2] << 16;

({int width, int height})? _webp(List<int> b) {
  final chunk = String.fromCharCodes(b.sublist(12, 16));
  switch (chunk) {
    case 'VP8 ':
      return (width: _le16(b, 26) & 0x3FFF, height: _le16(b, 28) & 0x3FFF);
    case 'VP8L':
      final bits = b[21] | b[22] << 8 | b[23] << 16 | b[24] << 24;
      return (width: (bits & 0x3FFF) + 1, height: ((bits >> 14) & 0x3FFF) + 1);
    case 'VP8X':
      return (width: _le24(b, 24) + 1, height: _le24(b, 27) + 1);
  }
  return null;
}

({int width, int height})? _jpeg(List<int> b) {
  var orientation = 1;
  var at = 2;
  while (at + 9 < b.length) {
    if (b[at] != 0xFF) return null;
    final marker = b[at + 1];
    // заполнители и маркеры без длины
    if (marker == 0xFF) {
      at++;
      continue;
    }
    if (marker >= 0xD0 && marker <= 0xD9) {
      at += 2;
      continue;
    }
    final length = _be16(b, at + 2);
    if (marker == 0xE1 && String.fromCharCodes(b.sublist(at + 4, at + 8)) == 'Exif') orientation = _exifOrientation(b, at + 10) ?? orientation;
    // SOF0–SOF15 кроме DHT, JPG и DAC: там высота и ширина кадра
    final frame = marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC;
    if (frame) {
      final height = _be16(b, at + 5);
      final width = _be16(b, at + 7);
      // 5–8: кадр лежит боком, на экране стороны меняются местами
      return orientation >= 5 && orientation <= 8 ? (width: height, height: width) : (width: width, height: height);
    }
    at += 2 + length;
  }
  return null;
}

int? _exifOrientation(List<int> b, int tiff) {
  final little = b[tiff] == 0x49;
  int u16(int at) => little ? _le16(b, at) : _be16(b, at);
  int u32(int at) => little ? (b[at] | b[at + 1] << 8 | b[at + 2] << 16 | b[at + 3] << 24) : _be32(b, at);
  final ifd = tiff + u32(tiff + 4);
  final count = u16(ifd);
  for (var entry = 0; entry < count; entry++) {
    final at = ifd + 2 + entry * 12;
    if (u16(at) == 0x0112) return u16(at + 8);
  }
  return null;
}
