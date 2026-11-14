import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/marked_text.dart';
import '../../core/widgets/motion_bits.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/item_kind.dart';
import '../../domain/note_links.dart' show shownTitle;
import '../../domain/models.dart';
import '../../domain/note_blocks.dart';
import '../../l10n/app_localizations.dart';
import '../item/adult_veil.dart';
import '../item/copying_bar.dart';

/// Ось ленты: по ней идёт пунктир, на ней точка в цвет папки.
const _rail = Space.screen + 6;

/// Отступ карточки заметки от края экрана: ось с точкой занимает узкую полосу слева.
const _indent = Space.screen + 22;

/// Точка заметки не выше уровня заголовка карточки.
const _dotTop = 18.0;

/// Точка у низа карточки — на уровне строки с меткой и временем.
const _dotBottom = 22.0;

/// Фото в ленте не выше этого: лента листается быстро, а целиком оно на странице заметки.
const _photoMax = 220.0;

/// Сколько строк текста видно на карточке; целиком заметку читают на её странице.
const _excerptLines = 2;

const _cardRadius = 24.0;

/// Лента главной: последние заметки по дням, точки в цвет папок на пунктирной оси слева, как в дневнике.
/// Заметку видно целиком, пункты списка отмечаются прямо здесь.
class NoteTimeline extends StatefulWidget {
  const NoteTimeline({
    super.key,
    required this.items,
    this.pinned = const [],
    required this.filesRoot,
    required this.now,
    this.aiSorting = false,
    this.bottomInset = 0,
    required this.onOpen,
    required this.onMove,
    required this.onAct,
    required this.onToggle,
  });

  final List<ItemCard> items;

  /// Закреплённые: своим блоком над днями, у карточки вместо часа — день записи.
  final List<ItemCard> pinned;

  /// Сколько снизу экрана закрывает строка ввода: точка заметки держится над ней.
  final double bottomInset;
  final Directory filesRoot;
  final DateTime now;

  /// Ключ ИИ работает: заметки без папки в очереди подписаны «разбираю», а не «Без папки».
  final bool aiSorting;
  final ValueChanged<ItemCard> onOpen;

  /// Касание метки папки: переложить.
  final ValueChanged<ItemCard> onMove;

  /// Долгое нажатие: открыть, переложить, удалить.
  final ValueChanged<ItemCard> onAct;

  /// Касание пункта списка: номер строки в тексте заметки.
  final void Function(ItemCard item, int line) onToggle;

  @override
  State<NoteTimeline> createState() => _NoteTimelineState();
}

/// Сколько закреплённых видно сразу; остальные — по «Ещё N», чтобы лента не уезжала вниз.
const pinnedShown = 3;

