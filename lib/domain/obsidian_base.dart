import 'package:yaml/yaml.dart';

/// База Obsidian: файл `.base` (YAML) — вид на заметки хранилища по условиям.
/// Stowa понимает частый набор выражений (описание —
/// docs/specs/2026-11-15-canvas-base-files-design.md); непонятное условие не прячет
/// заметки молча: оно пропускается, а результат помечается [BaseResult.unsupported].

/// Заметка глазами базы.
class BaseNote {
  const BaseNote({
    required this.id,
    required this.path,
    required this.tags,
    required this.links,
    required this.properties,
    required this.created,
    required this.modified,
    this.title,
    this.image,
  });

  final String id;

  /// Путь от корня хранилища с расширением: «Книги/Идиот.md».
  final String path;

  /// Теги без «#».
  final List<String> tags;

  /// Куда ведут `[[…]]` из текста: имена заметок без расширения.
  final List<String> links;

  /// Свойства из шапки файла.
  final Map<String, Object?> properties;
  final DateTime created;
  final DateTime modified;

  /// Заголовок Stowa, если он не совпадает с именем файла.
  final String? title;

  /// Картинка для вида «Карточки»: путь от корня хранилища.
  final String? image;

  String get name => path.split('/').last;
  String get basename => name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
  String get ext => name.contains('.') ? name.substring(name.lastIndexOf('.') + 1) : '';
  String get folder => path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
}

enum BaseViewType { table, cards, list, map, other }

sealed class BaseFilter {
  const BaseFilter();

  /// Разбор `filters`: строка-выражение или `and`/`or`/`not` со списком.
  static BaseFilter? from(Object? yaml) {
    if (yaml == null) return null;
    if (yaml is String) return BaseExpr(yaml);
    if (yaml is Map) {
      for (final (key, make) in [('and', BaseAnd.new), ('or', BaseOr.new), ('not', BaseNot.new)]) {
        final list = yaml[key];
        if (list is List) return make([for (final one in list) ?BaseFilter.from(one)]);
      }
    }
    return BaseExpr('$yaml');
  }
}

class BaseAnd extends BaseFilter {
  const BaseAnd(this.all);
  final List<BaseFilter> all;
}

class BaseOr extends BaseFilter {
  const BaseOr(this.any);
  final List<BaseFilter> any;
}

/// `not`: ни одно из условий не выполнено.
class BaseNot extends BaseFilter {
  const BaseNot(this.none);
  final List<BaseFilter> none;
}

class BaseExpr extends BaseFilter {
  const BaseExpr(this.source);
  final String source;
}

class BaseView {
  const BaseView({required this.type, required this.name, this.filters, this.order = const [], this.sort = const [], this.limit, this.groupBy});

  final BaseViewType type;
  final String name;
  final BaseFilter? filters;

  /// Колонки по порядку: `file.name`, `note.author`, `author`, `formula.x`.
  final List<String> order;
  final List<({String property, bool descending})> sort;
  final int? limit;
  final ({String property, bool descending})? groupBy;
}

class BaseGroup {
  const BaseGroup(this.key, this.rows);
  final Object? key;
  final List<BaseNote> rows;
}

class BaseResult {
  const BaseResult({required this.rows, this.groups, this.unsupported = false});

  /// Заметки по порядку показа (с группами — подряд по группам).
  final List<BaseNote> rows;
  final List<BaseGroup>? groups;

  /// Встретилось условие или формула, которых Stowa не понимает.
  final bool unsupported;
}

class ObsidianBase {
  const ObsidianBase({this.filters, this.formulas = const {}, this.displayNames = const {}, this.views = const [], this.broken = false});

