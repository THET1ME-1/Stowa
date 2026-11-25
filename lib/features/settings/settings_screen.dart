import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/hint_banner.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/sheet_options.dart';
import '../../domain/ai_providers.dart';
import '../../domain/hints.dart' show Tip;
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../account/account_row.dart';
import '../composer/panel_text.dart' show untitledFor;
import '../subscription/subscribe_card.dart';
import '../../domain/appearance.dart';
import '../../domain/edge_settings.dart';
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
import 'edge_screen.dart';
import 'feedback_screen.dart';
import 'returns_screen.dart';
import 'settings_blocks.dart';
import 'storage_screen.dart';
import 'import_screen.dart';
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
  AiSettings(enabled: false) => l.aiStateOff,
  AiSettings(paused: true) => _pauseText(l, ai),
  AiSettings(hasKey: true) => '${l.aiStateOn} · ${_modelLabel(ai.sortModel)}',
  _ => l.aiStateOff,
};

/// Почему разбор на паузе: кончились деньги или поставщик не принял ключ.
String _pauseText(L l, AiSettings ai) => ai.pauseReason == AiFailureKind.payment.name ? l.aiPausedPayment : l.aiPausedAuth;

/// Настройки. Большие разделы (оформление, разбор ИИ, возврат, хранилище) — одной
/// строкой с итогом и на своём экране, остальное на месте.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.section, this.title});

  /// Только этот раздел (вкладка настроек широкого экрана): `outside`, `data`, `line`,
  /// `start`, `language`, `help`. null — все.
  final String? section;

  /// Заголовок вместо «Настройки».
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // в браузере нет того, что без телефона не работает: уведомлений, бота, переноса, места
    final inBrowser = ref.watch(storedInBrowserProvider);
    bool show(String id) => (section == null || section == id) && settingsSectionShown(id, inBrowser: inBrowser);
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
            SettingsHeader(title ?? l.settingsTitle),
            // под заголовком сразу группа: отступ, как в «Хранилище» и «Возврате»
            if (show('account')) ...[const SizedBox(height: 18), const SubscribeCard(), const AccountRow()],
            if (show('vault')) ...[
            SettingsSection(l.settingsCatalog),
            SettingsGroup(
              tint: settingsTint('teal'),
              children: [
                SettingsRow(
                  key: const ValueKey('settings-catalog'),
                  icon: ref.watch(vaultHomeProvider) == null ? 'folder_open' : 'folder',
                  title: openVaultTitle(ref, l),
                  value: openVaultSubtitle(ref, l),
                  onTap: () => Navigator.of(context).push(storageRoute()),
                ),
              ],
            ),
            ],
            if (show('look')) ...[
            SettingsSection(l.settingsLook),
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
            ],
            if (show('helpers')) ...[
            SettingsSection(l.settingsHelpers),
            SettingsGroup(
              tint: settingsTint('violet'),
              children: [
                SettingsRow(icon: 'auto_awesome', title: l.settingsAi, value: aiSummary(l, ai), onTap: () => Navigator.of(context).push(aiRoute())),
                SettingsRow(icon: 'replay', title: l.settingsReturns, value: returnsSummary(l, returns), onTap: () => Navigator.of(context).push(returnsRoute())),
              ],
            ),
            ],
            if (show('outside')) ...[
            SettingsSection(l.settingsOutside),
            SettingsGroup(
              tint: settingsTint('sky'),
              children: [
                SettingsRow(icon: 'send', title: l.tgTitle, value: telegram.botName == null ? l.tgNone : '@${telegram.botName}', onTap: () => showSettingsSheet(context, const _BotSheet())),
                // заметки у края поверх других приложений — только Android
                if (ref.watch(edgeAvailableProvider))
                  SettingsRow(
                    key: const ValueKey('settings-edge'),
                    icon: 'view_sidebar',
                    title: l.edgeTitle,
                    value: edgeSummary(l, ref.watch(edgeSettingsProvider).value ?? const EdgeSettings()),
                    onTap: () => Navigator.of(context).push(edgeRoute()),
                  ),
              ],
            ),
            ],
            if (show('order')) ...[
            SettingsSection(l.settingsOrder),
            SettingsGroup(
              tint: settingsTint('amber'),
              children: [SettingsRow(icon: 'label', title: l.settingsTooltip, onTap: () => Navigator.of(context).push(tagsRoute()))],
            ),
            ],
            if (show('data')) ...[
            SettingsSection(l.settingsData),
            SettingsGroup(
              tint: settingsTint('teal'),
              children: [SettingsRow(icon: 'delete', title: l.trashTitle, value: trashed > 0 ? '$trashed' : null, onTap: () => Navigator.of(context).push(trashRoute()))],
            ),
            const SizedBox(height: 8),
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
            SettingsHint(inBrowser ? l.placeSettingHintBrowser : l.placeSettingHint),
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
            SettingsHint(inBrowser ? l.crashSettingHintBrowser : l.crashSettingHint),
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
            ],
            if (show('import')) ...[
            SettingsSection(l.settingsImport),
            SettingsGroup(
              tint: settingsTint('sky'),
              children: [
                SettingsRow(
                  key: const ValueKey('settings-import'),
                  icon: 'move_down',
                  title: l.settingsImport,
                  value: l.importSummary,
                  onTap: () => Navigator.of(context).push(importRoute()),
                ),
              ],
            ),
            ],
            if (show('line')) ...[
            SettingsSection(l.settingsLine),
            SettingsGroup(
              tint: settingsTint('teal'),
              children: [
                SettingsRow(
                  key: const ValueKey('settings-enter'),
                  icon: 'keyboard_return',
                  title: l.enterKeyTitle,
                  value: (ref.watch(enterSendsProvider).value ?? false) ? l.enterStow : l.enterNewLine,
                  onTap: () => showSettingsSheet(context, const _EnterSheet()),
                ),
              ],
            ),
            SettingsHint(l.enterHint),
            ],
            if (show('start')) ...[
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
            ],
            if (show('language')) ...[
            SettingsSection(l.settingsLanguage),
            SettingsGroup(
              tint: settingsTint('orchid'),
              children: [SettingsRow(icon: 'translate', title: l.settingsLanguage, value: language?.label ?? l.languageSystem, onTap: () => _showLanguageSheet(context, language))],
            ),
            ],
            if (show('help')) ...[
            SettingsSection(l.settingsHelp),
            SettingsGroup(
              tint: settingsTint('coral'),
              children: [
                SettingsRow(
                  key: const ValueKey('settings-feedback'),
                  icon: 'flag',
                  title: l.feedbackRow,
                  value: l.feedbackRowHint,
                  onTap: () => Navigator.of(context).push(feedbackRoute()),
                ),
                SettingsRow(
                  key: const ValueKey('settings-support'),
                  icon: 'mail',
                  title: l.supportRow,
                  value: supportEmail,
                  onTap: () => launchUrl(Uri.parse('mailto:$supportEmail?subject=Stowa'), mode: LaunchMode.externalApplication).catchError((_) => false),
                ),
                SettingsRow(
                  key: const ValueKey('settings-privacy'),
                  icon: 'policy',
                  title: l.settingsPrivacyPolicy,
                  onTap: () => launchUrl(privacyPolicyUrl(Localizations.localeOf(context)), mode: LaunchMode.externalApplication).catchError((_) => false),
                ),
                SettingsSwitchRow(
                  key: const ValueKey('settings-hints'),
                  icon: 'tips_and_updates',
                  title: l.hintsToggle,
                  value: !(ref.watch(hintsProvider).value?.off ?? false),
                  onChanged: (on) => ref.read(hintsRepositoryProvider).setOff(!on),
                ),
                SettingsRow(
                  key: const ValueKey('settings-hints-restart'),
                  icon: 'replay',
                  title: l.hintsRestart,
                  onTap: () {
                    final hints = ref.read(hintsRepositoryProvider);
                    final before = hints.state;
                    hints.restart().ignore();
                    showUndo(ScaffoldMessenger.of(context), message: l.hintsRestarted, label: l.undo, onUndo: () => hints.restore(before));
                  },
                ),
              ],
            ),
            ],
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

