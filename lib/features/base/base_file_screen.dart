import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/hint_banner.dart';
import '../../core/widgets/sheet_options.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/base_edit.dart';
import '../../domain/hints.dart' show Tip;
import '../../domain/base_filter_rows.dart';
import '../../domain/obsidian_base.dart';
import '../../l10n/app_localizations.dart';
import '../folder/folder_sheets.dart' show showRenameSheet;
import '../item/item_screen.dart' show itemRoute;
import '../item/properties_block.dart' show editProperty;
import 'base_filter_sheet.dart';
import 'base_sheets.dart';
import 'base_views.dart';

/// Заметки глазами базы: пересчитываются при любой правке заметок, тегов и файлов.
final baseNotesProvider = StreamProvider.autoDispose<List<BaseNote>>((ref) {
  final db = ref.watch(databaseProvider);
  final repository = ref.watch(documentsRepositoryProvider);
  return db.changesOf([db.items, db.itemTags, db.vaultFiles, db.folders, db.attachments]).asyncMap((_) => repository.baseNotes());
});

/// Свойства файла, которые база знает всегда.
const _fileProperties = ['file.name', 'file.folder', 'file.tags', 'file.links', 'file.ctime', 'file.mtime', 'file.path'];

/// База Obsidian (`.base`) как в Obsidian: виды вкладками, панель «Сортировка, Группа,
/// Фильтр, Свойства, Поиск, Создать», таблица с правкой ячеек, итогами и шириной колонок,
/// карточки, список и доска. Любая правка сразу ложится в тот же файл.
class BaseFileScreen extends ConsumerStatefulWidget {
  const BaseFileScreen({super.key, required this.item});

  final Item item;

  @override
  ConsumerState<BaseFileScreen> createState() => _BaseFileScreenState();
}

class _BaseFileScreenState extends ConsumerState<BaseFileScreen> {
  var _view = 0;
  var _search = '';
  var _searching = false;
  final _searchField = TextEditingController();
  final _collapsed = <Object?>{};

  /// Записанный, но ещё не вернувшийся из базы текст файла: следующая правка идёт от него.
  String? _pending;

  String get _text => _pending ?? widget.item.document ?? '';

  @override
  void didUpdateWidget(BaseFileScreen old) {
    super.didUpdateWidget(old);
    if (_pending != null && widget.item.document == _pending) _pending = null;
  }

  @override
  void dispose() {
    _searchField.dispose();
    super.dispose();
  }

  Future<void> _edit(void Function(BaseEditor editor) change) async {
    final editor = BaseEditor(_text);
    change(editor);
    final next = editor.text;
    if (next == _text) return;
    _pending = next;
    // лист, закрываясь, дописывает последнюю правку, когда дерево виджетов занято: перерисовка — после кадра
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      setState(() {});
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    await ref.read(documentsRepositoryProvider).saveBase(widget.item.id, next);
  }

