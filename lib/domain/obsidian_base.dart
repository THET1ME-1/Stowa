import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:yaml/yaml.dart';

import 'word_forms.dart' show foldText;

part 'base_eval.dart';

/// База Obsidian: файл `.base` (YAML) — вид на заметки хранилища по условиям.
/// Stowa понимает выражения Bases (описание —
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
    this.size,
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

  /// Размер файла в байтах, если известен.
  final int? size;

  String get name => path.split('/').last;
  String get basename => name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
  String get ext => name.contains('.') ? name.substring(name.lastIndexOf('.') + 1) : '';
  String get folder => path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
}

enum BaseViewType { table, cards, list, kanban, map, other }

/// Как картинка ложится в карточку: обрезкой по рамке или целиком.
enum BaseImageFit { cover, contain }

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

typedef BaseSortKey = ({String property, bool descending});

class BaseView {
  const BaseView({
    required this.type,
    required this.name,
    this.filters,
    this.order = const [],
    this.sort = const [],
    this.limit,
    this.groupBy,
    this.image,
    this.cardSize,
    this.imageAspectRatio,
    this.imageFit = BaseImageFit.cover,
    this.columnSize = const {},
    this.summaries = const {},
  });

  final BaseViewType type;
  final String name;
  final BaseFilter? filters;

  /// Колонки по порядку: `file.name`, `note.author`, `author`, `formula.x`.
  final List<String> order;
  final List<BaseSortKey> sort;
  final int? limit;
  final BaseSortKey? groupBy;

  /// Свойство с картинкой карточки: `note.Обложка`.
  final String? image;

  /// Ширина карточки и колонки канбана в точках Obsidian.
  final double? cardSize;

  /// Высота картинки к ширине карточки.
  final double? imageAspectRatio;
  final BaseImageFit imageFit;

  /// Ширина колонок таблицы: ключ как в `order`.
  final Map<String, double> columnSize;

  /// Итог под колонкой: «Average», «Sum», «Filled» или своё имя из `summaries` файла.
  final Map<String, String> summaries;

  /// Ширина колонки, где бы её ни записали: `note.x` и `x` — одно свойство.
  double? widthOf(String property) => columnSize[property] ?? columnSize[_noted(property)] ?? columnSize[_bare(property)];

  String? summaryOf(String property) => summaries[property] ?? summaries[_noted(property)] ?? summaries[_bare(property)];
}

class BaseGroup {
  const BaseGroup(this.key, this.rows);
  final Object? key;
  final List<BaseNote> rows;
}

class BaseResult {
  const BaseResult({required this.rows, this.groups, this.unsupported = false, int? total}) : total = total ?? rows.length;

  /// Заметки по порядку показа (с группами — подряд по группам).
  final List<BaseNote> rows;
  final List<BaseGroup>? groups;

  /// Встретилось условие или формула, которых Stowa не понимает.
  final bool unsupported;

  /// Сколько заметок прошло условия до предела вида.
  final int total;
}

