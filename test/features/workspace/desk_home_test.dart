import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/workspace/workspace_model.dart';
import 'package:stowa/features/workspace/workspace_shell.dart';

import '../../helpers/test_app.dart';

// хозяин 20.11: «пройдёшься как пользователь, что впервые на сайт зашёл». Пустая главная
// была чёрным полем с одним словом «Главная»: не ясно, что делать
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<WorkspaceController> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    return WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!;
  }

  testWidgets('пустая главная объясняет, что делать, и даёт три первых шага', (tester) async {
    await open(tester);
    final empty = find.byKey(const ValueKey('ws-empty'));
    expect(empty, findsOneWidget);
    expect(find.descendant(of: empty, matching: find.text('Здесь будут твои заметки')), findsOneWidget);
    for (final step in ['ws-empty-write', 'ws-empty-folder', 'ws-empty-restore']) {
      expect(find.byKey(ValueKey(step)), findsOneWidget, reason: step);
    }
    // по центру окна, а не прилипло к левому краю
    final box = tester.getRect(empty);
    final tab = tester.getRect(find.byKey(const ValueKey('tab-home:')));
    expect((box.center.dx - tab.center.dx).abs(), lessThan(4));
    expect(box.width, lessThanOrEqualTo(640));
  });

  testWidgets('«Записать первую» ставит курсор в строку', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('ws-empty-write')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.descendant(of: find.byType(LineDock), matching: find.byType(TextField)).first);
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('«Восстановить из копии» открывает настройки хранилища', (tester) async {
    final shell = await open(tester);
    await tester.tap(find.byKey(const ValueKey('ws-empty-restore')));
    await tester.pumpAndSettle();
    final settings = shell.workspace.panes.expand((pane) => pane.tabs).where((tab) => tab.kind == 'settings');
    expect(settings.map((tab) => tab.id), contains('vault'));
  });

  testWidgets('есть заметки — пустой главной нет', (tester) async {
    await open(tester);
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Первая', body: const Value('Первая'), createdAt: world.now, updatedAt: world.now),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ws-empty')), findsNothing);
  });
}
