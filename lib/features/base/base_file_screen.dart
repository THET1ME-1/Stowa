import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/marked_text.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/obsidian_base.dart';
import '../../l10n/app_localizations.dart';
import '../../services/vault/vault_layout.dart';
import '../folder/folder_sheets.dart' show showRenameSheet;
import '../item/item_screen.dart' show itemRoute;

/// Заметки глазами базы: пересчитываются при любой правке заметок, тегов и файлов.
final baseNotesProvider = StreamProvider.autoDispose<List<BaseNote>>((ref) {
  final db = ref.watch(databaseProvider);
  final repository = ref.watch(documentsRepositoryProvider);
  return db.changesOf([db.items, db.itemTags, db.vaultFiles, db.folders, db.attachments]).asyncMap((_) => repository.baseNotes());
});

/// База Obsidian (`.base`): виды вкладками сверху, под ними выбранный вид.
/// Только просмотр: условия и колонки правятся в файле.
class BaseFileScreen extends ConsumerStatefulWidget {
  const BaseFileScreen({super.key, required this.item});

  final Item item;

  @override
  ConsumerState<BaseFileScreen> createState() => _BaseFileScreenState();
}

class _BaseFileScreenState extends ConsumerState<BaseFileScreen> {
  var _view = 0;

  Future<void> _rename() async {
    final name = await showRenameSheet(context, widget.item.title);
    if (name == null || name.trim().isEmpty) return;
    await ref.read(documentsRepositoryProvider).rename(widget.item.id, name.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final base = ObsidianBase.parse(widget.item.document ?? '');
    final notes = ref.watch(baseNotesProvider).value;
    final now = ref.watch(clockProvider)();
    final filesRoot = ref.watch(filesRootProvider);
    final index = _view.clamp(0, base.views.length - 1);
    final view = base.views[index];
    final result = notes == null || base.broken ? null : base.run(index, notes, now: now);
    final columns = view.order.isEmpty ? const ['file.name'] : view.order;

    String label(String property) => base.displayName(property) ?? builtInLabel(l, property);
    String show(BaseNote note, String property) => formatBaseValue(l, _value(base, note, property, now), property);
    void open(BaseNote note) => Navigator.of(context).push(itemRoute(note.id));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 8),
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
                          Text(result == null ? l.kindBase : '${l.kindBase} · ${l.baseCount(result.rows.length)}', style: text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (base.views.length > 1)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                  children: [
                    for (final (i, one) in base.views.indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      ChoiceChip(
                        key: ValueKey('base-view-$i'),
                        label: Text(one.name.isEmpty ? builtInViewName(l, one.type) : one.name),
                        // выбранный — белая пилюля с тёмной подписью, как выбор в настройках
                        labelStyle: text.labelLarge!.copyWith(color: i == index ? Tokens.onAccent : Tokens.onSurface),
                        avatar: Icon(symbolIcon(_viewIcon(one.type)), size: 18, color: i == index ? Tokens.onAccent : Tokens.onSurfaceVariant),
                        selected: i == index,
                        selectedColor: Tokens.accent,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _view = i),
                      ),
                    ],
                  ],
                ),
              ),
            if (base.broken) _Note(text: l.baseBroken, icon: 'error'),
            if (result?.unsupported ?? false) _Note(text: l.baseUnsupported, icon: 'help'),
            if (view.type == BaseViewType.map) _Note(text: l.baseMapAsList, icon: 'map'),
            Expanded(
              child: result == null
                  ? const SizedBox.shrink()
                  : result.rows.isEmpty
                  ? Center(child: Text(l.baseEmpty, style: text.bodyMedium!.copyWith(color: Tokens.muted)))
                  : switch (view.type) {
                      BaseViewType.table || BaseViewType.other => _Table(result: result, columns: columns, label: label, show: show, onOpen: open, groupLabel: (key) => _groupLabel(l, key)),
                      BaseViewType.cards => _Cards(result: result, columns: columns, show: show, filesRoot: filesRoot, onOpen: open),
                      BaseViewType.list || BaseViewType.map => _List(result: result, columns: columns, label: label, show: show, onOpen: open, groupLabel: (key) => _groupLabel(l, key)),
                    },
            ),
          ],
        ),
      ),
    );
  }

  Object? _value(ObsidianBase base, BaseNote note, String property, DateTime now) {
    try {
      return base.value(note, property, now: now);
    } on BaseUnsupported {
      return null;
    }
  }

  String _groupLabel(L l, Object? key) => key == null || (key is String && key.isEmpty) ? l.baseNoGroup : formatBaseValue(l, key, '');
}

String _viewIcon(BaseViewType type) => switch (type) {
  BaseViewType.table || BaseViewType.other => 'table_view',
  BaseViewType.cards => 'grid_view',
  BaseViewType.list => 'view_agenda',
  BaseViewType.map => 'map',
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
  _ => property.replaceFirst(RegExp(r'^(note|formula)\.'), ''),
};

