import 'obsidian_base.dart';

/// Фильтр базы глазами экрана: строки «свойство — условие — значение» в группах
/// «все / любое / ни одно», как в окне фильтра Obsidian. Выражение, которое строкой
/// не разложить, остаётся строкой-выражением и пишется обратно как было.

enum FilterOp {
  isEqual,
  isNot,
  contains,
  notContains,
  startsWith,
  endsWith,
  isEmpty,
  isNotEmpty,
  greater,
  atLeast,
  less,
  atMost,
  hasTag,
  notHasTag,
  inFolder,
  notInFolder,
  hasLink,
  expression,
}

/// Условию значение не нужно: «пусто», «не пусто».
bool filterOpTakesValue(FilterOp op) => op != FilterOp.isEmpty && op != FilterOp.isNotEmpty && op != FilterOp.expression;

/// Условия, которые есть у свойства: теги — «есть тег», папка — «в папке», остальное — сравнения.
List<FilterOp> filterOpsFor(String property) => [
  if (property == 'file.tags') ...[FilterOp.hasTag, FilterOp.notHasTag],
  if (property == 'file.folder') ...[FilterOp.inFolder, FilterOp.notInFolder],
  if (property == 'file.links') FilterOp.hasLink,
  FilterOp.isEqual,
  FilterOp.isNot,
  FilterOp.contains,
  FilterOp.notContains,
  FilterOp.startsWith,
  FilterOp.endsWith,
  FilterOp.isEmpty,
  FilterOp.isNotEmpty,
  FilterOp.greater,
  FilterOp.atLeast,
  FilterOp.less,
  FilterOp.atMost,
];

sealed class FilterItem {
  const FilterItem();
}

class FilterRow extends FilterItem {
  /// [property]: `file.folder`, `formula.x` или имя свойства заметки без `note.`.
  /// [quoted] — значение строкой в кавычках; число и true/false — без.
  const FilterRow(this.property, this.op, this.value, {this.quoted = true}) : raw = null;

  const FilterRow.expression(String source) : property = '', op = FilterOp.expression, value = '', quoted = false, raw = source;

  final String property;
  final FilterOp op;
  final String value;
  final bool quoted;
  final String? raw;

  /// Условие дописано: значение есть там, где оно нужно.
  bool get complete => !filterOpTakesValue(op) || value.trim().isNotEmpty;

  /// Новое значение: похожее на число или true/false пишется без кавычек.
  FilterRow withValue(String value) => FilterRow(property, op, value, quoted: !RegExp(r'^\s*(-?\d+(\.\d+)?|true|false)\s*$').hasMatch(value));

  FilterRow withOp(FilterOp op) => op == FilterOp.expression ? FilterRow.expression(source) : FilterRow(property, op, value, quoted: quoted);

  FilterRow withProperty(String property) {
    final ops = filterOpsFor(property);
    return FilterRow(property, ops.contains(op) ? op : ops.firstWhere((one) => one == FilterOp.isEqual), value, quoted: quoted);
  }

  static final _property = r'''(note\["(?:[^"\\]|\\.)*"\]|[\p{L}_][\p{L}\p{N}_.-]*)''';
  static final _literal = r'''("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|-?\d+(?:\.\d+)?|true|false)''';

