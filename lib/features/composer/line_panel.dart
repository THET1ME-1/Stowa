import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../core/format/duration_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/marked_text.dart';
import '../../core/widgets/motion_bits.dart';
import '../../core/widgets/shape_badge.dart';
import '../../core/widgets/tag_tile.dart';
import '../../domain/item_kind.dart';
import '../../domain/item_title.dart';
import '../../domain/note_blocks.dart';
import '../../domain/models.dart';
import '../../domain/search_rank.dart';
import '../../domain/video_text.dart' show videoAt;
import '../item/adult_veil.dart';
import '../../l10n/app_localizations.dart';
import 'panel_model.dart';
import 'panel_text.dart';

/// Панель над строкой: снизу «Закинуть», выше то, что уже лежит, или подсказки
/// под курсором. Белая плашка переезжает к строке, которую сделает кнопка.
class LinePanel extends StatefulWidget {
  const LinePanel({
    super.key,
    required this.state,
    required this.selected,
    required this.rest,
    required this.now,
    required this.filesRoot,
    required this.filter,
    required this.onFilter,
    required this.onTap,
    required this.onAppend,
    this.onSmartFolder,
  });

  /// Поиск понял фильтр: запрос можно сохранить умной папкой.
  final VoidCallback? onSmartFolder;

  final PanelState state;
  final int selected;

  /// Текст строки без команды: из него заголовок будущей вещи.
  final String rest;
  final DateTime now;
  final Directory filesRoot;
  final ItemKind? filter;
  final ValueChanged<ItemKind?> onFilter;
  final ValueChanged<int> onTap;
  final ValueChanged<ResultRow> onAppend;

  @override
  State<LinePanel> createState() => _LinePanelState();
}

