import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../domain/base_filter_rows.dart';
import '../../domain/obsidian_base.dart';
import '../../l10n/app_localizations.dart';
import 'base_sheets.dart';

/// Окно фильтра, как в Obsidian: условия всех видов и этого вида, группы «все / любое /
/// ни одно» с вложением, перетаскивание строк, перенос строки между «всеми» и «этим».
/// Правка пишется в файл через полсекунды после последнего изменения.

String baseOpLabel(L l, FilterOp op) => switch (op) {
  FilterOp.isEqual => l.baseOpIs,
  FilterOp.isNot => l.baseOpIsNot,
  FilterOp.contains => l.baseOpContains,
  FilterOp.notContains => l.baseOpNotContains,
  FilterOp.startsWith => l.baseOpStarts,
  FilterOp.endsWith => l.baseOpEnds,
  FilterOp.isEmpty => l.baseOpEmpty,
  FilterOp.isNotEmpty => l.baseOpNotEmpty,
  FilterOp.greater => l.baseOpGreater,
  FilterOp.atLeast => l.baseOpAtLeast,
  FilterOp.less => l.baseOpLess,
  FilterOp.atMost => l.baseOpAtMost,
  FilterOp.hasTag => l.baseOpHasTag,
  FilterOp.notHasTag => l.baseOpNotHasTag,
  FilterOp.inFolder => l.baseOpInFolder,
  FilterOp.notInFolder => l.baseOpNotInFolder,
  FilterOp.hasLink => l.baseOpHasLink,
  FilterOp.expression => l.baseExpression,
};

String baseJoinLabel(L l, FilterJoin join) => switch (join) {
  FilterJoin.all => l.baseJoinAll,
  FilterJoin.any => l.baseJoinAny,
  FilterJoin.none => l.baseJoinNone,
};

/// [onChanged]: null — условия всех видов, иначе этого вида; фильтр null — условий нет.
Future<void> showBaseFilterSheet(
  BuildContext context, {
  required BaseFilter? all,
  required BaseFilter? view,
  required List<String> properties,
  required String Function(String property) label,
  required void Function(bool forAll, BaseFilter? filter) onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Tokens.container,
  builder: (sheet) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.9),
      child: SafeArea(
        top: false,
        child: _FilterSheet(all: all, view: view, properties: properties, label: label, onChanged: onChanged),
      ),
    ),
  ),
);

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.all, required this.view, required this.properties, required this.label, required this.onChanged});
  final BaseFilter? all;
  final BaseFilter? view;
  final List<String> properties;
  final String Function(String property) label;
  final void Function(bool forAll, BaseFilter? filter) onChanged;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late var _all = FilterGroup.from(widget.all);
  late var _view = FilterGroup.from(widget.view);
  // открывается на «этом виде», если условия есть только там
  late var _forAll = _view.items.isEmpty && _all.items.isNotEmpty;
  final _dirty = <bool>{};
  Timer? _save;

  @override
  void dispose() {
    _flush();
    super.dispose();
  }

  void _flush() {
    _save?.cancel();
    for (final forAll in _dirty) {
      widget.onChanged(forAll, (forAll ? _all : _view).toFilter());
    }
    _dirty.clear();
  }

  void _set(bool forAll, FilterGroup group, {bool now = false}) {
    setState(() => forAll ? _all = group : _view = group);
    _dirty.add(forAll);
    _save?.cancel();
    if (now) {
      _flush();
    } else {
      _save = Timer(const Duration(milliseconds: 500), _flush);
    }
  }

  /// Строка уходит из одной половины в другую: в конец группы верхнего уровня.
  void _move(List<int> path) {
    final from = _forAll ? _all : _view;
    final item = _at(from, path);
    _set(_forAll, _removeAt(from, path), now: true);
    final to = _forAll ? _view : _all;
    _set(!_forAll, to.copyWith(items: [...to.items, item]), now: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final group = _forAll ? _all : _view;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BaseSheetTitle(l.baseFilter),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 12),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: true, label: Text(_scopeLabel(l.baseFilterAll, _all.count))),
              ButtonSegment(value: false, label: Text(_scopeLabel(l.baseFilterThis, _view.count))),
            ],
            selected: {_forAll},
            onSelectionChanged: (value) => setState(() => _forAll = value.single),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
            child: _GroupEditor(
              key: ValueKey('filter-${_forAll ? 'all' : 'view'}'),
              group: group,
              path: const [],
              properties: widget.properties,
              label: widget.label,
              moveLabel: _forAll ? l.baseMoveToThis : l.baseMoveToAll,
              onChanged: (next) => _set(_forAll, next),
              onChangedNow: (next) => _set(_forAll, next, now: true),
              onMove: _move,
            ),
          ),
        ),
      ],
    );
  }

  String _scopeLabel(String text, int count) => count == 0 ? text : '$text · $count';
}

