import 'dart:convert';
import 'dart:math';

/// Холст Obsidian: файл `.canvas`, формат JSON Canvas 1.0 (jsoncanvas.org).
/// Узел и стрелка помнят исходный объект целиком: правка меняет только свои поля,
/// чужие (`styleAttributes`, поля плагинов) и порядок узлов остаются как были.

enum CanvasNodeType { text, file, link, group, unknown }

enum CanvasSide { top, right, bottom, left }

enum CanvasEnd { none, arrow }

class CanvasNode {
  const CanvasNode(this.raw);

  final Map<String, Object?> raw;

  String get id => raw['id'] as String;
  CanvasNodeType get type => CanvasNodeType.values.asNameMap()[raw['type']] ?? CanvasNodeType.unknown;
  num get x => raw['x'] as num;
  num get y => raw['y'] as num;
  num get width => raw['width'] as num;
  num get height => raw['height'] as num;
  String? get color => raw['color'] as String?;
  String get text => raw['text'] as String? ?? '';
  String? get file => raw['file'] as String?;
  String? get subpath => raw['subpath'] as String?;
  String? get url => raw['url'] as String?;
  String get label => raw['label'] as String? ?? '';

  /// Узел целиком лежит внутри [other] — для группы это её содержимое.
  bool inside(CanvasNode other) => x >= other.x && y >= other.y && x + width <= other.x + other.width && y + height <= other.y + other.height;

  CanvasNode copyWith(Map<String, Object?> changes) {
    final next = {...raw};
    for (final MapEntry(:key, :value) in changes.entries) {
      value == null ? next.remove(key) : next[key] = value;
    }
    return CanvasNode(next);
  }
}

class CanvasEdge {
  const CanvasEdge(this.raw);

  final Map<String, Object?> raw;

  String get id => raw['id'] as String;
  String get fromNode => raw['fromNode'] as String;
  String get toNode => raw['toNode'] as String;
  CanvasSide? get fromSide => CanvasSide.values.asNameMap()[raw['fromSide']];
  CanvasSide? get toSide => CanvasSide.values.asNameMap()[raw['toSide']];
  CanvasEnd get fromEnd => CanvasEnd.values.asNameMap()[raw['fromEnd']] ?? CanvasEnd.none;
  CanvasEnd get toEnd => CanvasEnd.values.asNameMap()[raw['toEnd']] ?? CanvasEnd.arrow;
  String? get color => raw['color'] as String?;
  String get label => raw['label'] as String? ?? '';

  CanvasEdge copyWith(Map<String, Object?> changes) {
    final next = {...raw};
    for (final MapEntry(:key, :value) in changes.entries) {
      value == null ? next.remove(key) : next[key] = value;
    }
    return CanvasEdge(next);
  }
}

/// Весь холст. Неизменяемый: каждая правка возвращает новый.
class CanvasDoc {
  const CanvasDoc({required this.nodes, required this.edges, this.rest = const {}, this.broken = false});

  factory CanvasDoc.empty() => const CanvasDoc(nodes: [], edges: []);