/// Страница политики на GitHub Pages (`site/`): русская для русского языка, иначе английская.
Uri privacyPolicyUrl(Locale locale) =>
    Uri.parse('https://thet1me-1.github.io/Stowa/${locale.languageCode == 'ru' ? 'ru/' : ''}privacy.html');

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
            _AiCard(
              settings: ai,
              queued: queued,
              busy: ref.watch(aiBusyProvider).value ?? false,
              onSortNow: () => ref.read(aiDrainProvider)().ignore(),
              onToggle: (on) async {
                // включить без ключа нечего: сразу к ключу
                if (on && !ai.hasKey) {
                  await showSettingsSheet(context, const _KeySheet());
                  return;
                }
                await ref.read(settingsRepositoryProvider).setAiEnabled(on);
                // включили — очередь, что ждала, идёт сразу
                if (on) ref.read(aiDrainProvider)().ignore();
              },
              onResume: () async {
                await ref.read(settingsRepositoryProvider).resume();
                ref.read(aiDrainProvider)().ignore();
              },
              onChangeKey: () => showSettingsSheet(context, const _KeySheet()),
            ),
            const SizedBox(height: 12),
            // где взять ключ — первый вопрос новичка; с ключом подсказка не нужна
            HintBanner(tip: Tip.aiKey, when: !ai.hasKey, padding: const EdgeInsets.only(bottom: 8)),
            SettingsGroup(
              tint: settingsTint('violet'),
              children: [
                SettingsRow(icon: 'key', title: l.aiKey, value: ai.hasKey ? l.aiKeySet : l.aiKeyNone, onTap: () => showSettingsSheet(context, const _KeySheet())),
                SettingsRow(icon: 'dns', title: l.aiProvider, value: ai.provider?.name ?? Uri.tryParse(ai.baseUrl)?.host ?? ai.baseUrl, onTap: () => _pickProvider(context, ref, ai)),
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
                  value: !ai.canTranscribe ? l.aiSpeechUnavailable : (ai.speechModel == null ? l.aiSpeechOff : _modelLabel(ai.speechModel!)),
                  onTap: ai.canTranscribe ? () => showSettingsSheet(context, const _ModelSheet(speech: true)) : null,
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

/// Поставщик из списка знакомых или свой адрес. Другой поставщик — модели по умолчанию.
Future<void> _pickProvider(BuildContext context, WidgetRef ref, AiSettings ai) async {
  final l = L.of(context);
  const custom = '';
  final current = ai.provider;
  final picked = await showOptionsSheet<String>(
    context,
    title: l.aiProvider,
    selected: current?.id ?? custom,
    options: [
      for (final provider in aiProviders) SheetChoice(value: provider.id, title: provider.name, subtitle: provider.host),
      SheetChoice(value: custom, title: l.aiProviderCustom, icon: 'link', subtitle: current == null ? Uri.tryParse(ai.baseUrl)?.host : l.aiProviderCustomHint),
    ],
  );
  if (picked == null || !context.mounted) return;
  if (picked == custom) {
    await showSettingsSheet(context, _ProviderSheet(current: ai.baseUrl));
    return;
  }
  final provider = aiProviders.firstWhere((one) => one.id == picked);
  if (provider != current) await ref.read(settingsRepositoryProvider).setProvider(provider);
}

/// Выключатель разбора и его состояние: работает, выключен, на паузе или ждёт поставщика.
/// Выключенный разбор ключ не теряет: включил обратно — очередь пошла с того же места.
class _AiCard extends StatelessWidget {
  const _AiCard({
    required this.settings,
    required this.queued,
    required this.busy,
    required this.onSortNow,
    required this.onToggle,
    required this.onResume,
    required this.onChangeKey,
  });

  final AiSettings settings;
  final int queued;
  final bool busy;
  final VoidCallback onSortNow;

  /// Касание выключателя; без ключа включение открывает ввод ключа.
  final ValueChanged<bool> onToggle;

  /// Снять паузу тем же ключом и сменить ключ — две кнопки на плашке паузы.
  final VoidCallback onResume;
  final VoidCallback onChangeKey;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final on = settings.hasKey && settings.enabled;
    final retryAt = settings.retryAt;
    final waiting = settings.active && retryAt != null && retryAt.isAfter(DateTime.now());
    final label = switch (settings) {
      _ when !on => l.aiStateOff,
      AiSettings(paused: true) => l.aiStatePaused,
      _ => l.aiStateOn,
    };
    final payment = settings.pauseReason == AiFailureKind.payment.name;

    // что сейчас с разбором — плашкой, приклеенной к выключателю снизу
    final Widget? state = switch (settings) {
      AiSettings(stalled: true) => _SwitchFooter(
        title: payment ? l.aiPauseReasonPayment : l.aiPauseReasonAuth,
        body: payment ? l.aiPauseAdvicePayment : l.aiPauseAdviceAuth,
        alarm: true,
        // главное действие — по причине: деньги пополняют и повторяют, плохой ключ меняют
        actions: [
          (label: payment ? l.aiPauseRetry : l.aiPauseChangeKey, onPressed: payment ? onResume : onChangeKey, main: true, icon: null),
          (label: payment ? l.aiPauseChangeKey : l.aiPauseRetry, onPressed: payment ? onChangeKey : onResume, main: false, icon: null),
        ],
      ),
      _ when waiting => _SwitchFooter(title: l.aiStateWait(DateFormat.Hm(Localizations.localeOf(context).toLanguageTag()).format(retryAt))),
      AiSettings(active: true) when queued > 0 => _SwitchFooter(
        title: l.aiQueued(queued),
        actions: [
          (
            label: busy ? l.aiSortingNow : l.aiSortNow,
            onPressed: busy ? null : onSortNow,
            main: false,
            icon: busy
                ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Tokens.onSurfaceVariant))
                : Icon(symbolIcon('play_arrow', filled: true)),
          ),
        ],
      ),
      _ => null,
    };
    // выключенному разбору хватает подписи: делать с ним нечего, пока не включишь
    final caption = switch (settings) {
      AiSettings(hasKey: false) => l.aiStateOffHint,
      AiSettings(enabled: false) => l.aiDisabledHint,
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MainSwitch(key: const ValueKey('ai-switch'), on: on, label: label, joined: state != null, onChanged: onToggle),
        if (state != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ClipRRect(
              key: const ValueKey('ai-state'),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(Radii.card)),
              child: state,
            ),
          ),
        // подпись — от края надписи выключателя, а не от края пилюли
        if (caption != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: Text(caption, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
          ),
      ],
    );
  }
}

