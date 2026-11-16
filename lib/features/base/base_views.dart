import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/file_picture.dart';
import '../../domain/obsidian_base.dart';
import '../../services/vault/vault_layout.dart';

/// Раскладки вида базы: таблица, карточки, список, доска. Всё, что меняет файл или
/// заметку, уходит наверх через [BaseViewActions]: раскладки сами ничего не пишут.

class BaseViewActions {
  const BaseViewActions({
    required this.label,
    required this.show,
    required this.open,
    required this.editCell,
    required this.columnMenu,
    required this.resize,
    required this.summaryMenu,
    required this.summaryText,
    required this.groupLabel,
    required this.create,
    required this.move,
    required this.canEdit,
  });

  final String Function(String property) label;
  final String Function(BaseNote note, String property) show;
  final void Function(BaseNote note) open;

  /// Касание ячейки свойства заметки: правка значения.
  final void Function(BaseNote note, String property) editCell;
  final void Function(String property) columnMenu;
  final void Function(String property, double width) resize;
  final void Function(String property) summaryMenu;

  /// Итог колонки строкой; null — итога нет.
  final String? Function(String property) summaryText;
  final String Function(Object? key) groupLabel;

  /// Новая заметка в колонке доски со значением группы.
  final void Function(Object? groupKey) create;

  /// Карточку доски перенесли в колонку [groupKey].
  final void Function(BaseNote note, Object? groupKey) move;
  final bool canEdit;
}

/// Свойство заметки (не файла и не формула): его можно править в ячейке и на доске.
bool isNoteProperty(String property) => !property.startsWith('file.') && !property.startsWith('formula.');

/// Шапка группы: подпись, число, касание сворачивает.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.count, required this.collapsed, required this.onTap});
  final String title;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Row(
          children: [
            Icon(symbolIcon(collapsed ? 'chevron_right' : 'expand_more'), size: 20, color: Tokens.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
            ),
            const SizedBox(width: 8),
            Text('$count', style: text.bodySmall!.copyWith(color: Tokens.muted)),
          ],
        ),
      ),
    );
  }
}

/// Группы вида; без группировки — одна безымянная.
List<BaseGroup> _groupsOf(BaseResult result) => result.groups ?? [BaseGroup(null, result.rows)];

// ── таблица ─────────────────────────────────────────────────────────────────

class BaseTable extends StatefulWidget {
  const BaseTable({super.key, required this.result, required this.view, required this.columns, required this.actions, required this.collapsed, required this.onToggle});

  final BaseResult result;
  final BaseView view;
  final List<String> columns;
  final BaseViewActions actions;
  final Set<Object?> collapsed;
  final ValueChanged<Object?> onToggle;

  @override
  State<BaseTable> createState() => _BaseTableState();
}

class _BaseTableState extends State<BaseTable> {
  final _sideways = ScrollController();

  /// Ширина, пока тянут край колонки: в файл уходит, когда отпустили.
  final _dragging = <String, double>{};

  static const _rowHeight = 48.0;
  static const _headHeight = 44.0;

  @override
  void dispose() {
    _sideways.dispose();
    super.dispose();
  }

  /// Ширины в файле — точки Obsidian на компьютере; на телефоне та же колонка уже.
  static const _scale = 0.7;

  double _width(String property, {required bool first}) {
    if (_dragging[property] case final width?) return width;
    // ширины Obsidian сняты с компьютера: на телефоне колонка уже, но пропорции те же
    final screen = MediaQuery.sizeOf(context).width;
    // одна колонка — на всю ширину, а не узкой полосой слева
    if (first && widget.columns.length == 1) return screen - 2 * Space.screen;
    final saved = widget.view.widthOf(property);
    // закреплённое название не шире половины экрана: справа должны быть видны другие колонки
    if (saved != null) return (saved * _scale).clamp(64, first ? screen * 0.5 : 360);
    return first ? 168 : 140;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final actions = widget.actions;
    final first = widget.columns.first;
    final rest = widget.columns.skip(1).toList();
    final sortOf = {for (final key in widget.view.sort) key.property: key.descending};
    final summaries = widget.columns.any((column) => actions.summaryText(column) != null);
    final headStyle = text.labelMedium!.copyWith(color: Tokens.onSurfaceVariant);

    Widget head(String property, {required bool isFirst}) {
      final width = _width(property, first: isFirst);
      final sorted = sortOf[property];
      return SizedBox(
        key: ValueKey('base-head-$property'),
        width: width,
        height: _headHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: InkWell(
                onTap: actions.canEdit ? () => actions.columnMenu(property) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(actions.label(property), maxLines: 1, overflow: TextOverflow.ellipsis, style: headStyle),
                      ),
                      if (sorted != null) Icon(symbolIcon(sorted ? 'arrow_downward' : 'arrow_upward'), size: 14, color: Tokens.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
            if (actions.canEdit)
              Positioned(
                right: 0,
                top: 8,
                bottom: 8,
                width: 14,
                child: GestureDetector(
                  key: ValueKey('base-resize-$property'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) => setState(() => _dragging[property] = (width + details.delta.dx).clamp(64, 600)),
                  onHorizontalDragEnd: (_) {
                    final width = _dragging.remove(property);
                    // в файл — обратно в масштаб Obsidian
                    if (width != null) actions.resize(property, width / _scale);
                  },
                  child: Center(child: Container(width: 2, color: Tokens.outline.withValues(alpha: 0.5))),
                ),
              ),
          ],
        ),
      );
    }

