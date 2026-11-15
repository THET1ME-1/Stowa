import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import 'settings_blocks.dart';

/// Почта поддержки: её показывает строка «Написать в поддержку».
const supportEmail = 'stgroup.dev@gmail.com';

/// Приём обращений на сервере Togetherly (`pb_hooks/stowa_feedback.pb.js` в его репозитории):
/// запись в базу и письмо в ящик поддержки, оттуда — в Gmail владельца.
final feedbackEndpoint = Uri.parse('https://togetherly.day/api/stowa/feedback');

/// Меньше сервер не примет.
const feedbackMinLength = 10;

Route<void> feedbackRoute() => settingsPageRoute(const FeedbackScreen());

enum FeedbackKind { bug, idea, question }

enum FeedbackResult { sent, tooMany, badEmail, failed }

/// Что уходит на сервер. [device] — пусто, если человек снял «Приложить версию и модель».
class FeedbackDraft {
  const FeedbackDraft({required this.kind, required this.text, required this.email, required this.device, required this.app, required this.platform, required this.lang});

  final FeedbackKind kind;
  final String text;
  final String email;
  final String? device;
  final String app;
  final String platform;
  final String lang;

  Map<String, String> toJson() => {
    'kind': kind.name,
    'text': text,
    'email': email,
    'device': device ?? '',
    'app': app,
    'platform': platform,
    'lang': lang,
  };
}

Future<FeedbackResult> sendFeedback(http.Client client, FeedbackDraft draft) async {
  try {
    final response = await client
        .post(feedbackEndpoint, headers: {'Content-Type': 'application/json'}, body: jsonEncode(draft.toJson()))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) return FeedbackResult.sent;
    if (response.statusCode == 429) return FeedbackResult.tooMany;
    if (response.statusCode == 400 && response.body.contains('bad_email')) return FeedbackResult.badEmail;
    return FeedbackResult.failed;
  } catch (_) {
    // обрыв сети, срок вышел: текст остаётся на экране, человек нажмёт ещё раз
    return FeedbackResult.failed;
  }
}

/// Строка о телефоне: версия Stowa, производитель с моделью, система.
/// Сведения берутся из `about.json`, который Android пишет для отчётов об ошибках.
String deviceLine(String version, Map<String, Object?> about) {
  final phone = [about['maker'], about['model']].whereType<String>().where((part) => part.isNotEmpty).join(' ');
  return ['Stowa $version', phone, about['os']].whereType<String>().where((part) => part.isNotEmpty).join(' · ');
}

