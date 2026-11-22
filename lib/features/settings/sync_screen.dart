import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/sync/sync_engine.dart';
import '../../services/sync/sync_progress.dart';
import '../../services/sync/sync_service.dart';
import '../../services/billing/subscription.dart';
import '../account/email_code_form.dart';
import '../subscription/paywall_screen.dart';
import '../subscription/subscribe_card.dart';
import 'own_password_sheet.dart';
import 'settings_blocks.dart';
import 'sync_progress_card.dart';

Route<void> syncRoute() => settingsPageRoute(const SyncScreen());

/// Синхронизация: вход кодом с почты, потом состояние и выход.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  SyncAccount? _account;
  bool _loaded = false;

  SyncService get _service => ref.read(syncServiceProvider);

  /// Блок хода вместо «Синхронизировать сейчас»: проход с работой или начатый касанием.
  /// Пустой проход (открыли экран, вернулись свои же правки) мигал бы кнопкой и блоком.
  bool _showProgress = false;
  bool _asked = false;
  late final ValueNotifier<SyncProgress?> _progress;

  void _onProgress() {
    final progress = _progress.value;
    final show = progress != null && (_showProgress || _asked || _hasWork(progress));
    if (progress == null) _asked = false;
    if (show != _showProgress && mounted) setState(() => _showProgress = show);
  }

  /// Сверка папки обходит всю папку и при пустом проходе: работа видна только с приёма.
  static bool _hasWork(SyncProgress progress) => switch (progress.stage) {
    SyncStage.folder => false,
    SyncStage.receive || SyncStage.send => (progress.total ?? 0) > 0,
    SyncStage.place => true,
  };

  void _syncNow() {
    setState(() {
      _asked = true;
      _showProgress = true;
    });
    ref.read(vaultSyncProvider).run().ignore();
  }

  @override
  void initState() {
    super.initState();
    // в dispose ref уже не читается: ход слушаем через запомненный notifier
    _progress = _service.progress..addListener(_onProgress);
    final progress = _progress.value;
    _showProgress = progress != null && _hasWork(progress);
    _service.account().then((account) {
      if (!mounted) return;
      setState(() {
        _account = account;
        _loaded = true;
      });
      // открыли экран — сразу свежий проход, строка состояния покажет его итог
      if (account != null) {
        ref.read(vaultSyncProvider).run().ignore();
        _readPassword();
      }
    });
  }

  /// Включён ли свой пароль шифрования; null — ещё не знаем (сервер не ответил).
  bool? _passwordOn;

  void _readPassword() => _service.passwordOn().then((on) {
    if (mounted) setState(() => _passwordOn = on);
  }).ignore();

  Future<void> _ownPassword() async {
    final on = _passwordOn;
    if (on == null) return;
    final next = await showOwnPasswordSheet(context, on: on);
    if (next != null && mounted) setState(() => _passwordOn = next);
  }

  @override
  void dispose() {
    _progress.removeListener(_onProgress);
    super.dispose();
  }

  Future<void> _signedIn() async {
    final account = await _service.account();
    if (mounted) setState(() => _account = account);
    _readPassword();
  }

  Future<void> _signOut() async {
    await _service.signOut();
    if (mounted) setState(() => _account = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.syncTitle),
            if (!_loaded)
              const SizedBox.shrink()
            else if (_account != null) ...[
              const SizedBox(height: 18),
              _signedInView(l, _account!),
            ]
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                child: Text(l.syncIntro, style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
              ),
              AccentCard(key: const ValueKey('sync-buy'), title: l.subBuy, hint: l.subBuyHint, onTap: () => Navigator.of(context).push(paywallRoute())),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
                child: Text(l.syncHaveSub, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600)),
              ),
              EmailCodeForm(onSignedIn: _signedIn),
            ],
          ],
        ),
      ),
    );
  }

  Widget _signedInView(L l, SyncAccount account) {
    final noVault = ref.watch(vaultRootProvider) == null;
    final otherVault = !_service.syncsOpenVault(account);
    final tint = settingsTint('sky');
    final calm = MediaQuery.disableAnimationsOf(context);
    final subscription = ref.watch(subscriptionProvider).value ?? Subscription.none;
    return ListenableBuilder(
      listenable: Listenable.merge([_service.status, _service.progress]),
      builder: (context, _) {
        final status = _service.status.value;
        // подписки нет: сервер это сказал при входе или снимок с сервера её не видит
        final locked = status.inactive || subscription.signedIn && !subscription.activeNow;
        // касание успело раньше первого отчёта прохода — сверка папки без цифр
        final running = _showProgress ? _service.progress.value ?? const SyncProgress(SyncStage.folder) : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (locked) ...[
              AccentCard(key: const ValueKey('sync-offer'), title: l.syncOffer, hint: l.syncOfferHint, onTap: () => Navigator.of(context).push(paywallRoute())),
              const SizedBox(height: 16),
            ],
            SettingsGroup(
              tint: tint,
              children: [
                SettingsRow(key: const ValueKey('sync-account'), icon: 'mail', title: account.email, value: locked ? null : _statusLine(l, status, otherVault), onTap: null),
                if (!otherVault && !locked && !noVault)
                  AnimatedSwitcher(
                    duration: calm ? Duration.zero : const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SizeTransition(sizeFactor: animation, alignment: Alignment.topCenter, child: child),
                    ),
                    child: running != null
                        ? SyncProgressCard(key: const ValueKey('sync-progress-card'), progress: running, tint: tint)
                        : SettingsRow(key: const ValueKey('sync-now'), icon: 'sync', title: l.syncNow, value: _lastPass(l, status), onTap: _syncNow),
                  ),
              ],
            ),
            if (noVault) SettingsHint(l.syncNoVault),
            // свой пароль шифрования: ключ к заметкам знает только человек
            if (!locked && _passwordOn != null) ...[
              const SizedBox(height: 16),
              SettingsGroup(
                tint: settingsTint('violet'),
                children: [
                  SettingsRow(
                    key: const ValueKey('sync-own-password'),
                    icon: 'key',
                    title: l.syncOwnPassword,
                    value: _passwordOn! ? l.syncOwnPasswordOn : l.syncOwnPasswordOff,
                    onTap: _ownPassword,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SettingsGroup(
              tint: settingsTint('rose'),
              children: [SettingsRow(key: const ValueKey('sync-sign-out'), icon: 'logout', title: l.syncSignOut, onTap: _signOut)],
            ),
            SettingsHint(l.syncSignOutHint),
          ],
        );
      },
    );
  }

  /// Итог прошлого прохода под «Синхронизировать сейчас»: сколько заметок и файлов пришло и ушло.
  String? _lastPass(L l, SyncStatus status) {
    if (status.lastAt == null || status.error != null) return null;
    if (status.received > 0 && status.sent > 0) return l.syncPassBoth(status.received, status.sent);
    if (status.received > 0) return l.syncPassReceived(status.received);
    if (status.sent > 0) return l.syncPassSent(status.sent);
    return null;
  }

  String? _statusLine(L l, SyncStatus status, bool otherVault) {
    if (otherVault) return l.syncOtherVault;
    if (status.inactive) return l.syncInactive;
    switch (status.error) {
      case SyncError.massDelete:
        return l.syncMassDelete;
      case SyncError.vaultUnreadable:
        return l.syncVaultUnreadable;
      case SyncError.network:
        return l.syncOffline;
      case null:
        final at = status.lastAt;
        return at == null ? null : l.syncLast(DateFormat.Hm(Localizations.localeOf(context).toString()).format(at));
    }
  }
}
