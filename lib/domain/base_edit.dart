import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'obsidian_base.dart';

/// Правка файла `.base` по месту: меняется только тронутый ключ, комментарии,
/// порядок и чужие ключи (настройки плагинов) остаются как были — Obsidian видит тот же файл.
class BaseEditor {
  // пустой файл база показывает таблицей: с неё и начинается, иначе YAML вышел бы в строку {…}
  BaseEditor(String text) : _editor = YamlEditor(_brokenOrEmpty(text) ? 'views:\n  - type: table\n    name: Таблица\n' : text);

  YamlEditor _editor;

  String get text {
    final out = _editor.toString();
    return out.endsWith('\n') ? out : '$out\n';
  }

  static bool _brokenOrEmpty(String text) {
    if (text.trim().isEmpty) return true;
    try {
      return loadYaml(text) is! Map;
    } on Object {
      return true;
    }
  }

  Object? _read(List<Object> path) {
    try {
      final node = _editor.parseAt(path, orElse: () => wrapAsYamlNode(null));
      return node is YamlScalar ? node.value : node;
    } on Object {
      return null;
    }
  }

  bool _has(List<Object> path) {
    try {
      _editor.parseAt(path);
      return true;
    } on Object {
      return false;
    }
  }

  void _setKey(List<Object> mapPath, String key, Object? value) {
    if (value == null) {
      if (_has([...mapPath, key])) _editor.remove([...mapPath, key]);
      return;
    }
    _put([...mapPath, key], value);
  }

  /// Значение по пути; недостающие словари заводятся вместе с ним, столбиком: пустой
  /// словарь YAML пишет как `{}`, и ключи в него легли бы строкой.
  void _put(List<Object> path, Object? value) {
    final parent = path.sublist(0, path.length - 1);
    if (parent.isEmpty || _read(parent) is YamlMap) {
      _editor.update(path, value);
      return;
    }
    _put(parent, _block({'${path.last}': _plainYaml(value)}));
  }

  int get _viewCount => switch (_read(['views'])) {
    final YamlList list => list.length,
    _ => 0,
  };

  /// Вид [index] в файле. Без видов база показывает таблицу сама: первая правка её записывает.
  List<Object> _view(int index) {
    if (_viewCount == 0) {
      _editor.update(['views'], _block([
        {'type': 'table', 'name': 'Таблица'},
      ]));
    }
    return ['views', index.clamp(0, _viewCount - 1)];
  }

  // ── вид ──

  void setSort(int view, List<BaseSortKey> sort) => _setKey(_view(view), 'sort', sort.isEmpty ? null : _block([for (final key in sort) _key(key)]));

  void setGroupBy(int view, BaseSortKey? group) => _setKey(_view(view), 'groupBy', group == null ? null : _block(_key(group)));

  void setOrder(int view, List<String> order) => _setKey(_view(view), 'order', _block(order));

  void setLimit(int view, int? limit) => _setKey(_view(view), 'limit', limit);

  void setColumnSize(int view, String property, double width) {
    final path = _view(view);
    final key = _existingKey([...path, 'columnSize'], property) ?? _fileKey(property);
    _put([...path, 'columnSize', key], width.round());
  }

  void setSummary(int view, String property, String? summary) {
    final path = [..._view(view), 'summaries'];
    final key = _existingKey(path, property) ?? _fileKey(property);
    _setKey(path, key, summary);
    if (summary != null) return;
    if (_read(path) case YamlMap(isEmpty: true)) _editor.remove(path);
  }

  /// Карточки и канбан: `image`, `cardSize`, `imageAspectRatio`, `imageFit`.
  void setCardOption(int view, String key, Object? value) => _setKey(_view(view), key, value);

  /// Условия: [view] null — для всех видов (верх файла), иначе только этого вида.
  void setFilter(int? view, BaseFilter? filter) {
    final path = view == null ? <Object>[] : _view(view);
    _setKey(path, 'filters', filter == null ? null : _block(_filterYaml(filter is BaseExpr ? BaseAnd([filter]) : filter)));
  }

  // ── виды ──

  void addView(BaseViewType type, String name) {
    _view(0);
    _editor.appendToList(['views'], _block({'type': type.name, 'name': name, 'order': ['file.name']}));
  }

