import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/app.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/catalog/catalog_screen.dart';
import 'package:stowa/features/folder/folder_screen.dart';
import 'package:stowa/features/privacy/code_entry.dart';
import 'package:stowa/features/settings/settings_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  late Directory vault;

  setUp(() {
    world = TestWorld();
    vault = Directory(p.join(world.files.path, 'vault'))..createSync();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    // экран телефона: клавиатура кода целиком на виду
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...world.overrides, vaultRootProvider.overrideWith(() => VaultRootNotifier(vault))],
        child: const StowaApp(locale: Locale('ru')),
      ),
    );
    await tester.pumpAndSettle();
  }

  // замок и скрытое пишут файлы: у виджет-теста время поддельное, диску нужно настоящее
  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 80; round++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    // цифры только с клавиатуры кода: на экране под ней тоже бывают «1» и «2»
    final pad = find.byType(CodeEntry).last;
    for (final digit in code.split('')) {
      await tester.tap(find.descendant(of: pad, matching: find.text(digit)));
      await tester.pump();
    }
    await tester.tap(find.descendant(of: pad, matching: find.text('Готово')));
    await settle(tester);
  }

  Future<void> leaveAndCome(WidgetTester tester) async {
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 10));
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await settle(tester);
  }

  testWidgets('завести код в настройках, включить код на вход «сразу»: после ухода — замок, снимается верным кодом', (tester) async {
    await pumpApp(tester);
    appNavigator.currentState!.push(settingsRoute());
    await tester.pumpAndSettle();
    final settings = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Завести код'), 300, scrollable: settings);
    await tester.tap(find.text('Завести код'));
    await tester.pumpAndSettle();
    expect(find.text('Придумайте код'), findsOneWidget);
    await enterCode(tester, '123456');
    expect(find.text('Повторите код'), findsOneWidget);
    await enterCode(tester, '123456');

    await tester.scrollUntilVisible(find.text('Код на вход'), 300, scrollable: settings);
    await tester.tap(find.text('Код на вход'));
    await settle(tester);
    await tester.tap(find.text('Запирать снова'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сразу'));
    await settle(tester);

    await leaveAndCome(tester);
    expect(find.text('Введите код'), findsOneWidget);
    await enterCode(tester, '000000');
    expect(find.text('Неверный код'), findsOneWidget);
    await enterCode(tester, '123456');
    expect(find.text('Введите код'), findsNothing);
    expect(find.text('Приватность'.toUpperCase()), findsOneWidget);
  });

  testWidgets('скрыть папку из меню: код заводится, в каталоге замок; закрыть — папки нет, открыть кодом — снова есть', (tester) async {
    final db = world.db;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'secret', name: 'Секрет', icon: 'lock', shape: 'pill'));
    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'b', kind: ItemKind.note, title: 'План', body: const Value('План побега'), folderId: const Value('secret'), createdAt: world.now, updatedAt: world.now),
    );
    await pumpApp(tester);
    appNavigator.currentState!.push(folderRoute('secret'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Скрыть папку'));
    await settle(tester);
    await enterCode(tester, '123456');
    await enterCode(tester, '123456');
    expect(find.text('Папка «Секрет» скрыта'), findsOneWidget);
    expect((await db.select(db.folders).getSingle()).hidden, isTrue);

    appNavigator.currentState!.push(catalogRoute());
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) => widget is Icon && widget.semanticLabel == 'скрыта'), findsOneWidget);
    await tester.tap(find.text('Закрыть скрытые папки'));
    await settle(tester);
    expect(find.text('Секрет'), findsNothing);
    expect(await db.select(db.items).get(), isEmpty);

    await tester.tap(find.text('Скрытые папки'));
    await settle(tester);
    expect(find.text('Код скрытых папок'), findsOneWidget);
    await enterCode(tester, '654321');
    expect(find.text('Неверный код'), findsOneWidget);
    await enterCode(tester, '123456');
    expect(find.text('Секрет'), findsOneWidget);
    expect((await db.select(db.items).getSingle()).body, 'План побега');
  });
}
