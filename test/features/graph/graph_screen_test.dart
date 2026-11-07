import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/home/folder_shelf.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> openGraph(WidgetTester tester, {bool linked = true}) async {
    final db = world.db;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'garden', name: 'Огород', icon: 'yard', shape: 'pill'));
    for (final (id, text) in [('a', 'Рассада томатов'), ('b', 'Полив огурцов'), ('c', 'Парник')]) {
      await db.into(db.items).insert(
        ItemsCompanion.insert(id: id, kind: ItemKind.note, title: text, body: Value(text), folderId: const Value('garden'), sortState: const Value(SortState.sorted), createdAt: world.now, updatedAt: world.now),
      );
    }
    if (linked) await db.into(db.links).insert(LinksCompanion.insert(fromId: 'a', toId: 'b', source: LinkSource.ai));
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(FolderPill), matching: find.text('Огород')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Граф связей'));
    // лист меню закрывается, потом въезжает экран графа
    for (var round = 0; round < 20 && find.byType(CircularProgressIndicator).evaluate().isEmpty; round++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // раскладка считается в отдельном потоке: ответ приходит только в настоящем времени
    for (var round = 0; round < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; round++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('граф папки открывается из её меню и рисует связи', (tester) async {
    await openGraph(tester);
    expect(find.text('Граф связей'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.textContaining('Связей пока нет'), findsNothing);
  });

  testWidgets('без связей — честная подпись, а не пустой экран', (tester) async {
    await openGraph(tester, linked: false);
    expect(find.textContaining('Связей пока нет'), findsOneWidget);
  });
}
