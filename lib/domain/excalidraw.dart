import 'dart:convert';
import 'dart:math' as math;

/// Рисунок Excalidraw из Obsidian — файл `Имя.excalidraw.md`: свойства с
/// `excalidraw-plugin`, разделы «Text Elements» (подписи для поиска), «Embedded Files»
/// (картинки ссылками на файлы хранилища) и «Drawing» — сам рисунок JSON-ом, обычно
/// сжатым lz-string. Stowa рисунок только показывает: формат меняется от версии к
/// версии модуля, и правка мимо Obsidian его бы испортила.

/// Рисунок ли текст: по свойству `excalidraw-plugin` в шапке файла.
bool isExcalidrawText(String text) {
  final content = text.replaceAll('\r\n', '\n');
  if (!content.startsWith('---\n')) return false;
  final end = content.indexOf('\n---', 4);
  if (end < 0) return false;
  return RegExp(r'^excalidraw-plugin\s*:', multiLine: true).hasMatch(content.substring(4, end));
}

/// Имя рисунка без `.excalidraw.md` (или без `.md`, если файл назван просто).
String excalidrawTitle(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.excalidraw.md')) return fileName.substring(0, fileName.length - '.excalidraw.md'.length);
  if (lower.endsWith('.md')) return fileName.substring(0, fileName.length - 3);
  return fileName;
}

/// `id` заметки, если Stowa когда-то записала его в шапку рисунка.
String excalidrawId(String text) {
  final content = text.replaceAll('\r\n', '\n');
  final end = content.indexOf('\n---', 4);
  if (!content.startsWith('---\n') || end < 0) return '';
  return RegExp(r'^id:\s*"?([^"\n]+)"?\s*$', multiLine: true).firstMatch(content.substring(4, end))?.group(1)?.trim() ?? '';
}

/// Подписи рисунка из раздела «Text Elements»: строки без хвоста `^ключ` и служебных `%%…%%`.
List<String> excalidrawTexts(String text) {
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final start = lines.indexWhere((line) => RegExp(r'^#{1,2} Text Elements\s*$').hasMatch(line));
  if (start < 0) return const [];
  final found = <String>[];
  final current = <String>[];
  void flush() {
    final joined = current.join('\n').replaceAll(RegExp(r'%%.*?%%', dotAll: true), '').replaceFirst(RegExp(r'\s*\^[A-Za-z0-9_-]{6,12}\s*$'), '').trim();
    if (joined.isNotEmpty) found.add(joined);
    current.clear();
  }

  for (final line in lines.skip(start + 1)) {
    if (line.startsWith('## ') || line.startsWith('# ') || line.trim() == '%%') break;
    if (line.trim().isEmpty) {
      flush();
      continue;
    }
    current.add(line);
    // у каждой подписи свой ключ в конце: следующая начинается с новой строки
    if (RegExp(r'\^[A-Za-z0-9_-]{6,12}\s*$').hasMatch(line)) flush();
  }
  flush();
  return found;
}

/// Картинки рисунка: номер файла в рисунке → имя файла хранилища из `[[…]]`.
Map<String, String> excalidrawFiles(String text) => {
  for (final match in RegExp(r'^([0-9a-fA-F]{8,64}):\s*\[\[([^\]|]+)(?:\|[^\]]*)?\]\]', multiLine: true).allMatches(text)) match.group(1)!: match.group(2)!.trim(),
};

/// Сам рисунок: элементы и цвет листа. Не прочитался — null.
ExcalidrawScene? parseExcalidraw(String text) {
  final content = text.replaceAll('\r\n', '\n');
  final drawing = content.indexOf(RegExp(r'^#{1,2} Drawing\s*$', multiLine: true));
  if (drawing < 0) return null;
  final block = RegExp(r'```(compressed-json|json)\n([\s\S]*?)\n```').firstMatch(content.substring(drawing));
  if (block == null) return null;
  final raw = block.group(1) == 'compressed-json' ? lzDecompressFromBase64(block.group(2)!.replaceAll(RegExp(r'\s'), '')) : block.group(2)!;
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, Object?>) return null;
    return ExcalidrawScene.fromJson(json, files: excalidrawFiles(content));
  } on FormatException {
    return null;
  }
}

/// Сцена Excalidraw: элементы снизу вверх и цвет листа.
class ExcalidrawScene {
  const ExcalidrawScene({required this.elements, required this.background, this.files = const {}});

  factory ExcalidrawScene.fromJson(Map<String, Object?> json, {Map<String, String> files = const {}}) {
    final elements = [
      for (final raw in (json['elements'] as List? ?? const []).whereType<Map<String, Object?>>())
        if (raw['isDeleted'] != true) ExcalidrawElement.fromJson(raw),
    ];
    final state = json['appState'];
    final background = state is Map ? state['viewBackgroundColor'] : null;
    return ExcalidrawScene(elements: elements, background: excalidrawColor(background is String ? background : null) ?? 0xFFFFFFFF, files: files);
  }