  Future<void> _rename() async {
    final name = await showRenameSheet(context, widget.item.title, label: L.of(context).baseColName);
    if (name == null || name.trim().isEmpty) return;
    await ref.read(documentsRepositoryProvider).rename(widget.item.id, name.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final base = ObsidianBase.parse(_text);
    final notes = ref.watch(baseNotesProvider).value;
    final now = ref.watch(clockProvider)();
    final filesRoot = ref.watch(filesRootProvider);
    final index = _view.clamp(0, base.views.length - 1);
    final view = base.views[index];
    final columns = view.order.isEmpty ? const ['file.name'] : view.order;
    final result = notes == null || base.broken ? null : base.run(index, notes, now: now, search: _searching ? _search : '', columns: columns);
    final canEdit = !base.broken;

    Object? read(BaseNote note, String property) {
      try {
        return base.value(note, property, now: now);
      } on BaseUnsupported {
        return null;
      }
    }

    String label(String property) => base.displayName(property) ?? builtInLabel(l, property);
    final properties = _properties(base, notes ?? const [], now);

    final actions = BaseViewActions(
      label: label,
      show: (note, property) => formatBaseValue(l, read(note, property), property),
      open: (note) => Navigator.of(context).push(itemRoute(note.id)),
      editCell: _editCell,
      columnMenu: (property) => _columnMenu(base, index, property, label),
      resize: (property, width) => _edit((editor) => editor.setColumnSize(index, property, width)),
      summaryMenu: (property) async {
        final picked = await pickBaseSummary(context, selected: view.summaryOf(property), custom: base.summaries.keys);
        if (picked != null) await _edit((editor) => editor.setSummary(index, property, picked.isEmpty ? null : picked));
      },
      summaryText: (property) {
        final name = view.summaryOf(property);
        if (name == null || result == null) return null;
        final value = base.summary(name, [for (final note in result.rows) read(note, property)], now: now);
        final shown = formatBaseValue(l, value, property);
        return '${baseSummaryLabel(l, name)} $shown'.trim();
      },
      groupLabel: (key) => key == null || (key is String && key.isEmpty) ? l.baseNoGroup : formatBaseValue(l, key, ''),
      create: (key) => _createNote(base, index, group: key),
      move: (note, key) => _move(view, note, key, result?.rows ?? const []),
      canEdit: canEdit,
    );

    final subtitle = result == null
        ? l.kindBase
        : result.total > result.rows.length
        ? '${l.kindBase} · ${l.baseShown(result.rows.length, result.total)}'
        : '${l.kindBase} · ${l.baseCount(result.rows.length)}';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(symbolIcon('arrow_back')),
                    style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(44)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('base-title'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _rename,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleLarge),
                          Text(subtitle, style: text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _ViewTabs(
              views: base.views,
              selected: index,
              canEdit: canEdit,
              onSelect: (i) => setState(() {
                _view = i;
                _collapsed.clear();
              }),
              onMenu: (i) => _viewMenu(base, i, properties, label),
              onAdd: () => _addView(base, properties, label),
              onReorder: (from, to) async {
                await _edit((editor) => editor.moveView(from, to));
                if (!mounted) return;
                // выбранный вид остаётся выбранным, куда бы ни переехал
                if (from == index) {
                  setState(() => _view = to);
                } else if (from < index && to >= index) {
                  setState(() => _view = index - 1);
                } else if (from > index && to <= index) {
                  setState(() => _view = index + 1);
                }
              },
            ),
            // значки панели без подписей: один раз назвать их словами
            if (canEdit) const HintBanner(tip: Tip.base, padding: EdgeInsets.fromLTRB(Space.screen, 4, Space.screen, 4)),
            if (canEdit) _toolbar(l, base, index, view, properties, label, now, notes ?? const []),
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 2, Space.screen, 6),
                child: TextField(
                  key: const ValueKey('base-search-field'),
                  controller: _searchField,
                  autofocus: true,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l.baseSearchHint,
                    prefixIcon: Icon(symbolIcon('search')),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() {
                        _searching = false;
                        _search = '';
                        _searchField.clear();
                      }),
                      icon: Icon(symbolIcon('close')),
                    ),
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
            if (base.broken) _Note(text: l.baseBroken, icon: 'error'),
            if (result?.unsupported ?? false) _Note(text: l.baseUnsupported, icon: 'help'),
            if (view.type == BaseViewType.map) _Note(text: l.baseMapAsList, icon: 'map'),
            if (view.type == BaseViewType.kanban && view.groupBy == null) _Note(text: l.baseKanbanNeedsGroup, icon: 'view_kanban'),
            Expanded(
              child: result == null
                  ? const SizedBox.shrink()
                  : result.rows.isEmpty && view.type != BaseViewType.kanban
                  ? Center(child: Text(l.baseEmpty, style: text.bodyMedium!.copyWith(color: Tokens.muted)))
                  : switch (view.type) {
                      BaseViewType.table || BaseViewType.other => BaseTable(
                        result: result,
                        view: view,
                        columns: columns,
                        actions: actions,
                        collapsed: _collapsed,
                        onToggle: _toggle,
                      ),
                      BaseViewType.cards => BaseCards(
                        result: result,
                        view: view,
                        columns: view.order,
                        actions: actions,
                        filesRoot: filesRoot,
                        read: read,
                        collapsed: _collapsed,
                        onToggle: _toggle,
                      ),
                      BaseViewType.kanban when view.groupBy != null => BaseKanban(
                        result: result,
                        view: view,
                        columns: view.order,
                        actions: actions,
                        filesRoot: filesRoot,
                        read: read,
                      ),
                      BaseViewType.list || BaseViewType.map || BaseViewType.kanban => BaseList(
                        result: result,
                        columns: columns,
                        actions: actions,
                        collapsed: _collapsed,
                        onToggle: _toggle,
                      ),
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(Object? key) => setState(() => _collapsed.contains(key) ? _collapsed.remove(key) : _collapsed.add(key));

  /// Свойства для выбора: файла, заметок базы (по общим условиям) и формулы.
  List<String> _properties(ObsidianBase base, List<BaseNote> notes, DateTime now) {
    final inBase = ObsidianBase(filters: base.filters, formulas: base.formulas, views: const [BaseView(type: BaseViewType.table, name: '')]).run(0, notes, now: now).rows;
    final keys = <String>{for (final note in inBase) ...note.properties.keys}..removeAll(const ['tags', 'aliases', 'cssclasses']);
    return [..._fileProperties, ...keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())), for (final name in base.formulas.keys) 'formula.$name'];
  }

  Widget _toolbar(L l, ObsidianBase base, int index, BaseView view, List<String> properties, String Function(String) label, DateTime now, List<BaseNote> notes) {
    final filters = FilterGroup.from(base.filters).count + FilterGroup.from(view.filters).count;
    final buttons = [
      _ToolButton(
        key: const ValueKey('base-sort'),
        icon: 'swap_vert',
        label: l.baseSort,
        active: view.sort.isNotEmpty,
        count: view.sort.length,
        onTap: () => showBaseSortSheet(context, sort: view.sort, properties: properties, label: label, onChanged: (sort) => _edit((editor) => editor.setSort(index, sort))),
      ),
      _ToolButton(
        key: const ValueKey('base-group'),
        icon: 'workspaces',
        label: l.baseGroup,
        active: view.groupBy != null,
        onTap: () => showBaseGroupSheet(context, group: view.groupBy, properties: properties, label: label, onChanged: (group) => _edit((editor) => editor.setGroupBy(index, group))),
      ),
      _ToolButton(
        key: const ValueKey('base-filter'),
        icon: 'filter_list',
        label: l.baseFilter,
        active: filters > 0,
        count: filters,
        onTap: () => showBaseFilterSheet(
          context,
          all: base.filters,
          view: view.filters,
          properties: properties,
          label: label,
          onChanged: (forAll, filter) => _edit((editor) => editor.setFilter(forAll ? null : index, filter)),
        ),
      ),
      _ToolButton(
        key: const ValueKey('base-properties'),
        icon: 'view_column',
        label: l.baseProperties,
        active: false,
        onTap: () => showBasePropertiesSheet(
          context,
          order: view.order.isEmpty && view.type == BaseViewType.table ? const ['file.name'] : view.order,
          properties: properties,
          formulas: base.formulas,
          label: label,
          preview: (expression) => _preview(base, expression, notes, now),
          actions: BasePropertiesActions(
            onOrder: (order) => _edit((editor) => editor.setOrder(index, order)),
            onRename: (property, name) => _edit((editor) => editor.setDisplayName(property, name)),
            onFormula: (name, expression) => _edit((editor) => editor.setFormula(name, expression)),
            onRenameFormula: (from, to) => _edit((editor) => editor.renameFormula(from, to)),
          ),
        ),
      ),
      _ToolButton(
        key: const ValueKey('base-search'),
        icon: 'search',
        label: l.baseSearch,
        active: _searching,
        onTap: () => setState(() => _searching = true),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen - 8, 0, Space.screen, 4),
      child: Row(
        children: [
          ...buttons,
          const Spacer(),
          _ToolButton(key: const ValueKey('base-create'), icon: 'add', label: l.baseCreate, active: false, filled: true, onTap: () => _createNote(base, index)),
        ],
      ),
    );
  }

  /// Значение формулы у первой заметки базы — подсказка под полем.
  String _preview(ObsidianBase base, String expression, List<BaseNote> notes, DateTime now) {
    final rows = base.run(_view.clamp(0, base.views.length - 1), notes, now: now).rows;
    if (rows.isEmpty) return '';
    final probe = ObsidianBase(formulas: {...base.formulas, '\u0000': expression}, views: base.views);
    try {
      return formatBaseValue(L.of(context), probe.value(rows.first, 'formula.\u0000', now: now), '');
    } on BaseUnsupported catch (error) {
      return error.what;
    }
  }

  Future<void> _editCell(BaseNote note, String property) async {
    final name = property.startsWith('note.') ? property.substring(5) : property;
    final next = await editProperty(context, note.properties, name: name);
    if (next == null) return;
    await ref.read(itemsRepositoryProvider).setProperties(note.id, next, ref.read(clockProvider)());
  }

  Future<void> _columnMenu(ObsidianBase base, int index, String property, String Function(String) label) async {
    final l = L.of(context);
    final view = base.views[index];
    final formula = property.startsWith('formula.') ? property.substring(8) : null;
    final action = await showOptionsSheet<String>(
      context,
      title: label(property),
      options: [
        SheetChoice(value: 'asc', title: l.baseAscending, icon: 'arrow_upward'),
        SheetChoice(value: 'desc', title: l.baseDescending, icon: 'arrow_downward'),
        SheetChoice(value: 'rename', title: l.baseRename, icon: 'edit'),
        SheetChoice(value: 'summary', title: l.baseSummary, icon: 'calculate', subtitle: view.summaryOf(property) == null ? null : baseSummaryLabel(l, view.summaryOf(property)!)),
        if (formula != null) SheetChoice(value: 'formula', title: l.baseFormulaEdit, icon: 'functions'),
        if (property != (view.order.firstOrNull ?? 'file.name')) SheetChoice(value: 'hide', title: l.baseColumnHide, icon: 'visibility_off'),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'asc' || 'desc':
        await _edit((editor) => editor.setSort(index, [(property: property, descending: action == 'desc')]));
      case 'rename':
        final name = await askBaseText(context, title: l.baseRename, initial: label(property));
        if (name != null) await _edit((editor) => editor.setDisplayName(property, name));
      case 'summary':
        final picked = await pickBaseSummary(context, selected: view.summaryOf(property), custom: base.summaries.keys);
        if (picked != null) await _edit((editor) => editor.setSummary(index, property, picked.isEmpty ? null : picked));
      case 'formula':
        final notes = ref.read(baseNotesProvider).value ?? const [];
        final now = ref.read(clockProvider)();
        final result = await showBaseFormulaEditor(
          context,
          name: formula,
          expression: base.formulas[formula] ?? '',
          preview: (expression) => _preview(base, expression, notes, now),
          taken: base.formulas.keys.where((one) => one != formula).toSet(),
        );
        if (result == null) return;
        await _edit((editor) {
          if (result.$1 != formula) editor.renameFormula(formula!, result.$1);
          editor.setFormula(result.$1, result.$2);
        });
      case 'hide':
        final order = view.order.isEmpty ? const ['file.name'] : view.order;
        await _edit((editor) => editor.setOrder(index, [for (final one in order) if (one != property) one]));
    }
  }

  Future<void> _viewMenu(ObsidianBase base, int index, List<String> properties, String Function(String) label) async {
    final l = L.of(context);
    final view = base.views[index];
    final action = await showOptionsSheet<String>(
      context,
      title: view.name.isEmpty ? l.kindBase : view.name,
      options: [
        SheetChoice(value: 'settings', title: l.baseViewSettings, icon: 'tune'),
        SheetChoice(value: 'layout', title: l.baseViewLayout, icon: _viewIcon(view.type), subtitle: _layoutName(l, view.type)),
        SheetChoice(value: 'rename', title: l.baseRename, icon: 'edit'),
        SheetChoice(value: 'copy', title: l.baseViewCopy, icon: 'content_copy'),
        if (base.views.length > 1) SheetChoice(value: 'delete', title: l.baseViewDelete, icon: 'delete', danger: true),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'settings':
        await showBaseViewSettings(context, view: view, properties: properties, label: label, onChanged: (key, value) => _edit((editor) => editor.setCardOption(index, key, value)));
      case 'layout':
        final type = await _pickLayout(view.type);
        if (type == null) return;
        await _edit((editor) => editor.setViewType(index, type));
        if (type == BaseViewType.kanban && view.groupBy == null) await _askColumns(index, properties, label);
      case 'rename':
        final name = await askBaseText(context, title: l.baseRename, initial: view.name);
        if (name != null && name.trim().isNotEmpty) await _edit((editor) => editor.renameView(index, name.trim()));
      case 'copy':
        await _edit((editor) => editor.duplicateView(index, '${view.name.isEmpty ? l.kindBase : view.name} 2'));
        if (mounted) setState(() => _view = base.views.length);
      case 'delete':
        await _edit((editor) => editor.deleteView(index));
        if (mounted) setState(() => _view = (index - 1).clamp(0, base.views.length - 2));
    }
  }

  Future<BaseViewType?> _pickLayout(BaseViewType? selected) {
    final l = L.of(context);
    return showOptionsSheet<BaseViewType>(
      context,
      title: l.baseViewLayout,
      selected: selected,
      options: [
        for (final type in const [BaseViewType.table, BaseViewType.cards, BaseViewType.list, BaseViewType.kanban])
          SheetChoice(value: type, title: _layoutName(l, type), icon: _viewIcon(type)),
      ],
    );
  }

  Future<void> _addView(ObsidianBase base, List<String> properties, String Function(String) label) async {
    final l = L.of(context);
    final type = await _pickLayout(null);
    if (type == null || !mounted) return;
    final name = await askBaseText(context, title: l.baseViewAdd, initial: _layoutName(l, type));
    if (name == null || !mounted) return;
    await _edit((editor) => editor.addView(type, name.trim().isEmpty ? _layoutName(l, type) : name.trim()));
    if (!mounted) return;
    setState(() => _view = base.views.length);
    if (type == BaseViewType.kanban) await _askColumns(base.views.length, properties, label);
  }

  /// Доска без колонок пуста: свойство для них спрашивается сразу, а не подсказкой «выберите в Группе».
  Future<void> _askColumns(int index, List<String> properties, String Function(String) label) async {
    if (!mounted) return;
    await showBaseGroupSheet(context, group: null, properties: properties, label: label, onChanged: (group) => _edit((editor) => editor.setGroupBy(index, group)));
  }

  /// Новая заметка вида: папка, свойства и теги из условий, чтобы она в виде и осталась.
  Future<void> _createNote(ObsidianBase base, int index, {Object? group}) async {
    final l = L.of(context);
    final view = base.views[index];
    final defaults = newNoteDefaults(base, index, group: view.groupBy == null || group == null || (group is String && group.isEmpty) ? null : (view.groupBy!.property, group));
    final documents = ref.read(documentsRepositoryProvider);
    var folderId = defaults.folder == null ? widget.item.folderId : await documents.folderAt(defaults.folder!);
    if (view.groupBy?.property == 'file.folder' && group != null) folderId = await documents.folderAt('$group') ?? folderId;
    final id = await documents.createNote(title: l.baseUntitled, folderId: folderId, properties: defaults.properties);
    for (final tag in defaults.tags) {
      await ref.read(tagsRepositoryProvider).link(id, tag);
    }
    if (mounted) await Navigator.of(context).push(itemRoute(id));
  }

  /// Карточку доски перенесли: новое значение свойства или папка.
  Future<void> _move(BaseView view, BaseNote note, Object? key, List<BaseNote> rows) async {
    final property = view.groupBy?.property;
    if (property == null) return;
    final now = ref.read(clockProvider)();
    final empty = key == null || (key is String && key.isEmpty);
    if (property == 'file.folder') {
      final folderId = empty ? null : await ref.read(documentsRepositoryProvider).folderAt('$key');
      await ref.read(itemsRepositoryProvider).moveToFolder(note.id, folderId, now);
      return;
    }
    final name = property.startsWith('note.') ? property.substring(5) : property;
    final next = {...note.properties};
    if (empty) {
      next.remove(name);
    } else {
      next[name] = boardColumnValue(rows, name, key);
    }
    await ref.read(itemsRepositoryProvider).setProperties(note.id, next, now);
  }
}

/// Кнопка панели: значок с подсказкой; включённое — цветом акцента, [count] — числом в углу.
/// Подписи на телефоне не помещаются: шесть кнопок со словами шире экрана.
class _ToolButton extends StatelessWidget {
  const _ToolButton({super.key, required this.icon, required this.label, required this.active, required this.onTap, this.count = 0, this.filled = false});
  final String icon;
  final String label;
  final bool active;
  final int count;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Tokens.accent : Tokens.onSurfaceVariant;
    final glyph = Icon(symbolIcon(icon), size: 22, color: filled ? Tokens.onAccent : color);
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      style: filled ? IconButton.styleFrom(backgroundColor: Tokens.accent) : null,
      icon: count > 0 ? Badge(label: Text('$count'), backgroundColor: Tokens.accent, textColor: Tokens.onAccent, child: glyph) : glyph,
    );
  }
}

/// Виды вкладками. Касание выбранного — меню вида, долгое нажатие — перетащить, «+» — новый вид.
class _ViewTabs extends StatelessWidget {
  const _ViewTabs({required this.views, required this.selected, required this.canEdit, required this.onSelect, required this.onMenu, required this.onAdd, required this.onReorder});
  final List<BaseView> views;
  final int selected;
  final bool canEdit;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onMenu;
  final VoidCallback onAdd;
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    Widget chip(int i) {
      final view = views[i];
      final on = i == selected;
      return Padding(
        key: ValueKey('base-view-$i'),
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(view.name.isEmpty ? builtInViewName(l, view.type) : view.name),
          // выбранный — белая пилюля с тёмной подписью, как выбор в настройках
          labelStyle: text.labelLarge!.copyWith(color: on ? Tokens.onAccent : Tokens.onSurface),
          avatar: Icon(symbolIcon(_viewIcon(view.type)), size: 18, color: on ? Tokens.onAccent : Tokens.onSurfaceVariant),
          selected: on,
          selectedColor: Tokens.accent,
          showCheckmark: false,
          onSelected: (_) => on && canEdit ? onMenu(i) : onSelect(i),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: Space.screen),
              buildDefaultDragHandles: canEdit && views.length > 1,
              proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
              onReorderItem: onReorder,
              children: [for (var i = 0; i < views.length; i++) chip(i)],
            ),
          ),
          if (canEdit)
            IconButton(
              key: const ValueKey('base-view-add'),
              tooltip: l.baseViewAdd,
              onPressed: onAdd,
              icon: Icon(symbolIcon('add')),
            ),
          const SizedBox(width: Space.screen - 8),
        ],
      ),
    );
  }
}

