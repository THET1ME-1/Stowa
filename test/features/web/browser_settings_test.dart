import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/features/settings/settings_blocks.dart';
import 'package:stowa/features/settings/settings_screen.dart';
import 'package:stowa/features/settings/storage_screen.dart';
import 'package:stowa/l10n/app_localizations.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> show(WidgetTester tester, Widget screen, {required bool inBrowser}) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...world.overrides, storedInBrowserProvider.overrideWithValue(inBrowser)],
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('ru'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('в браузере нет разделов, которым там не с чем работать; остальные на месте', () {
    for (final id in ['sync', 'returns', 'outside', 'import']) {
      expect(settingsSectionShown(id, inBrowser: true), isFalse, reason: id);
      expect(settingsSectionShown(id, inBrowser: false), isTrue, reason: id);
    }
    for (final id in ['vault', 'look', 'ai', 'order', 'data', 'line', 'keys', 'start', 'language', 'help']) {
      expect(settingsSectionShown(id, inBrowser: true), isTrue, reason: id);
    }
  });

  testWidgets('«Данные» в браузере: места и отчётов об ошибках нет — там их никто не собирает', (tester) async {
    await show(tester, const SettingsScreen(section: 'data'), inBrowser: true);
    expect(find.text('Запоминать, где сохранено'), findsNothing);
    expect(find.text('Отчёты об ошибках'), findsNothing);
    expect(find.text('Корзина'), findsOneWidget);
  });

  testWidgets('«Данные» на телефоне: всё как было', (tester) async {
    await show(tester, const SettingsScreen(section: 'data'), inBrowser: false);
    expect(find.text('Запоминать, где сохранено'), findsOneWidget);
    expect(find.text('Отчёты об ошибках'), findsOneWidget);
  });

  testWidgets('«Хранилище» в браузере: без Stowa Sync и без слов про приложение «Файлы»', (tester) async {
    await show(tester, const StorageScreen(), inBrowser: true);
    expect(find.text('Stowa Sync'), findsNothing);
    expect(find.text('В этом браузере'), findsOneWidget);
    expect(find.text('Заметки лежат в хранилище этого браузера, на диске их не видно.'), findsOneWidget);
    expect(find.text('Сохранить копию'), findsOneWidget);
  });
}
