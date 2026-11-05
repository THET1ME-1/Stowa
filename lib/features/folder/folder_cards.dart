import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/format/duration_format.dart';
import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/marked_text.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/voice_player.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/item_kind.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../composer/panel_text.dart' show shortDate;
import '../item/adult_veil.dart';
import '../item/copying_bar.dart';

/// Карточка вещи в ленте папки: у каждого вида своя, как на экране 6 макета.
class FolderItemCard extends StatelessWidget {
  const FolderItemCard({super.key, required this.card, required this.filesRoot, required this.now, required this.onTap, this.onLongPress});

  final ItemCard card;
  final Directory filesRoot;
  final DateTime now;
  final VoidCallback onTap;

  /// Долгое нажатие: переложить, удалить.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: WithCopyingBar(
        itemId: card.id,
        copying: card.copying > 0,
        child: switch (card.kind) {
          // без обложки большая плитка пустая: такой ролик идёт строкой, как ссылка
          ItemKind.video when card.thumbPath == null => _RowCard(card: card, filesRoot: filesRoot, onTap: onTap),
          ItemKind.video => _VideoCard(card: card, filesRoot: filesRoot, now: now, onTap: onTap),
          ItemKind.voice => _VoiceCard(card: card, filesRoot: filesRoot, onTap: onTap),
          ItemKind.link || ItemKind.file => _RowCard(card: card, filesRoot: filesRoot, onTap: onTap),
          ItemKind.image => _PhotoCard(card: card, filesRoot: filesRoot, now: now, onTap: onTap),
          ItemKind.note => _NoteCard(card: card, now: now, onTap: onTap),
        },
      ),
    );
  }
}

String? _host(ItemCard card) {
  final host = card.url == null ? null : Uri.tryParse(card.url!)?.host;
  return host == null || host.isEmpty ? null : sourceName(host);
}

/// Напоминание и теги маленькими чипами под заголовком.
class _Meta extends StatelessWidget {
  const _Meta({required this.card, required this.now});

  final ItemCard card;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 13, color: Tokens.onSurface);
    Widget chip(String label, {String? icon}) => Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(symbolIcon(icon), size: 15, color: Tokens.onSurfaceVariant), const SizedBox(width: 4)],
          Text(label, style: style),
        ],
      ),
    );
    final reminder = card.reminderAt;
    // когда и где сохранено — тихой строкой, чтобы не спорить с заголовком
    final when = '${shortDate(l, card.createdAt, now)}, ${DateFormat.jm(l.localeName).format(card.createdAt)}';
    final stamp = [when, ?card.placeName].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reminder != null || card.tags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (reminder != null) chip(formatReminderShort(l, reminder, now), icon: 'alarm'),
                for (final tag in card.tags.take(3)) chip('#$tag'),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(stamp, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 12, color: Tokens.muted)),
        ],
      ),
    );
  }
}

// картинка карточки; у вещи 18+ без разрешённого показа — размытая
Widget _photo(Directory root, String path, {required String id, double? height, int? cacheWidth, bool compact = false}) => AdultVeil(
  itemId: id,
  compact: compact,
  child: Image.file(
    File(p.join(root.path, path)),
    fit: BoxFit.cover,
    width: double.infinity,
    height: height,
    cacheWidth: cacheWidth,
    errorBuilder: (_, _, _) => SizedBox(height: height ?? 120, child: const ColoredBox(color: Tokens.containerHigh)),
  ),
);

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.card, required this.filesRoot, required this.now, required this.onTap});

  final ItemCard card;
  final Directory filesRoot;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final host = _host(card);
    final width = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 168,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  card.thumbPath != null ? _photo(filesRoot, card.thumbPath!, id: card.id, cacheWidth: width) : const ColoredBox(color: Tokens.containerHigh),
                  if (host != null)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(symbolIcon('play_arrow', filled: true), size: 16, color: Tokens.onAccent),
                            const SizedBox(width: 4),
                            Text(host, style: text.labelSmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: Tokens.onAccent)),
                          ],
                        ),
                      ),
                    ),
                  if (card.durationSeconds != null)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Tokens.background.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(13)),
                        child: Text(
                          formatClock(Duration(seconds: card.durationSeconds!)),
                          style: text.labelSmall!.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: Tokens.onSurface),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
                      child: Icon(symbolIcon('play_arrow', filled: true), color: Tokens.onAccent),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 12, Space.screen, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.title, style: text.titleMedium!.copyWith(fontSize: 16, height: 1.3)),
                  _Meta(card: card, now: now),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.card, required this.filesRoot, required this.now, required this.onTap});

  final ItemCard card;
  final Directory filesRoot;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final width = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();
    // имя файла вместо подписи не показываем
    final captioned = card.body.trim().isNotEmpty;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // высокое фото во весь рост закрыло бы ленту: не выше 340, обрезка по центру
            if (card.thumbPath != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: _photo(filesRoot, card.thumbPath!, id: card.id, cacheWidth: width),
              ),
            if (captioned || card.tags.isNotEmpty || card.reminderAt != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 12, Space.screen, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (captioned) Text(card.title, style: text.titleMedium!.copyWith(fontSize: 16, height: 1.3)),
                    _Meta(card: card, now: now),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.card, required this.now, required this.onTap});

  final ItemCard card;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lines = card.body.trim().split('\n');
    // первая строка уже заголовок
    final rest = lines.skip(1).where((line) => line.trim().isNotEmpty).join('\n');
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 16),
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.title, style: text.titleMedium!.copyWith(fontSize: 16, height: 1.3)),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 6),
              // оформление из разметки: жирное жирным, галочки значками
              MarkedText.note(rest, maxLines: 4, style: text.bodyMedium!.copyWith(height: 1.4, color: Tokens.onSurfaceVariant)),
            ],
            _Meta(card: card, now: now),
          ],
        ),
      ),
    );
  }
}

