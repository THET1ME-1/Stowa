import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../l10n/app_language.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ai_client.dart';
import '../tags/tags_screen.dart';

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

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            Row(
              children: [
                _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(child: Text(l.settingsTitle, style: text.titleLarge!.copyWith(fontSize: 18))),
              ],
            ),
            const SizedBox(height: 18),
            _AiCard(settings: ai, queued: queued, onSortNow: () => ref.read(aiDrainProvider)().ignore()),
            const SizedBox(height: 8),
            _Group(
              children: [
                _Row(icon: 'key', title: l.aiKey, value: ai.hasKey ? l.aiKeySet : l.aiKeyNone, onTap: () => _showKeySheet(context)),
                _Row(icon: 'dns', title: l.aiProvider, value: Uri.tryParse(ai.baseUrl)?.host ?? ai.baseUrl, onTap: () => _showProviderSheet(context, ai.baseUrl)),
                _Row(icon: 'category', title: l.aiSortModel, value: _modelLabel(ai.sortModel), onTap: () => _showModelSheet(context, speech: false)),
                _Row(icon: 'graphic_eq', title: l.aiSpeechModel, value: ai.speechModel == null ? l.aiSpeechOff : _modelLabel(ai.speechModel!), onTap: () => _showModelSheet(context, speech: true)),
              ],
            ),
            _Section(l.settingsOrder),
            _Group(
              children: [_Row(icon: 'label', title: l.settingsTooltip, onTap: () => Navigator.of(context).push(tagsRoute()))],
            ),
            _Section(l.settingsLanguage),
            _Group(
              children: [_Row(icon: 'translate', title: l.settingsLanguage, value: language?.label ?? l.languageSystem, onTap: () => _showLanguageSheet(context, language))],
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

/// «nvidia/nemotron-3.5-super-vl:free» → «nemotron-3.5-super-vl»: поставщик и пометка цены и так видны в списке.
String _modelLabel(String id) => id.split('/').last.replaceFirst(RegExp(r':free$'), '');

/// Состояние разбора: работает, выключен, на паузе или ждёт поставщика.
class _AiCard extends StatelessWidget {
  const _AiCard({required this.settings, required this.queued, required this.onSortNow});

  final AiSettings settings;
  final int queued;
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
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Tokens.graphite, shape: BoxShape.circle),
                child: Icon(symbolIcon('auto_awesome', filled: true), size: 22, color: Tokens.onSurface),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(l.settingsAi, style: text.titleMedium)),
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
            FilledButton.tonalIcon(onPressed: onSortNow, icon: Icon(symbolIcon('play_arrow', filled: true)), label: Text(l.aiSortNow)),
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
      if (failure.kind != AiFailureKind.network && failure.kind != AiFailureKind.server) {
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

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8, left: 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: Tokens.onSurfaceVariant)),
    );
  }
}

/// Строки одной группы сцеплены: крайние скруглены крупно, между ними щель в два пикселя.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < children.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 2),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(index == 0 ? Radii.tile : 6),
                bottom: Radius.circular(index == children.length - 1 ? Radii.tile : 6),
              ),
              child: children[index],
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, this.value, required this.onTap});

  final String icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Tokens.containerHigh,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Icon(symbolIcon(icon), size: 22, color: Tokens.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: text.bodyLarge)),
              if (value != null)
                Flexible(
                  child: Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
                ),
              const SizedBox(width: 4),
              Icon(symbolIcon('chevron_right'), size: 20, color: Tokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        pressedScale: 0.9,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
          child: Icon(symbolIcon(icon), color: Tokens.onSurface),
        ),
      ),
    );
  }
}