  static FilterRow parse(String source) {
    final text = source.trim();
    RegExpMatch? match(String pattern) => RegExp('^$pattern\$', unicode: true).firstMatch(text);
    String name(String raw) {
      if (raw.startsWith('note[')) return _unquote(raw.substring(5, raw.length - 1));
      return raw.startsWith('note.') ? raw.substring(5) : raw;
    }

    FilterRow literal(String property, FilterOp op, String raw) {
      final quoted = raw.startsWith('"') || raw.startsWith("'");
      return FilterRow(property, op, quoted ? _unquote(raw) : raw, quoted: quoted);
    }

    for (final (pattern, op) in [
      (r'file\.hasTag\(' + _literal + r'\)', FilterOp.hasTag),
      (r'!\s*file\.hasTag\(' + _literal + r'\)', FilterOp.notHasTag),
      (r'file\.inFolder\(' + _literal + r'\)', FilterOp.inFolder),
      (r'!\s*file\.inFolder\(' + _literal + r'\)', FilterOp.notInFolder),
      (r'file\.hasLink\(' + _literal + r'\)', FilterOp.hasLink),
    ]) {
      if (match(pattern) case final found?) {
        final property = switch (op) {
          FilterOp.hasTag || FilterOp.notHasTag => 'file.tags',
          FilterOp.hasLink => 'file.links',
          _ => 'file.folder',
        };
        return literal(property, op, found[1]!);
      }
    }
    for (final (pattern, op) in [
      ('!\\s*$_property\\.contains\\($_literal\\)', FilterOp.notContains),
      ('$_property\\.contains\\($_literal\\)', FilterOp.contains),
      ('$_property\\.startsWith\\($_literal\\)', FilterOp.startsWith),
      ('$_property\\.endsWith\\($_literal\\)', FilterOp.endsWith),
    ]) {
      if (match(pattern) case final found?) return literal(name(found[1]!), op, found[2]!);
    }
    if (match('!\\s*$_property\\.isEmpty\\(\\)') case final found?) return FilterRow(name(found[1]!), FilterOp.isNotEmpty, '');
    if (match('$_property\\.isEmpty\\(\\)') case final found?) return FilterRow(name(found[1]!), FilterOp.isEmpty, '');
    if (match('$_property\\s*(==|!=|>=|<=|>|<)\\s*$_literal') case final found?) {
      final op = switch (found[2]!) {
        '==' => FilterOp.isEqual,
        '!=' => FilterOp.isNot,
        '>=' => FilterOp.atLeast,
        '<=' => FilterOp.atMost,
        '>' => FilterOp.greater,
        _ => FilterOp.less,
      };
      return literal(name(found[1]!), op, found[3]!);
    }
    return FilterRow.expression(text);
  }

  /// Выражение Bases для этой строки.
  String get source {
    if (op == FilterOp.expression) return raw ?? '';
    final subject = property.startsWith('file.') || property.startsWith('formula.') || RegExp(r'^[\p{L}_][\p{L}\p{N}_]*$', unicode: true).hasMatch(property)
        ? property
        : 'note[${_quote(property)}]';
    final literal = quoted ? _quote(value) : value.trim();
    final tag = _quote(value.trim().replaceFirst('#', ''));
    return switch (op) {
      FilterOp.isEqual => '$subject == $literal',
      FilterOp.isNot => '$subject != $literal',
      FilterOp.contains => '$subject.contains($literal)',
      FilterOp.notContains => '!$subject.contains($literal)',
      FilterOp.startsWith => '$subject.startsWith($literal)',
      FilterOp.endsWith => '$subject.endsWith($literal)',
      FilterOp.isEmpty => '$subject.isEmpty()',
      FilterOp.isNotEmpty => '!$subject.isEmpty()',
      FilterOp.greater => '$subject > $literal',
      FilterOp.atLeast => '$subject >= $literal',
      FilterOp.less => '$subject < $literal',
      FilterOp.atMost => '$subject <= $literal',
      FilterOp.hasTag => 'file.hasTag($tag)',
      FilterOp.notHasTag => '!file.hasTag($tag)',
      FilterOp.inFolder => 'file.inFolder(${_quote(value)})',
      FilterOp.notInFolder => '!file.inFolder(${_quote(value)})',
      FilterOp.hasLink => 'file.hasLink(${_quote(value)})',
      FilterOp.expression => raw ?? '',
    };
  }

  @override
  bool operator ==(Object other) => other is FilterRow && other.property == property && other.op == op && other.value == value && other.quoted == quoted && other.raw == raw;

  @override
  int get hashCode => Object.hash(property, op, value, quoted, raw);