    Widget cell(BaseNote note, String property, {required bool isFirst, required Color shade}) {
      final value = actions.show(note, property);
      final editable = actions.canEdit && !isFirst && isNoteProperty(property);
      return InkWell(
        key: ValueKey('base-cell-${note.id}-$property'),
        onTap: isFirst || !editable ? () => actions.open(note) : () => actions.editCell(note, property),
        child: Container(
          width: _width(property, first: isFirst),
          height: _rowHeight,
          color: shade,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: isFirst ? text.titleSmall : text.bodyMedium),
        ),
      );
    }

    Widget footer(String property, {required bool isFirst}) {
      final value = actions.summaryText(property);
      return InkWell(
        key: ValueKey('base-summary-$property'),
        onTap: actions.canEdit ? () => actions.summaryMenu(property) : null,
        child: Container(
          width: _width(property, first: isFirst),
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Text(
            value ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelLarge!.copyWith(color: Tokens.onSurfaceVariant),
          ),
        ),
      );
    }

    final firstColumn = <Widget>[head(first, isFirst: true)];
    final restRows = <Widget>[
      Row(children: [for (final column in rest) head(column, isFirst: false)]),
    ];
    var stripe = 0;
    for (final group in _groupsOf(widget.result)) {
      final collapsed = widget.collapsed.contains(group.key);
      if (widget.result.groups != null) {
        final title = _GroupHeader(title: actions.groupLabel(group.key), count: group.rows.length, collapsed: collapsed, onTap: () => widget.onToggle(group.key));
        firstColumn.add(SizedBox(width: _width(first, first: true), height: _rowHeight + 4, child: title));
        restRows.add(const SizedBox(height: _rowHeight + 4));
      }
      if (collapsed) continue;
      for (final note in group.rows) {
        final shade = stripe.isOdd ? Tokens.containerLow : Colors.transparent;
        stripe++;
        firstColumn.add(
          Container(
            key: ValueKey('base-row-${note.id}'),
            child: cell(note, first, isFirst: true, shade: shade),
          ),
        );
        restRows.add(Row(children: [for (final column in rest) cell(note, column, isFirst: false, shade: shade)]));
      }
    }
    if (summaries) {
      firstColumn.add(footer(first, isFirst: true));
      restRows.add(Row(children: [for (final column in rest) footer(column, isFirst: false)]));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 96),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Space.screen - 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: firstColumn),
          ),
          Expanded(
            child: Scrollbar(
              controller: _sideways,
              child: SingleChildScrollView(
                controller: _sideways,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: Space.screen),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: restRows),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── список ──────────────────────────────────────────────────────────────────

class BaseList extends StatelessWidget {
  const BaseList({super.key, required this.result, required this.columns, required this.actions, required this.collapsed, required this.onToggle});

  final BaseResult result;
  final List<String> columns;
  final BaseViewActions actions;
  final Set<Object?> collapsed;
  final ValueChanged<Object?> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 96),
      children: [
        for (final group in _groupsOf(result)) ...[
          if (result.groups != null) _GroupHeader(title: actions.groupLabel(group.key), count: group.rows.length, collapsed: collapsed.contains(group.key), onTap: () => onToggle(group.key)),
          if (!collapsed.contains(group.key))
            for (final note in group.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Tokens.containerHigh,
                  borderRadius: BorderRadius.circular(Radii.tile),
                  child: InkWell(
                    key: ValueKey('base-row-${note.id}'),
                    borderRadius: BorderRadius.circular(Radii.tile),
                    onTap: () => actions.open(note),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(actions.show(note, columns.first), style: text.titleSmall),
                          for (final column in columns.skip(1))
                            if (actions.show(note, column) case final value when value.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('${actions.label(column)}: $value', maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall),
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

// ── карточки ────────────────────────────────────────────────────────────────

/// Картинка заметки для карточки: свойство из настроек вида (`[[путь|имя]]`, путь), иначе
/// первая картинка заметки. Ссылка на сайт — null: картинки из сети база не тянет.
String? baseCardImage(BaseView view, BaseNote note, Object? Function(String property) read) {
  if (view.image case final property?) {
    var value = read(property);
    if (value is List) value = value.firstOrNull;
    if (value is! String || value.trim().isEmpty) return null;
    final path = value.trim().replaceAll(RegExp(r'^!?\[\[|\]\]$'), '').split('|').first.trim();
    if (path.startsWith('http')) return null;
    return path.contains('/') || note.folder.isEmpty ? path : '${note.folder}/$path';
  }
  return note.image;
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.path, required this.filesRoot, required this.fit});
  final String? path;
  final Directory filesRoot;
  final BaseImageFit fit;

  @override
  Widget build(BuildContext context) {
    final empty = ColoredBox(
      color: Tokens.containerHighest,
      child: Icon(symbolIcon('description'), color: Tokens.muted),
    );
    if (path == null) return empty;
    return ColoredBox(
      color: Tokens.containerHighest,
      child: FilePicture(File(vaultAbsolute(filesRoot.path, path!)), fit: fit == BaseImageFit.contain ? BoxFit.contain : BoxFit.cover, cacheWidth: 600, errorBuilder: (_, _, _) => empty),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.note, required this.view, required this.columns, required this.actions, required this.filesRoot, required this.image, required this.imageHeight, this.bounded = false});

  /// Карточка в сетке с заданной высотой; на доске высота по тексту.
  final bool bounded;
  final BaseNote note;
  final BaseView view;
  final List<String> columns;
  final BaseViewActions actions;
  final Directory filesRoot;
  final String? image;
  final double? imageHeight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = columns.contains('file.name') || columns.isEmpty ? 'file.name' : columns.first;
    return Material(
      color: Tokens.containerHigh,
      borderRadius: BorderRadius.circular(Radii.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('base-row-${note.id}'),
        onTap: () => actions.open(note),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageHeight != null)
              SizedBox(
                height: imageHeight,
                child: _CardImage(path: image, filesRoot: filesRoot, fit: view.imageFit),
              ),
            // в сетке высота карточки задана: длинный текст обрезается рамкой, а не вылезает за неё
            if (bounded) Flexible(child: ClipRect(child: _text(text, title))) else _text(text, title),
          ],
        ),
      ),
    );
  }

  Widget _text(TextTheme text, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(actions.show(note, title), maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
        for (final column in columns)
          if (column != title)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${actions.label(column)}  ',
                      style: text.labelSmall!.copyWith(color: Tokens.muted),
                    ),
                    TextSpan(
                      text: actions.show(note, column),
                      style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      ],
    ),
  );
}

