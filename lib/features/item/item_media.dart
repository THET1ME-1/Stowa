import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../core/format/duration_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../domain/item_kind.dart';
import '../../l10n/app_localizations.dart';
import 'adult_veil.dart';

/// «PDF · 1.2 MB»: расширение и размер, как в карточках папки.
String fileCaption(String path, int size) {
  final kind = p.extension(path).replaceFirst('.', '').toUpperCase();
  final weight = size < 1024 * 1024 ? '${(size / 1024).ceil()} KB' : '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  return kind.isEmpty ? weight : '$kind · $weight';
}

/// Имя файла без номера, который приписывает хранилище: «0_Договор.pdf» → «Договор.pdf».
String fileTitle(String path) => p.basename(path).replaceFirst(RegExp(r'^\d+_'), '');

/// Значок файла по его типу.
String fileIcon(String mime, String path) {
  final extension = p.extension(path).toLowerCase();
  if (mime == 'application/pdf' || extension == '.pdf') return 'picture_as_pdf';
  if (mime.startsWith('video/')) return 'movie';
  if (mime.startsWith('audio/')) return 'graphic_eq';
  if (mime.startsWith('image/')) return 'image';
  if (const ['.zip', '.rar', '.7z', '.tar', '.gz'].contains(extension)) return 'folder_zip';
  if (const ['.xls', '.xlsx', '.csv', '.ods'].contains(extension)) return 'table';
  if (const ['.doc', '.docx', '.odt', '.rtf', '.txt', '.md'].contains(extension)) return 'article';
  if (extension == '.apk') return 'android';
  return 'description';
}

/// Открыть свой файл в приложении системы: PDF в просмотрщике, видео в плеере.
Future<void> openLocalFile(BuildContext context, String path, String mime) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = L.of(context).fileOpenFailed;
  final result = await OpenFilex.open(path, type: mime);
  if (result.type != ResultType.done) showNote(messenger, message, overDock: true);
}

/// Превью ссылки: картинка страницы, сайт и описание. Касание открывает страницу.
/// Страница 18+, а показ не включён — картинка размыта, описание спрятано.
class LinkPreviewCard extends ConsumerWidget {
  const LinkPreviewCard({super.key, required this.item, required this.filesRoot, required this.onOpen});

  final Item item;
  final Directory filesRoot;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = Uri.tryParse(item.url ?? '')?.host ?? '';
    final site = item.previewSite ?? sourceName(host);
    final hidden = adultHidden(ref, item.id);
    final description = hidden && item.previewText != null ? L.of(context).adultHidden : item.previewText;
    final cover = item.coverPath;
    return Pressable(
      onTap: onOpen,
      pressedScale: 0.98,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cover != null)
              SizedBox(
                height: 190,
                child: AdultVeil(
                  itemId: item.id,
                  child: Image.file(
                    File(p.join(filesRoot.path, cover)),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
                    errorBuilder: (_, _, _) => const ColoredBox(color: Tokens.containerHigh),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SiteMark(site: site),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(site, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Tokens.onSurfaceVariant)),
                      ),
                      Icon(symbolIcon('open_in_new'), size: 18, color: Tokens.muted),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // описания ещё нет — видно сам адрес, чтобы было понятно, куда ведёт
                  Text(
                    description ?? item.url ?? '',
                    maxLines: description == null ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.45, color: Tokens.onSurfaceVariant),
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

/// Первая буква сайта на маленькой плашке вместо значка сайта: значки не качаем.
class _SiteMark extends StatelessWidget {
  const _SiteMark({required this.site});

  final String site;

  @override
  Widget build(BuildContext context) {
    final letter = site.isEmpty ? '' : site.characters.first.toUpperCase();
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(7)),
      child: Text(letter, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Tokens.onSurface)),
    );
  }
}

/// Обложка ролика: сервис в углу, длина, круглая кнопка посередине. Касание запускает.
class VideoCover extends StatelessWidget {
  const VideoCover({super.key, required this.coverPath, required this.filesRoot, required this.onPlay, this.source, this.duration, this.itemId});

  /// Чья обложка: у ролика 18+ она размыта, пока показ не включён.
  final String? itemId;
  final String? coverPath;
  final Directory filesRoot;
  final VoidCallback onPlay;
  final String? source;
  final Duration? duration;

  Widget _veiled(Widget image) => itemId == null ? image : AdultVeil(itemId: itemId!, child: image);

  @override
  Widget build(BuildContext context) {
    final cover = coverPath;
    Widget pill(Widget child) => Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Tokens.background.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(15)),
      child: child,
    );
    return Pressable(
      onTap: onPlay,
      pressedScale: 0.98,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover != null)
                _veiled(
                  Image.file(
                    File(p.join(filesRoot.path, cover)),
                    fit: BoxFit.cover,
                    cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
                    errorBuilder: (_, _, _) => const ColoredBox(color: Tokens.containerHigh),
                  ),
                )
              else
                const ColoredBox(color: Tokens.containerHigh),
              if (source != null)
                Positioned(
                  left: 12,
                  top: 12,
                  child: pill(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(symbolIcon('smart_display', filled: true), size: 18, color: Tokens.onSurface),
                        const SizedBox(width: 6),
                        Text(source!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Tokens.onSurface)),
                      ],
                    ),
                  ),
                ),
              if (duration != null)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: pill(Center(widthFactor: 1, child: Text(formatClock(duration!), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Tokens.onSurface)))),
                ),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
                  child: Icon(symbolIcon('play_arrow', filled: true), size: 36, color: Tokens.onAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Приложенный файл строкой: значок по типу, имя, вес. Касание открывает в системе.
class FileTile extends StatelessWidget {
  const FileTile({super.key, required this.file, required this.filesRoot});

  final Attachment file;
  final Directory filesRoot;

  @override
  Widget build(BuildContext context) {
    final path = p.join(filesRoot.path, file.path);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Tokens.container,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openLocalFile(context, path, file.mime),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(14)),
                  child: Icon(symbolIcon(fileIcon(file.mime, file.path)), size: 24, color: Tokens.onSurface),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fileTitle(file.path), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Tokens.onSurface)),
                      const SizedBox(height: 2),
                      Text(fileCaption(file.path, file.size), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Tokens.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(symbolIcon('open_in_new'), size: 22, color: Tokens.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