/// Кнопка плашки: [main] — залитая кнопка приложения, иначе тихая того же размера и формы.
typedef _FooterAction = ({String label, VoidCallback? onPressed, bool main, Widget? icon});

/// Плашка под главным выключателем, его продолжение: текст с того же края, что надпись
/// выключателя, кнопки поровну на всю ширину. [alarm] — сбой, который ждёт человека: заголовок
/// красный. Красной подложки нет: в тёмной теме розовый поверх серого выходит бурым.
class _SwitchFooter extends StatelessWidget {
  const _SwitchFooter({required this.title, this.body, this.alarm = false, this.actions = const []});

  final String title;
  final String? body;
  final bool alarm;
  final List<_FooterAction> actions;

  /// Поле вокруг кнопок: слева — край надписи выключателя, справа и снизу столько же.
  static const _edge = 22.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: Tokens.containerHigh,
      child: Padding(
        padding: EdgeInsets.fromLTRB(_edge, 16, _edge, actions.isEmpty ? 16 : _edge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: text.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: alarm ? Tokens.error : Tokens.onSurface)),
            if (body != null) ...[
              const SizedBox(height: 4),
              Text(body!, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.35)),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) => _buttons(context, constraints.maxWidth)),
            ],
          ],
        ),
      ),
    );
  }

  /// Кнопки делят ширину поровну. Если надпись не влезает в свою долю (узкий экран, крупный
  /// шрифт, длинный перевод), каждая кнопка встаёт на всю ширину, одна под другой.
  Widget _buttons(BuildContext context, double width) {
    final share = (width - _gap * (actions.length - 1)) / actions.length;
    final fits = actions.every((action) => _buttonWidth(context, action) <= share);
    final buttons = [for (final action in actions) _button(action)];
    if (fits) {
      return Row(children: [for (final (index, button) in buttons.indexed) ...[if (index > 0) const SizedBox(width: _gap), Expanded(child: button)]]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final (index, button) in buttons.indexed) ...[if (index > 0) const SizedBox(height: _gap), button]],
    );
  }

  /// Сколько кнопке нужно в ширину: надпись её же шрифтом и размером, значок и поля.
  double _buttonWidth(BuildContext context, _FooterAction action) {
    final style = Theme.of(context).filledButtonTheme.style?.textStyle?.resolve(const {}) ?? Theme.of(context).textTheme.labelLarge;
    final painter = TextPainter(
      text: TextSpan(text: action.label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final label = painter.width;
    painter.dispose();
    return label + (action.icon == null ? 0 : 18 + 8) + _padding * 2;
  }

  Widget _button(_FooterAction action) {
    final style = action.main ? _inlineButton : FilledButton.styleFrom(backgroundColor: Tokens.containerHighest, foregroundColor: Tokens.onSurface).merge(_inlineButton);
    final label = Text(action.label, textAlign: TextAlign.center);
    return action.icon == null
        ? FilledButton(onPressed: action.onPressed, style: style, child: label)
        : FilledButton.icon(onPressed: action.onPressed, style: style, icon: action.icon, label: label);
  }
}

/// Поле внутри кнопки плашки по бокам.
const _padding = 20.0;

/// Кнопки плашки ниже общих (56): в плашке на две строки текста большая кнопка не по росту.
const _inlineButton = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(0, 40)),
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: _padding)),
);