  /// Разбор файла. Битый YAML — база без видов с [broken]. Без видов — одна таблица.
  factory ObsidianBase.parse(String text) {
    Object? yaml;
    try {
      yaml = text.trim().isEmpty ? null : loadYaml(text);
    } on Object {
      return const ObsidianBase(broken: true);
    }
    if (yaml != null && yaml is! Map) return const ObsidianBase(broken: true);
    final map = (yaml as Map?) ?? const {};
    final properties = map['properties'];
    final views = [
      for (final view in (map['views'] as List?) ?? const [])
        if (view is Map) _view(view),
    ];
    return ObsidianBase(
      filters: BaseFilter.from(map['filters']),
      formulas: {for (final MapEntry(:key, :value) in ((map['formulas'] as Map?) ?? const {}).entries) '$key': '$value'},
      displayNames: {
        if (properties is Map)
          for (final MapEntry(:key, :value) in properties.entries)
            if (value is Map && value['displayName'] != null) _bare('$key'): '${value['displayName']}',
      },
      views: views.isEmpty ? const [BaseView(type: BaseViewType.table, name: '')] : views,
    );
  }

  static BaseView _view(Map view) {
    ({String property, bool descending})? key(Object? raw) => raw is Map && raw['property'] != null
        ? (property: '${raw['property']}', descending: '${raw['direction'] ?? 'ASC'}'.toUpperCase() == 'DESC')
        : raw is String
        ? (property: raw, descending: false)
        : null;
    return BaseView(
      type: BaseViewType.values.asNameMap()[view['type']] ?? BaseViewType.other,
      name: '${view['name'] ?? ''}',
      filters: BaseFilter.from(view['filters']),
      order: [for (final one in (view['order'] as List?) ?? const []) '$one'],
      sort: [for (final one in (view['sort'] as List?) ?? const []) ?key(one)],
      limit: view['limit'] is int ? view['limit'] as int : null,
      groupBy: key(view['groupBy']),
    );
  }

  final BaseFilter? filters;
  final Map<String, String> formulas;

  /// Подписи колонок из `properties`, ключ без `note.`.
  final Map<String, String> displayNames;
  final List<BaseView> views;
  final bool broken;

  String? displayName(String property) => displayNames[_bare(property)];

  /// Заметки вида [viewIndex]: общие условия и условия вида, сортировка, предел, группы.
  BaseResult run(int viewIndex, List<BaseNote> notes, {required DateTime now}) {
    final view = views[viewIndex.clamp(0, views.length - 1)];
    var unsupported = false;
    bool passes(BaseFilter? filter, BaseNote note) {
      if (filter == null) return true;
      switch (filter) {
        case BaseAnd(:final all):
          return all.every((one) => passes(one, note));
        case BaseOr(:final any):
          return any.isEmpty || any.any((one) => passes(one, note));
        case BaseNot(:final none):
          return !none.any((one) => passes(one, note));
        case BaseExpr(:final source):
          try {
            return _truthy(_Eval(note, this, now).run(source));
          } on BaseUnsupported {
            unsupported = true;
            // непонятое условие пропускается внутри and; в not/or это true — вывод тот же: заметка не прячется
            return true;
          }
      }
    }

    var rows = [for (final note in notes) if (passes(filters, note) && passes(view.filters, note)) note];
    Object? read(BaseNote note, String property) {
      try {
        return value(note, property, now: now);
      } on BaseUnsupported {
        unsupported = true;
        return null;
      }
    }

    for (final key in view.sort.reversed) {
      rows = _stableSort(rows, (a, b) => _compare(read(a, key.property), read(b, key.property)) * (key.descending ? -1 : 1));
    }
    if (view.limit case final limit? when rows.length > limit) rows = rows.sublist(0, limit);
    List<BaseGroup>? groups;
    if (view.groupBy case final group?) {
      final byKey = <Object?, List<BaseNote>>{};
      for (final note in rows) {
        byKey.putIfAbsent(_groupKey(read(note, group.property)), () => []).add(note);
      }
      final keys = byKey.keys.toList()..sort((a, b) => _compare(a, b) * (group.descending ? -1 : 1));
      groups = [for (final key in keys) BaseGroup(key, byKey[key]!)];
      rows = [for (final group in groups) ...group.rows];
    }
    return BaseResult(rows: rows, groups: groups, unsupported: unsupported);
  }

