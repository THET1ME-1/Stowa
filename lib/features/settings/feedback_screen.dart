import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import 'settings_blocks.dart';

/// Почта поддержки: на неё уходят обращения и её же показывает строка настроек.
const supportEmail = 'stgroup.dev@gmail.com';

Route<void> feedbackRoute() => settingsPageRoute(const FeedbackScreen());

/// Письмо в поддержку. Пробелы кодируются как %20: «+» почтовые программы показывают плюсом.
Uri feedbackMail({required String subject, required String text, required String? device}) {
  final body = device == null ? text : '$text\n\n—\n$device';
  return Uri.parse('mailto:$supportEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
}

/// Строка о телефоне для письма: версия Stowa, производитель с моделью, система.
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

enum FeedbackKind { bug, idea, question }

String _kindLabel(L l, FeedbackKind kind) => switch (kind) {
  FeedbackKind.bug => l.feedbackKindBug,
  FeedbackKind.idea => l.feedbackKindIdea,
  FeedbackKind.question => l.feedbackKindQuestion,
};

/// «Сообщить о проблеме»: вид обращения, текст и сведения о телефоне собираются в письмо,
/// а отправляет его сам человек из своей почты. Своего сервера для обращений у Stowa нет.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key, this.open});

  /// Открыть письмо; в тестах подменяется, в приложении — почтовая программа телефона.
  final Future<bool> Function(Uri mail)? open;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _text = TextEditingController();
  var _kind = FeedbackKind.bug;
  var _attach = true;
  String? _device;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    final about = _readAbout(ref.read(appSupportProvider));
    PackageInfo.fromPlatform().then((info) => info.version, onError: (_) => '').then((version) {
      if (mounted) setState(() => _device = deviceLine(version.isEmpty ? '?' : version, about));
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = L.of(context);
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final mail = feedbackMail(subject: 'Stowa — ${_kindLabel(l, _kind).toLowerCase()}', text: text, device: _attach ? _device : null);
    final open = widget.open ?? (uri) => launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (await open(mail) || !mounted) return;
    // почтовой программы нет: текст в буфер, адрес на плашке
    showNote(ScaffoldMessenger.of(context), l.feedbackNoMail(supportEmail));
    unawaited(Clipboard.setData(ClipboardData(text: mail.queryParameters['body'] ?? text)));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final ready = _text.text.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.feedbackRow),
            const SizedBox(height: 8),
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
            TextField(
              key: const ValueKey('feedback-text'),
              controller: _text,
              minLines: 6,
              maxLines: 14,
              textCapitalization: TextCapitalization.sentences,
              style: text.bodyLarge,
              decoration: InputDecoration(
                hintText: l.feedbackField,
                filled: true,
                fillColor: Tokens.containerHigh,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.card), borderSide: BorderSide.none),
              ),
            ),
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
              child: Text(l.feedbackSend),
            ),
            SettingsHint(l.feedbackHint),
          ],
        ),
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
