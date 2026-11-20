import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show Deflate, getCrc32;

/// Zip, который пишется куском за куском: файл прочитали, сжали и сразу отдали получателю.
///
/// Резервная копия в браузере собирается так: держать её целиком в памяти вкладки нельзя,
/// а писать на диск привычным способом там нечем. Архив обычный, его читают телефон,
/// компьютер и любой распаковщик. Без zip64: до 4 ГБ и 65 535 файлов.
class ZipStreamWriter {
  ZipStreamWriter(this._sink);

  final FutureOr<void> Function(Uint8List chunk) _sink;
  final _entries = <_ZipEntry>[];
  var _offset = 0;
  var _closed = false;

  // то, что уже сжато: второй проход ничего не даст, а на большом файле стоит секунд
  static const _packed = {
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'avif', 'mp4', 'mov', 'mkv', 'webm', 'mp3', 'm4a', 'ogg', 'opus', 'aac', 'flac',
    'zip', 'gz', '7z', 'rar', 'pdf', 'docx', 'xlsx', 'pptx', 'odt', 'epub', 'apk',
  };
  static const _limit = 0xFFFFFFFF;

  /// Положить файл [name] (путь через «/») с содержимым [bytes].
  Future<void> add(String name, List<int> bytes, {DateTime? modified}) async {
    if (_closed) throw StateError('архив уже закрыт');
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final extension = name.contains('.') ? name.substring(name.lastIndexOf('.') + 1).toLowerCase() : '';
    var body = data;
    var method = 0;
    if (data.isNotEmpty && !_packed.contains(extension)) {
      final deflated = Deflate(data).getBytes();
      if (deflated.length < data.length) {
        body = deflated;
        method = 8;
      }
    }
    final entry = _ZipEntry(
      name: Uint8List.fromList(utf8.encode(name)),
      method: method,
      crc: getCrc32(data),
      packed: body.length,
      size: data.length,
      offset: _offset,
      stamp: _dosStamp(modified ?? DateTime.now()),
    );
    if (_entries.length >= 0xFFFF || _offset + body.length > _limit) throw StateError('архив больше 4 ГБ или 65 535 файлов');
    _entries.add(entry);
    await _write(entry.header(local: true));
    if (body.isNotEmpty) await _write(body);
  }

  /// Дописать оглавление. Без него архив не откроется.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final start = _offset;
    for (final entry in _entries) {
      await _write(entry.header(local: false));
    }
    final end = ByteData(22)
      ..setUint32(0, 0x06054b50, Endian.little)
      ..setUint16(8, _entries.length, Endian.little)
      ..setUint16(10, _entries.length, Endian.little)
      ..setUint32(12, _offset - start, Endian.little)
      ..setUint32(16, start, Endian.little);
    await _write(end.buffer.asUint8List());
  }

  Future<void> _write(Uint8List chunk) async {
    _offset += chunk.length;
    await _sink(chunk);
  }

  // время и дата в виде MS-DOS: секунды парами, год от 1980
  static (int, int) _dosStamp(DateTime at) {
    final year = at.year < 1980 ? 1980 : at.year;
    return ((at.hour << 11) | (at.minute << 5) | (at.second ~/ 2), ((year - 1980) << 9) | (at.month << 5) | at.day);
  }
}

class _ZipEntry {
  _ZipEntry({required this.name, required this.method, required this.crc, required this.packed, required this.size, required this.offset, required this.stamp});

  final Uint8List name;
  final int method;
  final int crc;
  final int packed;
  final int size;
  final int offset;
  final (int, int) stamp;

  /// Шапка перед содержимым ([local]) или запись оглавления.
  Uint8List header({required bool local}) {
    final fixed = local ? 30 : 46;
    final out = ByteData(fixed + name.length);
    var at = 0;
    void u16(int value) {
      out.setUint16(at, value, Endian.little);
      at += 2;
    }

    void u32(int value) {
      out.setUint32(at, value, Endian.little);
      at += 4;
    }

    u32(local ? 0x04034b50 : 0x02014b50);
    if (!local) u16(20); // чем сделан
    u16(20); // чем читать
    u16(0x0800); // имена в UTF-8
    u16(method);
    u16(stamp.$1);
    u16(stamp.$2);
    u32(crc);
    u32(packed);
    u32(size);
    u16(name.length);
    u16(0); // доп. поле
    if (!local) {
      u16(0); // комментарий
      u16(0); // том
      u16(0); // внутренние признаки
      u32(0); // внешние признаки
      u32(offset);
    }
    final bytes = out.buffer.asUint8List();
    bytes.setRange(fixed, fixed + name.length, name);
    return bytes;
  }
}