  final List<ExcalidrawElement> elements;

  /// Цвет листа ARGB.
  final int background;

  /// Номер картинки → имя файла хранилища.
  final Map<String, String> files;

  /// Рамка всего нарисованного в координатах рисунка: left, top, right, bottom. Пусто — null.
  ({double left, double top, double right, double bottom})? get bounds {
    double? left, top, right, bottom;
    for (final element in elements) {
      final box = element.bounds;
      left = left == null ? box.left : math.min(left, box.left);
      top = top == null ? box.top : math.min(top, box.top);
      right = right == null ? box.right : math.max(right, box.right);
      bottom = bottom == null ? box.bottom : math.max(bottom, box.bottom);
    }
    if (left == null) return null;
    return (left: left, top: top!, right: right!, bottom: bottom!);
  }
}

/// Один элемент рисунка: фигура, линия, рука, подпись или картинка.
class ExcalidrawElement {
  const ExcalidrawElement({
    required this.type,
    required this.x,
    required this.y,
    this.width = 0,
    this.height = 0,
    this.angle = 0,
    this.stroke = 0xFF1E1E1E,
    this.fill,
    this.fillStyle = 'solid',
    this.strokeWidth = 1,
    this.strokeStyle = 'solid',
    this.opacity = 1,
    this.rounded = false,
    this.points = const [],
    this.startArrowhead,
    this.endArrowhead,
    this.text = '',
    this.fontSize = 20,
    this.fontFamily = 1,
    this.textAlign = 'left',
    this.lineHeight = 1.25,
    this.fileId,
    this.name,
  });

  factory ExcalidrawElement.fromJson(Map<String, Object?> json) {
    double number(String key, [double fallback = 0]) => (json[key] as num?)?.toDouble() ?? fallback;
    final background = excalidrawColor(json['backgroundColor'] as String?);
    final roundness = json['roundness'];
    return ExcalidrawElement(
      type: json['type'] as String? ?? 'rectangle',
      x: number('x'),
      y: number('y'),
      width: number('width'),
      height: number('height'),
      angle: number('angle'),
      stroke: excalidrawColor(json['strokeColor'] as String?) ?? 0xFF1E1E1E,
      fill: background == null || background >> 24 == 0 ? null : background,
      fillStyle: json['fillStyle'] as String? ?? 'solid',
      strokeWidth: number('strokeWidth', 1),
      strokeStyle: json['strokeStyle'] as String? ?? 'solid',
      opacity: (number('opacity', 100) / 100).clamp(0, 1).toDouble(),
      rounded: roundness is Map || json['strokeSharpness'] == 'round',
      points: [
        for (final point in (json['points'] as List? ?? const []).whereType<List>())
          if (point.length >= 2 && point[0] is num && point[1] is num) ((point[0] as num).toDouble(), (point[1] as num).toDouble()),
      ],
      startArrowhead: json['startArrowhead'] as String?,
      endArrowhead: json['endArrowhead'] as String?,
      text: json['text'] as String? ?? json['originalText'] as String? ?? '',
      fontSize: number('fontSize', 20),
      fontFamily: (json['fontFamily'] as num?)?.toInt() ?? 1,
      textAlign: json['textAlign'] as String? ?? 'left',
      lineHeight: number('lineHeight', 1.25),
      fileId: json['fileId'] as String?,
      name: json['name'] as String?,
    );
  }

  /// rectangle, diamond, ellipse, line, arrow, freedraw, text, image, frame, embeddable…
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;

  /// Поворот вокруг середины, в радианах.
  final double angle;

  /// Цвет линии ARGB.
  final int stroke;

  /// Заливка ARGB; прозрачная — null.
  final int? fill;

  /// solid, hachure, cross-hatch, zigzag.
  final String fillStyle;
  final double strokeWidth;

  /// solid, dashed, dotted.
  final String strokeStyle;

  /// 0…1.
  final double opacity;
  final bool rounded;

  /// Точки линии, стрелки и рисунка рукой — от (x, y).
  final List<(double, double)> points;
  final String? startArrowhead;
  final String? endArrowhead;
  final String text;
  final double fontSize;

  /// 1 и 5 — рукописный, 2 и 6 — обычный, 3 — моноширинный.
  final int fontFamily;
  final String textAlign;
  final double lineHeight;
  final String? fileId;

  /// Имя рамки (frame).
  final String? name;

  bool get isLinear => type == 'line' || type == 'arrow' || type == 'freedraw';

