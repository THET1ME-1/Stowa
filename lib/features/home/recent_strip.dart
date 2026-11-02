import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';

const recentCardWidth = 132.0;
const _artHeight = 64.0;

/// Текст заметки после первой строки: первая уже стоит заголовком.
String notePreview(String body) {
  final lines = body.trim().split('\n');
  return lines.skip(1).map((line) => line.trim()).where((line) => line.isNotEmpty).join('\n');
}

/// Высота карточки растёт вместе с системным шрифтом, иначе подпись режется.
double recentCardHeight(TextScaler scaler) {
  final title = scaler.scale(14) * 1.3 * 2;
  final caption = scaler.scale(12) * 1.35;
  return _artHeight + 10 + title + 8 + caption + 12;
}

/// «Только что»: последние вещи вбок. Новая вещь въезжает, а не появляется скачком.
class RecentStrip extends StatefulWidget {
  const RecentStrip({super.key, required this.items, required this.filesRoot, required this.now, this.onOpen});

  final List<ItemCard> items;
  final Directory filesRoot;
  final DateTime now;
  final ValueChanged<ItemCard>? onOpen;

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
            child: RecentCard(item: item, filesRoot: widget.filesRoot, now: widget.now, onTap: widget.onOpen == null ? null : () => widget.onOpen!(item)),
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
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.long, value: widget.play ? 0 : 1);

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
    final scale = CurvedAnimation(parent: _controller, curve: Motion.spatial);
    final fade = CurvedAnimation(parent: _controller, curve: Motion.emphasizedDecelerate);
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(scale), child: widget.child),
    );
  }
}

class RecentCard extends StatelessWidget {
  const RecentCard({super.key, required this.item, required this.filesRoot, required this.now, this.onTap});

  final ItemCard item;
  final Directory filesRoot;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: recentCardWidth,
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: _artHeight, child: _art(context)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.tile, 10, Space.tile, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium!.copyWith(fontSize: 14, height: 1.3, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 8),
                _Where(item: item, now: now),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _art(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final thumb = item.thumbPath;
    if (thumb != null) {
      final width = (recentCardWidth * MediaQuery.devicePixelRatioOf(context)).round();
      return Image.file(
        File(p.join(filesRoot.path, thumb)),
        fit: BoxFit.cover,
        cacheWidth: width,
        errorBuilder: (_, _, _) => const ColoredBox(color: Tokens.containerHigh),
      );
    }
    final String? label = switch (item.kind) {
      ItemKind.link || ItemKind.video => item.url == null ? null : Uri.tryParse(item.url!)?.host.replaceFirst('www.', ''),
      _ => null,
    };
    final preview = notePreview(item.body);
    final iconName = switch (item.kind) {
      ItemKind.video => 'play_arrow',
      ItemKind.link => 'link',
      ItemKind.voice => 'graphic_eq',
      ItemKind.file => 'description',
      _ when preview.isEmpty => 'notes',
      _ => null,
    };
    return ColoredBox(
      color: Tokens.containerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.tile, 10, Space.tile, 8),
        child: iconName == null
            ? Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(fontSize: 13, height: 1.3, color: Tokens.onSurfaceVariant),
              )
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(symbolIcon(iconName, filled: true), size: 20, color: Tokens.onSurface),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant)),
                  ),
                ],
              ]),
      ),
    );
  }
}

/// Подпись под карточкой: папка, а если её нет — когда напомнит или «Без папки».
class _Where extends StatelessWidget {
  const _Where({required this.item, required this.now});

  final ItemCard item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final style = Theme.of(context).textTheme.labelSmall!.copyWith(fontSize: 12, color: Tokens.muted);
    // ключ ИИ разбирает вещь: бегущая полоска вместо папки
    if (item.sortState == SortState.queued) {
      return Row(children: [
        const SizedBox(width: 16, height: 3, child: ClipRRect(borderRadius: BorderRadius.all(Radius.circular(2)), child: LinearProgressIndicator(color: Tokens.onSurfaceVariant, backgroundColor: Tokens.graphite))),
        const SizedBox(width: 6),
        Expanded(child: Text(l.itemSortingBadge, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ]);
    }
    final (String icon, String label) = item.folderName != null
        ? (item.folderIcon ?? 'folder', item.folderName!)
        : item.reminderAt != null
            ? ('alarm', formatReminderShort(l, item.reminderAt!, now))
            : ('inbox', l.folderNone);
    return Row(children: [
      Icon(symbolIcon(icon), size: 15, color: Tokens.muted),
      const SizedBox(width: 4),
      Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
    ]);
  }
}
