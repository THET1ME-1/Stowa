import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../data/settings_repository.dart' show KeyStore;
import '../../l10n/app_localizations.dart';
import '../../services/billing/subscription.dart';

/// Где на сайте открывается покупка: главная со знаком `?subscribe` сразу показывает её.
final subscribePageUrl = Uri.parse('https://stowa.work/?subscribe');

/// Боковая панель браузера — часть Stowa Sync. Без подписки вместо панели — замок с кнопкой,
/// открывающей покупку во вкладке. Подписку панель узнаёт из снимка, который пишет вкладка
/// сайта (общее хранилище страницы): купил во вкладке — замок снимается сам, без перезагрузки.
/// Работает и в лёгкой панели, где нет ни базы, ни провайдеров приложения.
class PanelGate extends StatefulWidget {
  const PanelGate({super.key, required this.store, required this.open, required this.child});

  /// Снимок подписки (`subscription` в защищённом хранилище страницы).
  final KeyStore store;
  final Future<bool> Function(Uri url) open;
  final Widget child;

  @override
  State<PanelGate> createState() => _PanelGateState();
}

class _PanelGateState extends State<PanelGate> {
  bool? _open;
  Timer? _watch;

  @override
  void initState() {
    super.initState();
    _check();
    // пока замок, раз в 3 секунды заглядываем в снимок: оплату ведёт вкладка сайта
    _watch = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_open != true) _check();
    });
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    var active = false;
    try {
      final text = await widget.store.read();
      if (text != null) active = Subscription.fromJson(jsonDecode(text) as Map<String, Object?>).activeNow;
    } on Object {
      // снимок повреждён — считаем, что подписки нет
    }
    if (mounted && active != _open) setState(() => _open = active);
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    if (open == null) return const SizedBox.shrink();
    if (open) return widget.child;
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.screen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
                      child: Icon(symbolIcon('side_navigation', filled: true), color: Tokens.onSurface, size: 26),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(l.panelSubLocked, style: text.titleLarge!.copyWith(fontWeight: FontWeight.w700, height: 1.25)),
                  const SizedBox(height: 8),
                  Text(l.panelSubLockedHint, style: text.bodyLarge!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('panel-subscribe'),
                    onPressed: () => widget.open(subscribePageUrl),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: Tokens.accent, foregroundColor: Tokens.onAccent),
                    child: Text(l.panelSubOpen),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