class _LinePanelState extends State<LinePanel> {
  final _stack = GlobalKey();
  final _keys = <String, GlobalKey>{};
  final _scroll = ScrollController();
  ({double bottom, double height})? _highlight;
  bool _faded = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final faded = _scroll.hasClients && _scroll.offset < _scroll.position.maxScrollExtent - 2;
      if (faded != _faded) setState(() => _faded = faded);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // плашка встаёт под выбранную строку после раскладки
  void _placeHighlight() {
    final rows = widget.state.rows;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    final selected = widget.selected < rows.length ? _keys[rows[widget.selected].key]?.currentContext?.findRenderObject() as RenderBox? : null;
    // от низа: список прижат к кнопке, новая строка сверху не двигает плашку
    ({double bottom, double height})? next;
    if (stack != null && selected != null && selected.attached && stack.attached) {
      final top = selected.localToGlobal(Offset.zero, ancestor: stack).dy;
      next = (bottom: stack.size.height - top - selected.size.height, height: selected.size.height);
    }
    if (next != _highlight && mounted) setState(() => _highlight = next);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final state = widget.state;
    WidgetsBinding.instance.addPostFrameCallback((_) => _placeHighlight());
    final header = _header(l, state);
    final rows = state.rows;
    _keys.removeWhere((key, _) => !rows.any((row) => row.key == key));

    return Container(
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.card)),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          Flexible(
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  reverse: true,
                  child: Stack(
                    key: _stack,
                    children: [
                      if (_highlight != null)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 400),
                          curve: Motion.spatial,
                          left: 0,
                          right: 0,
                          bottom: _highlight!.bottom,
                          height: _highlight!.height,
                          child: Container(
                            decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(Radii.tile)),
                          ),
                        ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // нулевая строка у самой кнопки, лучшее найденное прямо над ней
                          for (final (index, row) in rows.indexed.toList().reversed)
                            // переезд снаружи въезда: замер места не сбивает сдвиг самого въезда
                            _Glide(
                              key: _keys.putIfAbsent(row.key, GlobalKey.new),
                              stack: _stack,
                              child: RiseIn(
                                delay: index,
                                child: _RowView(
                                  row: row,
                                  selected: index == widget.selected,
                                  rest: widget.rest,
                                  now: widget.now,
                                  filesRoot: widget.filesRoot,
                                  onTap: () => widget.onTap(index),
                                  onAppend: row is ResultRow && row.canAppend ? () => widget.onAppend(row) : null,
                                  jump: row is ResultRow ? _jumpOf(row) : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // верх списка тает, только когда над ним есть что прокрутить
                if (_faded) Positioned(top: 0, left: 0, right: 0, height: 18, child: EdgeFade(color: Tokens.containerHigh, toTop: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _header(L l, PanelState state) {
    final label = switch (state.header) {
      PanelHeader.none => null,
      PanelHeader.tags => l.panelTags,
      PanelHeader.folders => l.panelFolders,
      PanelHeader.commands => l.panelCommands,
      PanelHeader.found => l.panelFound(state.count),
      PanelHeader.nothingFound => l.panelNothing,
      PanelHeader.similar => l.panelSimilar,
      PanelHeader.fresh => l.panelFresh,
    };
    if (label == null && state.kinds.isEmpty) return null;
    final text = Theme.of(context).textTheme;
    // что поиск понял из запроса: «Ищу: видео · вчера»
    final looking = state.understood.isEmpty || state.header == PanelHeader.fresh ? null : l.panelLooking(state.understood.join(' · '));
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  label,
                  style: text.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: Tokens.onSurfaceVariant),
                ),
              ),
            if (looking != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(looking, style: text.labelMedium!.copyWith(fontSize: 13, color: Tokens.onSurfaceVariant)),
              ),
            if (looking != null && widget.onSmartFolder != null) _FilterChip(icon: 'add', label: l.smartSave, on: false, onTap: widget.onSmartFolder!),
            if (state.kinds.isNotEmpty) ...[
              _FilterChip(label: l.filterAll, on: widget.filter == null, onTap: () => widget.onFilter(null)),
              for (final kind in state.kinds) _FilterChip(label: kindsLabel(l, kind), on: widget.filter == kind, onTap: () => widget.onFilter(kind)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.on, required this.onTap, this.icon});

  final String label;
  final bool on;
  final VoidCallback onTap;

  /// Значок перед подписью: у «+ Умная папка».
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.short,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? Tokens.accent : Tokens.containerHighest, borderRadius: BorderRadius.circular(15)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon case final icon?) ...[Icon(symbolIcon(icon), size: 16, color: on ? Tokens.onAccent : Tokens.onSurface), const SizedBox(width: 4)],
              Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 13, color: on ? Tokens.onAccent : Tokens.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка, которая осталась, переезжает на новое место плавно, а не прыгает.
class _Glide extends StatefulWidget {
  const _Glide({super.key, required this.stack, required this.child});

  final GlobalKey stack;
  final Widget child;

  @override
  State<_Glide> createState() => _GlideState();
}

class _GlideState extends State<_Glide> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  double? _top;
  double _from = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final stack = widget.stack.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.attached || !stack.attached) return;
    // список прижат к низу, поэтому место строки — расстояние от низа, оно не зависит от прокрутки
    final fromBottom = stack.size.height - box.localToGlobal(Offset.zero, ancestor: stack).dy;
    final before = _top;
    _top = fromBottom;
    if (before == null || (before - fromBottom).abs() < 0.5) return;
    // сдвиг с учётом ещё не доехавшей части прошлого переезда
    _from = fromBottom - before + _from * (1 - Motion.spatial.transform(_controller.value));
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, _controller.isAnimating ? _from * (1 - Motion.spatial.transform(_controller.value)) : 0), child: child),
      child: widget.child,
    );
  }
}

class _RowView extends StatelessWidget {
  const _RowView({
    required this.row,
    required this.selected,
    required this.rest,
    required this.now,
    required this.filesRoot,
    required this.onTap,
    this.onAppend,
    this.jump,
  });

  final PanelRow row;
  final bool selected;
  final String rest;
  final DateTime now;
  final Directory filesRoot;
  final VoidCallback onTap;
  final VoidCallback? onAppend;