  /// Разбор файла. Битый JSON — пустой холст с [broken]: экран не даст его перезаписать.
  /// Узел без id или координат и стрелка без концов пропускаются.
  factory CanvasDoc.parse(String text) {
    if (text.trim().isEmpty) return CanvasDoc.empty();
    Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return const CanvasDoc(nodes: [], edges: [], broken: true);
    }
    if (json is! Map<String, Object?>) return const CanvasDoc(nodes: [], edges: [], broken: true);
    bool sized(Map<String, Object?> node) => node['id'] is String && ['x', 'y', 'width', 'height'].every((key) => node[key] is num);
    final nodes = [
      for (final node in (json['nodes'] as List?) ?? const [])
        if (node is Map<String, Object?> && sized(node)) CanvasNode(node),
    ];
    final ids = {for (final node in nodes) node.id};
    final edges = [
      for (final edge in (json['edges'] as List?) ?? const [])
        if (edge is Map<String, Object?> && edge['id'] is String && ids.contains(edge['fromNode']) && ids.contains(edge['toNode'])) CanvasEdge(edge),
    ];
    return CanvasDoc(nodes: nodes, edges: edges, rest: {...json}..remove('nodes')..remove('edges'));
  }

  final List<CanvasNode> nodes;
  final List<CanvasEdge> edges;

  /// Поля верхнего уровня, кроме узлов и стрелок (`metadata` и чужие): пишутся обратно как были.
  final Map<String, Object?> rest;
  final bool broken;

  CanvasNode? node(String id) => nodes.where((node) => node.id == id).firstOrNull;
  CanvasEdge? edge(String id) => edges.where((edge) => edge.id == id).firstOrNull;

  /// Текст файла, как пишет Obsidian: табуляция, сначала узлы, потом стрелки.
  String encode() => const JsonEncoder.withIndent('\t').convert({
    'nodes': [for (final node in nodes) node.raw],
    'edges': [for (final edge in edges) edge.raw],
    ...rest,
  });

  /// Текст для поиска и ленты: карточки, подписи групп и стрелок, имена файлов, адреса.
  String plainText() => [
    for (final node in nodes)
      switch (node.type) {
        CanvasNodeType.text => node.text,
        CanvasNodeType.group => node.label,
        CanvasNodeType.file => _fileTitle(node.file ?? ''),
        CanvasNodeType.link => node.url ?? '',
        CanvasNodeType.unknown => '',
      },
    for (final edge in edges) edge.label,
  ].where((part) => part.trim().isNotEmpty).join('\n');

  CanvasDoc _with({List<CanvasNode>? nodes, List<CanvasEdge>? edges}) => CanvasDoc(nodes: nodes ?? this.nodes, edges: edges ?? this.edges, rest: rest);

  CanvasDoc _add(Map<String, Object?> node) => _with(nodes: [...nodes, CanvasNode({'id': newCanvasId(), ...node})]);

  CanvasDoc addText(String text, {required num x, required num y, num width = 260, num height = 140}) =>
      _add({'type': 'text', 'text': text, 'x': x.round(), 'y': y.round(), 'width': width.round(), 'height': height.round()});

  CanvasDoc addFile(String path, {required num x, required num y, num width = 400, num height = 300}) =>
      _add({'type': 'file', 'file': path, 'x': x.round(), 'y': y.round(), 'width': width.round(), 'height': height.round()});

  CanvasDoc addLink(String url, {required num x, required num y, num width = 400, num height = 120}) =>
      _add({'type': 'link', 'url': url, 'x': x.round(), 'y': y.round(), 'width': width.round(), 'height': height.round()});

  /// Группа встаёт первой: Obsidian рисует узлы по порядку, и группа должна лежать под карточками.
  CanvasDoc addGroup(String label, {required num x, required num y, num width = 600, num height = 400}) => _with(
    nodes: [
      CanvasNode({'id': newCanvasId(), 'type': 'group', 'label': label, 'x': x.round(), 'y': y.round(), 'width': width.round(), 'height': height.round()}),
      ...nodes,
    ],
  );

  CanvasDoc updateNode(String id, Map<String, Object?> changes) => _with(nodes: [for (final node in nodes) node.id == id ? node.copyWith(changes) : node]);

  CanvasDoc updateEdge(String id, Map<String, Object?> changes) => _with(edges: [for (final edge in edges) edge.id == id ? edge.copyWith(changes) : edge]);

  /// Сдвинуть узел; группу — вместе с тем, что лежит в ней целиком. Координаты целые.
  CanvasDoc moveNode(String id, num dx, num dy, {bool withContents = false}) {
    final moving = node(id);
    if (moving == null) return this;
    final carried = {
      id,
      if (withContents && moving.type == CanvasNodeType.group)
        for (final other in nodes)
          if (other.id != id && other.inside(moving)) other.id,
    };
    return _with(
      nodes: [
        for (final one in nodes)
          carried.contains(one.id) ? one.copyWith({'x': (one.x + dx).round(), 'y': (one.y + dy).round()}) : one,
      ],
    );
  }

  CanvasDoc resizeNode(String id, num width, num height) => updateNode(id, {'width': max(60, width).round(), 'height': max(40, height).round()});

  CanvasDoc removeNode(String id) => _with(
    nodes: [for (final node in nodes) if (node.id != id) node],
    edges: [for (final edge in edges) if (edge.fromNode != id && edge.toNode != id) edge],
  );

  CanvasDoc removeEdge(String id) => _with(edges: [for (final edge in edges) if (edge.id != id) edge]);

  /// Стрелка от одного узла к другому, стороны — по тому, как они лежат друг к другу.
  /// К себе и вторую такую же не ставит.
  CanvasDoc connect(String from, String to) {
    final a = node(from), b = node(to);
    if (a == null || b == null || from == to) return this;
    if (edges.any((edge) => edge.fromNode == from && edge.toNode == to)) return this;
    final (fromSide, toSide) = facingSides(a, b);
    return _with(
      edges: [
        ...edges,
        CanvasEdge({'id': newCanvasId(), 'fromNode': from, 'fromSide': fromSide.name, 'toNode': to, 'toSide': toSide.name}),
      ],
    );
  }
}

