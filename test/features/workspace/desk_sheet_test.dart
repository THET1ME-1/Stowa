import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/folder/folder_screen.dart';
import 'package:stowa/features/folder/folder_sheets.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/features/workspace/workspace_model.dart';
import 'package:stowa/features/workspace/workspace_shell.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> note() => world.db.into(world.db.items).insert(
    ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Схема курсовой', body: const Value('Схема курсовой'), createdAt: world.now, updatedAt: world.now),
  );

  Future<void> show(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  testWidgets('монитор: меню заметки — окно у верха по центру, а не шторка снизу во всю ширину', (tester) async {
    await note();
    await show(tester, const Size(1600, 960));
    WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!.open(const WsTab.item('n'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('desk-bar')), matching: find.byTooltip('Ещё')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    final sheet = tester.getRect(find.byKey(const ValueKey('desk-sheet')));
    expect(sheet.width, lessThanOrEqualTo(640));
    expect(sheet.top, inInclusiveRange(60, 200), reason: 'у верха окна, как палитра в макете');
    expect((sheet.center.dx - 800).abs(), lessThan(2), reason: 'по центру окна');
    expect(find.text('Закрепить'), findsOneWidget);

    // Esc закрывает окно
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desk-sheet')), findsNothing);
  });

  // хозяин 20.11: «уникальные приятные анимации, отклики и переходы». Окно как в макете:
  // проявляется, опускаясь на место сверху, а не возникает
  testWidgets('монитор: окно опускается на место и проявляется', (tester) async {
    await note();
    await show(tester, const Size(1600, 960));
    WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!.open(const WsTab.item('n'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('desk-bar')), matching: find.byTooltip('Ещё')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final midway = tester.getRect(find.byKey(const ValueKey('desk-sheet'))).top;
    var opacity = 1.0;
    for (final fade in tester.widgetList<FadeTransition>(find.ancestor(of: find.byKey(const ValueKey('desk-sheet')), matching: find.byType(FadeTransition)))) {
      opacity *= fade.opacity.value;
    }
    expect(opacity, inExclusiveRange(0, 1), reason: 'проявляется');
    await tester.pumpAndSettle();
    final settled = tester.getRect(find.byKey(const ValueKey('desk-sheet'))).top;
    expect(midway, lessThan(settled), reason: 'опускается сверху');
    expect(settled - midway, lessThanOrEqualTo(10));
  });

  testWidgets('монитор: окно из окна — тоже окно («Переложить» → «Новая папка»)', (tester) async {
    await note();
    await show(tester, const Size(1600, 960));
    WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!.open(const WsTab.item('n'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('desk-bar')), matching: find.byTooltip('Переложить в папку')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desk-sheet')), findsOneWidget);
    await tester.tap(find.text('Новая папка'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing, reason: 'вложенный выбор не выезжает шторкой снизу');
    expect(find.byKey(const ValueKey('desk-sheet')), findsWidgets);
  });

  // хозяин 22.11 со снимка сайта: «нажал Удалить папку. Окно висит, а папка не удалилась».
  // Кнопки окна закрывали его контекстом страницы папки: во вкладке это другой навигатор,
  // и вместо окна снималась сама страница
  testWidgets('монитор: «Удалить папку» из страницы папки закрывает окно, а не страницу', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'gym', name: 'Абонемент', icon: 'folder', shape: 'squircle'));
    await show(tester, const Size(1600, 960));
    WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!.open(const WsTab.folder('gym'));
    await tester.pumpAndSettle();
    final page = tester.element(find.byType(FolderScreen));

    bool? answer;
    confirmFolderDelete(page, 'Абонемент').then((yes) => answer = yes).ignore();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить папку'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
    expect(find.byKey(const ValueKey('desk-sheet')), findsNothing);
    expect(find.byType(FolderScreen), findsOneWidget, reason: 'страница папки на месте');

    // то же окно имени: «Сохранить» отдаёт имя и не трогает страницу
    String? name;
    showRenameSheet(page, 'Абонемент').then((value) => name = value).ignore();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(name, 'Абонемент');
    expect(find.byKey(const ValueKey('desk-sheet')), findsNothing);
    expect(find.byType(FolderScreen), findsOneWidget);
  });

  testWidgets('телефон: меню заметки — шторка снизу, как было', (tester) async {
    await note();
    await show(tester, const Size(400, 900));
    Navigator.of(tester.element(find.byType(LineDock))).push(itemRoute('n'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('desk-sheet')), findsNothing);
  });
}
