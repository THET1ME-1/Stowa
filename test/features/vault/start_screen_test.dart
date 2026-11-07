import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/home/home_screen.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> note(String id, {DateTime? opened}) => world.db.into(world.db.items).insert(ItemsCompanion.insert(
        id: id,
        kind: ItemKind.note,
        title: 'Заметка $id',
        body: Value('Заметка $id'),
        createdAt: world.now,
        updatedAt: world.now,
        openedAt: Value(opened),
      ));

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  testWidgets('по умолчанию запуск открывает главную', (tester) async {
    await note('a', opened: world.now);
    await launch(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(ItemScreen), findsNothing);
  });

  testWidgets('«Последняя заметка»: запуск открывает её поверх главной, назад — главная', (tester) async {
    world.startScreen = StartScreen.last;
    await note('a', opened: world.now.subtract(const Duration(days: 1)));
    await note('b', opened: world.now.subtract(const Duration(hours: 1)));
    await launch(tester);
    expect(tester.widget<ItemScreen>(find.byType(ItemScreen)).id, 'b');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('«Случайная заметка»: открывает одну из сохранённых; пустое хранилище — главная', (tester) async {
    world.startScreen = StartScreen.random;
    await launch(tester);
    expect(find.byType(ItemScreen), findsNothing);
  });

  testWidgets('«Случайная заметка» с заметкой открывает её', (tester) async {
    world.startScreen = StartScreen.random;
    await note('a');
    await launch(tester);
    expect(tester.widget<ItemScreen>(find.byType(ItemScreen)).id, 'a');
  });
}