/// Главный выключатель раздела, как «Использовать Wi‑Fi» в настройках Android: пилюля во всю
/// ширину, включённая залита акцентом. Касание по всей пилюле переключает. [joined] — под ним
/// строка состояния: низ скруглён слегка, как у строк внутри группы.
class _MainSwitch extends StatelessWidget {
  const _MainSwitch({super.key, required this.on, required this.label, required this.onChanged, this.joined = false});

  final bool on;
  final String label;
  final ValueChanged<bool> onChanged;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    final fill = on ? Tokens.accent : Tokens.containerHighest;
    final ink = on ? Tokens.onAccent : Tokens.onSurface;
    final radius = joined ? const BorderRadius.vertical(top: Radius.circular(Radii.card), bottom: Radius.circular(8)) : BorderRadius.circular(32);
    return Semantics(
      toggled: on,
      label: label,
      onTap: () => onChanged(!on),
      excludeSemantics: true,
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!on);
        },
        pressedScale: 0.98,
        radius: radius,
        child: AnimatedContainer(
          duration: Motion.short,
          curve: Motion.emphasized,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(22, 8, 12, 8),
          decoration: BoxDecoration(color: fill, borderRadius: radius),
          child: Row(
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: ink))),
              const SizedBox(width: 12),
              // на залитой акцентом пилюле обычный выключатель слился бы с ней: цвета наоборот
              Switch(
                value: on,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  onChanged(value);
                },
                thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Tokens.accent : Tokens.outline),
                trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Tokens.onAccent : Tokens.containerHigh),
              ),
            ],
          ),
        ),
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
        // на узком экране с крупным шрифтом «Проверить ключ» переносится, а не выталкивает край
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Icon(symbolIcon('pause_circle', filled: true), size: 22, color: Tokens.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_pauseText(l, settings), style: text.bodyMedium!.copyWith(color: Tokens.onSurface)),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.4),
                child: Text(l.aiPausedAction, textAlign: TextAlign.end, style: text.labelLarge!.copyWith(color: Tokens.error)),
              ),
            ],
          ),
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
    // ключ идёт к своему хозяину: `sk-ant-` — к Anthropic, даже если выбран OpenRouter
    final target = _target(key, settings.ai);
    final client = AiClient(http: ref.read(aiHttpProvider), baseUrl: target?.baseUrl ?? settings.ai.baseUrl, apiKey: key);
    try {
      await client.check();
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
    if (target != null && target != settings.ai.provider) {
      // модель — из живого списка нового поставщика: имя по умолчанию могло устареть
      String? model;
      try {
        final models = await client.models();
        if (models.isNotEmpty) model = pickSortModel(target, [for (final one in models) (id: one.id, seesImages: one.seesImages)]);
      } on AiFailure {
        // без списка остаётся модель по умолчанию
      }
      await settings.setProvider(target, model: model);
    }
    navigator.pop();
    showNote(messenger, l.aiCheckOk);
    ref.read(aiDrainProvider)().ignore();
  }

  /// Поставщик, узнанный по ключу. Свой адрес не трогаем: человек вписал его сам.
  AiProvider? _target(String key, AiSettings ai) => ai.provider == null ? null : (providerOfKey(key) ?? ai.provider);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final ai = ref.watch(aiSettingsProvider).value ?? const AiSettings();
    final hasKey = ai.hasKey;
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
              hintText: hasKey ? '••••••••' : 'sk-…',
              errorText: _error,
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton(onPressed: _paste, child: Text(l.aiKeyPaste)),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          // к кому уйдёт ключ: видно сразу после вставки, до проверки
          ListenableBuilder(
            listenable: _field,
            builder: (context, _) {
              final name = _target(_field.text.trim(), ai)?.name ?? Uri.tryParse(ai.baseUrl)?.host ?? ai.baseUrl;
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Text(l.aiKeyProvider(name), key: const ValueKey('ai-key-provider'), style: text.bodySmall!.copyWith(color: Tokens.muted)),
              );
            },
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
                // моделей бывают сотни: строки-блоки строятся по мере прокрутки
                final rows = <SheetOption>[
                  if (widget.speech) SheetOption(title: l.aiSpeechOff, icon: 'mic_off', selected: current == null, onTap: () => _pick(null)),
                  if (query.isNotEmpty && !models.any((model) => model.id.toLowerCase() == query))
                    SheetOption(title: l.aiModelOwn(_query.trim()), icon: 'edit', onTap: () => _pick(_query.trim())),
                  for (final model in shown)
                    SheetOption(
                      title: model.name,
                      subtitle: model.id,
                      icon: widget.speech ? 'graphic_eq' : 'smart_toy',
                      badges: [if (model.free) l.aiModelFree, if (model.seesImages) l.aiModelVision],
                      selected: model.id == current,
                      onTap: () => _pick(model.id),
                    ),
                ];
                return CustomScrollView(
                  slivers: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))),
                    if (note != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(Space.screen, 16, Space.screen, 16),
                          child: Text(note, textAlign: TextAlign.center, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      sliver: SliverList.separated(
                        itemCount: rows.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 4),
                        itemBuilder: (context, index) => rows[index].withRadius(sheetRowRadius(index, rows.length)),
                      ),
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

    return SheetOptionsBody(
      title: l.settingsLanguage,
      children: [
        SheetOption(title: l.languageSystem, icon: 'smartphone', selected: current == null, onTap: () => pick(null)),
        for (final language in AppLanguage.values)
          SheetOption(title: language.label, mark: language.code.toUpperCase(), selected: language == current, onTap: () => pick(language)),
      ],
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

    return SheetOptionsBody(
      children: [
        for (final date in TitleDate.values)
          SheetOption(
            title: titleDateLabel(l, date),
            icon: switch (date) {
              TitleDate.shot => 'photo_camera',
              TitleDate.saved => 'save',
            },
            selected: date == current,
            onTap: () => pick(date),
          ),
      ],
    );
  }
}

