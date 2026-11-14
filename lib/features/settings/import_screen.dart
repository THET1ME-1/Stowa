import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/notes_import.dart';
import '../vault/vault_actions.dart';
import 'settings_blocks.dart';
import 'telegram_import_action.dart';

Route<void> importRoute() => settingsPageRoute(const ImportScreen());

/// «Перенос»: откуда забрать накопленное — Telegram, Google Keep, закладки, Obsidian, mymind.
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.settingsImport),
            const SizedBox(height: 18),
            SettingsGroup(
              tint: settingsTint('sky'),
              children: [
                SettingsRow(icon: 'send', title: l.importTelegram, onTap: () => importTelegram(context, ref)),
                SettingsRow(icon: 'sticky_note_2', title: l.importKeep, onTap: () => importNotes(context, ref, ImportSource.keep)),
                SettingsRow(icon: 'bookmarks', title: l.importBookmarks, onTap: () => importNotes(context, ref, ImportSource.bookmarks)),
                SettingsRow(icon: 'description', title: l.importObsidian, onTap: () => importNotes(context, ref, ImportSource.markdown)),
                SettingsRow(icon: 'psychology', title: l.importMymind, onTap: () => importNotes(context, ref, ImportSource.mymind)),
              ],
            ),
            SettingsHint(l.importScreenHint),
          ],
        ),
      ),
    );
  }
}

/// Человек выбирает папку выгрузки (у закладок — файл), заметки переносятся, итог — плашкой:
/// сколько перенесено, сколько уже было, сколько файлов не нашлось.
Future<void> importNotes(BuildContext context, WidgetRef ref, ImportSource source) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final picked = source == ImportSource.bookmarks ? await ref.read(bookmarksPickerProvider)() : await ref.read(vaultPickerProvider)();
  if (picked == null || !context.mounted) return;
  if (!await ensureFileAccess(context, ref) || !context.mounted) return;

  final status = ValueNotifier<(String, double?)>((l.importProgress(0, 0), null));
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProgressDialog(status: status),
    ),
  );
  try {
    final import = NotesImport(ref.read(databaseProvider), ref.read(captureServiceProvider));
    final report = await import.run(source, picked, progress: (done, total) => status.value = (l.importProgress(done, total), total == 0 ? null : done / total));
    final done = [l.importDone(report.added), if (report.repeated > 0) l.importRepeated(report.repeated)].join(', ');
    showNote(messenger, report.filesMissing > 0 ? '$done. ${l.importFilesNotFound(report.filesMissing)}' : done);
  } on NotesImportError {
    showNote(messenger, switch (source) {
      ImportSource.keep => l.importNotKeep,
      ImportSource.bookmarks => l.importNotBookmarks,
      ImportSource.markdown => l.importNotObsidian,
      ImportSource.mymind => l.importNotMymind,
    });
  } finally {
    navigator.pop();
    status.dispose();
  }
}
