import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/palette.dart';
import 'core/theme/tokens.dart';
import 'data/providers.dart';
import 'domain/appearance.dart';
import 'features/vault/vault_gate.dart';
import 'l10n/app_language.dart';
import 'l10n/app_localizations.dart';

/// Навигатор приложения: через него тап по уведомлению открывает вещь.
final appNavigator = GlobalKey<NavigatorState>();

class StowaApp extends ConsumerStatefulWidget {
  const StowaApp({super.key, this.locale, this.home = const VaultGate()});

  /// Язык для тестов и кадров. Пусто — выбранный в настройках, иначе язык устройства.
  final Locale? locale;

  /// Первый экран: главная или окно «Поделиться».
  final Widget home;

  @override
  ConsumerState<StowaApp> createState() => _StowaAppState();
}

class _StowaAppState extends ConsumerState<StowaApp> with WidgetsBindingObserver {
  /// Перекрашивает «по времени» в 7:00 и 20:00.
  Timer? _switch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _switch?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // пока приложение спало, могли смениться обои и наступить вечер
    ref.invalidate(wallpaperProvider);
    setState(() {});
  }

  /// Таймер до ближайшей смены, только когда выбрано «по времени».
  void _planSwitch(Appearance appearance, DateTime now) {
    _switch?.cancel();
    _switch = null;
    if (appearance.choice != ThemeChoice.byTime) return;
    _switch = Timer(nextThemeSwitch(now).difference(now), () {
      if (mounted) setState(() {});
    });
  }

  /// Новая палитра: цвета Tokens читаются в build, поэтому перестраивается
  /// каждый элемент дерева, и константные куски тоже. Состояния живут.
  void _repaint(StowaPalette palette) {
    Tokens.use(palette);
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider).value ?? const Appearance();
    final wallpaper = ref.watch(wallpaperProvider).value;
    final now = ref.watch(clockProvider)();
    final brightness = brightnessFor(appearance, View.of(context).platformDispatcher.platformBrightness, now);
    final palette = paletteFor(appearance, brightness, wallpaper: brightness == Brightness.dark ? wallpaper?.dark : wallpaper?.light);
    if (palette != Tokens.palette) _repaint(palette);
    _planSwitch(appearance, now);

    return MaterialApp(
      navigatorKey: appNavigator,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => L.of(context).appName,
      theme: buildAppTheme(palette),
      // палитра Tokens меняется сразу, тема — тоже, иначе кадры разойдутся
      themeAnimationDuration: Duration.zero,
      locale: widget.locale ?? ref.watch(languageProvider).value?.locale,
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: (deviceLocales, _) => AppLanguage.resolve(deviceLocales ?? const []).locale,
      // значки строки состояния и навигации — светлые на тёмной теме, тёмные на светлой
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: (palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
        child: child!,
      ),
      home: widget.home,
    );
  }
}
