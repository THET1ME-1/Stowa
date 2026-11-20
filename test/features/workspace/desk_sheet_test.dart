import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
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
