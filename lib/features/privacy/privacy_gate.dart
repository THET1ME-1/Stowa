import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/privacy/privacy_service.dart' show PrivacyLock;
import 'code_entry.dart';
import 'privacy_flows.dart';

/// Замок поверх всего приложения. При запуске и после ухода из приложения дольше
/// выбранного времени просит код или отпечаток; там же закрывает скрытое. В списке
/// недавних приложений вместо содержимого — заставка.
class PrivacyGate extends ConsumerStatefulWidget {
  const PrivacyGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends ConsumerState<PrivacyGate> with WidgetsBindingObserver {
  // замок прочитан в main до первого кадра: запираем сразу
  late bool _locked = ref.read(startLockProvider)?.appLock ?? false;
  bool _covered = false;
  DateTime? _leftAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // пока замок читается с диска, верен прочитанный в main
  PrivacyLock? get _lock => ref.read(privacyLockProvider).value ?? ref.read(startLockProvider);

  bool get _guarding => (_lock?.appLock ?? false) || ref.read(privacyServiceProvider).isOpen;

  Duration get _delay => _lock?.closeAfter ?? const Duration(minutes: 1);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // своё окно отпечатка уводит приложение в фон: это не уход
    if (ref.read(privacyBusyProvider)) return;
    switch (state) {
      case AppLifecycleState.inactive:
        if (_guarding) setState(() => _covered = true);
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (!_guarding) return;
        setState(() => _covered = true);
        if (_leftAt != null) return;
        _leftAt = DateTime.now();
        _timer?.cancel();
        _timer = Timer(_delay, _expire);
      case AppLifecycleState.resumed:
        _timer?.cancel();
        final left = _leftAt;
        _leftAt = null;
        if (left != null && DateTime.now().difference(left) >= _delay) _expire();
        setState(() => _covered = false);
      case AppLifecycleState.detached:
        break;
    }
  }

  void _expire() {
    _timer?.cancel();
    ref.read(privacyServiceProvider).close().ignore();
    if ((_lock?.appLock ?? false) && mounted) setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    // замок включили в настройках — сейчас не запираем, только при следующем уходе
    ref.listen(privacyLockProvider, (previous, next) {
      if (next.value?.appLock != true && _locked) setState(() => _locked = false);
    });
    return Stack(
      children: [
        widget.child,
        if (_covered) const Positioned.fill(child: _Cover()),
        if (_locked) Positioned.fill(child: _LockScreen(onUnlocked: () => setState(() => _locked = false))),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Tokens.background,
    child: Center(child: Icon(symbolIcon('lock'), size: 40, color: Tokens.muted)),
  );
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen({required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  DateTime? _waitUntil;

  /// «Забыл код» спрашивает здесь же: над навигатором листам снизу не открыться.
  bool _forgetting = false;

  @override
  void initState() {
    super.initState();
    // палец спрашивается сам, как только замок встал
    WidgetsBinding.instance.addPostFrameCallback((_) => _fingerprint(auto: true));
    ref.read(privacyServiceProvider).waitUntil().then((until) {
      if (mounted) setState(() => _waitUntil = until);
    });
  }

  Future<void> _fingerprint({bool auto = false}) async {
    if (!mounted || !(ref.read(fingerprintOnProvider).value ?? await ref.read(privacyServiceProvider).hasFingerprintKey())) return;
    if (!mounted) return;
    if (await askFingerprint(ref, L.of(context).lockReason)) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final fingerprint = ref.watch(fingerprintOnProvider).value ?? false;
    final privacy = ref.read(privacyServiceProvider);
    final text = Theme.of(context).textTheme;
    return Material(
      color: Tokens.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: Space.screen + 8),
            child: _forgetting
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.codeForgetTitle, style: text.titleLarge),
                      const SizedBox(height: 8),
                      Text(l.codeForgetText, style: text.bodyMedium!.copyWith(color: Tokens.muted, height: 1.4)),
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Tokens.error, foregroundColor: Tokens.onError, minimumSize: const Size.fromHeight(52)),
                        onPressed: () async {
                          await privacy.forget();
                          widget.onUnlocked();
                        },
                        child: Text(l.codeForgetAction),
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: () => setState(() => _forgetting = false), child: Text(l.cancel)),
                    ],
                  )
                : CodeEntry(
                    title: l.lockTitle,
                    waitUntil: _waitUntil,
                    onFingerprint: fingerprint ? _fingerprint : null,
                    onSubmit: (code) async {
                      if (await privacy.checkCode(code) != null) {
                        widget.onUnlocked();
                        return null;
                      }
                      final until = await privacy.waitUntil();
                      if (mounted) setState(() => _waitUntil = until);
                      return until == null ? l.codeWrong : l.codeWait(until.difference(DateTime.now()).inSeconds + 1);
                    },
                    footer: TextButton(onPressed: () => setState(() => _forgetting = true), child: Text(l.codeForgot)),
                  ),
          ),
        ),
      ),
    );
  }
}
