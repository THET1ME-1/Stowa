import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/fs/web_files.dart' show startDownload;
import '../../core/icons/icon_registry.dart';
import '../../core/platform.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart' show VaultMode;
import '../../domain/known_vaults.dart';
import '../../l10n/app_localizations.dart';
import '../../services/backup_service.dart';
import '../../services/zip_stream.dart';
import '../../services/vault/vault_layout.dart' show attachmentFolderNameError, defaultAttachmentFolder, readAttachmentSetting, writeAttachmentSetting;
import '../folder/folder_sheets.dart' show showRenameSheet;
import '../privacy/markdown_export_action.dart';
import '../vault/vault_actions.dart';
import 'settings_blocks.dart';
import 'sync_screen.dart';

Route<void> storageRoute() => settingsPageRoute(const StorageScreen());

/// Хранилище внутри приложения (и старая установка до переноса): своего имени у папки нет.
bool _insideApp(WidgetRef ref) {
  final root = ref.watch(vaultRootProvider);
  return root == null || root.path.startsWith(ref.watch(appSupportProvider).path);
}

/// Имя открытого хранилища: имя его папки, «Внутри приложения» или, на iPhone, «Файлы» → Stowa.
String openVaultTitle(WidgetRef ref, L l) {
  if (ref.watch(vaultHomeProvider) != null) return l.vaultInFiles;
  if (_insideApp(ref)) return l.vaultInsideApp;
  return vaultTitle(ref.watch(vaultRootProvider)!.path);
}

/// «Documents · 128 заметок»: где лежит папка открытого и сколько в нём заметок.
String openVaultSubtitle(WidgetRef ref, L l) {
  final root = ref.watch(vaultRootProvider);
  final count = ref.watch(notesCountProvider).value;
  return [
    if (ref.watch(vaultHomeProvider) == null && !_insideApp(ref) && vaultParent(root!.path).isNotEmpty) vaultParent(root.path),
    if (count != null) l.itemsCount(count),
  ].join(' · ');
}

/// Сколько прежних хранилищ видно сразу; остальные — строкой «Все хранилища».
const _shownOthers = 3;

/// «Хранилище»: Stowa Sync, открытое и прежние хранилища для быстрой смены, копии.
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    // на iPhone папка одна: ни смены, ни других хранилищ
    final fixed = ref.watch(vaultHomeProvider) != null;
    final list = ref.watch(vaultsProvider).value;
    final others = [
      if (!fixed && list != null)
        for (final one in list.all)
          if (one.db != list.current) one,
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.vaultSection),
            const SizedBox(height: 18),
            SettingsGroup(tint: settingsTint('sky'), children: const [_SyncRow()]),
            SettingsSection(l.vaultsSection),
            SettingsGroup(
              tint: settingsTint('teal'),
              children: [
                _VaultRow(
                  key: const ValueKey('vault-current'),
                  icon: fixed ? 'folder' : (_insideApp(ref) ? 'smartphone' : 'folder_open'),
                  title: openVaultTitle(ref, l),
                  subtitle: openVaultSubtitle(ref, l),
                  current: true,
                  onTap: fixed ? null : () => changeVaultFolder(context, ref),
                ),
                for (final one in others.take(_shownOthers)) _OtherVault(vault: one),
                if (others.length > _shownOthers)
                  SettingsRow(icon: 'folder_copy', title: l.vaultAllCount(others.length), onTap: () => _pickFromAll(context, ref, others)),
                if (!fixed) SettingsRow(icon: 'add', title: l.vaultAdd, onTap: () => addVault(context, ref)),
              ],
            ),
            SettingsHint(fixed ? l.vaultFilesHint : l.vaultsHint),
            SettingsSection(l.attachmentsSection),
            SettingsGroup(tint: settingsTint('amber'), children: const [_AttachmentsRow(key: ValueKey('storage-attachments'))]),
            SettingsHint(l.attachmentsHint),
            SettingsSection(l.settingsCopies),
            SettingsGroup(
              tint: settingsTint('blue'),
              children: [
                SettingsRow(icon: 'backup', title: l.backupSave, onTap: () => saveBackup(context, ref)),
                SettingsRow(icon: 'file_export', title: l.markdownExport, onTap: () => exportMarkdownFlow(context, ref)),
                SettingsRow(icon: 'settings_backup_restore', title: l.backupRestore, onTap: () => _restoreBackup(context, ref)),
                SettingsRow(icon: 'manage_search', title: l.vaultRebuild, onTap: () => rebuildIndex(context, ref)),
              ],
            ),
            SettingsHint(l.backupSaveHint),
          ],
        ),
      ),
    );
  }
}

