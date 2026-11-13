import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../domain/known_vaults.dart';
import '../../domain/vault_note.dart';
import '../../l10n/app_localizations.dart';
import '../../services/vault/vault_location.dart';
import '../../services/vault/vault_move.dart';
import '../../services/vault/vault_reader.dart';
import '../../services/vault/vault_switch.dart';

/// Дан ли «Доступ ко всем файлам». Нет — лист с объяснением и переход в системные настройки;
/// ответ узнаётся, когда человек вернётся в приложение.
Future<bool> ensureFileAccess(BuildContext context, WidgetRef ref) async {
  final channel = ref.read(vaultChannelProvider);
  if (await channel.hasAllFiles()) return true;
  if (!context.mounted) return false;
  final l = L.of(context);
  final go = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Tokens.container,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.vaultAccessTitle, style: text.titleLarge),
              const SizedBox(height: 10),
              Text(l.vaultAccessHint, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.vaultAccessGrant)),
            ],
          ),
        ),
      );
    },
  );
  if (go != true) {
    if (context.mounted) showNote(ScaffoldMessenger.of(context), l.vaultAccessDenied);
    return false;
  }
  await channel.askAllFiles();
  if (await channel.hasAllFiles()) return true;
  await _untilResumed();
  final granted = await channel.hasAllFiles();
  if (!granted && context.mounted) showNote(ScaffoldMessenger.of(context), l.vaultAccessDenied);
  return granted;
}

// системные настройки открылись поверх приложения: ждём, пока человек вернётся
Future<void> _untilResumed() {
  final back = Completer<void>();
  late final AppLifecycleListener listener;
  listener = AppLifecycleListener(onResume: () {
    if (!back.isCompleted) back.complete();
  });
  return back.future.timeout(const Duration(minutes: 10), onTimeout: () {}).whenComplete(listener.dispose);
}

/// Перенести хранилище в [target], с полоской хода. [openExisting] — в папке уже есть
/// заметки (прежнее хранилище, Obsidian): сперва они собираются в базу.
Future<bool> moveVault(BuildContext context, WidgetRef ref, Directory target, VaultMode mode, {bool openExisting = false}) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final db = ref.read(databaseProvider);
  final settings = ref.read(settingsRepositoryProvider);
  final clock = ref.read(clockProvider);
  final from = ref.read(filesRootProvider);
  // старое внутри приложения можно стереть после переноса, папку человека — нельзя
  final fromInsideApp = settings.vaultPath == null || settings.vaultMode == VaultMode.app;
  final status = ValueNotifier<(String, double?)>((l.vaultMoving(0, 0), null));
  void report(String Function(int done, int total) label, int done, int total) => status.value = (label(done, total), total == 0 ? null : done / total);

  unawaited(showDialog<void>(context: context, barrierDismissible: false, builder: (context) => ProgressDialog(status: status)));
  try {
    if (openExisting) {
      await VaultReader(db, root: target, clock: clock).rebuild(progress: (done, total) => report(l.vaultBuilding, done, total));
    }
    final result = await VaultMove(db, settings: settings, from: from, fromInsideApp: fromInsideApp, clock: clock).moveTo(
      target,
      mode,
      progress: (done, total) => report(l.vaultMoving, done, total),
    );
    if (!result.ok) {
      showNote(messenger, l.vaultMoveFailed(result.missing.length));
      return false;
    }
    ref.read(vaultRootProvider.notifier).change(target);
    return true;
  } finally {
    navigator.pop();
    status.dispose();
  }
}

/// «Создать хранилище»: имя и место, разрешение, перенос.
Future<bool> createVault(BuildContext context, WidgetRef ref) async {
  final place = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Tokens.container,
    builder: (context) => const _CreateSheet(),
  );
  if (place == null || !context.mounted) return false;
  if (!await ensureFileAccess(context, ref) || !context.mounted) return false;
  final target = Directory(place);
  final existing = await target.exists() && await target.list(recursive: true).any((entity) => entity.path.endsWith('.md'));
  if (!context.mounted) return false;
  return moveVault(context, ref, target, VaultMode.device, openExisting: existing);
}

/// «Открыть папку как хранилище»: прежнее хранилище после переустановки или Obsidian.
Future<bool> openVaultFolder(BuildContext context, WidgetRef ref) async {
  final picked = await ref.read(vaultPickerProvider)();
  if (picked == null || !context.mounted) return false;
  if (!await ensureFileAccess(context, ref) || !context.mounted) return false;
  return moveVault(context, ref, Directory(picked), VaultMode.device, openExisting: true);
}

