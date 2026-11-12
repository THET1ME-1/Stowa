import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../composer/panel_text.dart' show untitledFor;
import '../../domain/appearance.dart';
import '../../domain/return_plan.dart';
import '../../l10n/app_language.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ai_client.dart';
import '../../services/telegram_service.dart';
import '../links/dead_links_screen.dart';
import '../privacy/privacy_settings.dart';
import '../tags/tags_screen.dart';
import 'ai_log_screen.dart';
import 'appearance_screen.dart';
import 'returns_screen.dart';
import 'settings_blocks.dart';
import 'storage_screen.dart';
import 'telegram_import_action.dart';
import 'trash_screen.dart';

Route<void> settingsRoute() => settingsPageRoute(const SettingsScreen());

/// Экран «Разбор ИИ». Плашка паузы на главной ведёт прямо сюда, к ключу.
Route<void> aiRoute() => settingsPageRoute(const AiScreen());

/// Почему не прошёл запрос к поставщику — словами человека.
String aiFailureText(L l, AiFailureKind kind) => switch (kind) {
  AiFailureKind.auth => l.aiCheckAuth,
  AiFailureKind.payment => l.aiCheckPayment,
  AiFailureKind.rateLimit => l.aiCheckRate,
  AiFailureKind.network => l.aiCheckNetwork,
  AiFailureKind.timeout => l.aiCheckTimeout,
  AiFailureKind.server || AiFailureKind.badResponse => l.aiCheckServer,
};

/// «Работает · nemotron-3.5-super-vl» — подпись строки «Разбор ИИ» в настройках.
String aiSummary(L l, AiSettings ai) => switch (ai) {
  AiSettings(paused: true) => _pauseText(l, ai),
  AiSettings(hasKey: true) => '${l.aiStateOn} · ${_modelLabel(ai.sortModel)}',
  _ => l.aiStateOff,
};

/// Почему разбор на паузе: кончились деньги или поставщик не принял ключ.
String _pauseText(L l, AiSettings ai) => ai.pauseReason == AiFailureKind.payment.name ? l.aiPausedPayment : l.aiPausedAuth;

