import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../domain/reminder_parser.dart' show defaultWorkEnd;
import '../composer/panel_text.dart' show untitledFor;
import '../../domain/appearance.dart';
import '../../domain/models.dart' show PlaceKind;
import '../../domain/return_plan.dart';
import '../../l10n/app_language.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ai_client.dart';
import '../../services/backup_service.dart';
import '../../services/telegram_service.dart';
import '../links/dead_links_screen.dart';
import '../places/places_screen.dart';
import '../places/reminder_permissions.dart';
import '../privacy/markdown_export_action.dart';
import '../privacy/privacy_settings.dart';
import '../tags/tags_screen.dart';
import '../vault/vault_actions.dart';
import 'ai_log_screen.dart';
import 'appearance_screen.dart';
import 'settings_blocks.dart';
import 'telegram_import_action.dart';
import 'trash_screen.dart';

Route<void> settingsRoute() => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => const SettingsScreen(),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// Почему не прошёл запрос к поставщику — словами человека.
String aiFailureText(L l, AiFailureKind kind) => switch (kind) {
  AiFailureKind.auth => l.aiCheckAuth,
  AiFailureKind.payment => l.aiCheckPayment,
  AiFailureKind.rateLimit => l.aiCheckRate,
  AiFailureKind.network => l.aiCheckNetwork,
  AiFailureKind.timeout => l.aiCheckTimeout,
  AiFailureKind.server || AiFailureKind.badResponse => l.aiCheckServer,
};