/// Значение ячейки строкой: дата коротко, список через запятую, «да/нет» галочкой.
String formatBaseValue(L l, Object? value, String property) => switch (value) {
  null => '',
  DateTime() => DateFormat.yMMMd(l.localeName).format(value),
  bool() => value ? '✓' : '—',
  num() => value % 1 == 0 ? '${value.toInt()}' : value.toStringAsFixed(2),
  List() => value.map((one) => '$one').join(', '),
  _ => '$value',
};

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.icon});

  final String text;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.screen, 4, Space.screen, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(symbolIcon(icon), size: 20, color: Tokens.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Таблица: первая колонка (название) стоит на месте, остальные листаются вбок вместе.
class _Table extends StatefulWidget {
  const _Table({required this.result, required this.columns, required this.label, required this.show, required this.onOpen, required this.groupLabel});

  final BaseResult result;
  final List<String> columns;
  final String Function(String property) label;
  final String Function(BaseNote note, String property) show;
  final void Function(BaseNote note) onOpen;
  final String Function(Object? key) groupLabel;

  @override
  State<_Table> createState() => _TableState();
}

class _TableState extends State<_Table> {
  final _sideways = ScrollController();

  @override
  void dispose() {
    _sideways.dispose();
    super.dispose();
  }

  static const _rowHeight = 52.0;
  static const _firstWidth = 168.0;
  static const _cellWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final first = widget.columns.first;
    final rest = widget.columns.skip(1).toList();
    final groups = widget.result.groups ?? [BaseGroup(null, widget.result.rows)];
    final hasGroups = widget.result.groups != null;

    Widget cell(String value, double width, {TextStyle? style, bool head = false}) => Container(
      width: width,
      height: head ? 40 : _rowHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(value, maxLines: head ? 1 : 2, overflow: TextOverflow.ellipsis, style: style),
    );

    final headStyle = text.labelMedium!.copyWith(color: Tokens.muted);
    final rows = <Widget>[];
    final firstColumn = <Widget>[cell(widget.label(first), _firstWidth, style: headStyle, head: true)];
    final restRows = <Widget>[Row(children: [for (final column in rest) cell(widget.label(column), _cellWidth, style: headStyle, head: true)])];
    for (final group in groups) {
      if (hasGroups) {
        final title = Container(
          height: 40,
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(widget.groupLabel(group.key), style: text.titleSmall),
        );
        firstColumn.add(SizedBox(width: _firstWidth, child: title));
        restRows.add(const SizedBox(height: 40));
      }
      for (final (i, note) in group.rows.indexed) {
        final shade = i.isOdd ? Tokens.containerLow : Colors.transparent;
        firstColumn.add(
          InkWell(
            key: ValueKey('base-row-${note.id}'),
            onTap: () => widget.onOpen(note),
            child: Container(color: shade, child: cell(widget.show(note, first), _firstWidth, style: text.titleSmall)),
          ),
        );
        restRows.add(
          InkWell(
            onTap: () => widget.onOpen(note),
            child: Container(color: shade, child: Row(children: [for (final column in rest) cell(widget.show(note, column), _cellWidth, style: text.bodyMedium)])),
          ),
        );
      }
    }
    rows
      ..add(Column(crossAxisAlignment: CrossAxisAlignment.start, children: firstColumn))
      ..add(
        Expanded(
          child: Scrollbar(
            controller: _sideways,
            child: SingleChildScrollView(
              controller: _sideways,
              scrollDirection: Axis.horizontal,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: restRows),
            ),
          ),
        ),
      );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.screen - 12, 0, 0, 32),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.result, required this.columns, required this.label, required this.show, required this.onOpen, required this.groupLabel});

  final BaseResult result;
  final List<String> columns;
  final String Function(String property) label;
  final String Function(BaseNote note, String property) show;
  final void Function(BaseNote note) onOpen;
  final String Function(Object? key) groupLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final groups = result.groups ?? [BaseGroup(null, result.rows)];
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 32),
      children: [
        for (final group in groups) ...[
          if (result.groups != null) Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 8), child: Text(groupLabel(group.key), style: text.titleSmall)),
          for (final note in group.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Tokens.containerHigh,
                borderRadius: BorderRadius.circular(Radii.tile),
                child: InkWell(
                  key: ValueKey('base-row-${note.id}'),
                  borderRadius: BorderRadius.circular(Radii.tile),
                  onTap: () => onOpen(note),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(show(note, columns.first), style: text.titleSmall),
                        for (final column in columns.skip(1))
                          if (show(note, column) case final value when value.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('${label(column)}: $value', maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({required this.result, required this.columns, required this.show, required this.filesRoot, required this.onOpen});

  final BaseResult result;
  final List<String> columns;
  final String Function(BaseNote note, String property) show;
  final Directory filesRoot;
  final void Function(BaseNote note) onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(Space.screen, 4, Space.screen, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.78),
      itemCount: result.rows.length,
      itemBuilder: (context, i) {
        final note = result.rows[i];
        final image = note.properties['image'] ?? note.properties['cover'] ?? note.image;
        return Material(
          color: Tokens.containerHigh,
          borderRadius: BorderRadius.circular(Radii.tile),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('base-row-${note.id}'),
            onTap: () => onOpen(note),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: image is String && image.isNotEmpty && !image.startsWith('http')
                      ? Image.file(
                          File(vaultAbsolute(filesRoot.path, image.replaceAll(RegExp(r'^\[\[|\]\]$'), ''))),
                          fit: BoxFit.cover,
                          cacheWidth: 500,
                          errorBuilder: (_, _, _) => ColoredBox(color: Tokens.containerHighest, child: Icon(symbolIcon('description'), color: Tokens.muted)),
                        )
                      : ColoredBox(color: Tokens.containerHighest, child: Icon(symbolIcon('description'), color: Tokens.muted)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(show(note, columns.first), maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                      if (columns.length > 1 && show(note, columns[1]).isNotEmpty)
                        MarkedText.note(show(note, columns[1]), style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
