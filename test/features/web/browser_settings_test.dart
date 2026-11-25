import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/app_theme.dart';
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
    world.inBrowser = inBrowser;
    await tester.pumpWidget(
      ProviderScope(
        overrides: world.overrides,
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

  test('сайт наравне с телефоном: в браузере все разделы настроек', () {
    // Stowa Sync — тот же аккаунт, что на телефоне; бот, перенос и уведомления — с 25.11.2026
    for (final id in ['vault', 'sync', 'look', 'ai', 'returns', 'outside', 'order', 'data', 'import', 'line', 'keys', 'start', 'language', 'help']) {
      expect(settingsSectionShown(id, inBrowser: true), isTrue, reason: id);
    }
  });

  testWidgets('«Данные» в браузере: место и отчёты об ошибках есть, подсказки про браузер', (tester) async {
    await show(tester, const SettingsScreen(section: 'data'), inBrowser: true);
    expect(find.text('Запоминать, где сохранено'), findsOneWidget);
    expect(find.text('Отчёты об ошибках'), findsOneWidget);
    expect(find.text('Разработчик получает ошибку и название браузера, без заметок и имён файлов.'), findsOneWidget);
    expect(find.text('Корзина'), findsOneWidget);
  });

  testWidgets('«Снаружи» в браузере: свой бот Telegram, без «Под рукой»', (tester) async {
    await show(tester, const SettingsScreen(section: 'outside'), inBrowser: true);
    expect(find.text('Свой бот Telegram'), findsOneWidget);
  });

  testWidgets('«Данные» на телефоне: всё как было', (tester) async {
    await show(tester, const SettingsScreen(section: 'data'), inBrowser: false);
    expect(find.text('Запоминать, где сохранено'), findsOneWidget);
    expect(find.text('Отчёты об ошибках'), findsOneWidget);
  });

  testWidgets('«Хранилище» в браузере: со Stowa Sync и без слов про приложение «Файлы»', (tester) async {
    await show(tester, const StorageScreen(), inBrowser: true);
    expect(find.text('Stowa Sync'), findsOneWidget);
    expect(find.text('В этом браузере'), findsOneWidget);
    expect(find.text('Заметки лежат в хранилище этого браузера, на диске их не видно.'), findsOneWidget);
    expect(find.text('Сохранить копию'), findsOneWidget);
  });
}