/// Ссылка или файл: картинка или значок слева, заголовок и источник.
class _RowCard extends StatelessWidget {
  const _RowCard({required this.card, required this.filesRoot, required this.onTap});

  final ItemCard card;
  final Directory filesRoot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final video = card.kind == ItemKind.video;
    final link = card.kind == ItemKind.link || video;
    final size = card.fileSize < 1024 * 1024 ? '${(card.fileSize / 1024).ceil()} KB' : '${(card.fileSize / 1024 / 1024).toStringAsFixed(1)} MB';
    final source = link ? (_host(card) ?? '') : (card.filePath == null ? '' : '${p.extension(card.filePath!).replaceFirst('.', '').toUpperCase()} · $size');
    final icon = video ? 'play_arrow' : (link ? 'link' : 'description');
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(Space.tile),
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox.square(
                dimension: 56,
                child: card.thumbPath != null
                    ? _photo(filesRoot, card.thumbPath!, id: card.id, compact: true, cacheWidth: (56 * MediaQuery.devicePixelRatioOf(context)).round())
                    : ColoredBox(
                        color: Tokens.containerHighest,
                        child: Icon(symbolIcon(icon, filled: video), color: Tokens.onSurface),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w500, height: 1.3)),
                  if (source.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(symbolIcon(video ? 'play_arrow' : (link ? 'link' : 'draft')), size: 15, color: Tokens.muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(source, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(fontSize: 13, color: Tokens.muted)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Голосовое: кнопка, волна с бегущим прогрессом, длина и расшифровка.
class _VoiceCard extends StatelessWidget {
  const _VoiceCard({required this.card, required this.filesRoot, required this.onTap});

  final ItemCard card;
  final Directory filesRoot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final transcript = card.transcript;
    final path = card.filePath;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(Space.tile),
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (path != null) VoicePlayer(path: p.join(filesRoot.path, path), seedId: card.id),
            const SizedBox(height: 10),
            if (transcript != null && transcript.isNotEmpty) ...[
              Text(l.voiceTranscribed, style: text.labelSmall!.copyWith(fontSize: 12, color: Tokens.muted)),
              const SizedBox(height: 2),
              Text(transcript, maxLines: 4, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(fontSize: 14, height: 1.4, color: Tokens.onSurfaceVariant)),
            ] else
              Text(l.voiceNoTranscript, style: text.bodySmall!.copyWith(fontSize: 13, color: Tokens.muted)),
          ],
        ),
      ),
    );
  }
}

/// Плитка доски: картинка в своих пропорциях, первый тег белой пилюлей; заметка — текстом.
class BoardTile extends StatelessWidget {
  const BoardTile({super.key, required this.card, required this.filesRoot, required this.width, required this.onTap, this.onLongPress, this.darkPill = false});

  final ItemCard card;
  final Directory filesRoot;
  final double width;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool darkPill;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tag = card.tags.firstOrNull;
    final thumb = card.thumbPath;
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: 0.97,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.photo),
        child: thumb == null
            ? Container(
                padding: const EdgeInsets.all(Space.tile),
                color: Tokens.container,
                child: Text(card.title, maxLines: 6, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(height: 1.4)),
              )
            : Stack(
                children: [
                  AdultVeil(
                    itemId: card.id,
                    child: Image.file(
                      File(p.join(filesRoot.path, thumb)),
                      width: width,
                      // размер известен заранее: место под картинку не меняется, когда она прочиталась
                      height: card.thumbRatio == null ? null : width * card.thumbRatio!,
                      fit: card.thumbRatio == null ? BoxFit.fitWidth : BoxFit.cover,
                      cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
                      frameBuilder: (context, child, frame, sync) => frame == null && !sync
                          ? SizedBox(width: width, height: width * (card.thumbRatio ?? 1), child: const ColoredBox(color: Tokens.containerHigh))
                          : child,
                      errorBuilder: (_, _, _) => SizedBox(width: width, height: width * (card.thumbRatio ?? 1), child: const ColoredBox(color: Tokens.containerHigh)),
                    ),
                  ),
                  if (tag != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        // пилюля белая, а на светлых фото тёмная: в макете обе, чередуются
                        decoration: BoxDecoration(color: darkPill ? Tokens.containerHighest : Tokens.accent, borderRadius: BorderRadius.circular(13)),
                        child: Text(
                          '#$tag',
                          style: text.labelSmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: darkPill ? Tokens.onSurface : Tokens.onAccent),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
