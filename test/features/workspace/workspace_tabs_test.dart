import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/workspace/workspace_model.dart';
import 'package:stowa/features/workspace/workspace_shell.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  // насколько видна вкладка: прозрачность её слоя в окне
  double shown(WidgetTester tester, String key) {
    final layer = find.descendant(of: find.byKey(ValueKey('tab-$key')), matching: find.byType(AnimatedOpacity)).first;
    return tester.renderObject<RenderAnimatedOpacity>(layer).opacity.value;
  }

  testWidgets('возврат на вкладку левее: ушедшая вкладка гаснет, а не остаётся поверх', (tester) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Схема курсовой', body: const Value('Схема курсовой'), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final shell = WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!;
    shell.open(const WsTab.item('n'));
    await tester.pumpAndSettle();
    shell.open(const WsTab.settings());
    await tester.pumpAndSettle();
    expect(shown(tester, 'settings'), 1);

    await tester.tap(find.byKey(const ValueKey('chip-item:n')));
    await tester.pumpAndSettle();

    expect(shown(tester, 'item:n'), 1);
    expect(shown(tester, 'settings'), 0, reason: 'настройки лежат в стопке выше заметки и закрывали бы её');
  });

  // хозяин 21.11 со снимка сайта: «заметка удалена, но всё равно окно на ней» — пустая вкладка
  // с «Удалил · Отменить». Удалить могли и меню заметки, и лента, и телефон через синхронизацию
  testWidgets('заметку удалили — её вкладка закрывается, соседние остаются', (tester) async {
    for (final id in ['n', 'm']) {
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: 'Заметка $id', body: Value('Заметка $id'), createdAt: world.now, updatedAt: world.now));
    }
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final shell = WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!;
    shell.open(const WsTab.item('m'));
    shell.open(const WsTab.item('n'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chip-item:n')), findsOneWidget);

    await (world.db.update(world.db.items)..where((t) => t.id.equals('n'))).write(ItemsCompanion(deletedAt: Value(world.now)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chip-item:n')), findsNothing);
    expect(find.byKey(const ValueKey('chip-item:m')), findsOneWidget);
    // удалённая не возвращается сочетанием «открыть закрытую»
    expect(shell.closed.where((tab) => tab.id == 'n'), isEmpty);
  });

  // хозяин 22.11: «CTRL + E для переключения видов заметки просмотр/редактирование»
  testWidgets('Ctrl+E в открытой заметке включает правку, ещё раз — сохраняет и возвращает просмотр', (tester) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Схема курсовой', body: const Value('Схема курсовой'), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!.open(const WsTab.item('n'));
    await tester.pumpAndSettle();
    final tab = find.byKey(const ValueKey('tab-item:n'));
    EditableText body() => tester.widget<EditableText>(find.descendant(of: tab, matching: find.byType(EditableText)).last);
    expect(find.descendant(of: tab, matching: find.byType(EditableText)), findsNothing);

    Future<void> ctrlE() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    await ctrlE();
    expect(body().controller.text, 'Схема курсовой');

    // правка с клавиатуры и снова Ctrl+E, уже из поля: текст сохранён, поля нет
    body().controller.text = 'Схема курсовой\nвторая строка';
    await ctrlE();
    expect(find.descendant(of: tab, matching: find.byType(EditableText)), findsNothing);
    final saved = await (world.db.select(world.db.items)..where((t) => t.id.equals('n'))).getSingle();
    expect(saved.body, 'Схема курсовой\nвторая строка');
  });

  testWidgets('папку удалили — её вкладка закрывается', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'gym', name: 'Абонемент', icon: 'folder', shape: 'squircle'));
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final shell = WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!;
    shell.open(const WsTab.folder('gym'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chip-folder:gym')), findsOneWidget);

    await (world.db.update(world.db.folders)..where((t) => t.id.equals('gym'))).write(FoldersCompanion(deletedAt: Value(world.now)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chip-folder:gym')), findsNothing);
    expect(shell.closed.where((tab) => tab.id == 'gym'), isEmpty);
  });

  // хозяин 20.11 про сайт: «переходы экранов». Вкладка не подменяется: входящая мягко
  // поднимается на место и проявляется
  testWidgets('смена вкладки: входящая поднимается на место, а не появляется сразу', (tester) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Схема курсовой', body: const Value('Схема курсовой'), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final shell = WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!;
    shell.open(const WsTab.item('n'));
    await tester.pumpAndSettle();
    final settled = tester.getRect(find.byKey(const ValueKey('tab-item:n'))).top;
    shell.open(const WsTab.settings());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chip-item:n')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final layer = find.descendant(of: find.byKey(const ValueKey('tab-item:n')), matching: find.byType(AnimatedOpacity)).first;
    final midway = tester.getRect(layer).top;
    expect(midway, greaterThan(settled), reason: 'ещё ниже своего места');
    expect(midway - settled, lessThanOrEqualTo(16), reason: 'сдвиг едва заметный');
    await tester.pumpAndSettle();
    expect(tester.getRect(layer).top, settled);
  });
}
