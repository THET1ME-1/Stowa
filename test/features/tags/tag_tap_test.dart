import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/features/workspace/workspace_model.dart';
import 'package:stowa/features/workspace/workspace_shell.dart';
import 'package:stowa/services/capture_service.dart';

import '../../helpers/test_app.dart';

// STOWA-10, хозяин 21.11: «сделать кликабельные теги — нажал и получил главную с фильтром по данному тегу»
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<String> note() async {
    final capture = CaptureService(world.db, tags: TagsRepository(world.db), filesRoot: world.files, clock: () => world.now);
    final id = await capture.capture(const CaptureInput(text: 'Шины на зиму #машина'));
    await world.db.update(world.db.items).write(const ItemsCompanion(sortState: Value(SortState.sorted)));
    return id;
  }

  // тег выбран в строке — чип с его именем у строки ввода
  Finder lineTag(String name) => find.descendant(of: find.byType(LineDock), matching: find.byKey(ValueKey('#$name')));

  testWidgets('телефон: касание тега на странице заметки — главная, строка ищет по тегу', (tester) async {
    await note();
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Шины на зиму'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('item-tag-машина')));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsNothing, reason: 'страница заметки закрылась до главной');
    expect(lineTag('машина'), findsOneWidget);
  });

  testWidgets('телефон, правка: касание тега по-прежнему снимает его, на главную не уводит', (tester) async {
    await note();
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Шины на зиму'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('item-tag-машина')));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
    expect(find.text('#машина'), findsNothing);
  });

  testWidgets('монитор: касание тега в свойствах — вкладка «Главная» с поиском, заметка остаётся вкладкой', (tester) async {
    final id = await note();
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final shell = WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!;
    shell.open(WsTab.item(id));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byKey(const ValueKey('desk-props')), matching: find.byKey(const ValueKey('item-tag-машина'))));
    await tester.pumpAndSettle();
    expect(shell.workspace.focusedPane.activeTab?.key, const WsTab.home().key);
    expect([for (final tab in shell.workspace.focusedPane.tabs) tab.key], contains(WsTab.item(id).key));
    expect(lineTag('машина'), findsOneWidget);
  });

  // окно на мониторе живёт над оболочкой: вкладку «Главная» открывает экран, а не окно
  testWidgets('монитор: окно тега в настройках — «Заметки с #тег» открывает вкладку «Главная»', (tester) async {
    await note();
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final shell = WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!;
    shell.open(const WsTab.settings('order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#машина'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-notes')));
    await tester.pumpAndSettle();
    expect(shell.workspace.focusedPane.activeTab?.key, const WsTab.home().key);
    expect(lineTag('машина'), findsOneWidget);
  });

  testWidgets('лист тега: «Заметки с #тег» — главная с поиском по нему', (tester) async {
    await note();
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Теги, папки и правила'), 200);
    await tester.ensureVisible(find.text('Теги, папки и правила'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Теги, папки и правила'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#машина'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-notes')));
    await tester.pumpAndSettle();
    expect(find.text('Теги, папки и правила'), findsNothing, reason: 'экраны настроек закрылись до главной');
    expect(lineTag('машина'), findsOneWidget);
  });
}