/// Высота картинки в карточке шириной [width]: пропорция из вида; без картинок — null.
double? _imageHeight(BaseView view, double width, bool anyImage) {
  if (view.image == null && !anyImage) return null;
  return width * (view.imageAspectRatio ?? (view.image == null ? 0.75 : 1));
}

class BaseCards extends StatelessWidget {
  const BaseCards({
    super.key,
    required this.result,
    required this.view,
    required this.columns,
    required this.actions,
    required this.filesRoot,
    required this.read,
    required this.collapsed,
    required this.onToggle,
  });

  final BaseResult result;
  final BaseView view;
  final List<String> columns;
  final BaseViewActions actions;
  final Directory filesRoot;
  final Object? Function(BaseNote note, String property) read;
  final Set<Object?> collapsed;
  final ValueChanged<Object?> onToggle;

  @override
  Widget build(BuildContext context) {
    final images = {for (final note in result.rows) note.id: baseCardImage(view, note, (property) => read(note, property))};
    final anyImage = images.values.any((path) => path != null);
    final shown = columns.where((column) => column != 'file.name').length;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        final inner = box.maxWidth - 2 * Space.screen;
        final wanted = (view.cardSize ?? 200).clamp(110.0, 420.0);
        final count = ((inner + gap) / (wanted + gap)).ceil().clamp(1, 8);
        final width = (inner - gap * (count - 1)) / count;
        final imageHeight = _imageHeight(view, width, anyImage);
        // высота карточки: картинка, заголовок в две строки, по строке на свойство
        final height = (imageHeight ?? 0) + 22 + 44 + 24.0 * shown;
        return CustomScrollView(
          slivers: [
            for (final group in _groupsOf(result)) ...[
              if (result.groups != null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                  sliver: SliverToBoxAdapter(
                    child: _GroupHeader(title: actions.groupLabel(group.key), count: group.rows.length, collapsed: collapsed.contains(group.key), onTap: () => onToggle(group.key)),
                  ),
                ),
              if (!collapsed.contains(group.key))
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Space.screen, 4, Space.screen, 8),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: count, mainAxisSpacing: gap, crossAxisSpacing: gap, mainAxisExtent: height),
                    itemCount: group.rows.length,
                    itemBuilder: (context, i) {
                      final note = group.rows[i];
                      return _Card(note: note, view: view, columns: columns, actions: actions, filesRoot: filesRoot, image: images[note.id], imageHeight: imageHeight, bounded: true);
                    },
                  ),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        );
      },
    );
  }
}