class _NoteTimelineState extends State<NoteTimeline> {
  // заметки, которые уже были на экране: им въезжать не нужно
  late final Set<String> _seen = {for (final item in [...widget.pinned, ...widget.items]) item.id};
  var _allPinned = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // заметки идут от новых к старым: день начинается, когда меняется дата
    final days = <(DateTime, List<ItemCard>)>[];
    for (final item in widget.items) {
      final at = item.createdAt;
      final day = DateTime(at.year, at.month, at.day);
      if (days.isEmpty || days.last.$1 != day) days.add((day, []));
      days.last.$2.add(item);
    }
    final pinned = widget.pinned;
    final hidden = pinned.length - pinnedShown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pinned.isNotEmpty) ...[
          const _PinnedHeader(),
          _group(_allPinned || hidden <= 0 ? pinned : pinned.take(pinnedShown).toList(), dated: true),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(left: _indent - 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('pinned-more'),
                  onPressed: () => setState(() => _allPinned = !_allPinned),
                  icon: Icon(symbolIcon(_allPinned ? 'expand_less' : 'expand_more'), size: 18),
                  label: Text(_allPinned ? l.homePinnedLess : l.homePinnedMore(hidden)),
                ),
              ),
            ),
        ],
        for (final (day, items) in days) ...[
          _DayHeader(day: day, now: widget.now),
          _group(items),
        ],
      ],
    );
  }

  /// Карточки на пунктирной оси. [dated] — у карточки день записи, а не час: закреплённые не по дням.
  Widget _group(List<ItemCard> items, {bool dated = false}) => Stack(
    children: [
      const Positioned(left: _rail - 0.75, top: _dotTop, bottom: 0, child: _DottedRail()),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            _Arrive(
              key: ValueKey(item.id),
              play: _seen.add(item.id),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _Entry(
                  item: item,
                  dated: dated,
                  filesRoot: widget.filesRoot,
                  now: widget.now,
                  aiSorting: widget.aiSorting,
                  bottomInset: widget.bottomInset,
                  onOpen: () => widget.onOpen(item),
                  onMove: () => widget.onMove(item),
                  onAct: () => widget.onAct(item),
                  onToggle: (line) => widget.onToggle(item, line),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

/// «Закреплено» над закреплёнными, тем же кеглем, что дни, со значком булавки.
class _PinnedHeader extends StatelessWidget {
  const _PinnedHeader();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('pinned-header'),
      padding: const EdgeInsets.fromLTRB(Space.screen, 22, Space.screen, 12),
      child: Row(
        children: [
          Text(L.of(context).homePinned, style: text.headlineSmall),
          const SizedBox(width: 8),
          Icon(symbolIcon('keep', filled: true), size: 20, color: Tokens.muted),
        ],
      ),
    );
  }
}

String _capitalized(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Точка заметки на оси, как аватарка в чате Telegram: у низа своей карточки; низ ушёл под
/// строку ввода — держится над строкой и едет с лентой, пока не упрётся в верх карточки.
class _TimelineDot extends LeafRenderObjectWidget {
  const _TimelineDot({super.key, required this.color, required this.ring, required this.bottomInset});

  final Color color;
  final Color ring;
  final double bottomInset;

  @override
  RenderTimelineDot createRenderObject(BuildContext context) =>
      RenderTimelineDot(color: color, ring: ring, bottomInset: bottomInset, scroll: Scrollable.maybeOf(context)?.position);

  @override
  void updateRenderObject(BuildContext context, RenderTimelineDot renderObject) {
    renderObject
      ..color = color
      ..ring = ring
      ..bottomInset = bottomInset
      ..scroll = Scrollable.maybeOf(context)?.position;
  }
}

/// Точка ленты сама решает, где стоять, по месту карточки на экране. Прокрутка её только
/// перерисовывает: ни сборки, ни раскладки ленты на каждый кадр.
class RenderTimelineDot extends RenderBox {
  RenderTimelineDot({required Color color, required Color ring, required double bottomInset, ScrollPosition? scroll})
    : _color = color, // ignore: prefer_initializing_formals
      _ring = ring, // ignore: prefer_initializing_formals
      _bottomInset = bottomInset, // ignore: prefer_initializing_formals
      _scroll = scroll; // ignore: prefer_initializing_formals

  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  Color _ring;
  set ring(Color value) {
    if (value == _ring) return;
    _ring = value;
    markNeedsPaint();
  }

  double _bottomInset;
  set bottomInset(double value) {
    if (value == _bottomInset) return;
    _bottomInset = value;
    markNeedsPaint();
  }

  ScrollPosition? _scroll;
  set scroll(ScrollPosition? value) {
    if (value == _scroll) return;
    if (attached) _scroll?.removeListener(markNeedsPaint);
    _scroll = value;
    if (attached) _scroll?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scroll?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scroll?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  /// Середина точки от верха карточки: у низа, но не ниже кромки строки ввода и не выше заголовка.
  double get dotCenter {
    final natural = size.height - _dotBottom;
    final viewport = RenderAbstractViewport.maybeOf(this);
    final box = viewport is RenderBox ? viewport as RenderBox : null;
    if (box == null || !box.hasSize) return math.max(_dotTop, natural);
    final edge = box.localToGlobal(Offset(0, box.size.height)).dy - _bottomInset - _dotBottom;
    final top = localToGlobal(Offset.zero).dy;
    return math.max(_dotTop, math.min(natural, edge - top));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final center = offset + Offset(size.width / 2, dotCenter);
    context.canvas
      ..drawCircle(center, 6, Paint()..color = _ring)
      ..drawCircle(center, 3.5, Paint()..color = _color);
  }
}

/// «Сегодня 7 ноября», «Вчера 6 ноября», «Среда 4 ноября».
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.now});

  final DateTime day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final today = DateTime(now.year, now.month, now.day);
    final ago = today.difference(day).inDays;
    final name = switch (ago) {
      0 => l.dateToday,
      1 => l.dateYesterday,
      _ => DateFormat.EEEE(l.localeName).format(day),
    };
    final date = day.year == now.year ? DateFormat.MMMMd(l.localeName).format(day) : DateFormat.yMMMMd(l.localeName).format(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 22, Space.screen, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(_capitalized(name), style: text.headlineSmall),
          const SizedBox(width: 10),
          Flexible(
            child: Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
          ),
        ],
      ),
    );
  }
}

