/// Текстовый слой PDF без движка: объекты, сжатие Flate, страницы по дереву, шрифты
/// с таблицей `ToUnicode` и простые шрифты WinAnsi. Скан без текста и зашифрованный
/// файл дают пустой список, а не ошибку.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Текст каждой страницы по порядку. Страница без текста — пустая строка.
List<String> pdfPages(Uint8List bytes) {
  try {
    final file = _PdfFile(bytes);
    if (file.encrypted) return const [];
    return [for (final page in file.pages()) file.pageText(page)];
  } catch (_) {
    // битый файл: заметка остаётся, просто без текста
    return const [];
  }
}

// --- значения PDF -------------------------------------------------------------

class _Name {
  const _Name(this.value);
  final String value;
}

class _Ref {
  const _Ref(this.number);
  final int number;
}

class _Op {
  const _Op(this.value);
  final String value;
}

class _Stream {
  _Stream(this.dictionary, this.data);
  final Map<String, Object?> dictionary;
  final List<int> data;
}

const _whitespace = {0, 9, 10, 12, 13, 32};
const _delimiters = {40, 41, 60, 62, 91, 93, 123, 125, 47, 37};

/// Разбор значений PDF по тексту файла: каждый байт — один знак latin1.
class _Lexer {
  _Lexer(this.text, [this.position = 0]);

  final String text;
  int position;

  bool get done {
    _skip();
    return position >= text.length;
  }

  void _skip() {
    while (position < text.length) {
      final char = text.codeUnitAt(position);
      if (_whitespace.contains(char)) {
        position++;
      } else if (char == 37) {
        // комментарий до конца строки
        while (position < text.length && text.codeUnitAt(position) != 10 && text.codeUnitAt(position) != 13) {
          position++;
        }
      } else {
        return;
      }
    }
  }

  /// Следующее значение; в потоке страницы — и операторы. Ссылку «12 0 R» собирает сам.
  Object? next() {
    _skip();
    if (position >= text.length) throw const FormatException('конец');
    final char = text.codeUnitAt(position);
    if (char == 60 && _at(position + 1) == 60) {
      position += 2;
      return _dictionary();
    }
    if (char == 60) return _hex();
    if (char == 91) {
      position++;
      final items = <Object?>[];
      while (true) {
        _skip();
        if (position >= text.length) return items;
        if (text.codeUnitAt(position) == 93) {
          position++;
          return items;
        }
        items.add(next());
      }
    }
    if (char == 40) return _literal();
    if (char == 47) return _name();
    if (char == 62 || char == 93 || char == 41 || char == 123 || char == 125) {
      // одинокая закрывающая — мусор, пропускается
      position++;
      return _Op(String.fromCharCode(char));
    }
    final word = _word();
    final number = num.tryParse(word);
    if (number != null) {
      // «12 0 R» — ссылка на объект
      if (number is int) {
        final saved = position;
        _skip();
        final generation = _wordAt();
        if (generation != null && int.tryParse(generation) != null) {
          position += generation.length;
          _skip();
          if (_at(position) == 82 && (position + 1 >= text.length || !_isRegular(text.codeUnitAt(position + 1)))) {
            position++;
            return _Ref(number);
          }
        }
        position = saved;
      }
      return number;
    }
    return switch (word) {
      'true' => true,
      'false' => false,
      'null' => null,
      _ => _Op(word),
    };
  }

  int? _at(int index) => index < text.length ? text.codeUnitAt(index) : null;

  static bool _isRegular(int char) => !_whitespace.contains(char) && !_delimiters.contains(char);

  String? _wordAt() {
    var end = position;
    while (end < text.length && _isRegular(text.codeUnitAt(end))) {
      end++;
    }
    return end == position ? null : text.substring(position, end);
  }

  String _word() {
    final start = position;
    while (position < text.length && _isRegular(text.codeUnitAt(position))) {
      position++;
    }
    if (position == start) position++;
    return text.substring(start, position);
  }

  Map<String, Object?> _dictionary() {
    final map = <String, Object?>{};
    while (true) {
      _skip();
      if (position >= text.length) return map;
      if (text.codeUnitAt(position) == 62 && _at(position + 1) == 62) {
        position += 2;
        return map;
      }
      final key = next();
      if (key is! _Name) continue;
      _skip();
      if (_at(position) == 62 && _at(position + 1) == 62) return map;
      map[key.value] = next();
    }
  }

