import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';

import 'helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester, {Locale locale = const Locale('ru')}) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app(locale: locale));
    await tester.pumpAndSettle();
  }

  testWidgets('приложение открывается по-русски на графите', (tester) async {
    await open(tester);
    expect(find.text('Stowa'), findsOneWidget);
    expect(find.text('Пока пусто. Закинь первую вещь в строку снизу.'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.scaffoldBackgroundColor, const Color(0xFF141517));
  });

  testWidgets('непереведённый язык показывает английский, а не русский', (tester) async {
    await open(tester, locale: const Locale('pl'));
    expect(find.text('Drop anything or search'), findsOneWidget);
  });

  testWidgets('закинутое сразу видно в «Только что», «Отменить» убирает и возвращает текст', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Купить батарейки для пульта');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();

    expect(find.text('Только что'), findsOneWidget);
    expect(find.text('Купить батарейки для пульта'), findsOneWidget);
    expect(find.text('Закинул'), findsOneWidget);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Только что'), findsNothing);
    expect(find.text('Закинул'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Купить батарейки для пульта');
  });

  testWidgets('плашка «Закинул» уходит сама', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'мысль');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    expect(find.text('Закинул'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Закинул'), findsNothing);
  });

  testWidgets('ближайшее напоминание наверху, «Готово» его снимает', (tester) async {
    final at = world.now.add(const Duration(hours: 3));
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'tooth',
          kind: ItemKind.note,
          title: 'Зубной',
          reminderAt: Value(at),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    await open(tester);
    expect(find.text('Зубной'), findsWidgets);
    await tester.tap(find.byTooltip('Готово'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Готово'), findsNothing);

    // случайный тап не стирает напоминание насовсем
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Готово'), findsOneWidget);
    expect((await world.db.select(world.db.items).getSingle()).reminderAt, at);
  });

  testWidgets('главная с вещами и папками влезает в 320 точек при крупном шрифте', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = world.db;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'f1', name: 'Рецепты на каждый день', icon: 'restaurant', shape: 'cookie9'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'f2', name: 'Машина', icon: 'directions_car', shape: 'pill'));
    for (final (index, title) in ['Борщ как у бабушки с пампушками', 'Замена масла', 'Идея для подарка'].indexed) {
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: 'i$index',
            kind: ItemKind.note,
            title: title,
            folderId: Value(index == 0 ? 'f1' : index == 1 ? 'f2' : null),
            reminderAt: Value(index == 2 ? world.now.add(const Duration(days: 1)) : null),
            createdAt: world.now.add(Duration(minutes: index)),
            updatedAt: world.now,
          ));
    }
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Папки'), findsOneWidget);
  });
}