/// «Хранить внутри приложения» — после предупреждения, что при удалении приложения заметки пропадут.
Future<bool> keepInsideApp(BuildContext context, WidgetRef ref) async {
  final l = L.of(context);
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Tokens.containerHigh,
      title: Text(l.vaultInApp),
      content: Text(l.vaultInAppWarning),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.vaultInAppConfirm)),
      ],
    ),
  );
  if (sure != true || !context.mounted) return false;
  final settings = ref.read(settingsRepositoryProvider);
  final inside = Directory(p.join(ref.read(appSupportProvider).path, 'vault'));
  // старая установка: файлы ещё на прежнем месте — переносятся внутрь
  if (settings.vaultPath == null) return moveVault(context, ref, inside, VaultMode.app);
  await settings.setVault(settings.vaultPath!, VaultMode.app);
  return true;
}

/// «Пересобрать указатель»: служебная база поиска заново из папки.
Future<void> rebuildIndex(BuildContext context, WidgetRef ref) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final status = ValueNotifier<(String, double?)>((l.vaultBuilding(0, 0), null));
  unawaited(showDialog<void>(context: context, barrierDismissible: false, builder: (context) => ProgressDialog(status: status)));
  try {
    await ref.read(vaultReaderProvider).rebuild(progress: (done, total) => status.value = (l.vaultBuilding(done, total), total == 0 ? null : done / total));
    showNote(messenger, l.vaultRebuilt);
  } finally {
    navigator.pop();
    status.dispose();
  }
}

/// Папка открытого хранилища: выбранная или, у старой установки, папка файлов.
String _openPath(WidgetRef ref) => ref.read(vaultRootProvider)?.path ?? ref.read(settingsRepositoryProvider).vaultPath ?? ref.read(filesRootProvider).path;

/// Сменить папку открытого хранилища (касание его строки). В выбранной папке уже есть
/// заметки или другое хранилище из списка — человек решает: открыть её отдельно или
/// перенести своё туда и объединить. Пустая папка — обычный перенос.
Future<void> changeVaultFolder(BuildContext context, WidgetRef ref) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final settings = ref.read(settingsRepositoryProvider);
  final picked = await ref.read(vaultPickerProvider)();
  if (picked == null || !context.mounted || sameVaultPath(picked, _openPath(ref))) return;
  if (!await ensureFileAccess(context, ref) || !context.mounted) return;
  final target = Directory(picked);
  final known = settings.vaults.where((one) => one.db != settings.vaultDb && sameVaultPath(one.path, picked)).firstOrNull;
  final hasNotes = await folderHasNotes(target);
  if (!context.mounted) return;
  if (known != null || hasNotes) {
    final choice = await showOptionsSheet<bool>(
      context,
      title: l.vaultHasNotes,
      options: [
        SheetChoice(value: false, title: l.vaultOpenSeparately, subtitle: l.vaultOpenSeparatelyHint, icon: 'folder_open'),
        SheetChoice(value: true, title: l.vaultMergeHere, subtitle: l.vaultMergeHereHint, icon: 'merge'),
      ],
    );
    if (choice == null || !context.mounted) return;
    if (!choice) {
      final entry = known ?? await settings.rememberVault(picked, VaultMode.device);
      if (context.mounted) await switchVault(context, ref, entry);
      return;
    }
    // папка другого хранилища становится общей: в списке её больше нет
    if (known != null) await settings.forgetVault(known.db);
    if (!context.mounted) return;
  }
  if (await moveVault(context, ref, target, VaultMode.device, openExisting: hasNotes)) showNote(messenger, l.vaultMoved);
}

