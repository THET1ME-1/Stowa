import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../domain/obsidian_base.dart';
import '../../domain/word_forms.dart' show foldText;
import '../../l10n/app_localizations.dart';

/// Листы панели базы: сортировка, группа, свойства и формулы, настройки вида, итоги.
/// Каждый лист правит файл сразу, как в Obsidian: кнопки «Сохранить» нет.

/// Значок свойства: файла, формулы или заметки.
String basePropertyIcon(String property) => property.startsWith('file.')
    ? switch (property) {
        'file.name' || 'file.basename' => 'title',
        'file.ctime' || 'file.mtime' => 'schedule',
        'file.folder' => 'folder',
        'file.tags' => 'sell',
        'file.links' => 'link',
        _ => 'description',
      }
    : property.startsWith('formula.')
    ? 'functions'
    : 'list_alt';

Future<T?> _sheet<T>(BuildContext context, Widget Function(BuildContext sheet) builder) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Tokens.container,
  builder: (sheet) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
      child: SafeArea(top: false, child: builder(sheet)),
    ),
  ),
);

/// Заголовок листа: крупно, с полем экрана.
class BaseSheetTitle extends StatelessWidget {
  const BaseSheetTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.screen + 4, 0, Space.screen, 8),
    child: Row(
      children: [
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
        ?trailing,
      ],
    ),
  );
}

/// Кнопка-строка «+ Добавить …» внизу листа.
class BaseAddButton extends StatelessWidget {
  const BaseAddButton({super.key, required this.label, required this.onPressed, this.icon = 'add'});
  final String label;
  final String icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(onPressed: onPressed, icon: Icon(symbolIcon(icon), size: 20), label: Text(label)),
  );
}

/// Выбор свойства: поиск сверху, если свойств много. [none] — строка «без свойства» (вернёт '').
Future<String?> pickBaseProperty(
  BuildContext context, {
  required List<String> properties,
  required String Function(String property) label,
  String? selected,
  String? none,
  String? title,
}) => showOptionsSheetWith<String>(context, (sheet) => _PropertyPicker(properties: properties, label: label, selected: selected, none: none, title: title));

class _PropertyPicker extends StatefulWidget {
  const _PropertyPicker({required this.properties, required this.label, this.selected, this.none, this.title});
  final List<String> properties;
  final String Function(String property) label;
  final String? selected;
  final String? none;
  final String? title;

  @override
  State<_PropertyPicker> createState() => _PropertyPickerState();
}

class _PropertyPickerState extends State<_PropertyPicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _PropertyChoice(
      title: widget.title,
      properties: widget.properties,
      label: widget.label,
      selected: widget.selected,
      query: _query,
      onQuery: (value) => setState(() => _query = value),
      keyPrefix: 'base-pick-',
      trailing: widget.none == null
          ? null
          : TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(widget.none!)),
      onPick: (property) => Navigator.pop(context, property),
      searchHint: l.baseSearch,
    );
  }
}

/// Свойства на выбор разделами: сперва свои свойства заметок и формулы — по ним и группируют,
/// и фильтруют, — потом свойства файла. Пилюли переносом, а не строка на свойство:
/// двенадцать строк столбиком листались, а свои свойства оказывались в самом низу.
class _PropertyChoice extends StatelessWidget {
  const _PropertyChoice({
    required this.properties,
    required this.label,
    required this.onPick,
    required this.keyPrefix,
    required this.query,
    required this.onQuery,
    required this.searchHint,
    this.title,
    this.selected,
    this.trailing,
    this.top,
  });

  final List<String> properties;
  final String Function(String property) label;
  final ValueChanged<String> onPick;
  final String keyPrefix;
  final String query;
  final ValueChanged<String> onQuery;
  final String searchHint;
  final String? title;
  final String? selected;

  /// Справа от заголовка: «Убрать», направление группы.
  final Widget? trailing;

  /// Под заголовком, над разделами.
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final want = foldText(query.trim());
    bool shown(String property) => want.isEmpty || foldText(label(property)).contains(want) || foldText(property).contains(want);
    final notes = [for (final property in properties) if (!property.startsWith('file.') && shown(property)) property];
    final file = [for (final property in properties) if (property.startsWith('file.') && shown(property)) property];