  _Name _name() {
    position++;
    final out = StringBuffer();
    while (position < text.length && _isRegular(text.codeUnitAt(position))) {
      final char = text.codeUnitAt(position);
      if (char == 35 && position + 2 < text.length) {
        final code = int.tryParse(text.substring(position + 1, position + 3), radix: 16);
        if (code != null) {
          out.writeCharCode(code);
          position += 3;
          continue;
        }
      }
      out.writeCharCode(char);
      position++;
    }
    return _Name(out.toString());
  }

  List<int> _hex() {
    position++;
    final digits = StringBuffer();
    while (position < text.length && text.codeUnitAt(position) != 62) {
      final char = text[position];
      if (RegExp('[0-9a-fA-F]').hasMatch(char)) digits.write(char);
      position++;
    }
    position++;
    var hex = digits.toString();
    if (hex.length.isOdd) hex = '${hex}0';
    return [for (var index = 0; index < hex.length; index += 2) int.parse(hex.substring(index, index + 2), radix: 16)];
  }

  List<int> _literal() {
    position++;
    final out = <int>[];
    var depth = 1;
    while (position < text.length) {
      final char = text.codeUnitAt(position++);
      if (char == 92 && position < text.length) {
        final escaped = text.codeUnitAt(position++);
        switch (escaped) {
          case 110:
            out.add(10);
          case 114:
            out.add(13);
          case 116:
            out.add(9);
          case 98:
            out.add(8);
          case 102:
            out.add(12);
          case 13:
            // перенос строки после «\» — продолжение строки
            if (_at(position) == 10) position++;
          case 10:
            break;
          default:
            if (escaped >= 48 && escaped <= 55) {
              var code = escaped - 48;
              for (var digit = 0; digit < 2 && position < text.length; digit++) {
                final next = text.codeUnitAt(position);
                if (next < 48 || next > 55) break;
                code = code * 8 + next - 48;
                position++;
              }
              out.add(code & 0xFF);
            } else {
              out.add(escaped);
            }
        }
      } else if (char == 40) {
        depth++;
        out.add(char);
      } else if (char == 41) {
        depth--;
        if (depth == 0) break;
        out.add(char);
      } else {
        out.add(char);
      }
    }
    return out;
  }
}

// --- файл ---------------------------------------------------------------------

class _PdfFile {
  _PdfFile(this._bytes) : _text = latin1.decode(_bytes, allowInvalid: true) {
    _scan();
  }

  final Uint8List _bytes;
  final String _text;

  /// Объект по номеру и где он в файле: определение ниже по файлу главнее.
  final _objects = <int, ({int at, Object? value})>{};
  final _trailers = <Map<String, Object?>>[];
  final _fonts = <Object, _Font>{};

  bool get encrypted => _trailers.any((trailer) => trailer.containsKey('Encrypt'));

  static final _objectHead = RegExp(r'(\d+)\s+(\d+)\s+obj\b');

  void _scan() {
    final streams = <({int at, _Stream stream})>[];
    for (final match in _objectHead.allMatches(_text)) {
      final number = int.parse(match.group(1)!);
      final lexer = _Lexer(_text, match.end);
      Object? value;
      try {
        value = lexer.next();
      } catch (_) {
        continue;
      }
      if (value is Map<String, Object?>) {
        final data = _streamData(lexer, value);
        if (data != null) {
          final stream = _Stream(value, data);
          final type = value['Type'];
          if (type is _Name && type.value == 'ObjStm') streams.add((at: match.start, stream: stream));
          if (type is _Name && type.value == 'XRef') _trailers.add(value);
          value = stream;
        }
      }
      _put(number, match.start, value);
    }
    for (final match in RegExp(r'trailer\s*<<').allMatches(_text)) {
      try {
        final trailer = _Lexer(_text, match.end - 2).next();
        if (trailer is Map<String, Object?>) _trailers.add(trailer);
      } catch (_) {
        continue;
      }
    }
    // объекты из сжатых потоков стоят там, где их поток
    for (final (:at, :stream) in streams) {
      _unpack(at, stream);
    }
  }

  void _put(int number, int at, Object? value) {
    final known = _objects[number];
    if (known == null || known.at <= at) _objects[number] = (at: at, value: value);
  }