FilterItem _at(FilterGroup group, List<int> path) {
  final item = group.items[path.first];
  return path.length == 1 ? item : _at(item as FilterGroup, path.sublist(1));
}

FilterGroup _removeAt(FilterGroup group, List<int> path) {
  if (path.length == 1) return group.copyWith(items: [...group.items]..removeAt(path.first));
  final inner = group.items[path.first] as FilterGroup;
  return group.copyWith(items: [for (final (i, item) in group.items.indexed) i == path.first ? _removeAt(inner, path.sublist(1)) : item]);
}

class _GroupEditor extends StatelessWidget {
  const _GroupEditor({
    super.key,
    required this.group,
    required this.path,
    required this.properties,
    required this.label,
    required this.moveLabel,
    required this.onChanged,
    required this.onChangedNow,
    required this.onMove,
    this.onRemove,
  });

  final FilterGroup group;
  final List<int> path;
  final List<String> properties;
  final String Function(String property) label;
  final String moveLabel;

  /// Правка текста — с задержкой; выбор из списка и порядок — сразу.
  final ValueChanged<FilterGroup> onChanged;
  final ValueChanged<FilterGroup> onChangedNow;

  /// Путь строки от верхней группы: перенести в другую половину.
  final ValueChanged<List<int>> onMove;
  final VoidCallback? onRemove;

  void _replace(int index, FilterItem item, {bool now = false}) {
    final next = group.copyWith(items: [for (final (i, one) in group.items.indexed) i == index ? item : one]);
    now ? onChangedNow(next) : onChanged(next);
  }

