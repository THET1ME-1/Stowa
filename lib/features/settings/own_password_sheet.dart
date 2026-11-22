import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import 'settings_blocks.dart';

/// Лист своего пароля шифрования. Отдаёт новое состояние: true — включён, false — выключен,
/// null — закрыли, ничего не меняя.
Future<bool?> showOwnPasswordSheet(BuildContext context, {required bool on}) => showSettingsSheet<bool>(context, _OwnPasswordSheet(on: on));

enum _Step { overview, form, confirmOff }

class _OwnPasswordSheet extends ConsumerStatefulWidget {
  const _OwnPasswordSheet({required this.on});

  final bool on;

  @override
  ConsumerState<_OwnPasswordSheet> createState() => _OwnPasswordSheetState();
}

class _OwnPasswordSheetState extends ConsumerState<_OwnPasswordSheet> {
  late _Step _step = widget.on ? _Step.overview : _Step.form;
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Короче не берём: пароль — единственное, что закрывает заметки от всех.
  static const _minLength = 8;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = L.of(context);
    if (_password.text.length < _minLength) return setState(() => _error = l.syncPasswordShort);
    if (_password.text != _repeat.text) return setState(() => _error = l.syncPasswordMismatch);
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      // Argon2 считается секунду-другую: кнопка крутит ожидание
      final ok = await ref.read(syncServiceProvider).setPassword(_password.text, cost: ref.read(keyLockCostProvider));
      if (!mounted) return;
      if (!ok) return _fail(l.syncNoServer);
      messenger?.showSnackBar(SnackBar(content: Text(l.syncPasswordDone)));
      navigator.pop(true);
    } on Object {
      if (mounted) _fail(l.syncNoServer);
    }
  }

  void _fail(String message) => setState(() {
    _busy = false;
    _error = message;
  });

  Future<void> _turnOff() async {
    final l = L.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      final ok = await ref.read(syncServiceProvider).removePassword();
      if (!mounted) return;
      if (!ok) return _fail(l.syncNoServer);
      messenger?.showSnackBar(SnackBar(content: Text(l.syncPasswordOffDone)));
      navigator.pop(false);
    } on Object {
      if (mounted) _fail(l.syncNoServer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.syncOwnPassword, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...switch (_step) {
            _Step.overview => [
              Text(l.syncOwnPasswordOn, style: muted),
              const SizedBox(height: 20),
              FilledButton.tonal(key: const ValueKey('own-password-change'), onPressed: () => setState(() => _step = _Step.form), child: Text(l.syncPasswordChange)),
              const SizedBox(height: 8),
              TextButton(key: const ValueKey('own-password-off'), onPressed: () => setState(() => _step = _Step.confirmOff), child: Text(l.syncPasswordTurnOff)),
            ],
            _Step.confirmOff => [
              Text(l.syncPasswordOffAsk, style: text.bodyLarge!.copyWith(height: 1.4)),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('own-password-off-yes'),
                onPressed: _busy ? null : _turnOff,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _busy ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4)) : Text(l.syncPasswordTurnOff),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(l.cancel)),
            ],
            _Step.form => [
              if (!widget.on) ...[Text(l.syncOwnPasswordIntro, style: muted), const SizedBox(height: 8)],
              Text(l.syncOwnPasswordWarn, style: text.bodyMedium!.copyWith(color: Tokens.onSurface, height: 1.4, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _field(const ValueKey('own-password'), _password, l.syncPassword, [AutofillHints.newPassword]),
              const SizedBox(height: 10),
              _field(const ValueKey('own-password-repeat'), _repeat, l.syncPasswordRepeat, [AutofillHints.newPassword]),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('own-password-on'),
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: Tokens.accent, foregroundColor: Tokens.onAccent),
                child: _busy
                    ? SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Tokens.onAccent))
                    : Text(widget.on ? l.syncPasswordChange : l.syncPasswordTurnOn),
              ),
            ],
          },
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: text.bodyMedium!.copyWith(color: Tokens.error, height: 1.4)),
            ),
        ],
      ),
    );
  }

  Widget _field(Key key, TextEditingController controller, String hint, List<String> autofill) => TextField(
    key: key,
    controller: controller,
    obscureText: true,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: autofill,
    onChanged: (_) => setState(() => _error = null),
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Tokens.containerHigh,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.card), borderSide: BorderSide.none),
    ),
  );
}