  // данные потока после словаря: по /Length, если она числом и сходится, иначе до «endstream»
  List<int>? _streamData(_Lexer lexer, Map<String, Object?> dictionary) {
    var start = lexer.position;
    while (start < _text.length && _whitespace.contains(_text.codeUnitAt(start)) && _text.codeUnitAt(start) != 13 && _text.codeUnitAt(start) != 10) {
      start++;
    }
    while (start < _text.length && (_text.codeUnitAt(start) == 13 || _text.codeUnitAt(start) == 10 || _text.codeUnitAt(start) == 32)) {
      start++;
    }
    if (!_text.startsWith('stream', start)) return null;
    start += 6;
    if (_text.startsWith('\r\n', start)) {
      start += 2;
    } else if (start < _text.length && (_text.codeUnitAt(start) == 10 || _text.codeUnitAt(start) == 13)) {
      start += 1;
    }
    final length = dictionary['Length'];
    if (length is int && start + length <= _bytes.length) {
      final tail = _text.substring(start + length, min(_text.length, start + length + 12)).trimLeft();
      if (tail.startsWith('endstream')) return Uint8List.sublistView(_bytes, start, start + length);
    }
    final end = _text.indexOf('endstream', start);
    if (end < 0) return null;
    var stop = end;
    while (stop > start && (_text.codeUnitAt(stop - 1) == 10 || _text.codeUnitAt(stop - 1) == 13)) {
      stop--;
    }
    return Uint8List.sublistView(_bytes, start, stop);
  }

  void _unpack(int at, _Stream stream) {
    final data = _decoded(stream);
    if (data == null) return;
    final text = latin1.decode(data, allowInvalid: true);
    final count = _number(stream.dictionary['N'])?.toInt() ?? 0;
    final first = _number(stream.dictionary['First'])?.toInt() ?? 0;
    final header = _Lexer(text);
    final entries = <(int, int)>[];
    for (var index = 0; index < count; index++) {
      final number = header.next();
      final offset = header.next();
      if (number is! int || offset is! int) break;
      entries.add((number, offset));
    }
    for (final (number, offset) in entries) {
      try {
        // чуть дальше потока: внутри него объекты новее объявленных до него
        _put(number, at + 1, _Lexer(text, first + offset).next());
      } catch (_) {
        continue;
      }
    }
  }

  Object? resolve(Object? value, [int depth = 0]) {
    var current = value;
    var hops = 0;
    while (current is _Ref && hops++ < 32) {
      current = _objects[current.number]?.value;
    }
    return current;
  }

  Map<String, Object?>? _dict(Object? value) => switch (resolve(value)) {
    final Map<String, Object?> map => map,
    final _Stream stream => stream.dictionary,
    _ => null,
  };

  static num? _number(Object? value) => value is num ? value : null;

  String? _nameOf(Object? value) => switch (resolve(value)) {
    final _Name name => name.value,
    _ => null,
  };

  /// Данные потока без сжатия; неизвестное сжатие — null.
  List<int>? _decoded(_Stream stream) {
    final filter = resolve(stream.dictionary['Filter']);
    final filters = [
      if (filter is _Name) filter.value,
      if (filter is List) for (final one in filter) ?_nameOf(one),
    ];
    var data = stream.data;
    for (final name in filters) {
      switch (name) {
        case 'FlateDecode' || 'Fl':
          data = _inflate(data);
        case 'ASCIIHexDecode' || 'AHx':
          data = _Lexer('<${latin1.decode(data, allowInvalid: true)}>')._hex();
        default:
          return null;
      }
    }
    return data;
  }

  static List<int> _inflate(List<int> data) {
    try {
      return const ZLibDecoder().decodeBytes(data);
    } catch (_) {
      // поток без заголовка zlib или с оборванным хвостом: голый deflate
      return Inflate(data.length > 2 ? data.sublist(2) : data).getBytes();
    }
  }

  // --- страницы ---------------------------------------------------------------

