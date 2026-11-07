import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/app.dart';
import 'package:stowa/core/theme/palette.dart';
import 'package:stowa/core/theme/tokens.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/appearance.dart';

import 'helpers/test_app.dart';

/// Кусок экрана, который читает цвета прямо из Tokens и собран константой:
/// именно такие места не перестроились бы от смены темы сами.
class _Swatch extends StatelessWidget {
  const _Swatch();

  @override
  Widget build(BuildContext context) => ColoredBox(key: const ValueKey('swatch'), color: Tokens.containerHigh, child: const SizedBox(width: 40, height: 40));
}

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final field = TextEditingController();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextField(key: const ValueKey('field'), controller: field),
        const _Swatch(),
        Builder(builder: (context) => TextButton(onPressed: () => showModalBottomSheet<void>(context: context, builder: (_) => const _Swatch()), child: const Text('лист'))),
      ],
    ),
  );
}

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

  Future<void> open(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(ProviderScope(overrides: world.overrides, child: const StowaApp(locale: Locale('ru'), home: _Probe())));
    await tester.pumpAndSettle();
  }

  Color swatch(WidgetTester tester) => tester.widget<ColoredBox>(find.byKey(const ValueKey('swatch')).last).color;

  testWidgets('смена темы перекрашивает экран и открытый лист, набранный текст на месте', (tester) async {
    await open(tester);
    expect(swatch(tester), StowaPalette.graphiteDark.containerHigh);
    expect(Theme.of(tester.element(find.byType(TextField))).brightness, Brightness.dark);

    await tester.enterText(find.byKey(const ValueKey('field')), 'черновик');
    await tester.tap(find.text('лист'));
    await tester.pumpAndSettle();

    await settings.setAppearance(const Appearance(choice: ThemeChoice.light));
    await tester.pumpAndSettle();

    expect(swatch(tester), StowaPalette.graphiteLight.containerHigh);
    expect(find.byKey(const ValueKey('swatch')), findsNWidgets(2));
    for (final element in find.byKey(const ValueKey('swatch')).evaluate()) {
      expect((element.widget as ColoredBox).color, StowaPalette.graphiteLight.containerHigh);
    }
    expect(Theme.of(tester.element(find.byType(TextField))).brightness, Brightness.light);
    expect(find.text('черновик'), findsOneWidget);
  });

  testWidgets('«как в системе» идёт за системой', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await settings.setAppearance(const Appearance(choice: ThemeChoice.system));
    await open(tester);
    expect(swatch(tester), StowaPalette.graphiteDark.containerHigh);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(swatch(tester), StowaPalette.graphiteLight.containerHigh);
  });

  testWidgets('цвет красит акцент', (tester) async {
    await settings.setAppearance(Appearance(seed: kThemeSeeds.first.toARGB32(), vibrant: false));
    await open(tester);
    expect(Tokens.accent, kThemeSeeds.first);
  });
}