  /// Значение колонки у заметки: `file.*`, свойство (`note.x` или `x`), `formula.x`.
  Object? value(BaseNote note, String property, {required DateTime now}) {
    if (property.startsWith('formula.')) {
      final formula = formulas[property.substring(8)];
      if (formula == null) return null;
      return _Eval(note, this, now).run(formula);
    }
    return _Eval(note, this, now).run(property);
  }
}

/// Новая база папки: заметки из неё и вложенных, таблица «Название» и «Изменена».
String newBaseFor(String folderPath) {
  final escaped = folderPath.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return 'filters:\n'
      '  and:\n'
      "    - 'file.inFolder(\"$escaped\")'\n"
      '    - \'file.ext == "md"\'\n'
      'views:\n'
      '  - type: table\n'
      '    name: Таблица\n'
      '    order:\n'
      '      - file.name\n'
      '      - file.mtime\n'
      '    sort:\n'
      '      - property: file.mtime\n'
      '        direction: DESC\n';
}

String _bare(String property) => property.startsWith('note.') ? property.substring(5) : property;

Object? _groupKey(Object? value) => value is List ? value.join(', ') : value;

List<T> _stableSort<T>(List<T> list, int Function(T, T) compare) {
  final indexed = [for (final (index, item) in list.indexed) (index, item)];
  indexed.sort((a, b) {
    final result = compare(a.$2, b.$2);
    return result != 0 ? result : a.$1.compareTo(b.$1);
  });
  return [for (final (_, item) in indexed) item];
}

/// Порядок: пустое в конце, числа и даты по значению, строки без регистра.
int _compare(Object? a, Object? b) {
  if (a == null || (a is String && a.isEmpty)) return (b == null || (b is String && b.isEmpty)) ? 0 : 1;
  if (b == null || (b is String && b.isEmpty)) return -1;
  if (a is num && b is num) return a.compareTo(b);
  if (a is DateTime && b is DateTime) return a.compareTo(b);
  if (a is bool && b is bool) return a == b ? 0 : (a ? -1 : 1);
  return '$a'.toLowerCase().compareTo('$b'.toLowerCase());
}

bool _truthy(Object? value) => switch (value) {
  null => false,
  bool() => value,
  num() => value != 0,
  String() => value.isNotEmpty,
  List() => value.isNotEmpty,
  _ => true,
};

/// Выражение Bases, которого Stowa не понимает.
class BaseUnsupported implements Exception {
  const BaseUnsupported(this.what);
  final String what;
  @override
  String toString() => 'BaseUnsupported($what)';
}

// ── вычислитель ─────────────────────────────────────────────────────────────

enum _T { number, string, ident, op, lparen, rparen, comma, dot, end }

class _Token {
  const _Token(this.type, this.text, [this.value]);
  final _T type;
  final String text;
  final Object? value;
}

