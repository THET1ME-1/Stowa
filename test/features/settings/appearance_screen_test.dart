import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/core/theme/palette.dart';
import 'package:stowa/core/theme/tokens.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/appearance.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  late SettingsRepository settings;

  setUp(() async {
    world = TestWorld();
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
    world.settings = settings;
  });
  tearDown(() {
    Tokens.use(StowaPalette.graphiteDark);
    return world.dispose();
  });

  Future<void> open(WidgetTester tester, {Size size = const Size(400, 880), double textScale = 1, String summary = 'Тёмная · Графит'}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text(summary), findsOneWidget);
    await tester.tap(find.text('Оформление'));
    await tester.pumpAndSettle();
  }

  testWidgets('режим темы: выбор сохраняется и сразу перекрашивает', (tester) async {
    await open(tester);
    expect(find.text('Тёмная'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mode-light')));
    await tester.pumpAndSettle();
    expect(settings.appearance.choice, ThemeChoice.light);
    expect(Tokens.palette.brightness, Brightness.light);
    expect(find.text('Светлая'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mode-byTime')));
    await tester.pumpAndSettle();
    expect(settings.appearance.choice, ThemeChoice.byTime);
    expect(find.text('Тёмная с 20:00 до 7:00'), findsOneWidget);
  });

  testWidgets('цвет и насыщенность; графит снимает цвет', (tester) async {
    await open(tester);
    expect(find.text('Насыщенность'.toUpperCase()), findsNothing);

    await tester.tap(find.byKey(const ValueKey('seed-0')));
    await tester.pumpAndSettle();
    expect(settings.appearance.seed, kThemeSeeds.first.toARGB32());
    expect(Tokens.accent, isNot(StowaPalette.graphiteDark.accent));
    expect(find.text('Коралл'), findsOneWidget);

    await tester.scrollUntilVisible(find.byKey(const ValueKey('intensity-faithful')), 100);
    await tester.tap(find.byKey(const ValueKey('intensity-faithful')));
    await tester.pumpAndSettle();
    expect(settings.appearance.vibrant, isFalse);
    expect(Tokens.accent, kThemeSeeds.first);

    await tester.scrollUntilVisible(find.byKey(const ValueKey('seed-graphite')), -100);
    await tester.tap(find.byKey(const ValueKey('seed-graphite')));
    await tester.pumpAndSettle();
    expect(settings.appearance.seed, isNull);
    expect(Tokens.palette, StowaPalette.graphiteDark);
    expect(find.byKey(const ValueKey('intensity-faithful')), findsNothing);
  });

  testWidgets('чёрный фон есть только в тёмной теме, обоев без Android 12 нет', (tester) async {
    await open(tester);
    expect(find.text('Цвета из обоев'), findsNothing);
    await tester.scrollUntilVisible(find.text('Чёрный фон'), 100);
    await tester.tap(find.text('Чёрный фон'));
    await tester.pumpAndSettle();
    expect(settings.appearance.amoled, isTrue);
    expect(Tokens.background, const Color(0xFF000000));

    await tester.scrollUntilVisible(find.byKey(const ValueKey('mode-light')), -100);
    await tester.tap(find.byKey(const ValueKey('mode-light')));
    await tester.pumpAndSettle();
    expect(find.text('Чёрный фон'), findsNothing);
  });

  testWidgets('цвета из обоев прячут выбор цвета', (tester) async {
    world.wallpaper = (light: ColorScheme.fromSeed(seedColor: Colors.green), dark: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark));
    await open(tester);
    await tester.scrollUntilVisible(find.text('Цвета из обоев'), 100);
    await tester.tap(find.text('Цвета из обоев'));
    await tester.pumpAndSettle();
    expect(settings.appearance.wallpaper, isTrue);
    expect(Tokens.accent, world.wallpaper!.dark.primary);
    expect(find.byKey(const ValueKey('seed-0')), findsNothing);
  });

  for (final light in [false, true]) {
    testWidgets('320 точек и крупный шрифт: всё влезает (${light ? 'светлая' : 'тёмная'})', (tester) async {
      if (light) await settings.setAppearance(const Appearance(choice: ThemeChoice.light, seed: 0xFF92BFFF));
      await open(tester, size: const Size(320, 700), textScale: 1.3, summary: light ? 'Светлая · Синий' : 'Тёмная · Графит');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
