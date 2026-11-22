import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/sync/sync_http.dart';
import '../../services/sync/sync_service.dart';

/// Вход кодом с почты: почта, потом шесть цифр из письма. Пароля нет, регистрация — тот же
/// вход. Работает без хранилища и без подписки: войти можно, чтобы купить или чтобы забрать
/// выданную подписку.
class EmailCodeForm extends ConsumerStatefulWidget {
  const EmailCodeForm({super.key, required this.onSignedIn});

  /// Код принят, аккаунт на устройстве.
  final VoidCallback onSignedIn;

  @override
  ConsumerState<EmailCodeForm> createState() => _EmailCodeFormState();
}

class _EmailCodeFormState extends ConsumerState<EmailCodeForm> {
  final _email = TextEditingController();
  final _emailFocus = FocusNode();
  final _code = TextEditingController();
  late final void Function() _stopAutofill;

  /// Почта, на которую ушёл код; null — шаг ввода почты.
  String? _sentTo;
  bool _busy = false;
  String? _error;
  int _wait = 0;
  Timer? _tick;

  SyncService get _service => ref.read(syncServiceProvider);

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() => _error = null));
    _code.addListener(_onCode);
    _stopAutofill = ref.read(autofillWatchProvider)('email', _autofilled);
  }

  @override
  void dispose() {
    _stopAutofill();
    _tick?.cancel();
    _email.dispose();
    _emailFocus.dispose();
    _code.dispose();
    super.dispose();
  }

  // менеджер паролей подставил почту, когда фокус ушёл в его окошко: Flutter ввод уже закрыл,
  // значение берётся из поля страницы. Пока человек печатает сам, поле не перебивается
  void _autofilled(String value) {
    if (!mounted || _emailFocus.hasFocus || _sentTo != null || value == _email.text) return;
    _email.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
  }

  void _onCode() {
    setState(() => _error = null);
    // шестая цифра — вход сам, без лишнего касания
    if (_code.text.length == 6 && !_busy) _verify();
  }

  void _countdown(int seconds) {
    _tick?.cancel();
    setState(() => _wait = seconds);
    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _wait--);
      if (_wait <= 0) timer.cancel();
    });
  }

  Future<void> _requestCode() async {
    final email = _email.text.trim();
    if (!email.contains('@') || _busy) return;
    final l = L.of(context);
    setState(() => _busy = true);
    final result = await _service.requestCode(email, lang: Localizations.localeOf(context).languageCode == 'ru' ? 'ru' : 'en');
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result) {
        case CodeSent():
          _sentTo = email;
          _code.clear();
          _countdown(60);
        case CodeWait(:final seconds):
          // код уже ушёл недавно: он в почте, ждём ввода
          _sentTo = email;
          _countdown(seconds);
        case CodeFailed():
          _error = l.syncMailFailed;
      }
    });
  }

  Future<void> _verify() async {
    final email = _sentTo;
    final code = _code.text.trim();
    if (email == null || code.length < 6 || _busy) return;
    final l = L.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      final ok = await _service.verify(email, code);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (!ok) _error = l.syncWrongCode;
      });
      if (ok) widget.onSignedIn();
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.syncNoServer;
        });
      }
    }
  }

  void _requestCodeAgain() {
    _email.text = _sentTo ?? _email.text;
    _requestCode();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
      child: _sentTo == null ? _emailStep(l) : _codeStep(l),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboard,
    List<String> autofill = const [],
    bool code = false,
    VoidCallback? onDone,
    FocusNode? focusNode,
  }) {
    final style = Theme.of(context).textTheme.bodyLarge!;
    return TextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboard,
      autofillHints: autofill,
      autocorrect: false,
      textCapitalization: TextCapitalization.none,
      textAlign: code ? TextAlign.center : TextAlign.start,
      maxLength: code ? 6 : null,
      inputFormatters: code ? [FilteringTextInputFormatter.digitsOnly] : null,
      onSubmitted: (_) => onDone?.call(),
      style: code ? style.copyWith(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.w600) : style,
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: Tokens.containerHigh,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.card), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _button({required Key key, required String label, required VoidCallback? onPressed}) => FilledButton(
    key: key,
    onPressed: onPressed,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: Tokens.accent, foregroundColor: Tokens.onAccent),
    child: _busy ? SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Tokens.onAccent)) : Text(label),
  );

  Widget _errorLine() => Padding(
    key: const ValueKey('sync-error'),
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
    child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.error)),
  );

  Widget _emailStep(L l) => Column(
    key: const ValueKey('sync-email-step'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _field(
        key: const ValueKey('sync-email'),
        controller: _email,
        focusNode: _emailFocus,
        hint: l.syncEmail,
        keyboard: TextInputType.emailAddress,
        autofill: const [AutofillHints.email],
        onDone: _requestCode,
      ),
      const SizedBox(height: 16),
      _button(key: const ValueKey('sync-get-code'), label: l.syncGetCode, onPressed: _email.text.contains('@') && !_busy ? _requestCode : null),
      if (_error != null) _errorLine(),
    ],
  );

  Widget _codeStep(L l) {
    final text = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('sync-code-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(l.syncCodeSent(_sentTo!), style: text.bodyLarge),
        ),
        _field(key: const ValueKey('sync-code'), controller: _code, hint: l.syncCode, keyboard: TextInputType.number, autofill: const [AutofillHints.oneTimeCode], code: true, onDone: _verify),
        const SizedBox(height: 16),
        _button(key: const ValueKey('sync-sign-in'), label: l.syncSignIn, onPressed: _code.text.length == 6 && !_busy ? _verify : null),
        if (_error != null) _errorLine(),
        const SizedBox(height: 8),
        // на узком экране и длинном языке кнопки встают одна под другую
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            TextButton(key: const ValueKey('sync-resend'), onPressed: _wait > 0 || _busy ? null : _requestCodeAgain, child: Text(_wait > 0 ? l.syncResendIn(_wait) : l.syncResend)),
            TextButton(
              key: const ValueKey('sync-other-email'),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _sentTo = null;
                      _error = null;
                    }),
              child: Text(l.syncOtherEmail),
            ),
          ],
        ),
      ],
    );
  }
}