List<_Token> _lex(String source) {
  final tokens = <_Token>[];
  var i = 0;
  const twoChar = {'==', '!=', '>=', '<=', '&&', '||'};
  while (i < source.length) {
    final c = source[i];
    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    if (c == '"' || c == "'") {
      final buffer = StringBuffer();
      i++;
      while (i < source.length && source[i] != c) {
        if (source[i] == r'\' && i + 1 < source.length) i++;
        buffer.write(source[i]);
        i++;
      }
      if (i >= source.length) throw const BaseUnsupported('строка без конца');
      i++;
      tokens.add(_Token(_T.string, buffer.toString(), buffer.toString()));
      continue;
    }
    if (RegExp(r'[0-9]').hasMatch(c)) {
      final match = RegExp(r'[0-9]+(\.[0-9]+)?').matchAsPrefix(source, i)!;
      tokens.add(_Token(_T.number, match[0]!, num.parse(match[0]!)));
      i = match.end;
      continue;
    }
    final ident = RegExp(r'[A-Za-z_Ѐ-ӿ][A-Za-z0-9_Ѐ-ӿ-]*').matchAsPrefix(source, i);
    if (ident != null) {
      tokens.add(_Token(_T.ident, ident[0]!));
      i = ident.end;
      continue;
    }
    if (i + 1 < source.length && twoChar.contains(source.substring(i, i + 2))) {
      tokens.add(_Token(_T.op, source.substring(i, i + 2)));
      i += 2;
      continue;
    }
    switch (c) {
      case '(':
        tokens.add(const _Token(_T.lparen, '('));
      case ')':
        tokens.add(const _Token(_T.rparen, ')'));
      case ',':
        tokens.add(const _Token(_T.comma, ','));
      case '.':
        tokens.add(const _Token(_T.dot, '.'));
      case '>' || '<' || '!' || '+' || '-' || '*' || '/':
        tokens.add(_Token(_T.op, c));
      default:
        throw BaseUnsupported('знак «$c»');
    }
    i++;
  }
  tokens.add(const _Token(_T.end, ''));
  return tokens;
}

/// Объект `file` в выражении.
class _File {
  const _File(this.note);
  final BaseNote note;
}

class _Eval {
  _Eval(this.note, this.base, this.now);

  final BaseNote note;
  final ObsidianBase base;
  final DateTime now;
  late List<_Token> _tokens;
  var _at = 0;
  final _formulaDepth = <String>{};

  Object? run(String source) {
    _tokens = _lex(source);
    _at = 0;
    final value = _or();
    if (_peek.type != _T.end) throw BaseUnsupported('лишнее «${_peek.text}»');
    return value;
  }

  _Token get _peek => _tokens[_at];
  _Token _next() => _tokens[_at++];
  bool _op(String text) {
    if (_peek.type == _T.op && _peek.text == text) {
      _at++;
      return true;
    }
    return false;
  }

  Object? _or() {
    var left = _and();
    while (_op('||')) {
      final right = _and();
      left = _truthy(left) || _truthy(right);
    }
    return left;
  }

  Object? _and() {
    var left = _equality();
    while (_op('&&')) {
      final right = _equality();
      left = _truthy(left) && _truthy(right);
    }
    return left;
  }

  Object? _equality() {
    var left = _compareExpr();
    while (true) {
      if (_op('==')) {
        left = _equals(left, _compareExpr());
      } else if (_op('!=')) {
        left = !_equals(left, _compareExpr());
      } else {
        return left;
      }
    }
  }

  Object? _compareExpr() {
    var left = _additive();
    for (final op in ['>=', '<=', '>', '<']) {
      if (_op(op)) {
        final right = _additive();
        final (a, b) = _align(left, right);
        if (a == null || b == null) return false;
        final order = _compare(a, b);
        left = switch (op) { '>=' => order >= 0, '<=' => order <= 0, '>' => order > 0, _ => order < 0 };
        return left;
      }
    }
    return left;
  }

  Object? _additive() {
    var left = _multiplicative();
    while (true) {
      if (_op('+')) {
        final right = _multiplicative();
        left = switch ((left, right)) {
          (num a, num b) => a + b,
          (DateTime a, _) => a.add(_duration(right)),
          (String a, _) => '$a${right ?? ''}',
          _ => null,
        };
      } else if (_op('-')) {
        final right = _multiplicative();
        left = switch ((left, right)) {
          (num a, num b) => a - b,
          (DateTime a, DateTime b) => a.difference(b).inMilliseconds,
          (DateTime a, _) => a.subtract(_duration(right)),
          _ => null,
        };
      } else {
        return left;
      }
    }
  }

  Object? _multiplicative() {
    var left = _unary();
    while (true) {
      if (_op('*')) {
        final right = _unary();
        left = left is num && right is num ? left * right : null;
      } else if (_op('/')) {
        final right = _unary();
        left = left is num && right is num && right != 0 ? left / right : null;
      } else {
        return left;
      }
    }
  }

  Object? _unary() {
    if (_op('!')) return !_truthy(_unary());
    if (_op('-')) {
      final value = _unary();
      return value is num ? -value : null;
    }
    return _postfix(_primary());
  }

  Object? _primary() {
    final token = _next();
    switch (token.type) {
      case _T.number || _T.string:
        return token.value;
      case _T.lparen:
        final value = _or();
        if (_next().type != _T.rparen) throw const BaseUnsupported('нет «)»');
        return value;
      case _T.ident:
        final name = token.text;
        if (_peek.type == _T.lparen) return _call(name, _args());
        return switch (name) {
          'true' => true,
          'false' => false,
          'null' => null,
          'file' => _File(note),
          'note' => note.properties,
          'formula' => const _FormulaRoot(),
          _ => _property(name),
        };
      default:
        throw BaseUnsupported('«${token.text}»');
    }
  }

  List<Object?> _args() {
    _next();
    final args = <Object?>[];
    if (_peek.type == _T.rparen) {
      _next();
      return args;
    }
    while (true) {
      args.add(_or());
      final token = _next();
      if (token.type == _T.rparen) return args;
      if (token.type != _T.comma) throw const BaseUnsupported('список без «,»');
    }
  }

  Object? _postfix(Object? value) {
    while (_peek.type == _T.dot) {
      _next();
      final name = _next();
      if (name.type != _T.ident) throw const BaseUnsupported('точка без имени');
      value = _peek.type == _T.lparen ? _method(value, name.text, _args()) : _field(value, name.text);
    }
    return value;
  }

  Object? _property(String name) => _plain(note.properties[name]);

  Object? _field(Object? target, String name) {
    if (target is _File) {
      final file = target.note;
      return switch (name) {
        'name' => file.basename,
        'basename' => file.basename,
        'fullname' => file.name,
        'path' => file.path,
        'folder' => file.folder,
        'ext' => file.ext,
        'ctime' => file.created,
        'mtime' => file.modified,
        'tags' => file.tags,
        'links' => file.links,
        _ => throw BaseUnsupported('file.$name'),
      };
    }
    if (target is _FormulaRoot) {
      final formula = base.formulas[name];
      // формула, ссылающаяся на себя по кругу, даёт пусто, а не зависание
      if (formula == null || _formulaDepth.contains(name)) return null;
      final inner = _Eval(note, base, now).._formulaDepth.addAll({..._formulaDepth, name});
      return inner.run(formula);
    }
    if (target is Map) return _plain(target[name]);
    if (name == 'length') {
      if (target is String) return target.length;
      if (target is List) return target.length;
    }
    if (target == null) return null;
    throw BaseUnsupported('поле $name');
  }

  Object? _method(Object? target, String name, List<Object?> args) {
    if (target is _File) {
      final file = target.note;
      switch (name) {
        case 'inFolder':
          final folder = '${args.firstOrNull ?? ''}'.replaceAll(RegExp(r'^/+|/+$'), '');
          return folder.isEmpty || file.folder == folder || file.folder.startsWith('$folder/');
        case 'hasTag':
          return args.any((tag) {
            final want = '$tag'.replaceFirst('#', '').toLowerCase();
            return file.tags.any((one) => one.toLowerCase() == want || one.toLowerCase().startsWith('$want/'));
          });
        case 'hasLink':
          final want = '${args.firstOrNull ?? ''}'.replaceAll(RegExp(r'\.md$'), '').split('/').last.toLowerCase();
          return file.links.any((link) => link.toLowerCase() == want);
        case 'hasProperty':
          return file.properties.containsKey('${args.firstOrNull}');
      }
      throw BaseUnsupported('file.$name()');
    }
    switch ((target, name)) {
      case (String text, 'contains'):
        return text.contains('${args.firstOrNull ?? ''}');
      case (String text, 'containsAll'):
        return args.every((one) => text.contains('$one'));
      case (String text, 'containsAny'):
        return args.any((one) => text.contains('$one'));
      case (String text, 'startsWith'):
        return text.startsWith('${args.firstOrNull ?? ''}');
      case (String text, 'endsWith'):
        return text.endsWith('${args.firstOrNull ?? ''}');
      case (String text, 'lower'):
        return text.toLowerCase();
      case (String text, 'upper'):
        return text.toUpperCase();
      case (String text, 'trim'):
        return text.trim();
      case (String text, 'isEmpty'):
        return text.isEmpty;
      case (List list, 'contains'):
        return list.any((one) => _equals(one, args.firstOrNull));
      case (List list, 'containsAny'):
        return args.any((want) => list.any((one) => _equals(one, want)));
      case (List list, 'containsAll'):
        return args.every((want) => list.any((one) => _equals(one, want)));
      case (List list, 'isEmpty'):
        return list.isEmpty;
      case (List list, 'join'):
        return list.join('${args.firstOrNull ?? ', '}');
      case (null, 'isEmpty'):
        return true;
      case (null, _):
        return null;
    }
    throw BaseUnsupported('$name()');
  }

  Object? _call(String name, List<Object?> args) => switch (name) {
    'now' => now,
    'today' => DateTime(now.year, now.month, now.day),
    'date' => _date(args.firstOrNull),
    'if' => _truthy(args.elementAtOrNull(0)) ? args.elementAtOrNull(1) : args.elementAtOrNull(2),
    'number' => args.firstOrNull is num ? args.first : num.tryParse('${args.firstOrNull}'),
    'list' => args.firstOrNull is List ? args.first : [args.firstOrNull],
    _ => throw BaseUnsupported('$name()'),
  };
}

class _FormulaRoot {
  const _FormulaRoot();
}

/// YAML-списки и словари — обычными, дата строкой «2026-11-01» — датой.
Object? _plain(Object? value) {
  if (value is YamlList) return [for (final one in value) _plain(one)];
  if (value is YamlMap) return {for (final MapEntry(:key, :value) in value.entries) '$key': _plain(value)};
  return value;
}

DateTime? _date(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value.trim());
  return null;
}