/// Настройки. Большие разделы (оформление, разбор ИИ, возврат, хранилище) — одной
/// строкой с итогом и на своём экране, остальное на месте.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final ai = ref.watch(aiSettingsProvider).value ?? const AiSettings();
    final returns = ref.watch(returnSettingsProvider).value ?? const ReturnSettings();
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
            SettingsGroup(
              tint: settingsTint('violet'),
              children: [SettingsRow(icon: 'auto_awesome', title: l.settingsAi, value: aiSummary(l, ai), onTap: () => Navigator.of(context).push(aiRoute()))],
            ),
            const SizedBox(height: 8),
            SettingsGroup(
              tint: settingsTint('tangerine'),
              children: [SettingsRow(icon: 'replay', title: l.settingsReturns, value: returnsSummary(l, returns), onTap: () => Navigator.of(context).push(returnsRoute()))],
            ),
            const SizedBox(height: 8),
            SettingsGroup(
              tint: settingsTint('teal'),
              children: [
                SettingsRow(icon: 'inventory_2', title: l.vaultSection, value: vaultPlace(ref, l), onTap: () => Navigator.of(context).push(storageRoute())),
                SettingsRow(icon: 'delete', title: l.trashTitle, value: trashed > 0 ? '$trashed' : null, onTap: () => Navigator.of(context).push(trashRoute())),
              ],
            ),
            SettingsSection(l.settingsOutside),
            SettingsGroup(
              tint: settingsTint('sky'),
              children: [
                SettingsRow(icon: 'send', title: l.tgTitle, value: telegram.botName == null ? l.tgNone : '@${telegram.botName}', onTap: () => showSettingsSheet(context, const _BotSheet())),
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
            SettingsHint(l.placeSettingHint),
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
            SettingsHint(l.adultSettingHint),
            SettingsGroup(
              tint: settingsTint('sky'),
              children: [
                SettingsRow(
                  icon: 'calendar_month',
                  title: l.titleDateSetting,
                  value: titleDateLabel(l, ref.watch(titleDateProvider).value ?? TitleDate.shot),
                  onTap: () => showSettingsSheet(context, const _TitleDateSheet()),
                ),
              ],
            ),
            SettingsHint(l.titleDateHint),
            SettingsGroup(
              tint: settingsTint('amber'),
              children: [
                SettingsSwitchRow(
                  icon: 'bug_report',
                  title: l.crashSetting,
                  value: ref.watch(crashReportsProvider).value ?? true,
                  onChanged: (on) => ref.read(settingsRepositoryProvider).setCrashReports(on),
                ),
              ],
            ),
            SettingsHint(l.crashSettingHint),
            const PrivacySettings(),
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
            SettingsHint(l.articleImagesAbout),
            SettingsSection(l.settingsImport),
            SettingsGroup(
              tint: settingsTint('sky'),
              children: [SettingsRow(icon: 'send', title: l.importTelegram, onTap: () => importTelegram(context, ref))],
            ),
            SettingsHint(l.importTelegramHint),
            SettingsSection(l.settingsStart),
            SettingsGroup(
              tint: settingsTint('lime'),
              children: [
                SettingsRow(
                  icon: 'start',
                  title: l.startOpen,
                  value: startLabel(l, ref.watch(startScreenChoiceProvider).value ?? StartScreen.home),
                  onTap: () => showSettingsSheet(context, const _StartSheet()),
                ),
              ],
            ),
            SettingsHint(l.startHint),
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
                style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Tokens.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «nvidia/nemotron-3.5-super-vl:free» → «nemotron-3.5-super-vl»: поставщик и пометка цены и так видны в списке.
String _modelLabel(String id) => id.split('/').last.replaceFirst(RegExp(r':free$'), '');

/// «Разбор ИИ»: состояние, свой ключ, поставщик, модели, порядок с алгоритмом и журнал.
class AiScreen extends ConsumerWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final ai = ref.watch(aiSettingsProvider).value ?? const AiSettings();
    final queued = ref.watch(aiQueueProvider).value ?? 0;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.settingsAi),
            const SizedBox(height: 18),
            _AiCard(settings: ai, queued: queued, busy: ref.watch(aiBusyProvider).value ?? false, onSortNow: () => ref.read(aiDrainProvider)().ignore()),
            const SizedBox(height: 8),
            SettingsGroup(
              tint: settingsTint('violet'),
              children: [
                SettingsRow(icon: 'key', title: l.aiKey, value: ai.hasKey ? l.aiKeySet : l.aiKeyNone, onTap: () => showSettingsSheet(context, const _KeySheet())),
                SettingsRow(icon: 'dns', title: l.aiProvider, value: Uri.tryParse(ai.baseUrl)?.host ?? ai.baseUrl, onTap: () => showSettingsSheet(context, _ProviderSheet(current: ai.baseUrl))),
                SettingsRow(icon: 'category', title: l.aiSortModel, value: _modelLabel(ai.sortModel), onTap: () => showSettingsSheet(context, const _ModelSheet(speech: false))),
                SettingsSwitchRow(
                  icon: 'auto_awesome',
                  title: l.aiFirst,
                  subtitle: l.aiFirstHint,
                  value: ai.aiFirst,
                  onChanged: (on) => ref.read(settingsRepositoryProvider).setAiFirst(on),
                ),
                SettingsRow(
                  icon: 'graphic_eq',
                  title: l.aiSpeechModel,
                  value: ai.speechModel == null ? l.aiSpeechOff : _modelLabel(ai.speechModel!),
                  onTap: () => showSettingsSheet(context, const _ModelSheet(speech: true)),
                ),
                SettingsRow(icon: 'receipt_long', title: l.aiLog, onTap: () => Navigator.of(context).push(aiLogRoute())),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
      AiSettings(paused: true) => (_pauseText(l, settings), Tokens.error, Tokens.onError),
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
              child: Text(_pauseText(l, settings), style: text.bodyMedium!.copyWith(color: Tokens.onSurface)),
            ),
            const SizedBox(width: 8),
            Text(l.aiPausedAction, style: text.labelLarge!.copyWith(color: Tokens.error)),
          ],
        ),
      ),
    );
  }
}

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

Future<void> _showLanguageSheet(BuildContext context, AppLanguage? current) => showSettingsSheet(context, _LanguageSheet(current: current));

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