/// Стороны, которыми два узла смотрят друг на друга: по большей разнице центров.
(CanvasSide, CanvasSide) facingSides(CanvasNode a, CanvasNode b) {
  final dx = (b.x + b.width / 2) - (a.x + a.width / 2);
  final dy = (b.y + b.height / 2) - (a.y + a.height / 2);
  if (dx.abs() >= dy.abs()) return dx >= 0 ? (CanvasSide.right, CanvasSide.left) : (CanvasSide.left, CanvasSide.right);
  return dy >= 0 ? (CanvasSide.bottom, CanvasSide.top) : (CanvasSide.top, CanvasSide.bottom);
}

final _random = Random.secure();

/// Id как у Obsidian: 16 шестнадцатеричных знаков.
String newCanvasId() => List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

String _fileTitle(String path) {
  final name = path.split('/').last;
  return name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
}

/// Готовые цвета Obsidian «1»…«6» — ключи палитры папок Stowa (`FolderPalette.colors`).
const canvasPresets = {'1': 'coral', '2': 'tangerine', '3': 'amber', '4': 'mint', '5': 'sky', '6': 'violet'};

String? canvasPresetKey(String? color) => canvasPresets[color];

/// Место новой карточки [width]×[height]: желанное ([x], [y]), а занято — ближайшее свободное
/// справа, слева, ниже или выше соседних карточек. Группы не мешают: карточки лежат в них.
({num x, num y}) freeCanvasSpot(List<CanvasNode> nodes, {required num x, required num y, required num width, required num height}) {
  const gap = 40;
  final cards = [for (final node in nodes) if (node.type != CanvasNodeType.group) node];
  bool free(num left, num top) => !cards.any(
    (card) => left < card.x + card.width + gap && left + width + gap > card.x && top < card.y + card.height + gap && top + height + gap > card.y,
  );

  if (free(x, y)) return (x: x, y: y);
  // кандидаты — впритык к каждой карточке с четырёх сторон, берётся ближайший к желанному
  final candidates = [
    for (final card in cards) ...[
      (x: card.x + card.width + gap, y: card.y),
      (x: card.x - width - gap, y: card.y),
      (x: card.x, y: card.y + card.height + gap),
      (x: card.x, y: card.y - height - gap),
    ],
  ].where((spot) => free(spot.x, spot.y)).toList()
    ..sort((a, b) => ((a.x - x).abs() + (a.y - y).abs()).compareTo((b.x - x).abs() + (b.y - y).abs()));
  return candidates.firstOrNull ?? (x: x, y: y);
}

/// Свой цвет `#RRGGBB` числом ARGB; готовый или кривой — null.
int? canvasHex(String? color) {
  if (color == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) return null;
  return 0xFF000000 | int.parse(color.substring(1), radix: 16);
}
