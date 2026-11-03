import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'l10n/app_language.dart';
import 'l10n/app_localizations.dart';

/// Навигатор приложения: через него тап по уведомлению открывает вещь.
final appNavigator = GlobalKey<NavigatorState>();

class StowaApp extends StatelessWidget {
  const StowaApp({super.key, this.locale, this.home = const HomeScreen()});

  /// Язык, выбранный в настройках. Пусто — язык устройства.
  final Locale? locale;

  /// Первый экран: главная или окно «Поделиться».
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigator,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => L.of(context).appName,
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: (deviceLocales, _) => AppLanguage.resolve(deviceLocales ?? const []).locale,
      home: home,
    );
  }
}
