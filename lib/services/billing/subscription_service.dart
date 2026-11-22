import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/settings_repository.dart' show KeyStore;
import '../sync/sync_http.dart';
import '../sync/sync_service.dart';
import 'billing_api.dart';
import 'subscription.dart';

/// Подписка аккаунта на устройстве: снимок с сервера, сохранённый у себя. Включает и гасит
/// синхронизацию, когда подписка появилась или кончилась.
class SubscriptionService {
  // ignore: prefer_initializing_formals
  SubscriptionService({required this.sync, required KeyStore store, required this.api}) : _store = store {
    sync.status.addListener(_onSync);
    // аккаунт мог прочитаться раньше, чем завели службу: перемены уже не будет, сверяемся сразу
    if (sync.status.value.email != null) _onSync();
  }

  final SyncService sync;
  final KeyStore _store;
  final BillingApi api;

  final state = ValueNotifier(Subscription.none);
  bool _loaded = false;

  /// Почта, под которой снят снимок: вошли под другой или вышли — снимок меняется.
  String? _email;

  void _onSync() {
    final email = sync.status.value.email;
    if (email == _email) return;
    _email = email;
    unawaited(email == null ? signedOut() : refresh().then((_) {}));
  }

  /// Сохранённый снимок: без сети и до ответа сервера.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final text = await _store.read();
      if (text != null) state.value = Subscription.fromJson(jsonDecode(text) as Map<String, Object?>);
    } on Object {
      // снимок повреждён — до ответа сервера считаем, что подписки нет
    }
  }

  Future<Subscription>? _refreshing;

  /// Спросить сервер. Сеть упала — снимок прежний; вход погашен — снимок пустой.
  Future<Subscription> refresh() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<Subscription> _refresh() async {
    await load();
    final account = await sync.account();
    if (account == null) {
      await _save(Subscription.none);
      return state.value;
    }
    final Subscription fresh;
    try {
      fresh = await api.account(account.token);
    } on SyncHttpError catch (error) {
      if (error.status == 401) {
        // сервер погасил вход: телефон выходит тоже
        await sync.signOut();
        await _save(Subscription.none);
      }
      return state.value;
    } on Object {
      return state.value;
    }
    final was = state.value.activeNow;
    await _save(fresh);
    if (fresh.activeNow && (!was || sync.status.value.inactive)) {
      sync.activate();
    } else if (!fresh.activeNow) {
      sync.deactivate();
    }
    return fresh;
  }

  /// Вышли из аккаунта: снимок стирается.
  Future<void> signedOut() => _save(Subscription.none);

  Future<void> _save(Subscription next) async {
    state.value = next;
    await _store.write(next.signedIn ? jsonEncode(next.toJson()) : null);
  }

  void dispose() {
    sync.status.removeListener(_onSync);
    state.dispose();
  }
}