// ── доска ───────────────────────────────────────────────────────────────────

class BaseKanban extends StatefulWidget {
  const BaseKanban({super.key, required this.result, required this.view, required this.columns, required this.actions, required this.filesRoot, required this.read});

  final BaseResult result;
  final BaseView view;
  final List<String> columns;
  final BaseViewActions actions;
  final Directory filesRoot;
  final Object? Function(BaseNote note, String property) read;

  @override
  State<BaseKanban> createState() => _BaseKanbanState();
}

class _BaseKanbanState extends State<BaseKanban> {
  final _sideways = ScrollController();

  @override
  void dispose() {
    _sideways.dispose();
    super.dispose();
  }

  /// Карточку поднесли к краю экрана: доска едет туда сама, иначе соседнюю колонку не достать.
  void _edge(DragUpdateDetails details) {
    if (!_sideways.hasClients) return;
    final width = MediaQuery.sizeOf(context).width;
    final x = details.globalPosition.dx;
    final step = x > width - 56
        ? 14.0
        : x < 56
        ? -14.0
        : 0.0;
    if (step == 0) return;
    final position = _sideways.position;
    _sideways.jumpTo((position.pixels + step).clamp(position.minScrollExtent, position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final BaseKanban(:result, :view, :columns, :actions, :filesRoot, :read) = widget;
    final text = Theme.of(context).textTheme;
    final groups = result.groups ?? const <BaseGroup>[];
    final property = view.groupBy?.property;
    // переносить можно по свойству заметки и по папке, как в Obsidian
    final movable = actions.canEdit && property != null && (isNoteProperty(property) || property == 'file.folder');
    final width = (view.cardSize ?? 260).clamp(200.0, 360.0);
    final imageHeight = view.image == null ? null : width * (view.imageAspectRatio ?? 0.6);
    // пустая колонка «без значения» есть всегда: туда переносят, чтобы снять значение
    final shown = [...groups, if (!groups.any((group) => group.key == null || group.key == '')) const BaseGroup(null, [])];
    return ListView(
      controller: _sideways,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(Space.screen, 4, Space.screen, 24),
      children: [
        for (final group in shown)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: DragTarget<BaseNote>(
              onWillAcceptWithDetails: (details) => movable && !group.rows.contains(details.data),
              onAcceptWithDetails: (details) => actions.move(details.data, group.key),
              builder: (context, candidates, _) => Container(
                key: ValueKey('base-column-${group.key}'),
                width: width,
                decoration: BoxDecoration(color: candidates.isNotEmpty ? Tokens.containerHighest : Tokens.containerLow, borderRadius: BorderRadius.circular(Radii.tile)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 4, 4),
                      child: Row(
                        children: [
                          // имя колонки во всю оставшуюся ширину: Spacer рядом отнял бы у него половину
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(actions.groupLabel(group.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                                ),
                                const SizedBox(width: 8),
                                Text('${group.rows.length}', style: text.bodySmall!.copyWith(color: Tokens.muted)),
                              ],
                            ),
                          ),
                          if (movable) IconButton(key: ValueKey('base-column-add-${group.key}'), onPressed: () => actions.create(group.key), icon: Icon(symbolIcon('add'), size: 20)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        children: [
                          for (final note in group.rows)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _draggable(
                                movable,
                                note,
                                width - 16,
                                _Card(
                                  note: note,
                                  view: view,
                                  columns: columns,
                                  actions: actions,
                                  filesRoot: filesRoot,
                                  image: baseCardImage(view, note, (property) => read(note, property)),
                                  imageHeight: imageHeight,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _draggable(bool movable, BaseNote note, double width, Widget card) {
    if (!movable) return card;
    return LongPressDraggable<BaseNote>(
      data: note,
      onDragUpdate: _edge,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          child: Opacity(opacity: 0.9, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }
}
