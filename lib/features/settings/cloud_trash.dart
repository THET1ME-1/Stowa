/// «В облаке» в корзине: удалённое на любом устройстве и стёртое из корзины, которое ещё
/// хранит сервер Stowa Sync. Вернуть — на прежнее место, стереть — навсегда, с вопросом.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/desk_mode.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/sync/cloud_history.dart';
import '../../services/sync/sync_http.dart';
import '../item/history_screen.dart' show keepTogether;
import '../item/note_history.dart' show CloudAccess;

/// Удалённое в облаке и можно ли его сейчас видеть.
class CloudTrash {
  const CloudTrash(this.access, [this.files = const []]);

  final CloudAccess access;
  final List<DeletedFile> files;
}

final cloudTrashProvider = FutureProvider.autoDispose<CloudTrash>((ref) async {
  if (!await ref.watch(syncSignedInProvider.future)) return const CloudTrash(CloudAccess.signedOut);
  if (!(await ref.watch(subscriptionProvider.future)).activeNow) return const CloudTrash(CloudAccess.noSubscription);
  final history = await ref.watch(cloudHistoryProvider.future);
  if (history == null) return const CloudTrash(CloudAccess.signedOut);
  try {
    return CloudTrash(CloudAccess.on, await history.deleted());
  } on SyncHttpError catch (error) {
    return CloudTrash(error.status == 402 ? CloudAccess.noSubscription : CloudAccess.offline);
  } on Object {
    return const CloudTrash(CloudAccess.offline);
  }
});

/// Имя файла без расширения: «План ремонта», у рисунка — без «.excalidraw.md».
String deletedName(String path) {
  final name = p.posix.basename(path);
  if (name.toLowerCase().endsWith('.excalidraw.md')) return name.substring(0, name.length - '.excalidraw.md'.length);
  return p.posix.basenameWithoutExtension(name);
}

String _iconOf(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.excalidraw.md')) return 'draw';
  return switch (p.posix.extension(lower)) {
    '.md' => 'description',
    '.canvas' => 'dashboard',
    '.base' => 'table_view',
    '.jpg' || '.jpeg' || '.png' || '.webp' || '.heic' || '.gif' => 'image',
    '.mp4' || '.mov' || '.webm' || '.mkv' => 'movie',
    '.m4a' || '.mp3' || '.ogg' || '.wav' || '.opus' => 'graphic_eq',
    '.pdf' => 'picture_as_pdf',
    _ => 'draft',
  };
}

/// Раздел корзины. Без Stowa Sync его нет вовсе: в корзине не место предложениям подписки.
class CloudTrashSection extends ConsumerStatefulWidget {
  const CloudTrashSection({super.key});

  @override
  ConsumerState<CloudTrashSection> createState() => _CloudTrashSectionState();
}

class _CloudTrashSectionState extends ConsumerState<CloudTrashSection> {
  /// Вернули или стёрли, а сервер ещё не знает: строка уходит сразу.
  final _gone = <String>{};

  Future<void> _restore(DeletedFile file) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final history = await ref.read(cloudHistoryProvider.future);
    String? placed;
    try {
      placed = history == null ? null : await ref.read(syncServiceProvider).restoreDeleted(history, file);
    } on Object {
      placed = null;
    }
    if (placed == null) {
      showNote(messenger, l.trashCloudFailed);
      return;
    }
    if (mounted) setState(() => _gone.add(file.tomb));
    showNote(messenger, l.trashRestored(deletedName(placed)));
  }

  Future<bool> _purge(DeletedFile file) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showStowaSheet<bool>(
      context,
      maxHeightFactor: null,
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.trashCloudPurgeAsk(deletedName(file.path)), style: Theme.of(sheet).textTheme.titleMedium),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Tokens.error, foregroundColor: Tokens.onError),
                onPressed: () => Navigator.pop(sheet, true),
                child: Text(l.trashCloudPurge),
              ),
              TextButton(onPressed: () => Navigator.pop(sheet, false), child: Text(l.cancel)),
            ],
          ),
        ),
      ),
    );
    if (yes != true) return false;
    final history = await ref.read(cloudHistoryProvider.future);
    try {
      if (history == null) throw StateError('нет истории');
      await history.purge(file);
    } on Object {
      showNote(messenger, l.trashCloudFailed);
      return false;
    }
    if (mounted) setState(() => _gone.add(file.tomb));
    showNote(messenger, l.trashCloudPurged);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    // возврат и стирание читают историю `.future`: она должна быть под слушателем
    ref.watch(cloudHistoryProvider);
    final trash = ref.watch(cloudTrashProvider).value;
    if (trash == null) return const SizedBox.shrink();
    if (trash.access == CloudAccess.offline) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(symbolIcon('cloud_off'), size: 16, color: Tokens.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(l.trashCloudOffline, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.35))),
          ],
        ),
      );
    }
    final files = [for (final file in trash.files) if (!_gone.contains(file.tomb)) file];
    if (trash.access != CloudAccess.on || files.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('cloud-trash'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(symbolIcon('cloud', filled: true), size: 18, color: Tokens.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(l.trashCloudTitle, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(l.trashCloudHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
        ),
        const SizedBox(height: 12),
        for (final file in files)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Dismissible(
              key: ValueKey('cloud-trash-${file.tomb}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _purge(file),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(color: Tokens.error, borderRadius: BorderRadius.circular(Radii.tile)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.trashCloudPurge, style: text.labelLarge!.copyWith(color: Tokens.onError)),
                    const SizedBox(width: 8),
                    Icon(symbolIcon('delete_forever'), color: Tokens.onError),
                  ],
                ),
              ),
              child: _CloudRow(file: file, onRestore: () => _restore(file), onPurge: () => _purge(file)),
            ),
          ),
      ],
    );
  }
}

class _CloudRow extends StatelessWidget {
  const _CloudRow({required this.file, required this.onRestore, required this.onPurge});

  final DeletedFile file;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final folder = p.posix.dirname(file.path);
    final note = [
      if (folder != '.') folder,
      keepTogether(l.trashCloudDeleted(DateFormat.MMMd(l.localeName).format(file.deletedAt))),
      ?file.device,
      if (file.attachments.isNotEmpty) keepTogether(l.trashCloudAttachments(file.attachments.length)),
    ].join(' · ');
    return Pressable(
      radius: BorderRadius.circular(Radii.tile),
      onLongPress: onPurge,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.tile)),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: Tokens.graphite, borderRadius: BorderRadius.circular(14)),
              child: Icon(symbolIcon(_iconOf(file.path)), color: Tokens.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deletedName(file.path), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
                  const SizedBox(height: 2),
                  Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: Tokens.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: l.restoreAction,
              child: Pressable(
                onTap: onRestore,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(100)),
                  child: Text(l.restoreAction, style: text.labelLarge!.copyWith(color: Tokens.onAccent)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