String _viewIcon(BaseViewType type) => switch (type) {
  BaseViewType.table || BaseViewType.other => 'table_view',
  BaseViewType.cards => 'grid_view',
  BaseViewType.list => 'view_agenda',
  BaseViewType.kanban => 'view_kanban',
  BaseViewType.map => 'map',
};

String _layoutName(L l, BaseViewType type) => switch (type) {
  BaseViewType.table || BaseViewType.other => l.baseLayoutTable,
  BaseViewType.cards => l.baseLayoutCards,
  BaseViewType.list => l.baseLayoutList,
  BaseViewType.kanban => l.baseLayoutKanban,
  BaseViewType.map => l.baseLayoutMap,
};

/// Вид без имени в файле подписывается видом базы.
String builtInViewName(L l, BaseViewType type) => l.kindBase;

/// Подписи колонок `file.*` на языке приложения; свойство — как его назвали.
String builtInLabel(L l, String property) => switch (property) {
  'file.name' || 'file.basename' => l.baseColName,
  'file.ctime' => l.baseColCreated,
  'file.mtime' => l.baseColModified,
  'file.folder' => l.baseColFolder,
  'file.tags' => l.baseColTags,
  'file.path' => l.baseColPath,
  'file.links' => l.baseColLinks,
  'file.ext' => l.baseColExt,
  _ => property.replaceFirst(RegExp(r'^(note|formula)\.'), ''),
};

