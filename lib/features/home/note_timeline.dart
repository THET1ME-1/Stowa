import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
import '../../domain/models.dart';
import '../../domain/note_blocks.dart';
import '../../l10n/app_localizations.dart';
import '../item/adult_veil.dart';
import '../item/copying_bar.dart';

/// Ось ленты: по ней идёт пунктир, на ней точка в цвет папки.
const _rail = Space.screen + 6;

/// Отступ карточки заметки от края экрана: ось с точкой занимает узкую полосу слева.
const _indent = Space.screen + 22;

/// Точка заметки на оси — на уровне заголовка карточки.
const _dotTop = 18.0;

/// Фото в ленте не выше этого: лента листается быстро, а целиком оно на странице заметки.
const _photoMax = 220.0;

/// Сколько строк заметки видно в ленте; дальше — на её странице.
const _lines = 8;

const _cardRadius = 24.0;

/// Лента главной: последние заметки по дням, точки в цвет папок на пунктирной оси слева, как в дневнике.
/// Заметку видно целиком, пункты списка отмечаются прямо здесь.
class NoteTimeline extends StatefulWidget {
  const NoteTimeline({
    super.key,
    required this.items,
    required this.filesRoot,
    required this.now,
    this.aiSorting = false,
    required this.onOpen,
    required this.onMove,
    required this.onAct,
    required this.onToggle,
  });

  final List<ItemCard> items;
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

class _NoteTimelineState extends State<NoteTimeline> {
  // заметки, которые уже были на экране: им въезжать не нужно
  late final Set<String> _seen = {for (final item in widget.items) item.id};

  @override
  Widget build(BuildContext context) {
    // заметки идут от новых к старым: день начинается, когда меняется дата
    final days = <(DateTime, List<ItemCard>)>[];
    for (final item in widget.items) {
      final at = item.createdAt;
      final day = DateTime(at.year, at.month, at.day);
      if (days.isEmpty || days.last.$1 != day) days.add((day, []));
      days.last.$2.add(item);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (day, items) in days) ...[
          _DayHeader(day: day, now: widget.now),
          Stack(
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
                          filesRoot: widget.filesRoot,
                          now: widget.now,
                          aiSorting: widget.aiSorting,
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
          ),
        ],
      ],
    );
  }
}

String _capitalized(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

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
    required this.filesRoot,
    required this.now,
    required this.aiSorting,
    required this.onOpen,
    required this.onMove,
    required this.onAct,
    required this.onToggle,
  });

  final ItemCard item;
  final Directory filesRoot;
  final DateTime now;
  final bool aiSorting;
  final VoidCallback onOpen;
  final VoidCallback onMove;
  final VoidCallback onAct;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final thumb = item.thumbPath == null ? null : p.join(filesRoot.path, item.thumbPath!);
    final attachment = switch (item.kind) {
      ItemKind.link || ItemKind.video || ItemKind.file || ItemKind.voice => true,
      _ => false,
    };
    // у ссылки обложка слева с узким полем, у текста и фото поле шире
    final pad = attachment ? 10.0 : 16.0;
    final Widget content = switch (item.kind) {
      _ when attachment => Padding(padding: EdgeInsets.fromLTRB(pad, pad, pad, 0), child: _Attachment(item: item, thumb: thumb)),
      _ when thumb != null => _Photo(item: item, path: thumb, onToggle: onToggle),
      _ => Padding(padding: EdgeInsets.fromLTRB(pad, 14, pad, 0), child: _Text(item: item, onToggle: onToggle)),
    };
    // карточка чуть в цвет папки: заметки одной папки узнаются в ленте издалека
    final fill = item.folderColor == null ? Tokens.container : FolderPalette.tint(item.folderColor!, 0.1);
    final time = Text(
      DateFormat.jm(l.localeName).format(item.createdAt),
      style: Theme.of(context).textTheme.labelSmall!.copyWith(color: Tokens.muted, fontFeatures: const [FontFeature.tabularFigures()]),
    );
    return Stack(
      children: [
        // точка в цвет папки, у неразложенной серая; кольцо цвета фона разрывает пунктир
        Positioned(
          left: _rail - 6,
          top: _dotTop - 6,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: item.folderColor == null ? Tokens.muted : FolderPalette.ink(item.folderColor!),
              shape: BoxShape.circle,
              border: Border.all(color: Tokens.background, width: 2.5),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: _indent, right: Space.screen),
          child: Pressable(
            onTap: onOpen,
            onLongPress: onAct,
            pressedScale: 0.98,
            child: Container(
              decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(_cardRadius)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
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
            ),
          ),
        ),
      ],
    );
  }
}

TextStyle _titleStyle(TextTheme text) => text.titleMedium!.copyWith(fontSize: 17, height: 1.3);

TextStyle _bodyStyle(TextTheme text) => text.bodyMedium!.copyWith(fontSize: 15, height: 1.45, color: Tokens.onSurfaceVariant);

/// Заметка текстом: заголовок и строки под ним, пункты списка с галочками.
class _Text extends StatelessWidget {
  const _Text({required this.item, required this.onToggle});

  final ItemCard item;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lines = noteLinesUnderTitle(item.body, item.title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(item.title, maxLines: lines.isEmpty ? 6 : 3, overflow: TextOverflow.ellipsis, style: _titleStyle(text)),
        if (lines.isNotEmpty) ...[const SizedBox(height: 6), _Lines(lines: lines, color: item.folderColor, onToggle: onToggle)],
      ],
    );
  }
}

/// Строки заметки: обычные текстом, пункты — галочкой, которую можно отметить отсюда.
class _Lines extends StatelessWidget {
  const _Lines({required this.lines, required this.color, required this.onToggle});

  final List<NoteLine> lines;
  final Color? color;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final shown = lines.take(_lines).toList();
    final hiddenChecks = lines.skip(_lines).where((line) => line.done != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in shown)
          if (line.done case final done?)
            _CheckRow(text: line.text, done: done, color: color ?? Tokens.accent, onTap: () => onToggle(line.index))
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: MarkedText.note(line.text, maxLines: 4, style: _bodyStyle(text)),
            ),
        if (hiddenChecks > 0)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 2),
            child: Text(l.homeChecksMore(hiddenChecks), style: text.bodySmall!.copyWith(color: Tokens.muted)),
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
  const _Photo({required this.item, required this.path, required this.onToggle});

  final ItemCard item;
  final String path;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
        if (lines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: _titleStyle(text)),
                const SizedBox(height: 4),
                _Lines(lines: lines, color: item.folderColor, onToggle: onToggle),
              ],
            ),
          ),
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
                  Text(item.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: text.titleSmall!.copyWith(fontSize: 15, height: 1.3)),
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