/// Настройки: разбор ИИ по своему ключу, теги и правила, язык.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final ai = ref.watch(aiSettingsProvider).value ?? const AiSettings();
    final queued = ref.watch(aiQueueProvider).value ?? 0;
    final language = ref.watch(languageProvider).value;
    final trashed = ref.watch(trashProvider).value?.length ?? 0;
    final deadLinks = ref.watch(deadLinksProvider).value?.length ?? 0;
    final telegram = ref.watch(telegramStateProvider).value ?? const TelegramState();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.settingsTitle),
            const SizedBox(height: 18),
            SettingsGroup(
              tint: settingsTint('rose'),
              children: [
                SettingsRow(
                  icon: 'palette',
                  title: l.appearanceTitle,
                  value: appearanceSummary(l, ref.watch(appearanceProvider).value ?? const Appearance()),
                  onTap: () => Navigator.of(context).push(appearanceRoute()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _AiCard(settings: ai, queued: queued, busy: ref.watch(aiBusyProvider).value ?? false, onSortNow: () => ref.read(aiDrainProvider)().ignore()),
            const SizedBox(height: 8),
            SettingsGroup(
              tint: settingsTint('violet'),
              children: [
                SettingsRow(icon: 'key', title: l.aiKey, value: ai.hasKey ? l.aiKeySet : l.aiKeyNone, onTap: () => _showKeySheet(context)),
                SettingsRow(icon: 'dns', title: l.aiProvider, value: Uri.tryParse(ai.baseUrl)?.host ?? ai.baseUrl, onTap: () => _showProviderSheet(context, ai.baseUrl)),
                SettingsRow(icon: 'category', title: l.aiSortModel, value: _modelLabel(ai.sortModel), onTap: () => _showModelSheet(context, speech: false)),
                SettingsRow(icon: 'graphic_eq', title: l.aiSpeechModel, value: ai.speechModel == null ? l.aiSpeechOff : _modelLabel(ai.speechModel!), onTap: () => _showModelSheet(context, speech: true)),
                SettingsRow(icon: 'receipt_long', title: l.aiLog, onTap: () => Navigator.of(context).push(aiLogRoute())),
              ],
            ),
            SettingsSection(l.settingsOutside),
            SettingsGroup(
              tint: settingsTint('sky'),
              children: [
                SettingsRow(icon: 'send', title: l.tgTitle, value: telegram.botName == null ? l.tgNone : '@${telegram.botName}', onTap: () => _sheet(context, const _BotSheet())),
              ],
            ),
            SettingsSection(l.settingsOrder),
            SettingsGroup(
              tint: settingsTint('amber'),
              children: [SettingsRow(icon: 'label', title: l.settingsTooltip, onTap: () => Navigator.of(context).push(tagsRoute()))],
            ),
            SettingsSection(l.settingsData),
            SettingsGroup(
              tint: settingsTint('mint'),
              children: [
                SettingsSwitchRow(
                  icon: 'location_on',
                  title: l.placeSetting,
                  // без разрешения место не пишется — переключатель так и показывает
                  value: (ref.watch(placeEnabledProvider).value ?? true) && (ref.watch(placeGrantedProvider).value ?? true),
                  onChanged: (on) async {
                    if (on && ref.read(placeGrantedProvider).value == false) {
                      final granted = await ref.read(askPlaceProvider)();
                      ref.invalidate(placeGrantedProvider);
                      if (!granted) return;
                    }
                    await ref.read(settingsRepositoryProvider).setPlaceEnabled(on);
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(l.placeSettingHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
            ),
            SettingsGroup(
              tint: settingsTint('coral'),
              children: [
                SettingsSwitchRow(
                  icon: 'explicit',
                  title: l.adultSetting,
                  value: ref.watch(showAdultProvider).value ?? false,
                  onChanged: (on) => ref.read(settingsRepositoryProvider).setShowAdult(on),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(l.adultSettingHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
            ),
            SettingsGroup(
              tint: settingsTint('sky'),
              children: [
                SettingsRow(
                  icon: 'calendar_month',
                  title: l.titleDateSetting,
                  value: titleDateLabel(l, ref.watch(titleDateProvider).value ?? TitleDate.shot),
                  onTap: () => _sheet(context, const _TitleDateSheet()),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(l.titleDateHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
            ),
            const PrivacySettings(),
            SettingsSection(l.settingsReturns),
            const _ReturnGroup(),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(l.returnSettingsHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
            ),
            SettingsSection(l.settingsArticles),
            SettingsGroup(
              tint: settingsTint('lemon'),
              children: [
                SettingsSwitchRow(
                  icon: 'image',
                  title: l.articleImages,
                  value: ref.watch(articleImagesProvider).value ?? false,
                  onChanged: (on) => ref.read(settingsRepositoryProvider).setArticleImages(on),
                ),
                SettingsRow(
                  icon: 'link_off',
                  title: l.deadLinksTitle,
                  value: deadLinks > 0 ? l.deadLinksCount(deadLinks) : null,
                  onTap: () => Navigator.of(context).push(deadLinksRoute()),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(l.articleImagesAbout, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
            ),
            SettingsSection(l.vaultSection),
            SettingsGroup(
              tint: settingsTint('teal'),
              children: [
                SettingsRow(icon: 'folder_open', title: l.vaultFolder, value: _vaultPlace(ref, l), onTap: () => moveVaultElsewhere(context, ref)),
                SettingsRow(icon: 'drive_file_move', title: l.vaultMoveTo, onTap: () => moveVaultElsewhere(context, ref)),
                SettingsRow(icon: 'manage_search', title: l.vaultRebuild, onTap: () => rebuildIndex(context, ref)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(l.vaultSettingHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
            ),
            SettingsGroup(
              tint: settingsTint('blue'),
              children: [
                SettingsRow(icon: 'backup', title: l.backupSave, onTap: () => _saveBackup(context, ref)),
                SettingsRow(icon: 'file_export', title: l.markdownExport, onTap: () => exportMarkdownFlow(context, ref)),
                SettingsRow(icon: 'settings_backup_restore', title: l.backupRestore, onTap: () => _restoreBackup(context, ref)),
                SettingsRow(icon: 'delete', title: l.trashTitle, value: trashed > 0 ? '$trashed' : null, onTap: () => Navigator.of(context).push(trashRoute())),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(l.backupSaveHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
            ),
            SettingsSection(l.settingsImport),
            SettingsGroup(
              tint: settingsTint('sky'),
              children: [SettingsRow(icon: 'send', title: l.importTelegram, onTap: () => importTelegram(context, ref))],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(l.importTelegramHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
            ),
            SettingsSection(l.settingsStart),
            SettingsGroup(
              tint: settingsTint('lime'),
              children: [
                SettingsRow(
                  icon: 'start',
                  title: l.startOpen,
                  value: startLabel(l, ref.watch(startScreenChoiceProvider).value ?? StartScreen.home),
                  onTap: () => _sheet(context, const _StartSheet()),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(l.startHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
            ),
            SettingsSection(l.settingsLanguage),
            SettingsGroup(
              tint: settingsTint('orchid'),
              children: [SettingsRow(icon: 'translate', title: l.settingsLanguage, value: language?.label ?? l.languageSystem, onTap: () => _showLanguageSheet(context, language))],
            ),
            const SizedBox(height: 28),
            FutureBuilder(
              future: PackageInfo.fromPlatform().then((info) => info.version, onError: (_) => ''),
              builder: (context, version) => Text(
                version.data?.isNotEmpty == true ? l.settingsVersion(version.data!) : l.appName,
                textAlign: TextAlign.center,
                style: text.bodySmall!.copyWith(color: Tokens.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Где хранилище: папка человека или внутри приложения (и старая установка до переноса).
String _vaultPlace(WidgetRef ref, L l) {
  final root = ref.watch(vaultRootProvider);
  if (root == null || root.path.startsWith(ref.watch(appSupportProvider).path)) return l.vaultInsideApp;
  return shortVaultPath(root.path);
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
  final yes = await _sheet<bool>(
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

/// «nvidia/nemotron-3.5-super-vl:free» → «nemotron-3.5-super-vl»: поставщик и пометка цены и так видны в списке.
String _modelLabel(String id) => id.split('/').last.replaceFirst(RegExp(r':free$'), '');

/// Состояние разбора: работает, выключен, на паузе или ждёт поставщика.
class _AiCard extends StatelessWidget {
  const _AiCard({required this.settings, required this.queued, required this.busy, required this.onSortNow});

  final AiSettings settings;
  final int queued;
  final bool busy;
  final VoidCallback onSortNow;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final retryAt = settings.retryAt;
    final waiting = retryAt != null && retryAt.isAfter(DateTime.now());
    final (state, stateColor, stateText) = switch (settings) {
      AiSettings(paused: true) => (settings.pauseReason == AiFailureKind.payment.name ? l.aiPausedPayment : l.aiPausedAuth, Tokens.error, Tokens.onError),
      AiSettings(hasKey: true) => (l.aiStateOn, Tokens.accent, Tokens.onAccent),
      _ => (l.aiStateOff, Tokens.graphite, Tokens.onSurface),
    };
    final hint = switch (settings) {
      AiSettings(hasKey: false) => l.aiStateOffHint,
      _ when waiting => l.aiStateWait(DateFormat.Hm(Localizations.localeOf(context).toLanguageTag()).format(retryAt)),
      AiSettings(paused: true) => null,
      _ => queued > 0 ? l.aiQueued(queued) : null,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingsIconChip('auto_awesome', color: settingsTint('violet')),
              const SizedBox(width: 16),
              Expanded(child: Text(l.settingsAi, style: text.titleMedium!.copyWith(fontSize: 18, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 14),
          // состояние пилюлей: пауза видна издалека, без чтения мелкого текста
          Container(
            key: const ValueKey('ai-state'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: stateColor, borderRadius: BorderRadius.circular(100)),
            child: Text(state, style: text.labelLarge!.copyWith(color: stateText)),
          ),
          if (hint != null) ...[
            const SizedBox(height: 12),
            Text(hint, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
          ],
          if (settings.active && !waiting && queued > 0) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: busy ? null : onSortNow,
              icon: busy
                  ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Tokens.onSurfaceVariant))
                  : Icon(symbolIcon('play_arrow', filled: true)),
              label: Text(busy ? l.aiSortingNow : l.aiSortNow),
            ),
          ],
        ],
      ),
    );
  }
}

/// Плашка на главной: разбор стоит, пока человек не сменит ключ.
class AiPausedBanner extends StatelessWidget {
  const AiPausedBanner({super.key, required this.settings, required this.onTap});

  final AiSettings settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      child: Container(
        key: const ValueKey('ai-paused'),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(color: Tokens.error.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.tile)),
        child: Row(
          children: [
            Icon(symbolIcon('pause_circle', filled: true), size: 22, color: Tokens.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                settings.pauseReason == AiFailureKind.payment.name ? l.aiPausedPayment : l.aiPausedAuth,
                style: text.bodyMedium!.copyWith(color: Tokens.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            Text(l.aiPausedAction, style: text.labelLarge!.copyWith(color: Tokens.error)),
          ],
        ),
      ),
    );
  }
}

Future<T?> _sheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => Padding(
    // лист поднимается над клавиатурой
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(top: false, child: child),
  ),
);

Future<void> _showKeySheet(BuildContext context) => _sheet(context, const _KeySheet());

/// Ключ: вставить, сохранить и сразу проверить у поставщика.
class _KeySheet extends ConsumerStatefulWidget {
  const _KeySheet();

  @override
  ConsumerState<_KeySheet> createState() => _KeySheetState();
}

class _KeySheetState extends ConsumerState<_KeySheet> {
  final _field = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null) setState(() => _field.text = clip!.text!.trim());
  }

  Future<void> _save() async {
    final key = _field.text.trim();
    if (key.isEmpty) return;
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final settings = ref.read(settingsRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AiClient(http: ref.read(aiHttpProvider), baseUrl: settings.ai.baseUrl, apiKey: key).check();
    } on AiFailure catch (failure) {
      // поставщик молчит — ключ всё равно сохраняется, проверится при разборе
      if (!{AiFailureKind.network, AiFailureKind.timeout, AiFailureKind.server}.contains(failure.kind)) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = aiFailureText(l, failure.kind);
          });
        }
        return;
      }
    }
    await settings.saveKey(key);
    navigator.pop();
    showNote(messenger, l.aiCheckOk);
    ref.read(aiDrainProvider)().ignore();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final hasKey = ref.watch(aiSettingsProvider).value?.hasKey ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.aiKey, style: text.titleMedium),
          const SizedBox(height: 6),
          Text(l.aiKeyWhere, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('ai-key-field'),
            controller: _field,
            autofocus: !hasKey,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: hasKey ? '••••••••' : 'sk-or-…',
              errorText: _error,
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton(onPressed: _paste, child: Text(l.aiKeyPaste)),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text(l.aiKeySave),
          ),
          if (hasKey) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () async {
                await ref.read(settingsRepositoryProvider).saveKey(null);
                if (context.mounted) Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Tokens.error),
              child: Text(l.aiKeyRemove),
            ),
          ],
        ],
      ),
    );
  }
}

/// Свой бот: как завести у BotFather, токен, кого бот слушает.
class _BotSheet extends ConsumerStatefulWidget {
  const _BotSheet();

  @override
  ConsumerState<_BotSheet> createState() => _BotSheetState();
}

class _BotSheetState extends ConsumerState<_BotSheet> {
  final _field = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = _field.text.trim();
    if (token.isEmpty) return;
    final l = L.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(telegramServiceProvider).connect(token);
      _field.clear();
    } on TelegramFailure catch (failure) {
      _error = failure.badToken ? l.tgBadToken : l.tgOffline;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final state = ref.watch(telegramStateProvider).value ?? const TelegramState();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.tgTitle, style: text.titleMedium),
          const SizedBox(height: 12),
          if (state.connected) ...[
            // бот подключён: кто он и кого слушает
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.tile)),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
                    child: Icon(symbolIcon('send', filled: true), size: 20, color: Tokens.onAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@${state.botName}', style: text.bodyLarge),
                        Text(
                          state.ownerName == null ? l.tgWaitingOwner : l.tgOwner(state.ownerName!),
                          style: text.bodySmall!.copyWith(color: Tokens.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => launchUrl(Uri.parse('https://t.me/${state.botName}'), mode: LaunchMode.externalApplication).catchError((_) => false),
              child: Text(l.tgOpenBot),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => ref.read(telegramServiceProvider).disconnect(),
              style: TextButton.styleFrom(foregroundColor: Tokens.error),
              child: Text(l.tgDisconnect),
            ),
          ] else ...[
            Text(l.tgHowTo, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.5)),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('tg-token-field'),
              controller: _field,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(hintText: '123456:ABC…', errorText: _error),
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _connect,
              child: _busy ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text(l.tgConnect),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _showProviderSheet(BuildContext context, String current) => _sheet(context, _ProviderSheet(current: current));

/// Адрес поставщика, совместимого с OpenAI. Пусто — OpenRouter.
class _ProviderSheet extends ConsumerStatefulWidget {
  const _ProviderSheet({required this.current});

  final String current;

  @override
  ConsumerState<_ProviderSheet> createState() => _ProviderSheetState();
}

class _ProviderSheetState extends ConsumerState<_ProviderSheet> {
  late final _field = TextEditingController(text: widget.current == defaultAiBaseUrl ? '' : widget.current);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(settingsRepositoryProvider).setBaseUrl(_field.text);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.aiProvider, style: text.titleMedium),
          const SizedBox(height: 6),
          Text(l.aiProviderHint, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            controller: _field,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(hintText: defaultAiBaseUrl),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}

Future<void> _showModelSheet(BuildContext context, {required bool speech}) => _sheet(context, _ModelSheet(speech: speech));

/// Живой список моделей поставщика с поиском. Своё имя модели тоже можно вписать.
class _ModelSheet extends ConsumerStatefulWidget {
  const _ModelSheet({required this.speech});

  final bool speech;

  @override
  ConsumerState<_ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends ConsumerState<_ModelSheet> {
  late final Future<List<AiModel>?> _models = _load();
  String _query = '';

  Future<List<AiModel>?> _load() async {
    final settings = ref.read(settingsRepositoryProvider);
    final key = await settings.readKey();
    if (key == null) return null;
    return AiClient(http: ref.read(aiHttpProvider), baseUrl: settings.ai.baseUrl, apiKey: key).models();
  }

  Future<void> _pick(String? id) async {
    final settings = ref.read(settingsRepositoryProvider);
    if (widget.speech) {
      await settings.setSpeechModel(id);
    } else if (id != null) {
      await settings.setSortModel(id);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final ai = ref.watch(aiSettingsProvider).value ?? const AiSettings();
    final current = widget.speech ? ai.speechModel : ai.sortModel;
    final query = _query.trim().toLowerCase();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 12),
            child: TextField(
              autocorrect: false,
              decoration: InputDecoration(hintText: l.aiModelsSearch, prefixIcon: Icon(symbolIcon('search'))),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _models,
              builder: (context, snapshot) {
                final models = snapshot.data ?? const <AiModel>[];
                final shown = [
                  for (final model in models)
                    if (query.isEmpty || model.id.toLowerCase().contains(query) || model.name.toLowerCase().contains(query)) model,
                ];
                final note = switch (snapshot) {
                  AsyncSnapshot(connectionState: ConnectionState.waiting) => null,
                  AsyncSnapshot(hasError: true) => l.aiModelsFailed,
                  AsyncSnapshot(data: null) => l.aiModelsNeedKey,
                  _ => null,
                };
                return ListView(
                  padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
                  children: [
                    if (widget.speech) _ModelTile(title: l.aiSpeechOff, selected: current == null, onTap: () => _pick(null)),
                    if (query.isNotEmpty && !models.any((model) => model.id.toLowerCase() == query))
                      _ModelTile(title: l.aiModelOwn(_query.trim()), selected: false, onTap: () => _pick(_query.trim())),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(note, textAlign: TextAlign.center, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
                      ),
                    for (final model in shown)
                      _ModelTile(
                        title: model.name,
                        subtitle: model.id,
                        badges: [if (model.free) l.aiModelFree, if (model.seesImages) l.aiModelVision],
                        selected: model.id == current,
                        onTap: () => _pick(model.id),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.title, this.subtitle, this.badges = const [], required this.selected, required this.onTap});

  final String title;
  final String? subtitle;
  final List<String> badges;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.short,
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          decoration: BoxDecoration(color: selected ? Tokens.accent : Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.tile)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.bodyLarge!.copyWith(color: selected ? Tokens.onAccent : Tokens.onSurface)),
                    if (subtitle != null)
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: selected ? Tokens.onAccentVariant : Tokens.muted)),
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final badge in badges)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: selected ? Tokens.onAccent.withValues(alpha: 0.1) : Tokens.graphite, borderRadius: BorderRadius.circular(100)),
                              child: Text(badge, style: text.labelSmall!.copyWith(color: selected ? Tokens.onAccent : Tokens.onSurfaceVariant)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (selected) Icon(symbolIcon('check'), color: Tokens.onAccent),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showLanguageSheet(BuildContext context, AppLanguage? current) => _sheet(context, _LanguageSheet(current: current));

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet({required this.current});

  final AppLanguage? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    Future<void> pick(AppLanguage? language) async {
      await ref.read(settingsRepositoryProvider).setLanguage(language);
      if (context.mounted) Navigator.pop(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModelTile(title: l.languageSystem, selected: current == null, onTap: () => pick(null)),
          for (final language in AppLanguage.values) _ModelTile(title: language.label, selected: language == current, onTap: () => pick(language)),
        ],
      ),
    );
  }
}

String titleDateLabel(L l, TitleDate date) => switch (date) {
  TitleDate.shot => l.titleDateShot,
  TitleDate.saved => l.titleDateSaved,
};

/// По какому дню подпись фото: выбор сразу переименовывает уже сохранённые подписи.
class _TitleDateSheet extends ConsumerWidget {
  const _TitleDateSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final current = ref.watch(titleDateProvider).value ?? TitleDate.shot;
    Future<void> pick(TitleDate date) async {
      await ref.read(settingsRepositoryProvider).setTitleDate(date);
      String untitled({required String mime, required String fileName, required DateTime at}) => untitledFor(l, mime: mime, fileName: fileName, at: at);
      ref.read(captureServiceProvider).retitleUntitled(untitled, byShot: date == TitleDate.shot).ignore();
      if (context.mounted) Navigator.pop(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final date in TitleDate.values) _ModelTile(title: titleDateLabel(l, date), selected: date == current, onTap: () => pick(date)),
        ],
      ),
    );
  }
}

String startLabel(L l, StartScreen start) => switch (start) {
  StartScreen.home => l.startHome,
  StartScreen.last => l.startLast,
  StartScreen.random => l.startRandom,
};

class _StartSheet extends ConsumerWidget {
  const _StartSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final current = ref.watch(startScreenChoiceProvider).value ?? StartScreen.home;
    Future<void> pick(StartScreen start) async {
      await ref.read(settingsRepositoryProvider).setStartScreen(start);
      if (context.mounted) Navigator.pop(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final start in StartScreen.values) _ModelTile(title: startLabel(l, start), selected: start == current, onTap: () => pick(start)),
        ],
      ),
    );
  }
}

/// «Возвращать»: виды по одному, с какого часа вечером, тихие часы и день сводки.
class _ReturnGroup extends ConsumerWidget {
  const _ReturnGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final returns = ref.watch(returnSettingsProvider).value ?? const ReturnSettings();
    final workEnd = ref.watch(workEndChoiceProvider).value ?? defaultWorkEnd;
    // настройки — в момент правки, не при отрисовке: экран живёт и в тестах без них
    Future<void> save(ReturnSettings value) async {
      await ref.read(settingsRepositoryProvider).setReturns(value);
      // включил вид возврата — придут уведомления: тут и спросить разрешение
      final switchedOn = (value.watchLater && !returns.watchLater) || (value.onThisDay && !returns.onThisDay) || (value.week && !returns.week) || (value.shopping && !returns.shopping);
      if (switchedOn) await askNotifications(ref);
    }
    String clock(int minutes) => DateFormat.Hm(l.localeName).format(DateTime(2026, 1, 1, minutes ~/ 60, minutes % 60));
    // 1 ноября 2026 — воскресенье: день недели 1…7 ложится на 2…8 ноября
    String weekday(int day) => DateFormat.EEEE(l.localeName).format(DateTime(2026, 11, 1 + day));
    Future<int?> pickTime(int minutes, String help) async {
      final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60), helpText: help);
      return picked == null ? null : picked.hour * 60 + picked.minute;
    }

    // «Дом, работа, 2 магазина» — что уже отмечено
    String placesSummary() {
      final places = ref.watch(placesProvider).value ?? const [];
      final shops = places.where((place) => place.kind == PlaceKind.shop).length;
      final parts = [
        if (places.any((place) => place.kind == PlaceKind.home)) l.placesHome,
        if (places.any((place) => place.kind == PlaceKind.work)) l.placesWork,
        if (shops > 0) l.placesShopsCount(shops),
      ];
      return parts.isEmpty ? l.placesNotSet : parts.join(', ');
    }

    Future<void> pickWeekDay() async {
      final day = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: Tokens.container,
        builder: (sheet) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                ListTile(title: Text(weekday(day)), trailing: day == returns.weekDay ? Icon(symbolIcon('check')) : null, onTap: () => Navigator.pop(sheet, day)),
            ],
          ),
        ),
      );
      if (day != null) await save(returns.copyWith(weekDay: day));
    }

    return SettingsGroup(
      tint: settingsTint('tangerine'),
      children: [
        SettingsSwitchRow(icon: 'smart_display', title: l.returnWatchTitle, value: returns.watchLater, onChanged: (on) => save(returns.copyWith(watchLater: on))),
        SettingsSwitchRow(icon: 'history', title: l.returnOnThisDay, value: returns.onThisDay, onChanged: (on) => save(returns.copyWith(onThisDay: on))),
        SettingsSwitchRow(icon: 'calendar_view_week', title: l.returnWeekSetting, value: returns.week, onChanged: (on) => save(returns.copyWith(week: on))),
        SettingsSwitchRow(icon: 'shopping_basket', title: l.returnShoppingSetting, value: returns.shopping, onChanged: (on) => save(returns.copyWith(shopping: on))),
        SettingsRow(
          icon: 'schedule',
          title: l.returnEveningRow,
          value: clock(returns.evening),
          onTap: () async {
            final minutes = await pickTime(returns.evening, l.returnEveningRow);
            if (minutes != null) await save(returns.copyWith(evening: minutes));
          },
        ),
        // «после работы» в строке — в этот час
        SettingsRow(
          icon: 'work_history',
          title: l.workEndRow,
          value: clock(workEnd),
          onTap: () async {
            final minutes = await pickTime(workEnd, l.workEndRow);
            if (minutes != null) await ref.read(settingsRepositoryProvider).setWorkEnd(minutes);
          },
        ),
        SettingsRow(
          icon: 'bedtime',
          title: l.returnQuietRow,
          value: l.returnRange(clock(returns.quietStart), clock(returns.quietEnd)),
          onTap: () async {
            final start = await pickTime(returns.quietStart, l.returnQuietFrom);
            if (start == null || !context.mounted) return;
            final end = await pickTime(returns.quietEnd, l.returnQuietTo);
            if (end != null) await save(returns.copyWith(quietStart: start, quietEnd: end));
          },
        ),
        SettingsRow(icon: 'event_repeat', title: l.returnWeekDayRow, value: weekday(returns.weekDay), onTap: pickWeekDay),
        SettingsRow(icon: 'location_on', title: l.placesTitle, value: placesSummary(), onTap: () => Navigator.of(context).push(placesRoute())),
      ],
    );
  }
}