    Widget section(String name, List<String> list) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 10), child: SheetTitle(name)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final property in list)
              _PropertyPill(key: ValueKey('$keyPrefix$property'), label: label(property), icon: basePropertyIcon(property), selected: property == selected, onTap: () => onPick(property)),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null || trailing != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(child: Text(title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge)),
                ?trailing,
              ],
            ),
          ),
        ?top,
        // пилюлями десяток свойств виден разом: поиск нужен, только когда их правда много
        if (properties.length > 16)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              decoration: InputDecoration(hintText: searchHint, prefixIcon: Icon(symbolIcon('search'))),
              onChanged: onQuery,
            ),
          ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notes.isNotEmpty) section(l.baseSectionNotes, notes),
                if (file.isNotEmpty) section(l.baseSectionFile, file),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Пилюля свойства: значок и подпись; выбранная — белая, как выбранное в листах.
class _PropertyPill extends StatelessWidget {
  const _PropertyPill({super.key, required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Tokens.onAccent : Tokens.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? Tokens.accent : Tokens.containerHigh,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(symbolIcon(icon, filled: selected), size: 20, color: ink),
                  const SizedBox(width: 8),
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── сортировка ──────────────────────────────────────────────────────────────

Future<void> showBaseSortSheet(
  BuildContext context, {
  required List<BaseSortKey> sort,
  required List<String> properties,
  required String Function(String property) label,
  required ValueChanged<List<BaseSortKey>> onChanged,
}) => _sheet<void>(context, (sheet) => _SortSheet(sort: sort, properties: properties, label: label, onChanged: onChanged));

class _SortSheet extends StatefulWidget {
  const _SortSheet({required this.sort, required this.properties, required this.label, required this.onChanged});
  final List<BaseSortKey> sort;
  final List<String> properties;
  final String Function(String property) label;
  final ValueChanged<List<BaseSortKey>> onChanged;

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  late var _sort = [...widget.sort];

  void _set(List<BaseSortKey> next) {
    setState(() => _sort = next);
    widget.onChanged(next);
  }

  Future<void> _pick([int? index]) async {
    final property = await pickBaseProperty(context, properties: widget.properties, label: widget.label, selected: index == null ? null : _sort[index].property);
    if (property == null || property.isEmpty || !mounted) return;
    final next = [..._sort];
    if (index == null) {
      next.add((property: property, descending: false));
    } else {
      next[index] = (property: property, descending: next[index].descending);
    }
    _set(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BaseSheetTitle(l.baseSort),
        Flexible(
          child: ReorderableListView(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(horizontal: Space.screen),
            onReorderItem: (from, to) {
              final next = [..._sort];
              final key = next.removeAt(from);
              next.insert(to, key);
              _set(next);
            },
            children: [
              for (final (i, key) in _sort.indexed)
                Padding(
                  key: ValueKey('base-sort-$i-${key.property}'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Tokens.containerHigh,
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(padding: const EdgeInsets.all(12), child: Icon(symbolIcon('drag_indicator'), color: Tokens.muted)),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pick(i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(widget.label(key.property), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          key: ValueKey('base-sort-direction-$i'),
                          onPressed: () => _set([for (final (j, one) in _sort.indexed) j == i ? (property: one.property, descending: !one.descending) : one]),
                          icon: Icon(symbolIcon(key.descending ? 'arrow_downward' : 'arrow_upward'), size: 18),
                          label: Text(key.descending ? l.baseDescending : l.baseAscending),
                        ),
                        IconButton(
                          tooltip: l.baseRemove,
                          onPressed: () => _set([..._sort]..removeAt(i)),
                          icon: Icon(symbolIcon('close'), size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen - 4, 0, Space.screen, Space.screen),
          child: BaseAddButton(key: const ValueKey('base-sort-add'), label: l.baseSortAdd, onPressed: _pick),
        ),
      ],
    );
  }
}

// ── группа ──────────────────────────────────────────────────────────────────

Future<void> showBaseGroupSheet(
  BuildContext context, {
  required BaseSortKey? group,
  required List<String> properties,
  required String Function(String property) label,
  required ValueChanged<BaseSortKey?> onChanged,
}) => _sheet<void>(context, (sheet) => _GroupSheet(group: group, properties: properties, label: label, onChanged: onChanged));

class _GroupSheet extends StatefulWidget {
  const _GroupSheet({required this.group, required this.properties, required this.label, required this.onChanged});
  final BaseSortKey? group;
  final List<String> properties;
  final String Function(String property) label;
  final ValueChanged<BaseSortKey?> onChanged;

  @override
  State<_GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends State<_GroupSheet> {
  late var _group = widget.group;

  void _set(BaseSortKey? next) {
    setState(() => _group = next);
    widget.onChanged(next);
  }

  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final group = _group;
    return _PropertyChoice(
      title: l.baseGroup,
      properties: widget.properties,
      label: widget.label,
      selected: group?.property,
      query: _query,
      onQuery: (value) => setState(() => _query = value),
      searchHint: l.baseSearch,
      keyPrefix: 'base-group-',
      // без группы — кнопкой в шапке, а не первой строкой списка
      trailing: group == null ? null : TextButton(key: const ValueKey('base-group-none'), onPressed: () => _set(null), child: Text(l.baseGroupNone)),
      top: group == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(l.baseAscending, maxLines: 1, overflow: TextOverflow.ellipsis), icon: Icon(symbolIcon('arrow_upward'), size: 18)),
                  ButtonSegment(value: true, label: Text(l.baseDescending, maxLines: 1, overflow: TextOverflow.ellipsis), icon: Icon(symbolIcon('arrow_downward'), size: 18)),
                ],
                selected: {group.descending},
                onSelectionChanged: (value) => _set((property: group.property, descending: value.single)),
              ),
            ),
      onPick: (property) => _set((property: property, descending: group?.descending ?? false)),
    );
  }
}

// ── свойства и формулы ──────────────────────────────────────────────────────

/// Что меняется в листе «Свойства»: порядок показанных, подпись, формула.
class BasePropertiesActions {
  const BasePropertiesActions({required this.onOrder, required this.onRename, required this.onFormula, required this.onRenameFormula});
  final ValueChanged<List<String>> onOrder;
  final void Function(String property, String? name) onRename;

  /// Имя и выражение; выражение null — удалить.
  final void Function(String name, String? expression) onFormula;
  final void Function(String from, String to) onRenameFormula;
}

Future<void> showBasePropertiesSheet(
  BuildContext context, {
  required List<String> order,
  required List<String> properties,
  required Map<String, String> formulas,
  required String Function(String property) label,
  required String Function(String expression) preview,
  required BasePropertiesActions actions,
}) => _sheet<void>(
  context,
  (sheet) => _PropertiesSheet(order: order, properties: properties, formulas: formulas, label: label, preview: preview, actions: actions),
);

class _PropertiesSheet extends StatefulWidget {
  const _PropertiesSheet({required this.order, required this.properties, required this.formulas, required this.label, required this.preview, required this.actions});
  final List<String> order;
  final List<String> properties;
  final Map<String, String> formulas;
  final String Function(String property) label;
  final String Function(String expression) preview;
  final BasePropertiesActions actions;

  @override
  State<_PropertiesSheet> createState() => _PropertiesSheetState();
}

class _PropertiesSheetState extends State<_PropertiesSheet> {
  late var _order = [...widget.order];
  late final _formulas = {...widget.formulas};
  final _names = <String, String?>{};
  var _query = '';

  String _label(String property) => _names.containsKey(property) ? (_names[property] ?? widget.label(property)) : widget.label(property);

  List<String> get _all => {...widget.properties, for (final name in _formulas.keys) 'formula.$name'}.toList();

  void _setOrder(List<String> next) {
    setState(() => _order = next);
    widget.actions.onOrder(next);
  }

  Future<void> _menu(String property) async {
    final l = L.of(context);
    final formula = property.startsWith('formula.') ? property.substring(8) : null;
    final action = await showOptionsSheet<String>(
      context,
      title: _label(property),
      options: [
        SheetChoice(value: 'rename', title: l.baseRename, icon: 'edit'),
        if (formula != null) SheetChoice(value: 'formula', title: l.baseFormulaEdit, icon: 'functions'),
        if (formula != null) SheetChoice(value: 'delete', title: l.baseFormulaDelete, icon: 'delete', danger: true),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'rename':
        final name = await askBaseText(context, title: l.baseRename, initial: _label(property));
        if (name == null || !mounted) return;
        setState(() => _names[property] = name.trim().isEmpty ? null : name.trim());
        widget.actions.onRename(property, name.trim().isEmpty ? null : name.trim());
      case 'formula':
        await _editFormula(formula);
      case 'delete':
        setState(() {
          _formulas.remove(formula);
          _order = [for (final one in _order) if (one != property) one];
        });
        widget.actions.onFormula(formula!, null);
    }
  }

  Future<void> _editFormula([String? name]) async {
    final result = await showBaseFormulaEditor(context, name: name, expression: name == null ? '' : _formulas[name] ?? '', preview: widget.preview, taken: _formulas.keys.where((one) => one != name).toSet());
    if (result == null || !mounted) return;
    final (newName, expression) = result;
    if (name != null && name != newName) {
      widget.actions.onRenameFormula(name, newName);
      setState(() {
        _formulas.remove(name);
        _order = [for (final one in _order) one == 'formula.$name' ? 'formula.$newName' : one];
      });
    }
    setState(() => _formulas[newName] = expression);
    widget.actions.onFormula(newName, expression);
    // новая формула сразу видна колонкой
    if (name == null && !_order.contains('formula.$newName')) _setOrder([..._order, 'formula.$newName']);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final query = foldText(_query.trim());
    bool matches(String property) => query.isEmpty || foldText(_label(property)).contains(query);
    final others = [for (final property in _all) if (!_order.contains(property) && matches(property)) property];
    Widget row(String property, {required bool shown, int? index}) => Material(
      key: ValueKey('base-prop-$property'),
      color: Colors.transparent,
      child: Row(
        children: [
          if (index != null)
            ReorderableDragStartListener(
              index: index,
              child: Padding(padding: const EdgeInsets.all(10), child: Icon(symbolIcon('drag_indicator'), color: Tokens.muted)),
            )
          else
            const SizedBox(width: 44),
          Icon(symbolIcon(basePropertyIcon(property)), size: 20, color: Tokens.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _menu(property),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_label(property), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
              ),
            ),
          ),
          Switch(
            key: ValueKey('base-prop-switch-$property'),
            value: shown,
            onChanged: (on) => _setOrder(on ? [..._order, property] : [for (final one in _order) if (one != property) one]),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BaseSheetTitle(l.baseProperties),
        if (_all.length > 8)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 8),
            child: TextField(
              decoration: InputDecoration(hintText: l.baseSearch, prefixIcon: Icon(symbolIcon('search'))),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        Flexible(
          child: CustomScrollView(
            shrinkWrap: true,
            slivers: [
              if (_order.isNotEmpty) SliverToBoxAdapter(child: _Caption(l.baseShownProps)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen - 8),
                sliver: SliverReorderableList(
                  itemCount: _order.length,
                  onReorderItem: (from, to) {
                    final next = [..._order];
                    final one = next.removeAt(from);
                    next.insert(to, one);
                    _setOrder(next);
                  },
                  itemBuilder: (context, i) => row(_order[i], shown: true, index: i),
                ),
              ),
              if (others.isNotEmpty) SliverToBoxAdapter(child: _Caption(l.baseOtherProps)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen - 8),
                sliver: SliverList.list(children: [for (final property in others) row(property, shown: false)]),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen - 4, 4, Space.screen, Space.screen),
          child: BaseAddButton(key: const ValueKey('base-formula-add'), label: l.baseFormulaAdd, icon: 'functions', onPressed: _editFormula),
        ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.screen + 4, 12, Space.screen, 4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Tokens.onSurfaceVariant)),
  );
}

/// Имя и выражение формулы. Пока выражение не понято — под полем что не так; понято — значение
/// у первой заметки. [taken] — имена других формул.
Future<(String, String)?> showBaseFormulaEditor(
  BuildContext context, {
  String? name,
  required String expression,
  required String Function(String expression) preview,
  Set<String> taken = const {},
}) => _sheet<(String, String)>(context, (sheet) => _FormulaEditor(name: name, expression: expression, preview: preview, taken: taken));

class _FormulaEditor extends StatefulWidget {
  const _FormulaEditor({this.name, required this.expression, required this.preview, required this.taken});
  final String? name;
  final String expression;
  final String Function(String expression) preview;
  final Set<String> taken;

  @override
  State<_FormulaEditor> createState() => _FormulaEditorState();
}

class _FormulaEditorState extends State<_FormulaEditor> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _expression = TextEditingController(text: widget.expression);

  @override
  void dispose() {
    _name.dispose();
    _expression.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final problem = _expression.text.trim().isEmpty ? null : ObsidianBase.check(_expression.text);
    final name = _name.text.trim();
    final ready = name.isNotEmpty && !widget.taken.contains(name) && _expression.text.trim().isNotEmpty && problem == null && !name.contains(RegExp(r'[.\s]'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.name == null ? l.baseFormulaAdd : l.baseFormulaEdit, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('base-formula-name'),
            controller: _name,
            autofocus: widget.name == null,
            decoration: InputDecoration(labelText: l.baseFormulaName),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('base-formula-expression'),
            controller: _expression,
            autofocus: widget.name != null,
            minLines: 2,
            maxLines: 6,
            style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['monospace']),
            decoration: InputDecoration(
              labelText: l.baseExpression,
              errorText: problem == null ? null : l.baseFormulaError(problem),
              helperText: problem == null && _expression.text.trim().isNotEmpty ? '= ${widget.preview(_expression.text)}' : null,
              helperMaxLines: 2,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('base-formula-save'),
            onPressed: ready ? () => Navigator.pop(context, (name, _expression.text.trim())) : null,
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}

/// Строка текста: имя вида, подпись колонки. Пусто — пустая строка, передумал — null.
Future<String?> askBaseText(BuildContext context, {required String title, String initial = '', TextInputType? keyboard}) {
  final field = TextEditingController(text: initial)..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  return _sheet<String>(
    context,
    (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('base-text-field'),
            controller: field,
            autofocus: true,
            keyboardType: keyboard,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (value) => Navigator.pop(sheet, value),
          ),
          const SizedBox(height: 16),
          FilledButton(key: const ValueKey('base-text-save'), onPressed: () => Navigator.pop(sheet, field.text), child: Text(L.of(sheet).save)),
        ],
      ),
    ),
  );
}

// ── настройки вида ──────────────────────────────────────────────────────────

/// Предел и, у карточек и доски, картинка, размер, пропорция и посадка картинки.
Future<void> showBaseViewSettings(
  BuildContext context, {
  required BaseView view,
  required List<String> properties,
  required String Function(String property) label,
  required void Function(String key, Object? value) onChanged,
}) => _sheet<void>(context, (sheet) => _ViewSettings(view: view, properties: properties, label: label, onChanged: onChanged));

class _ViewSettings extends StatefulWidget {
  const _ViewSettings({required this.view, required this.properties, required this.label, required this.onChanged});
  final BaseView view;
  final List<String> properties;
  final String Function(String property) label;
  final void Function(String key, Object? value) onChanged;

  @override
  State<_ViewSettings> createState() => _ViewSettingsState();
}

class _ViewSettingsState extends State<_ViewSettings> {
  late int? _limit = widget.view.limit;
  late String? _image = widget.view.image;
  late double _size = widget.view.cardSize ?? 200;
  late double _ratio = widget.view.imageAspectRatio ?? 1;
  late BaseImageFit _fit = widget.view.imageFit;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final cards = widget.view.type == BaseViewType.cards || widget.view.type == BaseViewType.kanban;
    Widget tile({required String title, String? value, required VoidCallback onTap, Key? key}) => ListTile(
      key: key,
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
          Icon(symbolIcon('chevron_right'), color: Tokens.muted),
        ],
      ),
      onTap: onTap,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Space.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BaseSheetTitle(l.baseViewSettings),
          tile(
            key: const ValueKey('base-setting-limit'),
            title: l.baseLimit,
            value: _limit == null ? l.baseLimitNone : '$_limit',
            onTap: () async {
              final raw = await askBaseText(context, title: l.baseLimit, initial: _limit == null ? '' : '$_limit', keyboard: TextInputType.number);
              if (raw == null || !mounted) return;
              final limit = int.tryParse(raw.trim());
              setState(() => _limit = limit != null && limit > 0 ? limit : null);
              widget.onChanged('limit', _limit);
            },
          ),
          if (cards) ...[
            tile(
              key: const ValueKey('base-setting-image'),
              title: l.baseImage,
              value: _image == null ? l.baseImageNone : widget.label(_image!),
              onTap: () async {
                final picked = await pickBaseProperty(context, properties: widget.properties, label: widget.label, selected: _image ?? '', none: l.baseImageNone);
                if (picked == null || !mounted) return;
                setState(() => _image = picked.isEmpty ? null : picked);
                widget.onChanged('image', _image == null ? null : (_image!.contains('.') ? _image : 'note.$_image'));
              },
            ),
            _Slider(
              label: l.baseCardSize,
              value: _size,
              min: 100,
              max: 400,
              shown: '${_size.round()}',
              onChanged: (value) => setState(() => _size = value),
              onDone: (value) => widget.onChanged('cardSize', value.round()),
            ),
            if (_image != null) ...[
              _Slider(
                label: l.baseImageRatio,
                value: _ratio,
                min: 0.25,
                max: 2.5,
                shown: _ratio.toStringAsFixed(2),
                onChanged: (value) => setState(() => _ratio = value),
                onDone: (value) => widget.onChanged('imageAspectRatio', double.parse(value.toStringAsFixed(2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 4, Space.screen, 0),
                child: SegmentedButton<BaseImageFit>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: BaseImageFit.cover, label: Text(l.baseImageFitCover)),
                    ButtonSegment(value: BaseImageFit.contain, label: Text(l.baseImageFitContain)),
                  ],
                  selected: {_fit},
                  onSelectionChanged: (value) {
                    setState(() => _fit = value.single);
                    widget.onChanged('imageFit', _fit == BaseImageFit.contain ? 'contain' : null);
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({required this.label, required this.value, required this.min, required this.max, required this.shown, required this.onChanged, required this.onDone});
  final String label;
  final double value;
  final double min;
  final double max;
  final String shown;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onDone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.screen, 8, Space.screen, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
            Text(shown, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
          ],
        ),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged, onChangeEnd: onDone),
      ],
    ),
  );
}

// ── итоги ───────────────────────────────────────────────────────────────────

String baseSummaryLabel(L l, String name) => switch (name) {
  'Average' => l.baseSumAverage,
  'Median' => l.baseSumMedian,
  'Min' => l.baseSumMin,
  'Max' => l.baseSumMax,
  'Sum' => l.baseSumSum,
  'Range' => l.baseSumRange,
  'Stddev' => l.baseSumStddev,
  'Earliest' => l.baseSumEarliest,
  'Latest' => l.baseSumLatest,
  'Checked' => l.baseSumChecked,
  'Unchecked' => l.baseSumUnchecked,
  'Empty' => l.baseSumEmpty,
  'Filled' => l.baseSumFilled,
  'Unique' => l.baseSumUnique,
  _ => name,
};

/// Итог колонки: готовые и свои из файла; '' — без итога, передумал — null.
Future<String?> pickBaseSummary(BuildContext context, {String? selected, Iterable<String> custom = const []}) {
  final l = L.of(context);
  return showOptionsSheet<String>(
    context,
    title: l.baseSummary,
    selected: selected ?? '',
    options: [
      SheetChoice(value: '', title: l.baseSummaryNone, icon: 'block'),
      for (final name in baseSummaryNames) SheetChoice(value: name, title: baseSummaryLabel(l, name), icon: 'calculate'),
      for (final name in custom) SheetChoice(value: name, title: name, icon: 'functions'),
    ],
  );
}