/// Все прежние хранилища листом, когда их больше трёх.
Future<void> _pickFromAll(BuildContext context, WidgetRef ref, List<KnownVault> others) async {
  final l = L.of(context);
  final picked = await showOptionsSheet<KnownVault>(
    context,
    title: l.vaultsSection,
    options: [
      for (final one in others)
        SheetChoice(value: one, title: knownVaultTitle(l, one), subtitle: _otherSubtitle(l, one), icon: one.mode == VaultMode.app ? 'smartphone' : 'folder'),
    ],
  );
  if (picked != null && context.mounted) await switchVault(context, ref, picked);
}

String _otherSubtitle(L l, KnownVault vault) => [
  if (vault.mode != VaultMode.app && vaultParent(vault.path).isNotEmpty) vaultParent(vault.path),
  if (vault.notes case final notes?) l.itemsCount(notes),
].join(' · ');

/// Прежнее хранилище: касание открывает, «⋮» — открыть или убрать из списка.
/// Папки нет на месте — подпись «Папка не найдена».
/// Куда класть новые вложения, как в Obsidian: общая папка, рядом с заметкой, подпапка рядом,
/// корень. С Obsidian — та же настройка, что у него (`app.json`).
enum _AttachPlace { shared, near, sub, root }

class _AttachmentsRow extends ConsumerStatefulWidget {
  const _AttachmentsRow({super.key});

  @override
  ConsumerState<_AttachmentsRow> createState() => _AttachmentsRowState();
}

class _AttachmentsRowState extends ConsumerState<_AttachmentsRow> {
  ({_AttachPlace place, String name, bool obsidian}) _read() {
    final setting = readAttachmentSetting(ref.read(filesRootProvider));
    final value = setting.setting;
    if (value == null) return (place: setting.obsidian ? _AttachPlace.root : _AttachPlace.near, name: '', obsidian: setting.obsidian);
    if (value == '/') return (place: _AttachPlace.root, name: '', obsidian: setting.obsidian);
    if (value == '.' || value == './') return (place: _AttachPlace.near, name: '', obsidian: setting.obsidian);
    if (value.startsWith('./')) return (place: _AttachPlace.sub, name: value.substring(2), obsidian: setting.obsidian);
    return (place: _AttachPlace.shared, name: value, obsidian: setting.obsidian);
  }

  String _title(L l, _AttachPlace place) => switch (place) {
    _AttachPlace.shared => l.attachmentsShared,
    _AttachPlace.near => l.attachmentsNear,
    _AttachPlace.sub => l.attachmentsSub,
    _AttachPlace.root => l.attachmentsRoot,
  };