class ObsidianBase {
  const ObsidianBase({this.filters, this.formulas = const {}, this.displayNames = const {}, this.summaries = const {}, this.views = const [], this.broken = false});

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
      formulas: _strings(map['formulas']),
      displayNames: {
        if (properties is Map)
          for (final MapEntry(:key, :value) in properties.entries)
            if (value is Map && value['displayName'] != null) _bare('$key'): '${value['displayName']}',
      },
      summaries: _strings(map['summaries']),
      views: views.isEmpty ? const [BaseView(type: BaseViewType.table, name: '')] : views,
    );
  }

  static Map<String, String> _strings(Object? yaml) => {
    if (yaml is Map)
      for (final MapEntry(:key, :value) in yaml.entries) '$key': ?value?.toString(),
  };

  static BaseView _view(Map view) {
    BaseSortKey? key(Object? raw) => raw is Map && raw['property'] != null
        ? (property: '${raw['property']}', descending: '${raw['direction'] ?? 'ASC'}'.toUpperCase() == 'DESC')
        : raw is String
        ? (property: raw, descending: false)
        : null;
    double? number(Object? raw) => raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
    final sizes = view['columnSize'];
    return BaseView(
      type: BaseViewType.values.asNameMap()[view['type']] ?? BaseViewType.other,
      name: '${view['name'] ?? ''}',
      filters: BaseFilter.from(view['filters']),
      order: [for (final one in (view['order'] as List?) ?? const []) '$one'],
      sort: [for (final one in (view['sort'] as List?) ?? const []) ?key(one)],
      limit: view['limit'] is int ? view['limit'] as int : null,
      groupBy: key(view['groupBy']),
      image: view['image'] == null ? null : '${view['image']}',
      cardSize: number(view['cardSize']),
      imageAspectRatio: number(view['imageAspectRatio']),
      imageFit: '${view['imageFit']}' == 'contain' ? BaseImageFit.contain : BaseImageFit.cover,
      columnSize: {
        if (sizes is Map)
          for (final MapEntry(:key, :value) in sizes.entries) '$key': ?number(value),
      },
      summaries: _strings(view['summaries']),
    );
  }

  final BaseFilter? filters;
  final Map<String, String> formulas;

  /// Подписи колонок из `properties`, ключ без `note.`.
  final Map<String, String> displayNames;

  /// Свои итоги файла: имя — выражение над `values`.
  final Map<String, String> summaries;
  final List<BaseView> views;
  final bool broken;

  String? displayName(String property) => displayNames[_bare(property)];

  /// Заметки вида [viewIndex]: общие условия и условия вида, поиск, сортировка, предел, группы.
  /// [search] ищет в показанных свойствах [columns] без регистра и надстрочных знаков.
  BaseResult run(int viewIndex, List<BaseNote> notes, {required DateTime now, String search = '', List<String>? columns}) {
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

    Object? read(BaseNote note, String property) {
      try {
        return value(note, property, now: now);
      } on BaseUnsupported {
        unsupported = true;
        return null;
      }
    }

    var rows = [for (final note in notes) if (passes(filters, note) && passes(view.filters, note)) note];
    final query = foldText(search.trim());
    if (query.isNotEmpty) {
      final shown = {'file.name', ...?columns, ...view.order};
      rows = [
        for (final note in rows)
          if (shown.any((property) => foldText(_text(read(note, property))).contains(query))) note,
      ];
    }
    for (final key in view.sort.reversed) {
      rows = _stableSort(rows, (a, b) => _compare(read(a, key.property), read(b, key.property)) * (key.descending ? -1 : 1));
    }
    final total = rows.length;
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
    return BaseResult(rows: rows, groups: groups, unsupported: unsupported, total: total);
  }

  /// Значение колонки у заметки: `file.*`, свойство (`note.x` или `x`), `formula.x`.
  Object? value(BaseNote note, String property, {required DateTime now}) {
    if (property.startsWith('formula.')) {
      final formula = formulas[property.substring(8)];
      if (formula == null) return null;
      return _Eval(note, this, now).run(formula);
    }
    // в order и sort — имя свойства, а не выражение: «Курс обучения» с пробелом тоже свойство
    if (property.startsWith('file.')) return _Eval(note, this, now)._field(_File(note), property.substring(5));
    return _plain(note.properties[_bare(property)]);
  }

  /// Итог колонки: готовый («Average», «Filled»…) или свой из `summaries` файла.
  Object? summary(String name, List<Object?> values, {required DateTime now}) {
    if (summaries[name] case final formula?) {
      try {
        return _Eval(null, this, now).run(formula, vars: {'values': values});
      } on BaseUnsupported {
        return null;
      }
    }
    return summarizeBase(name, values);
  }

  /// Проверка выражения без заметок: null — понятно, иначе что не так.
  static String? check(String source) {
    try {
      _parse(source);
      return null;
    } on BaseUnsupported catch (error) {
      return error.what;
    }
  }
}

/// Готовые итоги Bases по значениям колонки.
const baseSummaryNames = ['Average', 'Median', 'Min', 'Max', 'Sum', 'Range', 'Stddev', 'Earliest', 'Latest', 'Checked', 'Unchecked', 'Empty', 'Filled', 'Unique'];

