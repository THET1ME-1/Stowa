import 'package:flutter/material.dart';

import 'core/theme/tokens.dart';
import 'data/db/database.dart';
import 'services/privacy/privacy_service.dart' show PrivacyLock;
import 'services/vault/vault_location.dart';

/// Открытое хранилище: его база, место файлов и замок. Другое хранилище — новая сессия.
class VaultSession {
  const VaultSession({required this.db, required this.place, required this.lock});

  final AppDatabase db;
  final VaultPlace place;
  final PrivacyLock? lock;
}

/// Открыть сессию: база [prepared] уже открыта (её собирали из папки) или открывается по настройкам.
typedef OpenSession = Future<VaultSession> Function(AppDatabase? prepared);

/// Пересобрать приложение на другом хранилище.
typedef ReopenSession = Future<void> Function(AppDatabase? prepared);

/// Стоит над `ProviderScope`: открыли другое хранилище — приложение строится заново на его
/// базе, а всё, что про процесс (prefs, уведомления, отчёты об ошибках), живёт дальше.
class SessionHost extends StatefulWidget {
  const SessionHost({super.key, required this.first, required this.open, required this.app});

  final VaultSession first;
  final OpenSession open;
  final Widget Function(VaultSession session, ReopenSession reopen) app;

  @override
  State<SessionHost> createState() => _SessionHostState();
}

class _SessionHostState extends State<SessionHost> {
  late VaultSession _session = widget.first;
  bool _switching = false;
  int _generation = 0;

  Future<void> _reopen(AppDatabase? prepared) async {
    final old = _session;
    // кадр без приложения: старое дерево снимается целиком, и ключ навигатора
    // не переезжает в новое вместе с экранами старого хранилища
    setState(() => _switching = true);
    await WidgetsBinding.instance.endOfFrame;
    VaultSession next;
    try {
      next = await widget.open(prepared);
    } catch (_) {
      // не открылось — остаёмся в прежнем
      if (mounted) setState(() => _switching = false);
      rethrow;
    }
    if (!mounted) return;
    setState(() {
      _session = next;
      _switching = false;
      _generation++;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!identical(old.db, next.db)) await old.db.close();
  }

  @override
  Widget build(BuildContext context) {
    if (_switching) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Tokens.background,
          child: Center(child: CircularProgressIndicator(color: Tokens.accent)),
        ),
      );
    }
    return KeyedSubtree(key: ValueKey(_generation), child: widget.app(_session, _reopen));
  }
}
