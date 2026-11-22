import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/known_vaults.dart';

import '../../helpers/test_app.dart';

// хозяин 22.11 со снимка левой панели: «вместо Stowa надо название текущей папки. При нажатии
// и стрелочку вниз (при анимации вверх)» — имя открытого хранилища и список для переключения
void main() {
  late TestWorld world;
  late SettingsRepository settings;
  late Directory notes, work;

  setUp(() async {
    world = TestWorld();
    notes = Directory(p.join(world.files.path, 'Конспекты'))..createSync();
    work = Directory(p.join(world.files.path, 'Работа'))..createSync();
    SharedPreferences.setMockInitialValues({
      'known_vaults': KnownVault.encodeList([KnownVault(path: work.path, mode: VaultMode.device, db: 'stowa-work', notes: 12, opened: DateTime(2026, 11, 9))]),
    });
    settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore(), clock: () => world.now);
    await settings.setVault(notes.path, VaultMode.device);
    world.settings = settings;
    world.vaultRoot = notes;
  });
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  double turns(WidgetTester tester) => tester.widget<AnimatedRotation>(find.descendant(of: find.byKey(const ValueKey('dock-vault')), matching: find.byType(AnimatedRotation))).turns;

  testWidgets('в шапке имя открытого хранилища со стрелкой; нажали — список, стрелка вверх', (tester) async {
    await open(tester);
    final head = find.byKey(const ValueKey('dock-vault'));
    expect(find.descendant(of: head, matching: find.text('Конспекты')), findsOneWidget);
    expect(find.descendant(of: head, matching: find.text('Stowa')), findsNothing);
    expect(turns(tester), 0);
    expect(find.text('Работа'), findsNothing);

    await tester.tap(head);
    await tester.pumpAndSettle();
    expect(turns(tester), 0.5, reason: 'список открыт — стрелка вверх');
    expect(find.byKey(const ValueKey('vault-option-stowa-work')), findsOneWidget);
    expect(find.text('Добавить хранилище'), findsOneWidget);
    // хозяин 22.11 со снимка: «почему ширина не такая же, как у меню» — список ровно по шапке
    final shown = tester.getRect(find.byKey(const ValueKey('dock-vault-menu')));
    final pill = tester.getRect(head);
    expect(shown.left, moreOrLessEquals(pill.left, epsilon: 0.5));
    expect(shown.width, moreOrLessEquals(pill.width, epsilon: 0.5));

    // щелчок мимо закрывает, стрелка возвращается
    await tester.tapAt(const Offset(900, 500));
    await tester.pumpAndSettle();
    expect(turns(tester), 0);
    expect(find.byKey(const ValueKey('vault-option-stowa-work')), findsNothing);
  });

  testWidgets('выбрали другое хранилище в списке — приложение открывается на нём', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('dock-vault')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vault-option-stowa-work')));
    for (var round = 0; round < 40; round++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(settings.vaultDb, 'stowa-work');
    expect(settings.vaultPath, work.path);
    expect(world.reopened, hasLength(1));
  });

  // сайт: папку на компьютере выбрать негде — хранилище заводится именем, рядом с первым;
  // переключение — настройки на него и перезагрузка страницы, без пересборки на месте
  testWidgets('браузер: «Добавить хранилище» спрашивает имя, заводит папку и открывает его', (tester) async {
    final more = Directory(p.join(world.files.path, 'vaults'))..createSync();
    world.inBrowser = true;
    world.vaultHome = notes;
    world.browserVaults = more.path;
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('dock-vault')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить хранилище'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Учёба');
    await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
    for (var round = 0; round < 40; round++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final made = p.join(more.path, 'Учёба');
    expect(Directory(made).existsSync(), isTrue);
    expect(settings.vaultPath, made);
    expect(settings.vaultDb, isNot('stowa'));
    expect(world.reopened, isEmpty, reason: 'в браузере хранилище поднимает перезагрузка страницы');
    // прежнее осталось в списке: к нему можно вернуться
    expect(settings.vaults.map((one) => one.path), containsAll([made, notes.path]));
  });
}