Object? summarizeBase(String name, List<Object?> values) {
  bool empty(Object? value) => value == null || (value is String && value.isEmpty) || (value is List && value.isEmpty);
  final numbers = [for (final value in values) if (value is num) value];
  final dates = [for (final value in values) ?_date(value is String && value.length >= 8 ? value : value is DateTime ? value : null)];
  num? mean() => numbers.isEmpty ? null : _whole(numbers.reduce((a, b) => a + b) / numbers.length);
  switch (name) {
    case 'Average':
      return mean();
    case 'Median':
      if (numbers.isEmpty) return null;
      final sorted = [...numbers]..sort();
      final middle = sorted.length ~/ 2;
      return sorted.length.isOdd ? sorted[middle] : _whole((sorted[middle - 1] + sorted[middle]) / 2);
    case 'Min':
      return numbers.isEmpty ? null : numbers.reduce(math.min);
    case 'Max':
      return numbers.isEmpty ? null : numbers.reduce(math.max);
    case 'Sum':
      return numbers.isEmpty ? null : numbers.reduce((a, b) => a + b);
    case 'Range':
      if (numbers.isNotEmpty) return numbers.reduce(math.max) - numbers.reduce(math.min);
      if (dates.isEmpty) return null;
      dates.sort();
      return dates.last.difference(dates.first);
    case 'Stddev':
      if (numbers.isEmpty) return null;
      final average = numbers.reduce((a, b) => a + b) / numbers.length;
      return math.sqrt(numbers.map((one) => (one - average) * (one - average)).reduce((a, b) => a + b) / numbers.length);
    case 'Earliest' || 'Latest':
      if (dates.isEmpty) return null;
      dates.sort();
      return name == 'Earliest' ? dates.first : dates.last;
    case 'Checked':
      return values.where((value) => value == true).length;
    case 'Unchecked':
      return values.where((value) => value != true).length;
    case 'Empty':
      return values.where(empty).length;
    case 'Filled':
      return values.where((value) => !empty(value)).length;
    case 'Unique':
      final seen = <Object?>[];
      for (final value in values.where((value) => !empty(value))) {
        if (!seen.any((other) => _equals(other, value))) seen.add(value);
      }
      return seen.length;
  }
  return null;
}

/// Значение строкой, как его показывает база: список через запятую, число без «.0».
String baseText(Object? value) => _text(value);

/// Новая база папки: заметки из неё и вложенных, таблица «Название» и «Изменена».
String newBaseFor(String folderPath) {
  // кавычка — для строки выражения, апостроф удваивается — для строки YAML в одинарных кавычках
  final escaped = folderPath.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll("'", "''");
  return 'filters:\n'
      '  and:\n'
      // база в корне смотрит на всё хранилище: условие «в папке» с пустым значением только путало
      "${folderPath.isEmpty ? '' : "    - 'file.inFolder(\"$escaped\")'\n"}"
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
String _noted(String property) => property.contains('.') ? property : 'note.$property';

Object? _groupKey(Object? value) => value is List ? value.map(_text).join(', ') : value;

/// Что записать в свойство [name] карточке, брошенной в колонку доски [key].
/// Колонка списка подписана склейкой «Прочитал, Любимое»: пишется сам список, а не одна строка с запятой.
Object? boardColumnValue(List<BaseNote> rows, String name, Object? key) {
  for (final row in rows) {
    final value = _plain(row.properties[name]);
    if (value is List && _groupKey(value) == key) return [...value];
  }
  // свойство-список остаётся списком и в новой колонке
  final asList = rows.any((row) => row.properties[name] is List);
  return asList ? [key] : key;
}

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
  bool empty(Object? value) => value == null || (value is String && value.isEmpty) || (value is List && value.isEmpty);
  if (empty(a)) return empty(b) ? 0 : 1;
  if (empty(b)) return -1;
  final (x, y) = _align(a, b);
  if (x is num && y is num) return x.compareTo(y);
  if (x is DateTime && y is DateTime) return x.compareTo(y);
  if (x is Duration && y is Duration) return x.compareTo(y);
  if (x is bool && y is bool) return x == y ? 0 : (x ? -1 : 1);
  return _text(x).toLowerCase().compareTo(_text(y).toLowerCase());
}

bool _truthy(Object? value) => switch (value) {
  null => false,
  bool() => value,
  num() => value != 0,
  String() => value.isNotEmpty,
  List() => value.isNotEmpty,
  Map() => value.isNotEmpty,
  _ => true,
};

/// Выражение Bases, которого Stowa не понимает.
class BaseUnsupported implements Exception {
  const BaseUnsupported(this.what);
  final String what;
  @override
  String toString() => 'BaseUnsupported($what)';
}