class _DottedRail extends StatelessWidget {
  const _DottedRail();

  @override
  Widget build(BuildContext context) => const CustomPaint(size: Size(1.5, double.infinity), painter: _DotsPainter());
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Tokens.outline
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + 2.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}

/// Одна заметка: точка на оси и карточка, внизу карточки метки и время.
class _Entry extends StatelessWidget {
  const _Entry({
    required this.item,
    this.dated = false,
    required this.filesRoot,
    required this.now,
    required this.aiSorting,
    required this.bottomInset,
    required this.onOpen,
    required this.onMove,
    required this.onAct,
    required this.onToggle,
  });

  final ItemCard item;

  /// В углу день записи вместо часа.
  final bool dated;
  final Directory filesRoot;
  final DateTime now;
  final bool aiSorting;
  final double bottomInset;
  final VoidCallback onOpen;
  final VoidCallback onMove;
  final VoidCallback onAct;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // точка в цвет папки, у неразложенной серая; кольцо цвета фона разрывает пунктир.
        // Как аватарка в Telegram: у низа карточки, а низ под строкой ввода — над строкой
        Positioned(
          left: _rail - 6,
          top: 0,
          bottom: 0,
          width: 12,
          child: _TimelineDot(
            key: ValueKey('dot-${item.id}'),
            color: item.folderColor == null ? Tokens.muted : FolderPalette.ink(item.folderColor!),
            ring: Tokens.background,
            bottomInset: bottomInset,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: _indent, right: Space.screen),
          child: NoteCard(
            item: item,
            dated: dated,
            filesRoot: filesRoot,
            now: now,
            aiSorting: aiSorting,
            onOpen: onOpen,
            onMove: onMove,
            onAct: onAct,
            onToggle: onToggle,
          ),
        ),
      ],
    );
  }
}

/// Карточка заметки, как в ленте главной: текст в две строки, фото, ссылка или файл, метка
/// папки и время. Её же показывает полка «Под рукой»; [trailing] — кнопка в правом верхнем углу.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.item,
    this.dated = false,
    required this.filesRoot,
    required this.now,
    this.aiSorting = false,
    required this.onOpen,
    required this.onMove,
    required this.onAct,
    required this.onToggle,
    this.trailing,
  });

  final ItemCard item;

  /// В углу день записи вместо часа.
  final bool dated;
  final Directory filesRoot;
  final DateTime now;
  final bool aiSorting;
  final VoidCallback onOpen;
  final VoidCallback onMove;
  final VoidCallback onAct;
  final ValueChanged<int> onToggle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final at = item.createdAt;
    final stamp = !dated
        ? DateFormat.jm(l.localeName).format(at)
        : at.year == now.year
        ? DateFormat.MMMd(l.localeName).format(at)
        : DateFormat.yMMMd(l.localeName).format(at);
    final thumb = item.thumbPath == null ? null : p.join(filesRoot.path, item.thumbPath!);
    final attachment = switch (item.kind) {
      ItemKind.link || ItemKind.video || ItemKind.file || ItemKind.voice => true,
      _ => false,
    };
    // у ссылки обложка слева с узким полем, у текста и фото поле шире
    final pad = attachment ? 10.0 : 16.0;
    // карточка чуть в цвет папки: заметки одной папки узнаются в ленте издалека
    final fill = item.folderColor == null ? Tokens.container : FolderPalette.tint(item.folderColor!, 0.1);
    final Widget content = switch (item.kind) {
      _ when attachment => Padding(padding: EdgeInsets.fromLTRB(pad, pad, pad, 0), child: _Attachment(item: item, thumb: thumb)),
      _ when thumb != null => _Photo(item: item, path: thumb, fill: fill, onToggle: onToggle),
      _ => Padding(padding: EdgeInsets.fromLTRB(pad, 14, pad, 0), child: _Text(item: item, fill: fill, onToggle: onToggle)),
    };
    final time = Text(
      stamp,
      style: Theme.of(context).textTheme.labelSmall!.copyWith(color: Tokens.muted, fontFeatures: const [FontFeature.tabularFigures()]),
    );
    final trailing = this.trailing;
    return Pressable(
      onTap: onOpen,
      onLongPress: onAct,
      pressedScale: 0.98,
      child: Container(
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(_cardRadius)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // у текста место под кнопку в углу, фото и обложка идут под неё
                if (trailing != null && thumb == null) Padding(padding: const EdgeInsets.only(right: 36), child: content) else content,
                // время — в углу рядом с меткой папки, а не отдельной строкой над карточкой
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 12, pad + 2, pad),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _Marks(item: item, now: now, aiSorting: aiSorting, onMove: onMove)),
                      const SizedBox(width: 8),
                      Padding(padding: const EdgeInsets.only(bottom: 6), child: time),
                    ],
                  ),
                ),
              ],
            ),
            if (trailing != null) Positioned(top: 8, right: 8, child: trailing),
          ],
        ),
      ),
    );
  }
}