  Future<void> _add(BuildContext context) async {
    final property = await pickBaseProperty(context, properties: properties, label: label);
    if (property == null || property.isEmpty) return;
    onChangedNow(group.copyWith(items: [...group.items, FilterRow(property, filterOpsFor(property).first, '')]));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final nested = path.isNotEmpty;
    return Container(
      decoration: nested ? BoxDecoration(color: Tokens.containerLow, borderRadius: BorderRadius.circular(18)) : null,
      padding: nested ? const EdgeInsets.fromLTRB(10, 6, 6, 6) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _Dropdown(
                    key: ValueKey('filter-join-${path.join('-')}'),
                    text: baseJoinLabel(l, group.join),
                    onTap: () async {
                      final join = await showOptionsSheet<FilterJoin>(
                        context,
                        selected: group.join,
                        options: [for (final join in FilterJoin.values) SheetChoice(value: join, title: baseJoinLabel(l, join))],
                      );
                      if (join != null) onChangedNow(group.copyWith(join: join));
                    },
                  ),
                ),
              ),
              if (onRemove != null) IconButton(tooltip: l.baseRemove, onPressed: onRemove, icon: Icon(symbolIcon('delete'), size: 20)),
            ],
          ),
          if (group.items.isEmpty && !nested)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l.baseFilterEmpty, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.muted)),
            ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) {
              final items = [...group.items];
              final item = items.removeAt(from);
              items.insert(to, item);
              onChangedNow(group.copyWith(items: items));
            },
            children: [
              for (final (i, item) in group.items.indexed)
                Padding(
                  // ключ по месту, а не по строке: строка меняется с каждой буквой, поле не должно терять фокус
                  key: ValueKey('filter-item-${[...path, i].join('-')}'),
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 12, 6, 12),
                          child: Icon(symbolIcon('drag_indicator'), color: Tokens.muted, size: 20),
                        ),
                      ),
                      Expanded(
                        child: switch (item) {
                          FilterRow() => _RowEditor(
                            key: ValueKey('filter-row-${[...path, i].join('-')}'),
                            row: item,
                            properties: properties,
                            label: label,
                            moveLabel: moveLabel,
                            onChanged: (row, {bool now = false}) => _replace(i, row, now: now),
                            onRemove: () => onChangedNow(group.copyWith(items: [...group.items]..removeAt(i))),
                            onMove: () => onMove([...path, i]),
                          ),
                          FilterGroup() => _GroupEditor(
                            group: item,
                            path: [...path, i],
                            properties: properties,
                            label: label,
                            moveLabel: moveLabel,
                            onChanged: (next) => _replace(i, next),
                            onChangedNow: (next) => _replace(i, next, now: true),
                            onMove: onMove,
                            onRemove: () => onChangedNow(group.copyWith(items: [...group.items]..removeAt(i))),
                          ),
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Wrap(
            children: [
              TextButton.icon(key: ValueKey('filter-add-${path.join('-')}'), onPressed: () => _add(context), icon: Icon(symbolIcon('add'), size: 20), label: Text(l.baseFilterAdd)),
              if (path.length < 3)
                TextButton.icon(
                  key: ValueKey('filter-add-group-${path.join('-')}'),
                  onPressed: () => onChangedNow(group.copyWith(items: [...group.items, const FilterGroup(FilterJoin.any, [])])),
                  icon: Icon(symbolIcon('data_object'), size: 20),
                  label: Text(l.baseFilterAddGroup),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RowEditor extends StatefulWidget {
  const _RowEditor({super.key, required this.row, required this.properties, required this.label, required this.moveLabel, required this.onChanged, required this.onRemove, required this.onMove});

  final FilterRow row;
  final List<String> properties;
  final String Function(String property) label;
  final String moveLabel;
  final void Function(FilterRow row, {bool now}) onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMove;

  @override
  State<_RowEditor> createState() => _RowEditorState();
}

class _RowEditorState extends State<_RowEditor> {
  late final _value = TextEditingController(text: _textOf(widget.row));

  static String _textOf(FilterRow row) => row.op == FilterOp.expression ? row.source : row.value;

  @override
  void didUpdateWidget(_RowEditor old) {
    super.didUpdateWidget(old);
    // строку перетащили или перенесли: на этом месте теперь другая
    if (_textOf(widget.row) != _value.text) _value.text = _textOf(widget.row);
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _menu() async {
    final l = L.of(context);
    final action = await showOptionsSheet<String>(
      context,
      options: [
        SheetChoice(value: 'move', title: widget.moveLabel, icon: 'drive_file_move'),
        if (widget.row.op != FilterOp.expression) SheetChoice(value: 'code', title: l.baseExpression, icon: 'code'),
        SheetChoice(value: 'remove', title: l.baseRemove, icon: 'delete', danger: true),
      ],
    );
    switch (action) {
      case 'move':
        widget.onMove();
      case 'code':
        final row = FilterRow.expression(widget.row.source);
        _value.text = row.source;
        widget.onChanged(row, now: true);
      case 'remove':
        widget.onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final row = widget.row;
    final expression = row.op == FilterOp.expression;
    final problem = expression && _value.text.trim().isNotEmpty ? ObsidianBase.check(_value.text) : null;
    return Material(
      color: Tokens.containerHigh,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 2, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // свойство и условие в свою ширину одной строкой; не влезли — условие переносится, а не режется
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: expression
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(l.baseExpression, style: Theme.of(context).textTheme.labelLarge),
                        )
                      : Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _Dropdown(
                              key: const ValueKey('filter-property'),
                              text: widget.label(row.property),
                              icon: basePropertyIcon(row.property),
                              onTap: () async {
                                final property = await pickBaseProperty(context, properties: widget.properties, label: widget.label, selected: row.property);
                                if (property != null && property.isNotEmpty) widget.onChanged(row.withProperty(property), now: true);
                              },
                            ),
                            _Dropdown(
                              key: const ValueKey('filter-op'),
                              text: baseOpLabel(l, row.op),
                              onTap: () async {
                                final op = await showOptionsSheet<FilterOp>(
                                  context,
                                  selected: row.op,
                                  options: [for (final op in filterOpsFor(row.property)) SheetChoice(value: op, title: baseOpLabel(l, op))],
                                );
                                if (op != null) widget.onChanged(row.withOp(op), now: true);
                              },
                            ),
                          ],
                        ),
                ),
                IconButton(key: const ValueKey('filter-row-menu'), onPressed: _menu, icon: Icon(symbolIcon('more_vert'), size: 20)),
              ],
            ),
            if (expression || filterOpTakesValue(row.op))
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextField(
                  key: const ValueKey('filter-value'),
                  controller: _value,
                  style: expression ? const TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['monospace']) : null,
                  minLines: 1,
                  maxLines: expression ? 4 : 1,
                  decoration: InputDecoration(isDense: true, hintText: expression ? 'file.mtime > now() - "7d"' : l.baseValue, errorText: problem == null ? null : l.baseFormulaError(problem)),
                  onChanged: (value) {
                    setState(() {});
                    widget.onChanged(expression ? FilterRow.expression(value) : row.withValue(value));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Подпись с треугольником: свойство, условие, «все / любое».
class _Dropdown extends StatelessWidget {
  const _Dropdown({super.key, required this.text, required this.onTap, this.icon});
  final String text;
  final String? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(symbolIcon(icon!), size: 18, color: Tokens.onSurfaceVariant), const SizedBox(width: 6)],
          Flexible(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge),
          ),
          Icon(symbolIcon('expand_more'), size: 18, color: Tokens.muted),
        ],
      ),
    ),
  );
}
