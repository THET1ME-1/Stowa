import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/marked_text.dart';
import '../../core/widgets/motion_bits.dart';
import '../../core/widgets/pressable.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/item_kind.dart';
import '../../domain/item_title.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../item/adult_veil.dart';
import '../item/copying_bar.dart';

const recentCardWidth = 132.0;
const _artHeight = 64.0;

/// Текст заметки под заголовком, без отступов: карточка узкая.
String notePreview(String body, {required String title}) => linesUnderTitle(body, title).map((line) => line.trim()).join('\n');

/// Высота карточки растёт вместе с системным шрифтом, иначе подпись режется.
double recentCardHeight(TextScaler scaler) {
  final title = scaler.scale(14) * 1.3 * 2;
  final caption = scaler.scale(12) * 1.35;
  return _artHeight + 10 + title + 8 + caption + 12;
}

/// «Только что»: последние вещи вбок. Новая вещь въезжает, а не появляется скачком.
class RecentStrip extends StatefulWidget {
  const RecentStrip({super.key, required this.items, required this.filesRoot, required this.now, this.aiSorting = false, this.onOpen, this.onMove, this.onAct});

  final List<ItemCard> items;
  final Directory filesRoot;
  final DateTime now;

  /// Ключ ИИ работает: вещи без папки в очереди подписаны «разбираю», а не «Без папки».
  final bool aiSorting;
  final ValueChanged<ItemCard>? onOpen;

  /// Касание подписи: переложить в папку.
  final ValueChanged<ItemCard>? onMove;

  /// Долгое нажатие: открыть, переложить, удалить.
  final ValueChanged<ItemCard>? onAct;

  @override
  State<RecentStrip> createState() => _RecentStripState();
}

class _RecentStripState extends State<RecentStrip> {
  // вещи, которые уже были на экране: им въезжать не нужно
  late final Set<String> _seen = {for (final item in widget.items) item.id};

  @override
  Widget build(BuildContext context) {
    final height = recentCardHeight(MediaQuery.textScalerOf(context));
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
        itemCount: widget.items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final fresh = _seen.add(item.id);
          return _Arrive(
            key: ValueKey(item.id),
            play: fresh,
            child: RecentCard(
              item: item,
              filesRoot: widget.filesRoot,
              now: widget.now,
              aiSorting: widget.aiSorting,
              onTap: widget.onOpen == null ? null : () => widget.onOpen!(item),
              onMove: widget.onMove == null ? null : () => widget.onMove!(item),
              onLongPress: widget.onAct == null ? null : () => widget.onAct!(item),
            ),
          );
        },
      ),
    );
  }
}

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
    // как rc-in в макете: снизу на 24 точки из 70% размера, пружинка 0,55 с;
    // соседи отъезжают за 0,5 с, место растёт той же пружинкой
    final rise = CurvedAnimation(parent: _controller, curve: Motion.spatial);
    final room = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 500 / 550, curve: Motion.spatial),
    );
    return SizeTransition(
      sizeFactor: room,
      axis: Axis.horizontal,
      alignment: AlignmentDirectional.centerStart,
      // двигается готовый слой, содержимое на каждом кадре не перерисовывается
      child: FadeTransition(
        opacity: rise.drive(const UnitClamp()),
        child: MatrixTransition(
          animation: rise,
          onTransform: (t) {
            final scale = 0.7 + 0.3 * t;
            return Matrix4.translationValues(0, 24 * (1 - t), 0)..scaleByDouble(scale, scale, 1, 1);
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class RecentCard extends StatelessWidget {
  const RecentCard({super.key, required this.item, required this.filesRoot, required this.now, this.aiSorting = false, this.onTap, this.onMove, this.onLongPress});

  final ItemCard item;
  final Directory filesRoot;
  final DateTime now;
  final bool aiSorting;
  final VoidCallback? onTap;

  /// Касание подписи с папкой: переложить.
  final VoidCallback? onMove;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: recentCardWidth,
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _artHeight,
              child: WithCopyingBar(itemId: item.id, copying: item.copying > 0, child: SizedBox.expand(child: _art(context))),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.tile, 10, Space.tile, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(fontSize: 14, height: 1.3, fontWeight: FontWeight.w500),
                      ),
                    ),
                    // подпись ловит касание на всю ширину и с запасом сверху: палец крупнее строки
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onMove,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _Where(item: item, now: now, aiSorting: aiSorting),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _art(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final thumb = item.thumbPath;
    if (thumb != null) {
      final width = (recentCardWidth * MediaQuery.devicePixelRatioOf(context)).round();
      return AdultVeil(
        itemId: item.id,
        child: Image.file(
          File(p.join(filesRoot.path, thumb)),
          fit: BoxFit.cover,
          cacheWidth: width,
          errorBuilder: (_, _, _) => const ColoredBox(color: Tokens.containerHigh),
        ),
      );
    }
    final String? label = switch (item.kind) {
      ItemKind.link || ItemKind.video => switch (item.url == null ? null : Uri.tryParse(item.url!)?.host) {
        final host? when host.isNotEmpty => sourceName(host),
        _ => null,
      },
      _ => null,
    };
    final preview = notePreview(item.body, title: item.title);
    final iconName = switch (item.kind) {
      ItemKind.video => 'play_arrow',
      ItemKind.link => 'link',
      ItemKind.voice => 'graphic_eq',
      ItemKind.file => 'description',
      _ when item.body.startsWith('- [') => 'check_box_outline_blank',
      _ when preview.isEmpty => 'notes',
      _ => null,
    };
    return ColoredBox(
      color: Tokens.containerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.tile, 10, Space.tile, 8),
        child: iconName == null
            ? MarkedText.note(preview, maxLines: 2, style: text.bodySmall!.copyWith(fontSize: 13, height: 1.3, color: Tokens.onSurfaceVariant))
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(symbolIcon(iconName, filled: true), size: 20, color: Tokens.onSurface),
                  if (label != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Подпись под карточкой: папка, а если её нет — когда напомнит или «Без папки».
class _Where extends StatelessWidget {
  const _Where({required this.item, required this.now, required this.aiSorting});

  final ItemCard item;
  final DateTime now;
  final bool aiSorting;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final style = Theme.of(context).textTheme.labelSmall!.copyWith(fontSize: 12, color: Tokens.muted);
    // ключ ИИ разбирает вещь: бегущая полоска вместо папки
    final waiting = item.folderId == null && (item.sortState == SortState.queued || item.sortState == SortState.pending);
    if (aiSorting && waiting) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(color: Tokens.onSurfaceVariant, backgroundColor: Tokens.graphite),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(l.itemSortingBadge, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          ),
        ],
      );
    }
    final (String icon, String label) = item.folderName != null
        ? (item.folderIcon ?? 'folder', item.folderName!)
        : item.reminderAt != null
        ? ('alarm', formatReminderShort(l, item.reminderAt!, now))
        : ('inbox', l.folderNone);
    return Row(
      children: [
        Icon(symbolIcon(icon), size: 15, color: Tokens.muted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
      ],
    );
  }
}