  /// Страницы по дереву каталога с унаследованными ресурсами. Каталога нет — все
  /// объекты-страницы по номерам.
  List<({Map<String, Object?> page, Map<String, Object?>? resources})> pages() {
    Map<String, Object?>? catalog;
    for (final trailer in _trailers.reversed) {
      catalog = _dict(trailer['Root']);
      if (catalog != null) break;
    }
    catalog ??= _objects.values.map((one) => one.value).whereType<Map<String, Object?>>().where((map) => _nameOf(map['Type']) == 'Catalog').firstOrNull;
    final found = <({Map<String, Object?> page, Map<String, Object?>? resources})>[];
    final seen = <Map<String, Object?>>{};
    void walk(Object? node, Map<String, Object?>? inherited) {
      final dictionary = _dict(node);
      if (dictionary == null || !seen.add(dictionary)) return;
      final resources = _dict(dictionary['Resources']) ?? inherited;
      final kids = resolve(dictionary['Kids']);
      if (kids is List) {
        for (final kid in kids) {
          walk(kid, resources);
        }
      } else if (_nameOf(dictionary['Type']) != 'Pages') {
        found.add((page: dictionary, resources: resources));
      }
    }

    if (catalog != null) walk(catalog['Pages'], null);
    if (found.isNotEmpty) return found;
    final numbers = _objects.keys.toList()..sort();
    return [
      for (final number in numbers)
        if (_dict(_objects[number]!.value) case final page? when _nameOf(page['Type']) == 'Page') (page: page, resources: _inheritedResources(page)),
    ];
  }

  Map<String, Object?>? _inheritedResources(Map<String, Object?> page) {
    Map<String, Object?>? node = page;
    for (var depth = 0; node != null && depth < 32; depth++) {
      final resources = _dict(node['Resources']);
      if (resources != null) return resources;
      node = _dict(node['Parent']);
    }
    return null;
  }

  String pageText(({Map<String, Object?> page, Map<String, Object?>? resources}) page) {
    final contents = resolve(page.page['Contents']);
    final parts = [
      if (contents is _Stream) contents,
      if (contents is List)
        for (final one in contents)
          if (resolve(one) case final _Stream stream) stream,
    ];
    final data = <int>[];
    for (final stream in parts) {
      final decoded = _decoded(stream);
      if (decoded == null) continue;
      data
        ..addAll(decoded)
        ..add(10);
    }
    if (data.isEmpty) return '';
    return _TextRun(this, page.resources).read(latin1.decode(data, allowInvalid: true));
  }

  /// Форма из ресурсов по имени (`Do`): её поток и её ресурсы; не форма — null.
  ({String content, Map<String, Object?>? resources})? form(Map<String, Object?>? resources, String name) {
    final stream = resolve(_dict(resources?['XObject'])?[name]);
    if (stream is! _Stream || _nameOf(stream.dictionary['Subtype']) != 'Form') return null;
    final data = _decoded(stream);
    if (data == null) return null;
    return (content: latin1.decode(data, allowInvalid: true), resources: _dict(stream.dictionary['Resources']) ?? resources);
  }

  _Font font(Object? reference) {
    final key = reference is _Ref ? reference.number : reference ?? 'none';
    return _fonts[key] ??= _Font.of(this, _dict(reference));
  }
}

// --- шрифты -------------------------------------------------------------------

/// Как коды строки становятся буквами: по таблице `ToUnicode`, по кодировке простого
/// шрифта, у составного шрифта без таблицы — никак (номера глифов не буквы).
class _Font {
  _Font(this.width, this.map, {this.simple = false, this.differences = const {}, this.advances = const {}, this.defaultAdvance = 500});

  /// Сколько байт в коде буквы: 1 у простых шрифтов, 2 у составных.
  final int width;
  final Map<int, String> map;
  final bool simple;
  final Map<int, String> differences;

  /// Ширина буквы по коду в тысячных кегля: по ней видно, где кончилось слово.
  final Map<int, double> advances;
  final double defaultAdvance;

  _Font withAdvances(Map<int, double> advances, double defaultAdvance) =>
      _Font(width, map, simple: simple, differences: differences, advances: advances, defaultAdvance: defaultAdvance);

