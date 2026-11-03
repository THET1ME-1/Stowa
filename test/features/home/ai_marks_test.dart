import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/models.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> addLoose() => world.db
      .into(world.db.items)
      .insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Мысль', createdAt: world.now, updatedAt: world.now));

  testWidgets('с рабочим ключом вещь без папки подписана «разбираю»', (tester) async {
    world.aiSettings = const AiSettings(hasKey: true);
    await addLoose();
    await open(tester);
    expect(find.text('разбираю'), findsOneWidget);
  });

  testWidgets('без ключа та же вещь — «Без папки»', (tester) async {
    await addLoose();
    await open(tester);
    expect(find.text('разбираю'), findsNothing);
  });

  testWidgets('папка от ИИ помечена «новая», пока её не открыли', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'g', name: 'Огород', icon: 'yard', shape: 'pill', createdByAi: const Value(true)));
    await open(tester);
    expect(find.text('новая'), findsOneWidget);
    await tester.tap(find.text('Огород'));
    await tester.pumpAndSettle();
    final folder = await world.db.select(world.db.folders).getSingle();
    expect(folder.createdByAi, isFalse);
  });
}