  Future<void> _pick() async {
    final l = L.of(context);
    final now = _read();
    final place = await showOptionsSheet<_AttachPlace>(
      context,
      title: l.attachmentsSection,
      selected: now.place,
      options: [
        SheetChoice(value: _AttachPlace.shared, title: l.attachmentsShared, icon: 'perm_media', subtitle: now.place == _AttachPlace.shared ? now.name : null),
        SheetChoice(value: _AttachPlace.near, title: l.attachmentsNear, icon: 'description'),
        SheetChoice(value: _AttachPlace.sub, title: l.attachmentsSub, icon: 'subdirectory_arrow_right', subtitle: now.place == _AttachPlace.sub ? now.name : null),
        SheetChoice(value: _AttachPlace.root, title: l.attachmentsRoot, icon: 'home_storage'),
      ],
    );
    if (place == null || !mounted) return;
    String value;
    switch (place) {
      case _AttachPlace.near:
        value = './';
      case _AttachPlace.root:
        value = '/';
      case _AttachPlace.shared || _AttachPlace.sub:
        final language = ref.read(settingsRepositoryProvider).language?.code ?? Localizations.localeOf(context).languageCode;
        final initial = now.place == place && now.name.isNotEmpty ? now.name : defaultAttachmentFolder(language);
        final name = await showRenameSheet(context, initial, label: l.attachmentsNameLabel);
        if (name == null || !mounted) return;
        if (attachmentFolderNameError(name) != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.attachmentsNameBad)));
          return;
        }
        final clean = name.trim().replaceAll(RegExp(r'/+$'), '');
        value = place == _AttachPlace.sub ? './$clean' : clean;
    }
    final saved = writeAttachmentSetting(ref.read(filesRootProvider), value);
    if (!mounted) return;
    if (!saved) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.attachmentsObsidianBroken)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final now = _read();
    final where = [_title(l, now.place), if (now.name.isNotEmpty) now.name].join(' · ');
    return SettingsRow(
      icon: 'attach_file',
      title: l.attachmentsSection,
      value: now.obsidian ? '$where\n${l.attachmentsWithObsidian}' : where,
      onTap: _pick,
    );
  }
}

class _OtherVault extends ConsumerStatefulWidget {
  const _OtherVault({required this.vault});

  final KnownVault vault;

  @override
  ConsumerState<_OtherVault> createState() => _OtherVaultState();
}

class _OtherVaultState extends ConsumerState<_OtherVault> {
  // папку проверяем один раз на показ строки: карту памяти вынули — видно сразу
  late final Future<bool> _here = Directory(widget.vault.path).exists();

  Future<void> _more() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(settingsRepositoryProvider);
    final forget = await showOptionsSheet<bool>(
      context,
      title: knownVaultTitle(l, widget.vault),
      options: [
        SheetChoice(value: false, title: l.vaultOpenIt, icon: 'folder_open'),
        SheetChoice(value: true, title: l.vaultForget, subtitle: l.vaultForgetHint, icon: 'playlist_remove', danger: true),
      ],
    );
    if (forget == null || !mounted) return;
    if (!forget) return switchVault(context, ref, widget.vault);
    final db = widget.vault.db;
    await settings.forgetVault(db);
    showUndo(messenger, message: l.vaultForgotten, label: l.undo, onUndo: () => settings.restoreVault(db));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final vault = widget.vault;
    return FutureBuilder(
      future: _here,
      builder: (context, here) {
        final gone = here.data == false;
        return _VaultRow(
          key: ValueKey('vault-${vault.db}'),
          icon: gone ? 'folder_off' : (vault.mode == VaultMode.app ? 'smartphone' : 'folder'),
          title: knownVaultTitle(l, vault),
          subtitle: gone ? l.vaultFolderGone : _otherSubtitle(l, vault),
          gone: gone,
          onTap: gone ? () => showNote(ScaffoldMessenger.of(context), l.vaultFolderGone) : () => switchVault(context, ref, vault),
          onMore: _more,
        );
      },
    );
  }
}

