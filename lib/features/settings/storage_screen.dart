import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/backup_service.dart';
import '../privacy/markdown_export_action.dart';
import '../vault/vault_actions.dart';
import 'settings_blocks.dart';

Route<void> storageRoute() => settingsPageRoute(const StorageScreen());

/// Где хранилище: папка человека или внутри приложения (и старая установка до переноса).
/// На iPhone место одно — папка приложения в «Файлах».
String vaultPlace(WidgetRef ref, L l) {
  if (ref.watch(vaultHomeProvider) != null) return l.vaultInFiles;
  final root = ref.watch(vaultRootProvider);
  if (root == null || root.path.startsWith(ref.watch(appSupportProvider).path)) return l.vaultInsideApp;
  return shortVaultPath(root.path);
}

/// «Хранилище»: где лежат заметки, перенос, указатель и резервные копии.
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    // на iPhone папка одна: переносить некуда
    final fixed = ref.watch(vaultHomeProvider) != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.vaultSection),
            const SizedBox(height: 18),
            SettingsGroup(
              tint: settingsTint('teal'),
              children: [
                SettingsRow(icon: 'folder_open', title: l.vaultFolder, value: vaultPlace(ref, l), onTap: fixed ? null : () => moveVaultElsewhere(context, ref)),
                if (!fixed) SettingsRow(icon: 'drive_file_move', title: l.vaultMoveTo, onTap: () => moveVaultElsewhere(context, ref)),
                SettingsRow(icon: 'manage_search', title: l.vaultRebuild, onTap: () => rebuildIndex(context, ref)),
              ],
            ),
            SettingsHint(fixed ? l.vaultFilesHint : l.vaultSettingHint),
            SettingsGroup(
              tint: settingsTint('blue'),
              children: [
                SettingsRow(icon: 'backup', title: l.backupSave, onTap: () => _saveBackup(context, ref)),
                SettingsRow(icon: 'file_export', title: l.markdownExport, onTap: () => exportMarkdownFlow(context, ref)),
                SettingsRow(icon: 'settings_backup_restore', title: l.backupRestore, onTap: () => _restoreBackup(context, ref)),
              ],
            ),
            SettingsHint(l.backupSaveHint),
          ],
        ),
      ),
    );
  }
}

/// Копия собирается во временную папку и уходит через «Поделиться»: в Диск, Telegram, на компьютер.
Future<void> _saveBackup(BuildContext context, WidgetRef ref) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final box = context.findRenderObject() as RenderBox?;
  try {
    // в копию идёт скрытое запечатанным: строк скрытых заметок в снимке базы быть не должно
    await ref.read(privacyServiceProvider).close();
    final zip = await ref.read(backupServiceProvider).export(await getTemporaryDirectory());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(zip.path, mimeType: 'application/zip')], sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size),
    );
  } catch (_) {
    showNote(messenger, l.backupFailed);
  }
}

/// Выбрать zip, показать, что в нём, и только после согласия заменить всё.
Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['zip']).catchError((_) => <PlatformFile>[]);
  final path = picked.firstOrNull?.path;
  if (path == null || !context.mounted) return;
  final zip = File(path);
  final BackupInfo info;
  try {
    info = await BackupService.inspect(zip);
  } on BackupError {
    showNote(messenger, l.backupNotStowa);
    return;
  }
  if (!context.mounted) return;
  final date = DateFormat.yMMMMd(Localizations.localeOf(context).toLanguageTag()).format(info.createdAt);
  final yes = await showSettingsSheet<bool>(
    context,
    Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 8, Space.screen, Space.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.backupRestoreAsk(info.items, date), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Tokens.error, foregroundColor: Tokens.onError),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.backupReplace),
            ),
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          ],
        ),
      ),
    ),
  );
  if (yes != true) return;
  try {
    await ref.read(privacyServiceProvider).close();
    await ref.read(backupServiceProvider).restore(zip);
    // в копии свой замок: код и скрытое — оттуда
    await ref.read(privacyServiceProvider).loadLock();
    // те же пути к файлам, другие картинки: кэш картинок показал бы прежние
    PaintingBinding.instance.imageCache.clear();
    showNote(messenger, l.backupRestored);
  } on BackupError catch (error) {
    showNote(messenger, error.problem == BackupProblem.tooNew ? l.backupTooNew : l.backupNotStowa);
  } catch (_) {
    showNote(messenger, l.backupFailed);
  }
}