Map<String, Object?> _readAbout(Directory appSupport) {
  try {
    return jsonDecode(File(p.join(appSupport.path, 'crashes', 'about.json')).readAsStringSync()) as Map<String, Object?>;
  } catch (_) {
    // на iPhone и до первого запуска Android файла нет: тогда только версия и система
    return {'os': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'.trim()};
  }
}

String _kindLabel(L l, FeedbackKind kind) => switch (kind) {
  FeedbackKind.bug => l.feedbackKindBug,
  FeedbackKind.idea => l.feedbackKindIdea,
  FeedbackKind.question => l.feedbackKindQuestion,
};

/// «Сообщить о проблеме»: вид, текст, почта для ответа и сведения о телефоне уходят
/// на наш сервер прямо из приложения, без почтовой программы.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key, this.send});

  /// Отправка; в тестах подменяется, в приложении — [sendFeedback].
  final Future<FeedbackResult> Function(FeedbackDraft draft)? send;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _text = TextEditingController();
  final _email = TextEditingController();
  var _kind = FeedbackKind.bug;
  var _attach = true;
  var _sending = false;
  String? _sentTo;
  bool _sent = false;
  FeedbackResult? _error;
  String _version = '';
  String? _device;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() => _error = null));
    _email.addListener(() => setState(() => _error = null));
    final about = _readAbout(ref.read(appSupportProvider));
    PackageInfo.fromPlatform().then((info) => info.version, onError: (_) => '').then((version) {
      if (mounted) {
        setState(() {
          _version = version;
          _device = deviceLine(version.isEmpty ? '?' : version, about);
        });
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.length < feedbackMinLength || _sending) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sending = true);
    final email = _email.text.trim();
    final draft = FeedbackDraft(
      kind: _kind,
      text: text,
      email: email,
      device: _attach ? _device : null,
      app: _version,
      platform: Platform.operatingSystem,
      lang: Localizations.localeOf(context).languageCode,
    );
    final result = await (widget.send ?? (draft) => sendFeedback(http.Client(), draft))(draft);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result == FeedbackResult.sent) {
        _sent = true;
        _sentTo = email.isEmpty ? null : email;
        _text.clear();
      } else {
        _error = result;
      }
    });
  }

  String? _errorText(L l) => switch (_error) {
    FeedbackResult.tooMany => l.feedbackTooMany,
    FeedbackResult.badEmail => l.feedbackBadEmail,
    FeedbackResult.failed => l.feedbackFailed,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.feedbackRow),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Motion.medium,
              child: _sent ? _sentView(l) : _form(l),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({required Key key, required TextEditingController controller, required String hint, int minLines = 1, int maxLines = 1, TextInputType? keyboard}) {
    return TextField(
      key: key,
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboard,
      textCapitalization: keyboard == TextInputType.emailAddress ? TextCapitalization.none : TextCapitalization.sentences,
      autocorrect: keyboard != TextInputType.emailAddress,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Tokens.containerHigh,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.card), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _form(L l) {
    final text = Theme.of(context).textTheme;
    final ready = _text.text.trim().length >= feedbackMinLength && !_sending;
    final error = _errorText(l);
    return Column(
      key: const ValueKey('feedback-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (index, kind) in FeedbackKind.values.indexed) ...[
              if (index > 0) const SizedBox(width: 6),
              Expanded(
                child: _KindChoice(
                  key: ValueKey('feedback-kind-${kind.name}'),
                  label: _kindLabel(l, kind),
                  selected: _kind == kind,
                  onTap: () => setState(() => _kind = kind),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _field(key: const ValueKey('feedback-text'), controller: _text, hint: l.feedbackField, minLines: 6, maxLines: 14),
        const SizedBox(height: 8),
        _field(key: const ValueKey('feedback-email'), controller: _email, hint: l.feedbackEmail, keyboard: TextInputType.emailAddress),
        const SizedBox(height: 10),
        SettingsGroup(
          tint: settingsTint('sky'),
          children: [
            SettingsSwitchRow(
              key: const ValueKey('feedback-attach'),
              icon: 'smartphone',
              title: l.feedbackAttach,
              subtitle: _device,
              value: _attach,
              onChanged: (on) => setState(() => _attach = on),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('feedback-send'),
          onPressed: ready ? _send : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: Tokens.accent, foregroundColor: Tokens.onAccent),
          child: _sending ? SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Tokens.onAccent)) : Text(l.feedbackSend),
        ),
        if (error != null)
          Padding(
            key: const ValueKey('feedback-error'),
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(error, style: text.bodyMedium!.copyWith(color: Tokens.error)),
          ),
        SettingsHint(l.feedbackHint),
      ],
    );
  }

  Widget _sentView(L l) {
    final text = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('feedback-sent'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: settingsTint('mint'), shape: BoxShape.circle),
            child: Icon(symbolIcon('check', filled: true), size: 32, color: inkOn(settingsTint('mint'))),
          ),
          const SizedBox(height: 16),
          Text(l.feedbackSentTitle, textAlign: TextAlign.center, style: text.titleLarge),
          const SizedBox(height: 8),
          Text(
            _sentTo == null ? l.feedbackSentQuiet : l.feedbackSentReply(_sentTo!),
            textAlign: TextAlign.center,
            style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            key: const ValueKey('feedback-again'),
            onPressed: () => setState(() => _sent = false),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(l.feedbackAgain),
          ),
        ],
      ),
    );
  }
}

/// Вид обращения — те же кнопки, что выбор края у «Под рукой».
class _KindChoice extends StatelessWidget {
  const _KindChoice({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge!;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.96,
        child: AnimatedContainer(
          duration: Motion.short,
          curve: Motion.emphasized,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? Tokens.accent : Tokens.containerHighest, borderRadius: BorderRadius.circular(selected ? 16 : 100)),
          child: Text(label, style: style.copyWith(color: selected ? Tokens.onAccent : Tokens.onSurfaceVariant)),
        ),
      ),
    );
  }
}