/// Для сравнения: дата строкой рядом с датой становится датой.
(Object?, Object?) _align(Object? a, Object? b) {
  if (a is DateTime && b is String) return (a, _date(b));
  if (b is DateTime && a is String) return (_date(a), b);
  return (a, b);
}

bool _equals(Object? a, Object? b) {
  final (x, y) = _align(a, b);
  if (x is num && y is num) return x == y;
  if (x is String && y is String) return x == y;
  if (x is List && y is! List) return x.any((one) => _equals(one, y));
  return x == y;
}

/// «7 days», «1 week», «2d», «3 months» — длительность.
Duration _duration(Object? value) {
  if (value is num) return Duration(milliseconds: value.round());
  final match = RegExp(r'^\s*(\d+)\s*([a-zA-Z]+)\s*$').firstMatch('$value');
  if (match == null) throw BaseUnsupported('длительность «$value»');
  final count = int.parse(match[1]!);
  final unit = match[2]!.toLowerCase();
  return switch (unit) {
    's' || 'sec' || 'second' || 'seconds' => Duration(seconds: count),
    'm' || 'min' || 'minute' || 'minutes' => Duration(minutes: count),
    'h' || 'hour' || 'hours' => Duration(hours: count),
    'd' || 'day' || 'days' => Duration(days: count),
    'w' || 'week' || 'weeks' => Duration(days: 7 * count),
    'month' || 'months' => Duration(days: 30 * count),
    'y' || 'year' || 'years' => Duration(days: 365 * count),
    _ => throw BaseUnsupported('единица «$unit»'),
  };
}