/// Строка хранилища: круглый значок, имя крупно, где лежит и сколько заметок. Справа у
/// открытого белая пилюля «Открыто», у прежних — «⋮».
class _VaultRow extends StatelessWidget {
  const _VaultRow({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap, this.current = false, this.gone = false, this.onMore});

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool current;
  final bool gone;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: Tokens.containerHigh,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, onMore == null ? 16 : 4, 12),
          child: Row(
            children: [
              SettingsIconChip(icon),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // на узком экране с крупным шрифтом пилюля «Открыто» оставляет имени мало места
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: gone ? Tokens.error : Tokens.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(100)),
                  child: Text(l.vaultOpenNow, style: text.labelMedium!.copyWith(color: Tokens.onAccent, fontWeight: FontWeight.w700)),
                ),
              if (onMore != null) IconButton(tooltip: l.itemMore, onPressed: onMore, icon: Icon(symbolIcon('more_vert'), color: Tokens.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stowa Sync: платная синхронизация. Под названием — почта аккаунта или «Выключена».
class _SyncRow extends ConsumerWidget {
  const _SyncRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final sync = ref.watch(syncServiceProvider);
    // аккаунт читается из защищённого хранилища: почта появится в строке, как прочтётся
    sync.account().ignore();
    return Material(
      color: Tokens.containerHigh,
      child: InkWell(
        key: const ValueKey('storage-sync'),
        onTap: () => Navigator.of(context).push(syncRoute()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              const SettingsIconChip('cloud_sync'),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(l.syncTitle, style: text.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                        const _PaidPill(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    ValueListenableBuilder(
                      valueListenable: sync.status,
                      builder: (context, status, _) => Text(status.email ?? l.syncOff, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(symbolIcon('chevron_right'), size: 22, color: Tokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Пилюля «Платно» цветом группы: видно, что это подписка, а не ещё одна настройка.
class _PaidPill extends StatelessWidget {
  const _PaidPill();

  @override
  Widget build(BuildContext context) {
    final tint = settingsTint('sky');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: FolderPalette.tint(tint, 0.22), borderRadius: BorderRadius.circular(100)),
      child: Text(
        L.of(context).syncPaid,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: FolderPalette.ink(tint), fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Копия собирается во временную папку и уходит через «Поделиться»: в Диск, Telegram, на компьютер.
/// В браузере — скачивается файлом. Сохранённую копию запоминают настройки: от неё
/// считается напоминание «сохраните копию».
Future<void> saveBackup(BuildContext context, WidgetRef ref) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final box = context.findRenderObject() as RenderBox?;
  try {
    // в копию идёт скрытое запечатанным: строк скрытых заметок в снимке базы быть не должно
    await ref.read(privacyServiceProvider).close();
    if (isWeb) {
      // в браузере копия — файлы хранилища без снимка базы: уходит браузеру кусками и скачивается файлом
      final download = startDownload();
      await ref.read(backupServiceProvider).exportFiles(ZipStreamWriter(download.add));
      final now = ref.read(clockProvider)();
      download.save('Stowa-${now.toIso8601String().substring(0, 10)}.zip');
      await ref.read(settingsRepositoryProvider).copySaved(now);
      return;
    }
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
  final chosen = picked.firstOrNull;
  if (chosen == null || !context.mounted) return;
  // в браузере у выбранного файла нет пути на диске: архив читается в память
  final bytes = isWeb ? await chosen.readAsBytes() : null;
  final path = chosen.path;
  if ((bytes == null && path == null) || !context.mounted) return;
  final zip = File(path ?? '');
  final BackupInfo info;
  try {
    info = bytes != null ? BackupService.inspectBytes(bytes) : await BackupService.inspect(zip);
  } on BackupError {
    showNote(messenger, l.backupNotStowa);
    return;
  }
  if (!context.mounted) return;
  final merges = bytes != null || !info.hasDatabase;
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
            // копия со снимком базы заменяет всё; без него (из браузера и в браузере) её файлы
            // добавляются к нынешним, и стирать тут нечего
            Text(merges ? l.backupMergeAsk(date) : l.backupRestoreAsk(info.items, date), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            FilledButton(
              style: merges ? null : FilledButton.styleFrom(backgroundColor: Tokens.error, foregroundColor: Tokens.onError),
              onPressed: () => Navigator.pop(context, true),
              child: Text(merges ? l.backupAdd : l.backupReplace),
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
    final service = ref.read(backupServiceProvider);
    final restored = bytes != null ? await service.restoreBytes(bytes) : await service.restore(zip);
    // копия без снимка базы (из браузера) положила в хранилище только файлы: указатель собирается из них
    if (!restored.hasDatabase && context.mounted) await rebuildIndex(context, ref);
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