  void duplicateView(int index, String name) {
    final source = _plainYaml(_read(_view(index))) as Map<String, Object?>;
    _editor.appendToList(['views'], _block({...source, 'name': name}));
  }

  void renameView(int index, String name) => _editor.update([..._view(index), 'name'], name);

  void setViewType(int index, BaseViewType type) => _editor.update([..._view(index), 'type'], type.name);

  void deleteView(int index) {
    if (_viewCount <= 1) return;
    _editor.remove(_view(index));
  }

  void moveView(int from, int to) {
    final node = _read(['views']);
    if (node is YamlList && from >= 0 && from < node.length) {
      final moved = _reorderedViews(_editor.toString(), node, from, to);
      if (moved != null) {
        _editor = YamlEditor(moved);
        return;
      }
    }
    // виды строкой `[{…}, {…}]`: кусков текста нет, список пишется заново
    final views = _plainYaml(node) as List<Object?>;
    if (from < 0 || from >= views.length) return;
    final view = views.removeAt(from);
    views.insert(to.clamp(0, views.length), view);
    _editor.update(['views'], _block(views));
  }

  // ── вся база ──

  /// Подпись колонки; null — снять. Свойство заметки пишется как `note.x`.
  void setDisplayName(String property, String? name) {
    final key = _existingKey(['properties'], property) ?? _fileKey(property);
    if (name == null || name.trim().isEmpty) {
      if (_has(['properties', key, 'displayName'])) _editor.remove(['properties', key, 'displayName']);
      if (_read(['properties', key]) case YamlMap(isEmpty: true)) _editor.remove(['properties', key]);
      if (_read(['properties']) case YamlMap(isEmpty: true)) _editor.remove(['properties']);
      return;
    }
    _put(['properties', key, 'displayName'], name.trim());
  }

  /// Формула: новая или правка; null — удалить вместе с её колонками.
  void setFormula(String name, String? expression) {
    if (expression == null) {
      _setKey(['formulas'], name, null);
      if (_read(['formulas']) case YamlMap(isEmpty: true)) _editor.remove(['formulas']);
      _replaceProperty('formula.$name', null);
      return;
    }
    _setKey(['formulas'], name, expression);
  }

  /// Новое имя формулы: колонки, сортировки, подписи и итоги видов идут следом.
  void renameFormula(String from, String to) {
    if (from == to) return;
    final expression = _read(['formulas', from]);
    if (expression == null) return;
    _setKey(['formulas'], to, '$expression');
    _editor.remove(['formulas', from]);
    _replaceProperty('formula.$from', 'formula.$to');
  }

  /// Свойство [from] меняется на [to] (null — убирается) во всех видах и подписях.
  void _replaceProperty(String from, String? to) {
    for (var i = 0; i < _viewCount; i++) {
      final view = ['views', i];
      final order = _plainYaml(_read([...view, 'order']));
      if (order is List && order.contains(from)) {
        _editor.update([...view, 'order'], _block([for (final one in order) if (one == from) ?to else one]));
      }
      final sort = _plainYaml(_read([...view, 'sort']));
      if (sort is List && sort.any((one) => one is Map && one['property'] == from)) {
        final next = [
          for (final one in sort)
            if (one is Map && one['property'] == from) ...[if (to != null) {...one, 'property': to}] else one,
        ];
        _setKey(view, 'sort', next.isEmpty ? null : _block(next));
      }
      for (final key in ['columnSize', 'summaries']) {
        final value = _read([...view, key, from]);
        if (value == null) continue;
        _editor.remove([...view, key, from]);
        if (to != null) _editor.update([...view, key, to], value);
      }
      if (_read([...view, 'groupBy', 'property']) == from) _setKey(view, 'groupBy', to == null ? null : _block({'property': to, 'direction': _read([...view, 'groupBy', 'direction']) ?? 'ASC'}));
    }
    final display = _read(['properties', from]);
    if (display != null) {
      _editor.remove(['properties', from]);
      if (to != null) _editor.update(['properties', to], _block(_plainYaml(display)));
    }
  }