String startLabel(L l, StartScreen start) => switch (start) {
  StartScreen.home => l.startHome,
  StartScreen.last => l.startLast,
  StartScreen.random => l.startRandom,
};

/// Что делает Enter в строке: новая строка (по умолчанию) или «Закинуть».
class _EnterSheet extends ConsumerWidget {
  const _EnterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final sends = ref.watch(enterSendsProvider).value ?? false;
    Future<void> pick(bool value) async {
      await ref.read(settingsRepositoryProvider).setEnterSends(value);
      if (context.mounted) Navigator.pop(context);
    }

    return SheetOptionsBody(
      title: l.enterKeyTitle,
      children: [
        SheetOption(title: l.enterNewLine, icon: 'keyboard_return', selected: !sends, onTap: () => pick(false)),
        SheetOption(title: l.enterStow, icon: 'arrow_upward', selected: sends, onTap: () => pick(true)),
      ],
    );
  }
}

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

    return SheetOptionsBody(
      title: l.startOpen,
      children: [
        for (final start in StartScreen.values)
          SheetOption(
            title: startLabel(l, start),
            icon: switch (start) {
              StartScreen.home => 'home',
              StartScreen.last => 'history',
              StartScreen.random => 'shuffle',
            },
            selected: start == current,
            onTap: () => pick(start),
          ),
      ],
    );
  }
}


