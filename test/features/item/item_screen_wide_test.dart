import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
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

  testWidgets('широкий экран: панель заметки под шапкой, низ у общей строки, текст колонкой', (tester) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Схема курсовой работы', body: const Value('Схема курсовой работы'), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final line = find.byType(LineDock);
    WorkspaceScope.maybeOf(tester.element(line))!.open(const WsTab.item('n'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
    final dock = tester.getRect(find.byKey(const ValueKey('view-dock')));
    final screen = tester.getRect(find.byType(ItemScreen));
    // панель — в верхней части окна, а не над строкой ввода
    expect(dock.top - screen.top, lessThan(160));
    expect(dock.width, lessThanOrEqualTo(760));
    // строка ввода с ней не пересекается
    final capsule = tester.getRect(find.descendant(of: line, matching: find.textContaining('Закинь')).first);
    expect(dock.bottom, lessThan(capsule.top));
  });
}