  /// Ключ, под которым свойство уже записано: `x` или `note.x`.
  String? _existingKey(List<Object> mapPath, String property) {
    final map = _read(mapPath);
    if (map is! YamlMap) return null;
    final bare = property.startsWith('note.') ? property.substring(5) : property;
    for (final key in [property, bare, 'note.$bare']) {
      if (map.containsKey(key)) return key;
    }
    return null;
  }
}

/// Как Obsidian пишет свойство заметки в ключах файла: `note.x`; `file.*` и `formula.*` как есть.
String _fileKey(String property) => property.startsWith('file.') || property.startsWith('formula.') || property.startsWith('note.') ? property : 'note.$property';

Map<String, Object?> _key(BaseSortKey key) => {'property': key.property, 'direction': key.descending ? 'DESC' : 'ASC'};

Object? _filterYaml(BaseFilter filter) => switch (filter) {
  BaseExpr(:final source) => source,
  BaseAnd(:final all) => {'and': [for (final one in all) _filterYaml(one)]},
  BaseOr(:final any) => {'or': [for (final one in any) _filterYaml(one)]},
  BaseNot(:final none) => {'not': [for (final one in none) _filterYaml(one)]},
};

/// Условие строкой: `and(a, or(b, c))` — для проверок и подписи «Расширенный фильтр».
String describeFilter(BaseFilter? filter) => switch (filter) {
  null => '',
  BaseExpr(:final source) => source,
  BaseAnd(:final all) => 'and(${all.map(describeFilter).join(', ')})',
  BaseOr(:final any) => 'or(${any.map(describeFilter).join(', ')})',
  BaseNot(:final none) => 'not(${none.map(describeFilter).join(', ')})',
};

/// Текст файла, где вид [from] стоит на месте [to]. Виды столбиком переставляются кусками
/// текста, и комментарии внутри вида едут вместе с ним. Не вышло разрезать — null.
String? _reorderedViews(String text, YamlList views, int from, int to) {
  if (views.style != CollectionStyle.BLOCK || views.length < 2) return null;
  int lineStart(int offset) => text.lastIndexOf('\n', offset - 1) + 1;
  int lineEnd(int offset) {
    final end = text.indexOf('\n', offset);
    return end < 0 ? text.length : end + 1;
  }

  // кусок вида начинается строкой с его «-»
  final starts = <int>[];
  for (final view in views.nodes) {
    final start = lineStart(view.span.start.offset);
    if (!text.substring(start, view.span.start.offset).trimLeft().startsWith('-')) return null;
    starts.add(start);
  }
  final dashIndent = text.indexOf('-', starts.first) - starts.first;

  // последний вид кончается последней непустой строкой глубже «-»: так в него попадает и комментарий в его конце
  var end = lineEnd(views.nodes.last.span.end.offset - 1);
  var scan = end;
  while (scan < text.length) {
    final next = lineEnd(scan);
    final line = text.substring(scan, next).replaceAll(RegExp(r'\s+$'), '');
    if (line.isNotEmpty) {
      if (line.length - line.trimLeft().length <= dashIndent) break;
      end = next;
    }
    scan = next;
  }

  final pieces = [
    for (var i = 0; i < starts.length; i++) text.substring(starts[i], i + 1 < starts.length ? starts[i + 1] : end),
  ];
  if (!pieces.last.endsWith('\n')) pieces.last = '${pieces.last}\n';
  final piece = pieces.removeAt(from);
  pieces.insert(to.clamp(0, pieces.length), piece);
  final moved = '${text.substring(0, starts.first)}${pieces.join()}${text.substring(end)}';

  // разрезанное должно читаться теми же видами, только в новом порядке
  try {
    final check = loadYaml(moved);
    if (check is! Map || check['views'] is! YamlList || (check['views'] as YamlList).length != views.length) return null;
  } on Object {
    return null;
  }
  return moved;
}

YamlNode _block(Object? value) => wrapAsYamlNode(value, collectionStyle: CollectionStyle.BLOCK);

Object? _plainYaml(Object? value) {
  if (value is YamlList) return [for (final one in value) _plainYaml(one)];
  if (value is YamlMap) return <String, Object?>{for (final MapEntry(:key, :value) in value.entries) '$key': _plainYaml(value)};
  if (value is YamlScalar) return value.value;
  return value;
}