  static _Font of(_PdfFile file, Map<String, Object?>? font) {
    final base = _bare(file, font);
    if (font == null) return base;
    final advances = <int, double>{};
    if (!base.simple) {
      // составной: ширины у шрифта-потомка, «W» вида [код [ширины…]] и [от до ширина]
      final descendants = file.resolve(font['DescendantFonts']);
      final cid = file._dict(descendants is List && descendants.isNotEmpty ? descendants.first : null);
      final list = (file.resolve(cid?['W']) as List?) ?? const [];
      for (var index = 0; index < list.length;) {
        final first = file.resolve(list[index]);
        final next = index + 1 < list.length ? file.resolve(list[index + 1]) : null;
        if (first is int && next is List) {
          for (final (offset, value) in next.indexed) {
            final number = file.resolve(value);
            if (number is num) advances[first + offset] = number.toDouble();
          }
          index += 2;
        } else if (first is int && next is int && index + 2 < list.length && file.resolve(list[index + 2]) is num) {
          final value = (file.resolve(list[index + 2])! as num).toDouble();
          for (var code = first; code <= next && code - first < 0xFFFF; code++) {
            advances[code] = value;
          }
          index += 3;
        } else {
          index++;
        }
      }
      return base.withAdvances(advances, (file.resolve(cid?['DW']) as num?)?.toDouble() ?? 1000);
    }
    final firstChar = (file.resolve(font['FirstChar']) as num?)?.toInt() ?? 0;
    for (final (offset, value) in ((file.resolve(font['Widths']) as List?) ?? const []).indexed) {
      final number = file.resolve(value);
      if (number is num) advances[firstChar + offset] = number.toDouble();
    }
    return base.withAdvances(advances, 500);
  }

  static _Font _bare(_PdfFile file, Map<String, Object?>? font) {
    if (font == null) return _Font(1, const {}, simple: true);
    final composite = file._nameOf(font['Subtype']) == 'Type0';
    final toUnicode = file.resolve(font['ToUnicode']);
    final differences = <int, String>{};
    final encoding = file.resolve(font['Encoding']);
    if (encoding is Map<String, Object?>) {
      var code = 0;
      for (final entry in (file.resolve(encoding['Differences']) as List?) ?? const []) {
        if (entry is int) {
          code = entry;
        } else if (entry is _Name) {
          final char = _glyph(entry.value);
          if (char != null) differences[code] = char;
          code++;
        }
      }
    }
    if (toUnicode is _Stream) {
      final data = file._decoded(toUnicode);
      if (data != null) {
        final cmap = _cmap(latin1.decode(data, allowInvalid: true), composite ? 2 : 1);
        return _Font(cmap.width, cmap.map, simple: !composite, differences: differences);
      }
    }
    return _Font(composite ? 2 : 1, const {}, simple: !composite, differences: differences);
  }

  /// Буквы строки и сколько она занимает в тысячных кегля.
  ({String text, double advance}) decode(List<int> bytes) {
    final out = StringBuffer();
    var advance = 0.0;
    for (var index = 0; index + width <= bytes.length; index += width) {
      var code = 0;
      for (var byte = 0; byte < width; byte++) {
        code = code << 8 | bytes[index + byte];
      }
      advance += advances[code] ?? defaultAdvance;
      final char = map[code] ?? differences[code] ?? (simple ? _winAnsi(code) : null);
      if (char != null) out.write(char);
    }
    return (text: out.toString(), advance: advance);
  }

  static final _block = RegExp(r'begin(bfchar|bfrange|codespacerange)([\s\S]*?)end\1');
  static final _hexToken = RegExp(r'<([0-9a-fA-F\s]*)>|\[|\]');

  static ({int width, Map<int, String> map}) _cmap(String text, int fallbackWidth) {
    var width = fallbackWidth;
    final map = <int, String>{};
    for (final block in _block.allMatches(text)) {
      final tokens = [for (final token in _hexToken.allMatches(block.group(2)!)) token.group(1)?.replaceAll(RegExp(r'\s'), '') ?? token.group(0)!];
      switch (block.group(1)) {
        case 'codespacerange':
          if (tokens.isNotEmpty) width = max(1, tokens.first.length ~/ 2);
        case 'bfchar':
          for (var index = 0; index + 1 < tokens.length; index += 2) {
            final code = int.tryParse(tokens[index], radix: 16);
            if (code != null) map[code] = _utf16(tokens[index + 1]);
          }
        case 'bfrange':
          var index = 0;
          while (index + 2 < tokens.length) {
            final low = int.tryParse(tokens[index], radix: 16);
            final high = int.tryParse(tokens[index + 1], radix: 16);
            if (low == null || high == null || high - low > 0xFFFF) {
              index++;
              continue;
            }
            if (tokens[index + 2] == '[') {
              var item = index + 3;
              for (var code = low; code <= high && item < tokens.length && tokens[item] != ']'; code++, item++) {
                map[code] = _utf16(tokens[item]);
              }
              while (item < tokens.length && tokens[item] != ']') {
                item++;
              }
              index = item + 1;
            } else {
              final start = _utf16Units(tokens[index + 2]);
              for (var code = low; code <= high; code++) {
                if (start.isEmpty) break;
                final units = [...start];
                units[units.length - 1] += code - low;
                map[code] = String.fromCharCodes(units);
              }
              index += 3;
            }
          }
      }
    }
    return (width: width, map: map);
  }

