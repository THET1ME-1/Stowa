import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/known_vaults.dart';
import 'package:stowa/domain/models.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  late SettingsRepository settings;
  late Directory obsidian;
  final monday = DateTime(2026, 11, 9, 10);

  setUp(() async {
    world = TestWorld();
    obsidian = Directory(p.join(world.files.path, 'Obsidian'))..createSync();
    SharedPreferences.setMockInitialValues({
      'known_vaults': KnownVault.encodeList([
        KnownVault(path: obsidian.path, mode: VaultMode.device, db: 'stowa-obs', notes: 12, opened: monday),
        KnownVault(path: p.join(world.files.path, 'Пропала'), mode: VaultMode.device, db: 'stowa-gone', notes: 3, opened: monday.subtract(const Duration(days: 1))),
      ]),
    });
    settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore(), clock: () => world.now);
    world.settings = settings;
  });
  tearDown(() => world.dispose());

  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 40; round++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester, {Size size = const Size(400, 880), double textScale = 1}) async {
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
  }

  Future<void> openCatalog(WidgetTester tester, {Size size = const Size(400, 880), double textScale = 1}) async {
    await openSettings(tester, size: size, textScale: textScale);
    await tester.tap(find.byKey(const ValueKey('settings-catalog')));
    await tester.pumpAndSettle();
  }

  double top(Finder finder) => finder.evaluate().isEmpty ? double.infinity : finder.evaluate().first.renderObject is RenderBox ? (finder.evaluate().first.renderObject! as RenderBox).localToGlobal(Offset.zero).dy : double.infinity;

  testWidgets('первым разделом «Каталог»: имя открытого хранилища и число заметок, ниже «Внешний вид»', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Раз', body: const Value('Раз'), createdAt: world.now, updatedAt: world.now));
    await tester.runAsync(() async {});
    await openSettings(tester);
    expect(find.text('КАТАЛОГ'), findsOneWidget);
    final row = find.byKey(const ValueKey('settings-catalog'));
    expect(find.descendant(of: row, matching: find.text('Внутри приложения')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('1 заметка')), findsOneWidget);
    expect(top(find.text('КАТАЛОГ')), lessThan(top(find.text('ВНЕШНИЙ ВИД'))));
    expect(top(find.text('ВНЕШНИЙ ВИД')), lessThan(top(find.text('РАЗБОР И УВЕДОМЛЕНИЯ'))));
    // хранилище больше не повторяется строкой ниже, корзина уехала в «Данные»
    expect(find.text('Хранилище'), findsNothing);
    await tester.scrollUntilVisible(find.text('Корзина'), 200);
    expect(top(find.text('ДАННЫЕ')), lessThan(top(find.text('Корзина'))));
  });

  testWidgets('экран: Stowa Sync «Платно · Скоро», открытое с пилюлей, прежние с числом заметок', (tester) async {
    await openCatalog(tester);
    // есть ли папка, строка узнаёт с диска
    await settle(tester);
    expect(find.text('Stowa Sync'), findsOneWidget);
    expect(find.text('Платно'), findsOneWidget);
    expect(find.text('Скоро'), findsOneWidget);
    final current = find.byKey(const ValueKey('vault-current'));
    expect(find.descendant(of: current, matching: find.text('Внутри приложения')), findsOneWidget);
    expect(find.descendant(of: current, matching: find.text('Открыто')), findsOneWidget);
    final other = find.byKey(const ValueKey('vault-stowa-obs'));
    expect(find.descendant(of: other, matching: find.text('Obsidian')), findsOneWidget);
    expect(find.descendant(of: other, matching: find.textContaining('12 заметок')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('vault-stowa-gone')), matching: find.text('Папка не найдена')), findsOneWidget);
    expect(top(current), lessThan(top(other)));
    expect(find.text('Добавить хранилище'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Восстановить из копии'), 200);
    for (final label in ['Сохранить копию', 'Выгрузить в Markdown', 'Пересобрать указатель']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('Stowa Sync: лист с одним предложением и «Понятно»', (tester) async {
    await openCatalog(tester);
    await tester.tap(find.text('Stowa Sync'));
    await tester.pumpAndSettle();
    expect(find.text('Заметки сами сойдутся на телефоне, планшете и компьютере.'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.text('Понятно'), findsNothing);
  });

  testWidgets('касание прежнего открывает его: настройки на нём, приложение пересобирается на его базе', (tester) async {
    await openCatalog(tester);
    await tester.tap(find.text('Obsidian'));
    await settle(tester);
    expect(settings.vaultDb, 'stowa-obs');
    expect(settings.vaultPath, obsidian.path);
    expect(world.reopened, hasLength(1));
    expect(identical(world.reopened.single, world.vaultDatabases['stowa-obs']), isTrue);
  });

  testWidgets('папки нет — плашка, хранилище не меняется', (tester) async {
    await openCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('vault-stowa-gone')));
    await settle(tester);
    expect(find.text('Папка не найдена'), findsWidgets);
    expect(world.reopened, isEmpty);
    expect(settings.vaultDb, 'stowa');
  });

  testWidgets('«⋮» → «Убрать из списка», «Отменить» возвращает', (tester) async {
    await openCatalog(tester);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('vault-stowa-obs')), matching: find.byTooltip('Ещё')));
    await tester.pumpAndSettle();
    expect(find.text('Файлы останутся в папке'), findsOneWidget);
    await tester.tap(find.text('Убрать из списка'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vault-stowa-obs')), findsNothing);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vault-stowa-obs')), findsOneWidget);
  });

  testWidgets('«Добавить хранилище» → «Открыть папку»: папка с заметками собирается в свою базу и открывается', (tester) async {
    final picked = Directory(p.join(world.files.path, 'Работа'))..createSync();
    File(p.join(picked.path, 'План.md')).writeAsStringSync('План\nна неделю');
    world.pickedFolder = picked.path;
    await openCatalog(tester);
    await tester.tap(find.text('Добавить хранилище'));
    await tester.pumpAndSettle();
    expect(find.text('Создать новое'), findsOneWidget);
    await tester.tap(find.text('Открыть папку'));
    await settle(tester);
    expect(settings.vaultPath, picked.path);
    expect(settings.vaultDb, isNot('stowa'));
    final prepared = world.reopened.single!;
    expect([for (final item in await tester.runAsync(() => prepared.select(prepared.items).get()) ?? <Item>[]) item.title], ['План']);
  });

  testWidgets('выбрали папку открытого — «уже открыто», без смены', (tester) async {
    await settings.setVault(obsidian.path, VaultMode.device);
    await settings.openKnownVault(settings.vaults.firstWhere((one) => one.db == 'stowa-obs'), notesHere: 0);
    world.pickedFolder = obsidian.path;
    await openCatalog(tester);
    await tester.tap(find.text('Добавить хранилище'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открыть папку'));
    await settle(tester);
    expect(find.text('Это хранилище уже открыто'), findsOneWidget);
    expect(world.reopened, isEmpty);
  });

  testWidgets('iPhone: место одно — без «Добавить» и без прежних', (tester) async {
    world.vaultHome = world.files;
    await openCatalog(tester);
    expect(find.text('Добавить хранилище'), findsNothing);
    expect(find.text('Obsidian'), findsNothing);
    expect(find.text('Stowa Sync'), findsOneWidget);
    final row = find.ancestor(of: find.text('«Файлы» → Stowa'), matching: find.byType(InkWell)).first;
    expect(tester.widget<InkWell>(row).onTap, isNull);
  });

  testWidgets('320 точек и крупный шрифт: экран влезает', (tester) async {
    await openCatalog(tester, size: const Size(320, 700), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
