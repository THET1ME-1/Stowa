import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_language.dart';
import '../../l10n/app_localizations.dart';

/// Вторая вкладка браузера с тем же хранилищем. Файлы и база в браузере держит одна
/// вкладка: вторая не открывает их, а показывает этот экран и предлагает перенести работу
/// сюда — тогда прежняя вкладка дописывает своё и освобождает хранилище.
///
/// Отдельное приложение: до базы и настроек хранилища эта вкладка ещё не дошла.
class TabBusyApp extends StatelessWidget {
  const TabBusyApp({super.key, required this.onOpenHere, this.locale});

  /// Попросить прежнюю вкладку закрыться; завершается, когда хранилище свободно.
  final Future<void> Function() onOpenHere;
  final Locale? locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Stowa',
    theme: buildAppTheme(Tokens.palette),
    locale: locale,
    supportedLocales: AppLanguage.supportedLocales,
    localizationsDelegates: const [L.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    localeListResolutionCallback: (deviceLocales, _) => AppLanguage.resolve(deviceLocales ?? const []).locale,
    home: _TabBusyScreen(onOpenHere: onOpenHere),
  );
}

class _TabBusyScreen extends StatefulWidget {
  const _TabBusyScreen({required this.onOpenHere});

  final Future<void> Function() onOpenHere;

  @override
  State<_TabBusyScreen> createState() => _TabBusyScreenState();
}

class _TabBusyScreenState extends State<_TabBusyScreen> {
  bool _waiting = false;

  Future<void> _openHere() async {
    if (_waiting) return;
    setState(() => _waiting = true);
    try {
      await widget.onOpenHere();
    } catch (_) {
      // та вкладка не ответила: можно попросить ещё раз
      if (mounted) setState(() => _waiting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Tokens.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.screen, 24, Space.screen, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.tabBusyTitle, style: text.headlineMedium),
                  const SizedBox(height: 12),
                  Text(l.tabBusyHint, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.45)),
                  const SizedBox(height: 28),
                  // кнопка и ожидание сменяют друг друга плавно, место под ними одно
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    switchInCurve: Motion.emphasized,
                    switchOutCurve: Motion.emphasized,
                    layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                    child: _waiting
                        ? SizedBox(
                            key: const ValueKey('waiting'),
                            height: 48,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.onSurfaceVariant)),
                                const SizedBox(width: 12),
                                Flexible(child: Text(l.tabBusyWaiting, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant))),
                              ],
                            ),
                          )
                        : SizedBox(
                            key: const ValueKey('button'),
                            height: 48,
                            child: FilledButton(onPressed: _openHere, child: Text(l.tabBusyOpenHere)),
                          ),
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
