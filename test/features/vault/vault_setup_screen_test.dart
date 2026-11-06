import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/home/home_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  late SettingsRepository settings;

  setUp(() async {
    world = TestWorld()..vaultAsked = false;
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
    world.settings = settings;
    // новая установка: хранилище внутри приложения уже заведено, место ещё не выбирали
    await settings.setVault(p.join(world.files.path, 'vault'), VaultMode.app, asked: false);
  });
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  testWidgets('первый запуск показывает три пути, как в Obsidian', (tester) async {
    await open(tester);
    expect(find.text('Где хранить заметки'), findsOneWidget);
    expect(find.text('Создать хранилище'), findsOneWidget);
    expect(find.text('Открыть папку как хранилище'), findsOneWidget);
    expect(find.text('Хранить внутри приложения'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('внутри приложения — только после предупреждения, потом главная', (tester) async {
    await open(tester);
    await tester.tap(find.text('Выбрать'));
    await tester.pumpAndSettle();
    expect(find.textContaining('пропадут, если его удалить'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await tester.tap(find.text('Хранить внутри'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(settings.vaultAsked, isTrue);
    expect(settings.vaultMode, VaultMode.app);
  });

  testWidgets('открыть папку: заметки из неё в приложении, хранилище — эта папка, потом главная', (tester) async {
    final folder = Directory(p.join(world.files.path, 'phone', 'Obsidian'))..createSync(recursive: true);
    File(p.join(folder.path, 'Идеи.md')).writeAsStringSync('Сделать полку');
    world.pickedFolder = folder.path;
    await open(tester);
    await tester.tap(find.text('Открыть'));
    // перенос идёт по настоящему диску: настоящее ожидание вперемешку с кадрами
    for (var round = 0; round < 200 && find.byType(HomeScreen).evaluate().isEmpty; round++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 1));
    expect(settings.vaultMode, VaultMode.device);
    expect((await world.db.select(world.db.items).get()).map((item) => item.title), ['Идеи']);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('без доступа к файлам хранилище в памяти телефона не создаётся', (tester) async {
    world
      ..allFiles = false
      ..pickedFolder = p.join(world.files.path, 'phone');
    await open(tester);
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    // лист с просьбой о разрешении — человек передумал
    expect(find.text('Нужен доступ к файлам'), findsOneWidget);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(settings.vaultMode, VaultMode.app);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('папка пропала: экран «Хранилище не найдено», вещи в базе целы', (tester) async {
    world
      ..vaultAsked = true
      ..vaultMissing = true;
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Идеи', body: const Value('Идеи'), createdAt: world.now, updatedAt: world.now));
    await open(tester);
    expect(find.text('Хранилище не найдено'), findsOneWidget);
    expect(find.text('Выбрать папку'), findsOneWidget);
    expect(await world.db.select(world.db.items).get(), hasLength(1));
  });
}