TextStyle _titleStyle(TextTheme text) => text.titleMedium!.copyWith(fontSize: 17, height: 1.3);

TextStyle _bodyStyle(TextTheme text) => text.bodyMedium!.copyWith(fontSize: 15, height: 1.45, color: Tokens.onSurfaceVariant);

/// Заметка текстом: заголовок и две строки под ним — целиком её читают на странице заметки.
/// Список начинается с пунктов — два пункта с галочками, которые отмечаются прямо отсюда.
class _Text extends StatelessWidget {
  const _Text({required this.item, required this.fill, required this.onToggle});

  final ItemCard item;

  /// Цвет карточки: в него растворяется конец второй строки.
  final Color fill;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lines = noteLinesUnderTitle(item.body, item.title);
    final checklist = lines.isNotEmpty && lines.first.done != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(shownTitle(item.title), maxLines: lines.isEmpty ? 4 : 2, overflow: TextOverflow.ellipsis, style: _titleStyle(text)),
        if (lines.isNotEmpty) const SizedBox(height: 6),
        if (checklist)
          _Checks(lines: lines, color: item.folderColor, onToggle: onToggle)
        else if (lines.isNotEmpty)
          _Excerpt(id: item.id, lines: lines, fill: fill),
      ],
    );
  }
}

/// Две строки текста. Не влез — конец второй строки растворяется в цвете карточки,
/// и поверх тихо сказано, сколько строк ещё внутри: вместо многоточия.
class _Excerpt extends StatelessWidget {
  const _Excerpt({required this.id, required this.lines, required this.fill});

