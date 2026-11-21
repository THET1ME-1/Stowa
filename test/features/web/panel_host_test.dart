import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/app.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/data/repositories/documents_repository.dart';
import 'package:stowa/data/repositories/folders_repository.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/data/repositories/smart_folders_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/web/panel_host.dart';
import 'package:stowa/services/capture_service.dart';
import 'package:stowa/services/panel_bridge.dart';
import 'package:stowa/services/panel_db.dart';
import 'package:stowa/services/panel_writes.dart';

import '../../helpers/test_app.dart';

// STOWA-9, хозяин 21.11 со снимков телефона: «оно не так, как на телефоне, почти ни одной
// функции не перенёс». В панели — та же строка, что на телефоне, на базе вкладки
void main() {
  late TestWorld world;
  late PanelBridge tab;
  late List<String> opened;
  setUp(() {
    world = TestWorld();
    opened = [];
    final capture = CaptureService(world.db, tags: TagsRepository(world.db), filesRoot: world.files, clock: () => world.now);
    final items = ItemsRepository(world.db, clock: () => world.now);
    tab = PanelBridge(
      link: PanelLink(),
      locked: () => false,
      capture: (text) async => (id: await capture.capture(CaptureInput(text: text)), folder: null),
      undo: (id) => items.softDelete(id, world.now),
      search: (query) async => const [],
      open: opened.add,
      database: PanelDbServer(world.db),
      schema: AppDatabase.schema,
      writes: PanelWrites(
        captureAll: capture.captureAll,
        append: (id, text) => items.append(id, text, world.now),
        makeFolder: (name, parent) => FoldersRepository(world.db).create(name, parentId: parent),
        makeSmartFolder: (name, query) => SmartFoldersRepository(world.db).create(name: name, query: query),
        makeDocument: (kind, title, folder) => DocumentsRepository(world.db).create(kind, title: title, folderId: folder),
        placeFile: (name, bytes) async => throw UnimplementedError(),
      ),
    )..start();
  });
  tearDown(() async {
    // панель закрывается, пока вкладка ещё отвечает
    await world.database?.close().timeout(const Duration(seconds: 2), onTimeout: () {});
    tab.stop();
    world.dispose();
  });

  Future<void> note(String id, String title) => world.db.into(world.db.items).insert(
    ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(title), sortState: const Value(SortState.sorted), createdAt: world.now, updatedAt: world.now),
  );

  // база в настоящем времени: даём ей ответить и рисуем кадр
  Future<void> settle(WidgetTester tester) async {
    for (var step = 0; step < 4; step++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> show(WidgetTester tester) async {
    final client = PanelClient(PanelLink());
    addTearDown(client.close);
    final db = await tester.runAsync(() => connectTabDatabase(client, closeStreamsSynchronously: true));
    world.database = db;
    tester.view.physicalSize = const Size(560, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...world.overrides,
          captureServiceProvider.overrideWith((ref) => PanelCaptureService(db!, client, filesRoot: world.files, clock: () => world.now)),
          itemsRepositoryProvider.overrideWith((ref) => PanelItemsRepository(db!, client, clock: () => world.now)),
          foldersRepositoryProvider.overrideWith((ref) => PanelFoldersRepository(db!, client)),
        ],
        child: StowaApp(locale: const Locale('ru'), lockable: false, home: PanelHost(client: client, onOpenHere: () async {}, onLost: () {}, pulse: const Duration(days: 1))),
      ),
    );
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String text) async {
    final field = find.descendant(of: find.byType(LineDock), matching: find.byType(TextField));
    await tester.showKeyboard(field);
    await tester.enterText(field, text);
    await tester.pump(const Duration(milliseconds: 200));
    await settle(tester);
  }

  testWidgets('строка телефона: знаки # @ /, «+» и «Развернуть» на месте', (tester) async {
    await show(tester);
    await type(tester, 'Ку');
    expect(find.text('#'), findsOneWidget);
    expect(find.text('@'), findsOneWidget);
    expect(find.text('/'), findsOneWidget);
    expect(find.byTooltip('На весь экран'), findsOneWidget);
  });

  testWidgets('набранное ищется по базе вкладки, касание найденного открывает его во вкладке', (tester) async {
    await tester.runAsync(() => note('tires', 'Шины на зиму'));
    await show(tester);
    await type(tester, 'шины');
    final found = find.descendant(of: find.byType(LineDock), matching: find.text('Шины на зиму', findRichText: true));
    // поиск ходит в базу вкладки несколько раз подряд: каждый ответ — в настоящем времени
    for (var step = 0; step < 20 && found.evaluate().isEmpty; step++) {
      await settle(tester);
    }
    expect(found, findsWidgets);
    await tester.tap(found.first);
    await settle(tester);
    expect(opened, ['tires']);
  });

  testWidgets('«Закинуть» в панели сохраняет вкладка', (tester) async {
    await show(tester);
    await type(tester, 'Купить фильтр для воды');
    await tester.tap(find.text('Закинуть'));
    await settle(tester);
    final rows = await tester.runAsync(() => world.db.select(world.db.items).get());
    expect(rows!.map((row) => row.title), contains('Купить фильтр для воды'));
  });
}