  /// Рамка элемента без поворота: у линий — по точкам.
  ({double left, double top, double right, double bottom}) get bounds {
    if (isLinear && points.isNotEmpty) {
      var left = points.first.$1, right = left, top = points.first.$2, bottom = top;
      for (final (px, py) in points) {
        left = math.min(left, px);
        right = math.max(right, px);
        top = math.min(top, py);
        bottom = math.max(bottom, py);
      }
      final pad = strokeWidth * 2;
      return (left: x + left - pad, top: y + top - pad, right: x + right + pad, bottom: y + bottom + pad);
    }
    final left = math.min(x, x + width), right = math.max(x, x + width);
    final top = math.min(y, y + height), bottom = math.max(y, y + height);
    if (angle == 0) return (left: left, top: top, right: right, bottom: bottom);
    // повёрнутая фигура занимает больше: описанный квадрат по диагонали
    final cx = (left + right) / 2, cy = (top + bottom) / 2;
    final half = math.sqrt(width * width + height * height) / 2;
    return (left: cx - half, top: cy - half, right: cx + half, bottom: cy + half);
  }
}

/// Цвет Excalidraw (`#rgb`, `#rrggbb`, `#rrggbbaa`, `transparent`, имя) в ARGB. Не понял — null.
int? excalidrawColor(String? value) {
  if (value == null) return null;
  final text = value.trim().toLowerCase();
  if (text == 'transparent' || text.isEmpty) return 0x00000000;
  const named = {
    'black': 0xFF000000,
    'white': 0xFFFFFFFF,
    'red': 0xFFFF0000,
    'green': 0xFF008000,
    'blue': 0xFF0000FF,
    'yellow': 0xFFFFFF00,
    'orange': 0xFFFFA500,
    'gray': 0xFF808080,
    'grey': 0xFF808080,
  };
  if (named[text] case final color?) return color;
  if (!text.startsWith('#')) return null;
  var hex = text.substring(1);
  if (hex.length == 3 || hex.length == 4) hex = [for (final char in hex.split('')) '$char$char'].join();
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  if (hex.length == 6) return 0xFF000000 | parsed;
  if (hex.length == 8) return (parsed & 0xFF) << 24 | parsed >> 8;
  return null;
}

const _base64Keys = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';

/// Распаковка lz-string `decompressFromBase64` — так модуль Excalidraw сжимает рисунок.
/// Битые данные — null.
String? lzDecompressFromBase64(String input) {
  if (input.isEmpty) return null;
  final values = <int>[];
  for (final unit in input.codeUnits) {
    final value = _base64Keys.indexOf(String.fromCharCode(unit));
    if (value < 0) return null;
    values.add(value);
  }
  return _lzDecompress(values.length, 32, (index) => index < values.length ? values[index] : 0);
}

String? _lzDecompress(int length, int resetValue, int Function(int index) next) {
  final dictionary = <String>['0', '1', '2'];
  var enlargeIn = 4;
  var dictSize = 4;
  var numBits = 3;
  final result = StringBuffer();
  var value = next(0);
  var position = resetValue;
  var index = 1;

  int read(int count) {
    var bits = 0;
    final maxPower = 1 << count;
    var power = 1;
    while (power != maxPower) {
      final bit = value & position;
      position >>= 1;
      if (position == 0) {
        position = resetValue;
        value = next(index++);
      }
      bits |= (bit > 0 ? 1 : 0) * power;
      power <<= 1;
    }
    return bits;
  }

  String c;
  switch (read(2)) {
    case 0:
      c = String.fromCharCode(read(8));
    case 1:
      c = String.fromCharCode(read(16));
    default:
      return '';
  }
  dictionary.add(c);
  var w = c;
  result.write(c);
  while (true) {
    if (index > length) return '';
    var code = read(numBits);
    switch (code) {
      case 0:
        dictionary.add(String.fromCharCode(read(8)));
        dictSize++;
        code = dictSize - 1;
        enlargeIn--;
      case 1:
        dictionary.add(String.fromCharCode(read(16)));
        dictSize++;
        code = dictSize - 1;
        enlargeIn--;
      case 2:
        return result.toString();
    }
    if (enlargeIn == 0) {
      enlargeIn = 1 << numBits;
      numBits++;
    }
    final String entry;
    if (code < dictionary.length) {
      entry = dictionary[code];
    } else if (code == dictSize) {
      entry = w + w[0];
    } else {
      return null;
    }
    result.write(entry);
    dictionary.add(w + entry[0]);
    dictSize++;
    enlargeIn--;
    w = entry;
    if (enlargeIn == 0) {
      enlargeIn = 1 << numBits;
      numBits++;
    }
  }
}