  final String id;
  final List<NoteLine> lines;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final style = _bodyStyle(Theme.of(context).textTheme);
    // пункты среди текста — значком, как их видно в заметке
    final markdown = [for (final line in lines) line.done == null ? line.text : '${line.done! ? '☑' : '☐'} ${line.text}'].join('\n');
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: renderMarkup(markdown, const []).text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: box.maxWidth);
        final hidden = painter.computeLineMetrics().length - _excerptLines;
        final line = painter.preferredLineHeight;
        painter.dispose();
        return Stack(
          children: [
            KeyedSubtree(key: ValueKey('excerpt-$id'), child: MarkedText.note(markdown, maxLines: _excerptLines, overflow: TextOverflow.clip, style: style)),
            if (hidden > 0)
              Positioned(
                key: ValueKey('excerpt-fade-$id'),
                right: 0,
                bottom: 0,
                height: line,
                width: math.min(box.maxWidth * 0.6, 220),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [fill.withValues(alpha: 0), fill, fill], stops: const [0, 0.42, 1]),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(l.homeMoreLines(hidden), maxLines: 1, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: Tokens.muted)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Список: первые два пункта галочками, которые отмечаются отсюда, остальное — «ещё N».
class _Checks extends StatelessWidget {
  const _Checks({required this.lines, required this.color, required this.onToggle});

  final List<NoteLine> lines;
  final Color? color;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final shown = lines.where((line) => line.done != null).take(_excerptLines).toList();
    final hidden = lines.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in shown) _CheckRow(text: line.text, done: line.done!, color: color ?? Tokens.accent, onTap: () => onToggle(line.index)),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 2),
            child: Text(l.homeChecksMore(hidden), style: text.bodySmall!.copyWith(color: Tokens.muted)),
          ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text, required this.done, required this.color, required this.onTap});

  final String text;
  final bool done;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _bodyStyle(Theme.of(context).textTheme);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Motion.short,
              curve: Motion.emphasized,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: done ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: done ? null : Border.all(color: Tokens.muted, width: 1.6),
              ),
              child: done ? Icon(symbolIcon('check'), size: 15, color: inkOn(color)) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MarkedText.note(
                text,
                maxLines: 2,
                style: done ? style.copyWith(color: Tokens.muted, decoration: TextDecoration.lineThrough, decorationColor: Tokens.muted) : style.copyWith(color: Tokens.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Своя картинка заметки во всю ширину; подпись, если человек её написал.
class _Photo extends StatelessWidget {
  const _Photo({required this.item, required this.path, required this.fill, required this.onToggle});

  final ItemCard item;
  final String path;
  final Color fill;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final lines = noteLinesUnderTitle(item.body, item.title);
    final width = (360 * MediaQuery.devicePixelRatioOf(context)).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // фото во всю ширину карточки, края скругляет сама карточка
        LayoutBuilder(
          builder: (context, box) => SizedBox(
            height: math.min(box.maxWidth * (item.thumbRatio ?? 0.75), _photoMax),
            child: WithCopyingBar(
              itemId: item.id,
              copying: item.copying > 0,
              child: SizedBox.expand(
                child: AdultVeil(
                  itemId: item.id,
                  child: Image.file(File(path), fit: BoxFit.cover, cacheWidth: width, errorBuilder: (_, _, _) => ColoredBox(color: Tokens.containerHigh)),
                ),
              ),
            ),
          ),
        ),
        // у фото без текста заголовок — «Фото от 7 ноября», день и так над ним
        // подпись — как текст заметки: заголовок и две строки
        if (lines.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _Text(item: item, fill: fill, onToggle: onToggle)),
      ],
    );
  }
}

/// Ссылка, ролик, файл или голосовое: обложка или значок слева, заголовок и откуда — справа.
class _Attachment extends StatelessWidget {
  const _Attachment({required this.item, required this.thumb});