  static List<int> _utf16Units(String hex) => [
    for (var index = 0; index + 4 <= hex.length; index += 4) int.parse(hex.substring(index, index + 4), radix: 16),
    if (hex.length == 2) int.parse(hex, radix: 16),
  ];

  static String _utf16(String hex) => String.fromCharCodes(_utf16Units(hex));

  // WinAnsi: верхняя половина как latin1, кроме 0x80–0x9F
  static const _winAnsiHigh = {
    0x80: '€', 0x82: '‚', 0x83: 'ƒ', 0x84: '„', 0x85: '…', 0x86: '†', 0x87: '‡', 0x88: 'ˆ', 0x89: '‰', 0x8A: 'Š', 0x8B: '‹', 0x8C: 'Œ', 0x8E: 'Ž', //
    0x91: '‘', 0x92: '’', 0x93: '“', 0x94: '”', 0x95: '•', 0x96: '–', 0x97: '—', 0x98: '˜', 0x99: '™', 0x9A: 'š', 0x9B: '›', 0x9C: 'œ', 0x9E: 'ž', 0x9F: 'Ÿ',
  };

  static String? _winAnsi(int code) {
    if (code < 32) return code == 9 || code == 10 ? ' ' : null;
    if (code < 0x80 || code >= 0xA0) return code <= 0xFF ? String.fromCharCode(code) : null;
    return _winAnsiHigh[code];
  }

  static const _named = {
    'space': ' ', 'exclam': '!', 'quotedbl': '"', 'numbersign': '#', 'dollar': r'$', 'percent': '%', 'ampersand': '&', 'quotesingle': "'", //
    'parenleft': '(', 'parenright': ')', 'asterisk': '*', 'plus': '+', 'comma': ',', 'hyphen': '-', 'period': '.', 'slash': '/', 'colon': ':',
    'semicolon': ';', 'less': '<', 'equal': '=', 'greater': '>', 'question': '?', 'at': '@', 'bracketleft': '[', 'backslash': r'\', 'bracketright': ']',
    'underscore': '_', 'quoteleft': '‘', 'quoteright': '’', 'quotedblleft': '“', 'quotedblright': '”', 'endash': '–', 'emdash': '—', 'bullet': '•',
    'ellipsis': '…', 'guillemotleft': '«', 'guillemotright': '»', 'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
    'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'numero': '№', 'afii61352': '№',
  };

  /// Буква по имени глифа: латиница одной буквой, `uni0416`, кириллица Adobe `afii10017`.
  static String? _glyph(String name) {
    if (name.length == 1) return name;
    final known = _named[name];
    if (known != null) return known;
    final unicode = RegExp(r'^uni([0-9A-Fa-f]{4})$').firstMatch(name) ?? RegExp(r'^u([0-9A-Fa-f]{4,6})$').firstMatch(name);
    if (unicode != null) return String.fromCharCode(int.parse(unicode.group(1)!, radix: 16));
    final afii = RegExp(r'^afii(\d{5})$').firstMatch(name);
    if (afii != null) {
      final code = int.parse(afii.group(1)!);
      if (code == 10023) return 'Ё';
      if (code == 10071) return 'ё';
      if (code >= 10017 && code <= 10022) return String.fromCharCode(0x0410 + code - 10017);
      if (code >= 10024 && code <= 10049) return String.fromCharCode(0x0416 + code - 10024);
      if (code >= 10065 && code <= 10070) return String.fromCharCode(0x0430 + code - 10065);
      if (code >= 10072 && code <= 10097) return String.fromCharCode(0x0436 + code - 10072);
    }
    return null;
  }
}

// --- поток страницы -----------------------------------------------------------

/// Текст из операторов страницы. Пробелы и переносы — по сдвигам: другая строка по высоте —
/// перенос; прыжок вправо дальше, чем кончилось слово по ширинам букв шрифта, или большой
/// отступ в `TJ` — пробел.
class _TextRun {
  _TextRun(this._file, this._resources);

  final _PdfFile _file;
  Map<String, Object?>? _resources;
  final _out = StringBuffer();

  /// Глубина вложенных форм: форма в форме бывает, бесконечная — нет.
  int _depth = 0;