final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?)?$');
final _wikiLink = RegExp(r'^!?\[\[([^\]|]+)(?:\|([^\]]+))?\]\]$');

/// Значение ячейки строкой: дата коротко, ссылка `[[путь|имя]]` — именем, список через
/// запятую, «да/нет» галочкой.
String formatBaseValue(L l, Object? value, String property) {
  String date(DateTime day) {
    // год пишется, только если он не нынешний: иначе дата со временем не влезает в колонку телефона
    final shown = (day.year == DateTime.now().year ? DateFormat.MMMd(l.localeName) : DateFormat.yMMMd(l.localeName)).format(day);
    return day.hour == 0 && day.minute == 0 ? shown : '$shown, ${DateFormat.Hm(l.localeName).format(day)}';
  }

  if (value is String) {
    final trimmed = value.trim();
    if (_wikiLink.firstMatch(trimmed) case final match?) return match[2] ?? match[1]!.split('/').last.replaceFirst(RegExp(r'\.md$'), '');
    if (_isoDate.hasMatch(trimmed)) {
      if (DateTime.tryParse(trimmed) case final day?) return date(day);
    }
    return value;
  }
  return switch (value) {
    null => '',
    DateTime() => date(value),
    bool() => value ? '✓' : '—',
    num() => value % 1 == 0 ? '${value.toInt()}' : value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), ''),
    List() => value.map((one) => formatBaseValue(l, one, property)).where((one) => one.isNotEmpty).join(', '),
    Duration() => '${value.inDays}d',
    _ => baseText(value),
  };
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.icon});
  final String text;
  final String icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 8),
    child: Row(
      children: [
        Icon(symbolIcon(icon), size: 18, color: Tokens.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Tokens.muted))),
      ],
    ),
  );
}
