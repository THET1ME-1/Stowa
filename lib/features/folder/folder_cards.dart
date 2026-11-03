import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/item_kind.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';

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
      child: switch (card.kind) {
        // без обложки большая плитка пустая: такой ролик идёт строкой, как ссылка
        ItemKind.video when card.thumbPath == null => _RowCard(card: card, filesRoot: filesRoot, onTap: onTap),
        ItemKind.video => _VideoCard(card: card, filesRoot: filesRoot, now: now, onTap: onTap),
        ItemKind.voice => _VoiceCard(card: card, filesRoot: filesRoot, onTap: onTap),
        ItemKind.link || ItemKind.file => _RowCard(card: card, filesRoot: filesRoot, onTap: onTap),
        ItemKind.image => _PhotoCard(card: card, filesRoot: filesRoot, now: now, onTap: onTap),
        ItemKind.note => _NoteCard(card: card, now: now, onTap: onTap),
      },
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
    if (reminder == null && card.tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (reminder != null) chip(formatReminderShort(l, reminder, now), icon: 'alarm'),
          for (final tag in card.tags.take(3)) chip('#$tag'),
        ],
      ),
    );
  }
}

Widget _photo(Directory root, String path, {double? height, int? cacheWidth}) => Image.file(
  File(p.join(root.path, path)),
  fit: BoxFit.cover,
  width: double.infinity,
  height: height,
  cacheWidth: cacheWidth,
  errorBuilder: (_, _, _) => SizedBox(height: height ?? 120, child: const ColoredBox(color: Tokens.containerHigh)),
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
                  card.thumbPath != null ? _photo(filesRoot, card.thumbPath!, cacheWidth: width) : const ColoredBox(color: Tokens.containerHigh),
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
            if (card.thumbPath != null) _photo(filesRoot, card.thumbPath!, cacheWidth: width),
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
              Text(rest, maxLines: 4, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(height: 1.4, color: Tokens.onSurfaceVariant)),
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
                    ? _photo(filesRoot, card.thumbPath!, cacheWidth: (56 * MediaQuery.devicePixelRatioOf(context)).round())
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
class _VoiceCard extends StatefulWidget {
  const _VoiceCard({required this.card, required this.filesRoot, required this.onTap});

  final ItemCard card;
  final Directory filesRoot;
  final VoidCallback onTap;

  @override
  State<_VoiceCard> createState() => _VoiceCardState();
}

class _VoiceCardState extends State<_VoiceCard> {
  AudioPlayer? _player;
  Duration? _length;
  double _progress = 0;
  bool _playing = false;
  final _subscriptions = <StreamSubscription<Object?>>[];

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final path = widget.card.filePath;
    if (path == null) return;
    var player = _player;
    if (player == null) {
      player = _player = AudioPlayer();
      _subscriptions
        ..add(
          player.playerStateStream.listen((state) {
            if (!mounted) return;
            final ended = state.processingState == ProcessingState.completed;
            setState(() => _playing = state.playing && !ended);
            if (ended) {
              player!.pause();
              player.seek(Duration.zero);
            }
          }),
        )
        ..add(
          player.positionStream.listen((position) {
            final length = _length?.inMilliseconds ?? 0;
            if (mounted && length > 0) setState(() => _progress = (position.inMilliseconds / length).clamp(0.0, 1.0));
          }),
        );
      final length = await player.setFilePath(p.join(widget.filesRoot.path, path));
      if (mounted) setState(() => _length = length);
    }
    _playing ? await player.pause() : await player.play();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final transcript = widget.card.transcript;
    final length = _length;
    // волна одна и та же у одного голосового: высоты из его id
    final seed = widget.card.id.codeUnits.fold(7, (sum, unit) => (sum * 31 + unit) & 0x7fffffff);
    return Pressable(
      onTap: widget.onTap,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(Space.tile),
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Tooltip(
                  message: _playing ? l.voicePause : l.voicePlay,
                  child: Pressable(
                    pressedScale: 0.9,
                    onTap: _toggle,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
                      child: Icon(symbolIcon(_playing ? 'pause' : 'play_arrow', filled: true), color: Tokens.onAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: Row(
                      children: [
                        for (var bar = 0; bar < 32; bar++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: Container(
                                height: 6 + ((seed >> (bar % 24)) & 7) * 3.0 + (bar % 5) * 1.5,
                                decoration: BoxDecoration(
                                  color: bar / 32 < _progress ? Tokens.accent : Tokens.onSurfaceVariant.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  length == null ? '' : '${length.inMinutes}:${(length.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: text.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: Tokens.muted),
                ),
              ],
            ),
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
                  Image.file(
                    File(p.join(filesRoot.path, thumb)),
                    width: width,
                    fit: BoxFit.fitWidth,
                    cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
                    // пока картинка не прочиталась, место держит квадрат
                    frameBuilder: (context, child, frame, sync) => frame == null && !sync ? SizedBox(width: width, height: width, child: const ColoredBox(color: Tokens.containerHigh)) : child,
                    errorBuilder: (_, _, _) => SizedBox(width: width, height: width, child: const ColoredBox(color: Tokens.containerHigh)),
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