/// «Добавить хранилище»: новое пустое или готовая папка (Stowa, Obsidian) — и сразу открыть его.
Future<void> addVault(BuildContext context, WidgetRef ref) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final create = await showOptionsSheet<bool>(
    context,
    title: l.vaultAdd,
    options: [
      SheetChoice(value: true, title: l.vaultAddNew, subtitle: l.vaultAddNewHint, icon: 'create_new_folder'),
      SheetChoice(value: false, title: l.vaultAddOpen, subtitle: l.vaultAddOpenHint, icon: 'folder_open'),
    ],
  );
  if (create == null || !context.mounted) return;
  final path = create
      ? await showModalBottomSheet<String>(context: context, isScrollControlled: true, backgroundColor: Tokens.container, builder: (context) => const _CreateSheet())
      : await ref.read(vaultPickerProvider)();
  if (path == null || !context.mounted) return;
  if (sameVaultPath(path, _openPath(ref))) {
    showNote(messenger, l.vaultAlreadyOpen);
    return;
  }
  if (!await ensureFileAccess(context, ref) || !context.mounted) return;
  if (create) await Directory(path).create(recursive: true);
  final entry = await ref.read(settingsRepositoryProvider).rememberVault(path, VaultMode.device);
  if (!context.mounted) return;
  await switchVault(context, ref, entry);
}

/// Открыть другое хранилище: своё скрытое запечатать, свои правки дописать в файлы,
/// базу цели открыть (пустую — собрать из папки) и пересобрать приложение на ней.
/// Очередь файлов старого хранилища живёт в его базе и доедет, когда его откроют снова.
Future<void> switchVault(BuildContext context, WidgetRef ref, KnownVault target) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final settings = ref.read(settingsRepositoryProvider);
  if (target.db == settings.vaultDb) return;
  if (!await Directory(target.path).exists()) {
    showNote(messenger, l.vaultFolderGone);
    return;
  }
  if (!context.mounted) return;
  if (target.mode == VaultMode.device && !await ensureFileAccess(context, ref)) return;
  if (!context.mounted) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  final db = ref.read(databaseProvider);
  final status = ValueNotifier<(String, double?)>((l.vaultSwitching(vaultTitle(target.path)), null));
  unawaited(showDialog<void>(context: context, barrierDismissible: false, builder: (context) => ProgressDialog(status: status)));
  final AppDatabase prepared;
  try {
    await ref.read(privacyServiceProvider).close().catchError((_) {});
    await ref.read(vaultWriterProvider).drain().catchError((_) => 0);
    final notes = await db.customSelect('SELECT count(*) AS n FROM items WHERE deleted_at IS NULL').getSingle().then((row) => row.read<int>('n'));
    prepared = await prepareVaultDatabase(
      target,
      open: ref.read(vaultDatabaseProvider),
      clock: ref.read(clockProvider),
      progress: (done, total) => status.value = (l.vaultBuilding(done, total), total == 0 ? null : done / total),
    );
    await settings.openKnownVault(target, notesHere: notes);
    // уведомления старого хранилища: их заметок в новой базе нет
    await ref.read(notificationPortProvider).cancelAll().catchError((_) {});
  } finally {
    navigator.pop();
    status.dispose();
  }
  // дальше приложение строится заново: этот экран и его ref уже не живут
  await ref.read(reopenSessionProvider)(prepared);
}

/// Окно с подписью и полоской, которое не закрыть, пока идёт долгая работа: перенос, сборка, импорт.
class ProgressDialog extends StatelessWidget {
  const ProgressDialog({super.key, required this.status});

  final ValueNotifier<(String, double?)> status;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Tokens.containerHigh,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder(
            valueListenable: status,
            builder: (context, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(value.$1, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: value.$2, minHeight: 6, color: Tokens.accent, backgroundColor: Tokens.graphite),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Имя хранилища и где его создать. Место подсказано «Документами», выбирает человек.
class _CreateSheet extends ConsumerStatefulWidget {
  const _CreateSheet();

  @override
  ConsumerState<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends ConsumerState<_CreateSheet> {
  final _name = TextEditingController(text: 'Stowa');
  String _parent = VaultLocation.suggestedFolder;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.vaultCreate, style: text.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: _name, decoration: InputDecoration(labelText: l.vaultName)),
              const SizedBox(height: 12),
              Material(
                color: Tokens.containerHigh,
                borderRadius: BorderRadius.circular(Radii.tile),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
                    final picked = await ref.read(vaultPickerProvider)();
                    if (picked != null && mounted) setState(() => _parent = picked);
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.vaultPlace, style: text.bodySmall!.copyWith(color: Tokens.muted)),
                        const SizedBox(height: 2),
                        Text(shortVaultPath(_parent), style: text.bodyLarge),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(p.join(_parent, vaultFileName(_name.text))),
                child: Text(l.vaultCreateButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Путь для глаз: без «/storage/emulated/0/».
String shortVaultPath(String path) => path.replaceFirst(RegExp(r'^/storage/emulated/0/?'), '');