  @override
  String toString() => 'FilterRow($source)';
}

/// «Все условия», «любое из», «ни одно из».
enum FilterJoin { all, any, none }

class FilterGroup extends FilterItem {
  const FilterGroup(this.join, this.items);

  final FilterJoin join;
  final List<FilterItem> items;

  factory FilterGroup.from(BaseFilter? filter) => switch (filter) {
    null => const FilterGroup(FilterJoin.all, []),
    BaseExpr(:final source) => FilterGroup(FilterJoin.all, [FilterRow.parse(source)]),
    BaseAnd(:final all) => FilterGroup(FilterJoin.all, [for (final one in all) _item(one)]),
    BaseOr(:final any) => FilterGroup(FilterJoin.any, [for (final one in any) _item(one)]),
    BaseNot(:final none) => FilterGroup(FilterJoin.none, [for (final one in none) _item(one)]),
  };

  static FilterItem _item(BaseFilter filter) => filter is BaseExpr ? FilterRow.parse(filter.source) : FilterGroup.from(filter);

  FilterGroup copyWith({FilterJoin? join, List<FilterItem>? items}) => FilterGroup(join ?? this.join, items ?? this.items);

  /// Сколько строк во всех вложенных группах: число на кнопке «Фильтр».
  int get count => items.fold(0, (sum, item) => sum + (item is FilterGroup ? item.count : 1));

  /// Фильтр для файла; пустая группа — фильтра нет. Условие, которому ещё не вписали значение,
  /// в файл не идёт: иначе база пустела, пока человек выбирает свойство и набирает значение.
  BaseFilter? toFilter() {
    final parts = [
      for (final item in items)
        if (item is FilterRow && item.source.trim().isNotEmpty && item.complete) BaseExpr(item.source) else if (item is FilterGroup) ?item.toFilter(),
    ];
    if (parts.isEmpty) return null;
    return switch (join) {
      FilterJoin.all => BaseAnd(parts),
      FilterJoin.any => BaseOr(parts),
      FilterJoin.none => BaseNot(parts),
    };
  }
}

/// С чем завести новую заметку в виде, чтобы она в нём и осталась: папка, свойства и теги
/// из условий «все» (общих и вида). [group] — колонка канбана: свойство и его значение.
({String? folder, Map<String, Object?> properties, List<String> tags}) newNoteDefaults(ObsidianBase base, int view, {(String, Object?)? group}) {
  String? folder;
  final properties = <String, Object?>{};
  final tags = <String>[];
  void take(BaseFilter? filter) {
    final group = FilterGroup.from(filter);
    if (group.join != FilterJoin.all) return;
    for (final item in group.items) {
      if (item is! FilterRow || item.property.startsWith('formula.')) continue;
      Object? value() => item.quoted ? item.value : (num.tryParse(item.value) ?? (item.value == 'true' ? true : item.value == 'false' ? false : item.value));
      switch (item.op) {
        case FilterOp.inFolder:
          folder = item.value;
        case FilterOp.isEqual when item.property == 'file.folder':
          folder = item.value;
        case FilterOp.hasTag:
          tags.add(item.value.replaceFirst('#', ''));
        case FilterOp.isEqual when !item.property.startsWith('file.'):
          properties[item.property] = value();
        case FilterOp.contains when !item.property.startsWith('file.'):
          properties[item.property] = [...?(properties[item.property] as List?), value()];
        default:
      }
    }
  }

  take(base.filters);
  if (base.views.isNotEmpty) take(base.views[view.clamp(0, base.views.length - 1)].filters);
  if (group case (final property, final value) when !property.startsWith('file.') && !property.startsWith('formula.')) {
    properties[property.startsWith('note.') ? property.substring(5) : property] = value;
  }
  return (folder: folder, properties: properties, tags: tags);
}

String _quote(String value) => '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

String _unquote(String raw) => raw.substring(1, raw.length - 1).replaceAllMapped(RegExp(r'\\(.)'), (match) => match[1]!);