  /// Нашлось во фразе ролика: открыть его с этой секунды.
  final ({Uri url, int seconds})? jump;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final ink = selected ? Tokens.onAccent : Tokens.onSurface;
    final soft = selected ? Tokens.onAccentVariant : Tokens.onSurfaceVariant;
    final faint = selected ? Tokens.onAccentVariant : Tokens.muted;
    final markColor = selected ? Tokens.onAccent.withValues(alpha: 0.1) : Tokens.onSurface.withValues(alpha: 0.17);
    final titleStyle = text.titleSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.25, color: ink);
    final subStyle = text.bodySmall!.copyWith(fontSize: 13, height: 1.35, color: soft);
    final whereStyle = text.labelSmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: faint);

    final Widget thumb;
    final Widget title;
    Widget? sub;
    Widget? where;
    switch (row) {
      case SaveRow(:final plan):
        final folder = plan.folder;
        thumb = _badge(folder?.shape ?? 'squircle', folder?.icon ?? 'inbox', selected);
        title = Text(saveTitle(l, plan, now), maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle);
        final subText = saveSub(l, plan, rest, now);
        sub = Row(
          children: [
            if (subText.alarm)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(symbolIcon('alarm'), size: 15, color: soft),
              ),
            Expanded(
              child: Text(subText.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: subStyle),
            ),
          ],
        );
        final why = saveWhere(l, plan);
        where = _where(why.icon, why.text, whereStyle, faint);
      case ResultRow(:final result):
        final card = result.card;
        final hit = result.hit;
        thumb = card.thumbPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AdultVeil(
                  itemId: card.id,
                  compact: true,
                  child: Image.file(
                    File(p.join(filesRoot.path, card.thumbPath!)),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    cacheWidth: (44 * MediaQuery.devicePixelRatioOf(context)).round(),
                    errorBuilder: (_, _, _) => _badge('squircle', kindIcon(card.kind), selected),
                  ),
                ),
              )
            : _badge('squircle', kindIcon(card.kind), selected);
        title = MarkedText(text: card.title, marks: hit.marks[SearchField.title] ?? const [], style: titleStyle, markColor: markColor);
        final whereField = hit.where;
        final fact = whereField == SearchField.facts ? hit.foundFact : null;
        var source = switch (whereField) {
          SearchField.deep => hit.doc.deep,
          SearchField.place => hit.doc.place,
          SearchField.facts => fact?.part.text ?? '',
          _ => card.body,
        };
        var marks = fact?.marks ?? hit.marks[whereField ?? SearchField.body] ?? const <TextMark>[];
        if (whereField != SearchField.deep && whereField != SearchField.place && whereField != SearchField.facts) {
          // первая строка заметки уже стоит заголовком, подпись берёт текст после неё
          final lineEnd = card.body.indexOf('\n');
          if (isTitleLine(lineEnd < 0 ? card.body : card.body.substring(0, lineEnd), card.title)) {
            final cut = lineEnd < 0 ? card.body.length : lineEnd + 1;
            source = card.body.substring(cut);
            marks = [
              for (final mark in marks)
                if (mark.$1 >= cut) (mark.$1 - cut, mark.$2),
            ];
          }
        }
        // в подсказке оформление как на странице: жирное жирным, галочки значками, без «**» и «- [ ]»
        final shown = renderMarkup(source, marks);
        sub = shown.text.trim().isEmpty
            ? null
            : MarkedText(
                text: snippetOf(shown.text, shown.marks),
                marks: snippetMarks(shown.text, shown.marks),
                styles: snippetStyles(shown.text, shown.marks, shown.styles),
                style: subStyle,
                markColor: markColor,
              );
        // сервис в подписи только у ссылок и роликов; у заметки со ссылкой внутри — «заметка»
        final web = card.kind == ItemKind.link || card.kind == ItemKind.video;
        final address = !web || card.url == null ? null : Uri.tryParse(card.url!)?.host;
        final host = address == null || address.isEmpty ? null : sourceName(address);
        final found = switch (whereField) {
          SearchField.deep => deepLabel(l, card.kind),
          SearchField.place => l.foundAtPlace,
          SearchField.facts when fact != null => factLabel(l, fact.part),
          _ => host ?? kindLabel(l, card.kind),
        };
        where = _where(kindIcon(card.kind), '$found · ${card.folderName ?? l.folderNone} · ${shortDate(l, card.createdAt, now)}', whereStyle, faint);
      case TagRow(:final tag):
        thumb = TagTile(kind: tag.iconKind, value: tag.iconValue, filesRoot: filesRoot, size: 44, inverted: selected);
        title = Text('#${tag.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle);
        sub = Text(l.itemsCount(tag.count), style: subStyle);
      case NewTagRow(:final name):
        thumb = _badge('cookie9', 'add', selected);
        title = Text(l.tagCreate(name), maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle);
        sub = Text(l.tagCreateHint, style: subStyle);
      case FolderRow(:final folder):
        thumb = _badge(folder.shape, folder.icon, selected);
        title = Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle);
        // у вложенной — где она лежит: две «Кухни» в разных папках различимы
        sub = Text([?folder.parentsLabel, l.itemsCount(folder.count)].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: subStyle);
      case NewFolderRow(:final name):
        thumb = _badge('squircle', 'create_new_folder', selected);
        title = Text(l.folderCreate(name), maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle);
        sub = Text(l.folderCreateHint, style: subStyle);
      case CommandRow(:final command, :final key_):
        thumb = _badge('squircle', commandIcons[command]!, selected);
        title = Text('/$key_', style: titleStyle);
        sub = Text(commandHint(l, command), maxLines: 1, overflow: TextOverflow.ellipsis, style: subStyle);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedDefaultTextStyle(
        duration: Motion.short,
        style: TextStyle(color: ink),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          child: Row(
            children: [
              thumb,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    if (sub != null) ...[const SizedBox(height: 2), sub],
                    if (where != null) ...[const SizedBox(height: 3), where],
                  ],
                ),
              ),
              if (onAppend != null) ...[const SizedBox(width: 8), _AppendButton(icon: 'edit_note', label: l.actionAppend, selected: selected, onTap: onAppend!)],
              if (jump case final jump?) ...[
                const SizedBox(width: 8),
                _AppendButton(
                  key: const ValueKey('result-jump'),
                  icon: 'play_arrow',
                  label: formatClock(Duration(seconds: jump.seconds)),
                  tooltip: l.watchFromHere,
                  selected: selected,
                  onTap: () => launchUrl(videoAt(jump.url, jump.seconds), mode: LaunchMode.externalApplication).ignore(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String shape, String icon, bool selected) => ShapeBadge(
    shape: BadgeShape.values.asNameMap()[shape] ?? BadgeShape.squircle,
    size: 44,
    color: selected ? Tokens.graphite : Tokens.containerHighest,
    child: Icon(symbolIcon(icon), size: 22, color: Tokens.onSurface),
  );

  Widget _where(String icon, String label, TextStyle style, Color color) => Row(
    children: [
      Icon(symbolIcon(icon), size: 14, color: color),
      const SizedBox(width: 4),
      Expanded(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ),
    ],
  );
}

/// Кнопка-пилюля в строке найденного: «Дописать», «▶ 0:42».
class _AppendButton extends StatelessWidget {
  const _AppendButton({super.key, required this.icon, required this.label, required this.selected, required this.onTap, this.tooltip});

  final String icon;
  final String label;
  final String? tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Tokens.onSurface : Tokens.onAccent;
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
        decoration: BoxDecoration(color: selected ? Tokens.graphite : Tokens.accent, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(symbolIcon(icon), size: 18, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Нашлось во фразе субтитров или в главе ролика — адрес и секунда, иначе null.
({Uri url, int seconds})? _jumpOf(ResultRow row) {
  final seconds = row.result.hit.foundFact?.part.seconds;
  final url = Uri.tryParse(row.result.card.url ?? '');
  if (seconds == null || url == null || !url.hasScheme || row.result.hit.where != SearchField.facts) return null;
  return (url: url, seconds: seconds.floor());
}

// длинный текст начинается чуть раньше первого совпадения, чтобы оно было видно
int _snippetStart(String text, List<TextMark>? marks) {
  if (marks == null || marks.isEmpty) return 0;
  final first = marks.map((mark) => mark.$1).reduce((a, b) => a < b ? a : b);
  if (first < 30) return 0;
  // одно слово перед найденным: строка узкая, рядом бывает кнопка «Дописать»
  return text.lastIndexOf(RegExp(r'\s'), first - 2) + 1;
}

/// Оформление для подсказки: сдвигается, как отметки, а начатое до обреза обрезается вместе с текстом.
List<(int, int, MarkupStyle)> snippetStyles(String text, List<TextMark>? marks, List<(int, int, MarkupStyle)> styles) {
  final start = _snippetStart(text, marks);
  // «…» в начале подсказки занимает один знак
  final shift = start == 0 ? 0 : start - 1;
  return [
    for (final (from, length, kind) in styles)
      if (from + length > start) (from < start ? start - shift : from - shift, from < start ? from + length - start : length, kind),
  ];
}

String snippetOf(String text, List<TextMark>? marks) {
  final start = _snippetStart(text, marks);
  final flat = text.substring(start).replaceAll('\n', ' ');
  return start == 0 ? flat : '…$flat';
}

List<TextMark> snippetMarks(String text, List<TextMark>? marks) {
  if (marks == null) return const [];
  final start = _snippetStart(text, marks);
  final shift = start == 0 ? 0 : start - 1;
  return [
    for (final mark in marks)
      if (mark.$1 >= start) (mark.$1 - shift, mark.$2),
  ];
}