  final ItemCard item;
  final String? thumb;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final icon = switch (item.kind) {
      ItemKind.video => 'play_arrow',
      ItemKind.voice => 'graphic_eq',
      ItemKind.file => 'description',
      _ => 'link',
    };
    final host = item.url == null ? null : Uri.tryParse(item.url!)?.host;
    final source = switch (item.kind) {
      ItemKind.link || ItemKind.video when host != null && host.isNotEmpty => sourceName(host),
      ItemKind.voice when item.durationSeconds != null => _duration(item.durationSeconds!),
      ItemKind.file when item.fileMime != null => item.fileMime!.split('/').last.toUpperCase(),
      _ => null,
    };
    final width = (76 * MediaQuery.devicePixelRatioOf(context)).round();
    final Widget art = thumb != null
        ? Stack(
            fit: StackFit.expand,
            children: [
              AdultVeil(
                itemId: item.id,
                compact: true,
                child: Image.file(File(thumb!), fit: BoxFit.cover, cacheWidth: width, errorBuilder: (_, _, _) => ColoredBox(color: Tokens.containerHigh)),
              ),
              if (item.kind == ItemKind.video)
                Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: Tokens.containerLowest.withValues(alpha: 0.7), shape: BoxShape.circle),
                    child: Icon(symbolIcon('play_arrow', filled: true), size: 20, color: Tokens.onSurface),
                  ),
                ),
            ],
          )
        : ColoredBox(
            color: item.folderColor == null ? Tokens.containerHighest : FolderPalette.tint(item.folderColor!, 0.28),
            child: Center(
              child: ShapeBadge(
                shape: BadgeShape.cookie9,
                size: 40,
                color: item.folderColor ?? Tokens.accent,
                child: Icon(symbolIcon(icon, filled: true), size: 20, color: inkOn(item.folderColor ?? Tokens.accent)),
              ),
            ),
          );
    return WithCopyingBar(
      itemId: item.id,
      copying: item.copying > 0,
      child: SizedBox(
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox.square(dimension: 76, child: art),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shownTitle(item.title), maxLines: 3, overflow: TextOverflow.ellipsis, style: text.titleSmall!.copyWith(fontSize: 15, height: 1.3)),
                  if (source != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(symbolIcon(icon), size: 14, color: Tokens.muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(source, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: Tokens.muted)),
                        ),
                      ],
                    ),
                  ] else if (item.kind == ItemKind.voice) ...[
                    const SizedBox(height: 4),
                    Text(l.kindVoice, style: text.bodySmall!.copyWith(color: Tokens.muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  static String _duration(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Метки под заметкой: папка в её цвете (касание перекладывает) и напоминание.
class _Marks extends StatelessWidget {
  const _Marks({required this.item, required this.now, required this.aiSorting, required this.onMove});

  final ItemCard item;
  final DateTime now;
  final bool aiSorting;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final waiting = item.folderId == null && (item.sortState == SortState.queued || item.sortState == SortState.pending);
    // метка — надпись цветом папки: в светлой теме тёмный тон того же оттенка
    final color = item.folderColor == null ? null : FolderPalette.ink(item.folderColor!);
    final Widget folder;
    if (aiSorting && waiting) {
      folder = _Chip(
        fill: Tokens.containerHigh,
        ink: Tokens.onSurfaceVariant,
        lead: SizedBox(
          width: 14,
          height: 3,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(2)),
            child: LinearProgressIndicator(color: Tokens.onSurfaceVariant, backgroundColor: Tokens.graphite),
          ),
        ),
        label: l.itemSortingBadge,
      );
    } else if (item.folderName != null) {
      folder = _Chip(
        // поверх карточки в цвет папки: подложка метки — тот же цвет погуще
        fill: (color ?? Tokens.muted).withValues(alpha: 0.18),
        ink: color ?? Tokens.onSurfaceVariant,
        lead: Icon(symbolIcon(item.folderIcon ?? 'folder', filled: true), size: 14, color: color ?? Tokens.onSurfaceVariant),
        label: item.folderName!,
      );
    } else {
      folder = _Chip(
        fill: Tokens.containerHigh,
        ink: Tokens.onSurfaceVariant,
        lead: Icon(symbolIcon('inbox'), size: 14, color: Tokens.onSurfaceVariant),
        label: l.folderNone,
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // метка ловит касание с запасом: палец крупнее пилюли
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: onMove, child: folder),
        if (item.reminderAt case final at?)
          _Chip(
            fill: Tokens.containerHigh,
            ink: Tokens.onSurfaceVariant,
            lead: Icon(symbolIcon('alarm'), size: 14, color: Tokens.onSurfaceVariant),
            label: formatReminderShort(l, at, now),
          ),
        if (item.gone)
          _Chip(
            fill: Tokens.containerHigh,
            ink: Tokens.onSurfaceVariant,
            lead: Icon(symbolIcon('link_off'), size: 14, color: Tokens.onSurfaceVariant),
            label: item.hasCopy ? l.readerGone : l.linkGone,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.fill, required this.ink, required this.lead, required this.label});

  final Color fill;
  final Color ink;
  final Widget lead;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.only(left: 9, right: 11),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          lead,
          const SizedBox(width: 5),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 12.5, color: ink)),
          ),
        ],
      ),
    );
  }
}

/// Новая заметка въезжает сверху: место растёт, сама поднимается и проявляется.
class _Arrive extends StatefulWidget {
  const _Arrive({super.key, required this.play, required this.child});

  final bool play;
  final Widget child;

  @override
  State<_Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<_Arrive> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 550), value: widget.play ? 0 : 1);

  @override
  void initState() {
    super.initState();
    if (widget.play) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = CurvedAnimation(parent: _controller, curve: Motion.spatial);
    final room = CurvedAnimation(parent: _controller, curve: const Interval(0, 500 / 550, curve: Motion.emphasized));
    return SizeTransition(
      sizeFactor: room,
      alignment: AlignmentDirectional.topStart,
      // двигается готовый слой, содержимое на каждом кадре не перерисовывается
      child: FadeTransition(
        opacity: rise.drive(const UnitClamp()),
        child: MatrixTransition(
          animation: rise,
          onTransform: (t) => Matrix4.translationValues(0, 16 * (1 - t), 0),
          child: widget.child,
        ),
      ),
    );
  }
}