  Map<String, Object?> get _fonts => _file._dict(_resources?['Font']) ?? const {};

  _Font? _font;
  double _size = 12;
  double _scale = 1;
  double _lineX = 0;
  double _lineY = 0;
  double _cursor = 0;
  var _gap = _Gap.none;

  /// Только что начался блок `BT`: положение текста — начало страницы.
  var _origin = true;

  double get _em => (_size * _scale).abs().clamp(1, 1000).toDouble();

  String read(String content) {
    _run(content);
    return _out
        .toString()
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  void _run(String content) {
    final lexer = _Lexer(content);
    final operands = <Object?>[];
    while (!lexer.done) {
      Object? token;
      try {
        token = lexer.next();
      } catch (_) {
        break;
      }
      if (token is! _Op) {
        operands.add(token);
        continue;
      }
      if (token.value == 'ID') {
        // картинка внутри потока: двоичное до «EI» пропускается
        final end = RegExp(r'\sEI(\s|$)').firstMatch(content.substring(lexer.position));
        lexer.position = end == null ? content.length : lexer.position + end.end;
      } else if (token.value == 'Do' && operands.firstOrNull is _Name && _depth < 8) {
        // текст внутри формы: Chrome, Skia и TeX кладут туда целые страницы
        final form = _file.form(_resources, (operands.first! as _Name).value);
        if (form != null) {
          final outer = _resources;
          _resources = form.resources;
          _depth++;
          _run(form.content);
          _depth--;
          _resources = outer;
        }
      } else {
        _apply(token.value, operands);
      }
      operands.clear();
    }
  }

  double _n(List<Object?> operands, int index) => index < operands.length && operands[index] is num ? (operands[index]! as num).toDouble() : 0;

  void _apply(String op, List<Object?> operands) {
    switch (op) {
      // новый блок текста начинает с начала страницы: следующий Td отсчитывается от нуля
      case 'BT':
        _origin = true;
      case 'Tf':
        if (operands.isNotEmpty && operands.first is _Name) {
          final name = (operands.first! as _Name).value;
          _font = _file.font(_fonts[name]);
        }
        _size = _n(operands, 1) == 0 ? _size : _n(operands, 1);
      case 'Td' || 'TD':
        if (_origin) {
          _scale = 1;
          _moveTo(_n(operands, 0), _n(operands, 1));
        } else {
          _moveTo(_lineX + _n(operands, 0) * _scale, _lineY + _n(operands, 1) * _scale);
        }
      case 'Tm':
        _scale = _n(operands, 0).abs() < 0.001 ? (_n(operands, 1).abs() < 0.001 ? 1 : _n(operands, 1).abs()) : _n(operands, 0).abs();
        _moveTo(_n(operands, 4), _n(operands, 5));
      case 'T*':
        _gap = _Gap.line;
        _cursor = _lineX;
      case 'Tj':
        _show(operands.firstOrNull);
      case "'":
        _gap = _Gap.line;
        _show(operands.firstOrNull);
      case '"':
        _gap = _Gap.line;
        _show(operands.length > 2 ? operands[2] : null);
      case 'TJ':
        final items = operands.firstOrNull;
        if (items is! List) return;
        for (final item in items) {
          if (item is num) {
            _cursor -= item / 1000 * _em;
            // отступ больше пятой части буквы — пробел между словами
            if (item < -180) _space();
          } else {
            _show(item);
          }
        }
    }
  }

  void _moveTo(double x, double y) {
    _origin = false;
    final sameLine = (y - _lineY).abs() < _em * 0.3;
    if (!sameLine) {
      _gap = _Gap.line;
    } else if (x > _cursor + _em * 0.15) {
      _space();
    }
    _lineX = x;
    _lineY = y;
    _cursor = x;
  }

  void _space() {
    if (_gap == _Gap.none) _gap = _Gap.space;
  }

  void _show(Object? value) {
    if (value is! List<int>) return;
    final (:text, :advance) = (_font ?? _file.font(null)).decode(value);
    _cursor += advance / 1000 * _em;
    if (text.isEmpty) return;
    if (_out.isNotEmpty) {
      if (_gap == _Gap.line) {
        _out.write('\n');
      } else if (_gap == _Gap.space) {
        _out.write(' ');
      }
    }
    _gap = _Gap.none;
    _out.write(text);
  }
}

enum _Gap { none, space, line }
