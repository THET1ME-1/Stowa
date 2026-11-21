import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/panel_bridge.dart';
import '../../services/panel_db.dart';
import '../../services/privacy/hidden_rows.dart';
import '../composer/line_dock.dart';

/// Боковая панель браузера при открытой вкладке Stowa (STOWA-9): строка телефона целиком —
/// «+», `# @ /`, «На весь экран», голос, найденное с действиями, — на базе вкладки
/// (`panel_db.dart`), которую панель только читает, а пишет просьбами вкладке
/// (`panel_writes.dart`). Найденное открывается во вкладке. Вкладка включила «Код на вход» —
/// [onLost]: панель перезагружается и встаёт лёгкой. Закрытие и перезагрузку вкладки ловит
/// замок хранилища в `main.dart`, а не пульс: занятая вкладка отвечает медленно, и
/// перезагрузка по пульсу стирала бы набранное.
class PanelHost extends ConsumerStatefulWidget {
  const PanelHost({super.key, required this.client, required this.onOpenHere, required this.onLost});

  final PanelClient client;

  /// Забрать Stowa в панель: вкладка отдаёт хранилище и перезагружается.
  final Future<void> Function() onOpenHere;
  final VoidCallback onLost;

  @override
  ConsumerState<PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends ConsumerState<PanelHost> {
  final _dock = GlobalKey<LineDockState>();
  late final StreamSubscription<Map<String, Object?>> _follow;
  late final StreamSubscription<Map<String, Object?>> _events;
  bool _lost = false;
  bool _leaving = false;
  String? _note;

  // пока база не ответила, считаем скрытое открытым: строка не покажет лишнего
  bool _hiddenOpen = true;

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseProvider);
    _follow = followPanelDb(db, widget.client.link.messages);
    _events = widget.client.link.messages.listen((message) {
      if (message['type'] == 'locked') _lose();
    });
    hiddenFolderIds(db).then((folders) {
      if (mounted) setState(() => _hiddenOpen = folders.isNotEmpty);
    }).ignore();
  }

  @override
  void dispose() {
    _follow.cancel().ignore();
    _events.cancel().ignore();
    super.dispose();
  }

  void _lose() {
    if (_lost) return;
    _lost = true;
    widget.onLost();
  }

  Future<void> _open(String id) async {
    final l = L.of(context);
    await widget.client.ask('open', payload: {'item': id});
    if (mounted) setState(() => _note = l.panelOpened);
  }

  Future<void> _openHere() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await widget.onOpenHere();
    } catch (_) {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      key: const ValueKey('panel-host'),
      backgroundColor: Tokens.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Stowa', style: text.titleLarge!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w700, fontSize: 20))),
                  TextButton(onPressed: _leaving ? null : _openHere, child: Text(l.tabBusyOpenHere)),
                ],
              ),
            ),
            if (_note case final note?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                child: Text(note, key: const ValueKey('panel-note'), style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant)),
              ),
            Expanded(
              child: Stack(
                children: [
                  // с открытым скрытым строка только закидывает: поиск обошёл бы его ключи во вкладке
                  Positioned.fill(child: LineDock(key: _dock, onOpenItem: _open, writeOnly: _hiddenOpen)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
