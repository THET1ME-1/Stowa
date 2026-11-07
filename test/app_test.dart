import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/home/folder_shelf.dart';
import 'package:stowa/features/home/note_timeline.dart';

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
    expect(find.text('Пока пусто. Закинь первую заметку в строку снизу.'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.scaffoldBackgroundColor, const Color(0xFF141517));
  });

  testWidgets('непереведённый язык показывает английский, а не русский', (tester) async {
    await open(tester, locale: const Locale('pl'));
    expect(find.text('Drop anything or search'), findsOneWidget);
  });

  testWidgets('закинутое сразу видно в ленте за сегодня, «Отменить» убирает и возвращает текст', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Купить батарейки для пульта');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();

    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.descendant(of: find.byType(NoteTimeline), matching: find.text('Купить батарейки для пульта')), findsOneWidget);
    expect(find.text('Закинул'), findsOneWidget);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Сегодня'), findsNothing);
    expect(find.text('Закинул'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Купить батарейки для пульта');
  });

  testWidgets('лента: касание метки папки перекладывает, долгое нажатие — лист действий', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'squircle'));
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Лампочки в коридор', createdAt: world.now, updatedAt: world.now));
    await open(tester);

    await tester.tap(find.descendant(of: find.byType(NoteTimeline), matching: find.text('Без папки')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дом').last);
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.items).getSingle()).folderId, 'home');
    // метка заметки теперь в цвет папки
    expect(find.descendant(of: find.byType(NoteTimeline), matching: find.text('Дом')), findsOneWidget);

    await tester.longPress(find.descendant(of: find.byType(NoteTimeline), matching: find.text('Лампочки в коридор')));
    await tester.pumpAndSettle();
    expect(find.text('Переложить в папку'), findsOneWidget);
  });

  testWidgets('лента: пункт списка отмечается прямо на главной, остальной текст как был', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'list',
          kind: ItemKind.note,
          title: 'Купить',
          body: const Value('Купить\n- [ ] Молоко\n- [ ] Хлеб'),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    await open(tester);

    await tester.tap(find.text('Хлеб'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.items).getSingle()).body, 'Купить\n- [ ] Молоко\n- [x] Хлеб');
  });

  testWidgets('папки пилюлями в две строки, остальные по «Ещё», «Свернуть» прячет обратно', (tester) async {
    for (var index = 0; index < 12; index++) {
      await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'f$index', name: 'Папка номер $index', icon: 'folder', shape: 'pill', sortOrder: Value(index)));
    }
    await open(tester);

    final shown = find.byType(FolderPill).evaluate().length;
    expect(shown, inInclusiveRange(2, 8));
    await tester.tap(find.text('Ещё ${12 - shown}'));
    await tester.pumpAndSettle();
    expect(find.byType(FolderPill), findsNWidgets(12));
    await tester.tap(find.text('Свернуть'));
    await tester.pumpAndSettle();
    expect(find.byType(FolderPill), findsNWidgets(shown));
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

    // плашка над строкой ввода, а не поверх её кнопок
    // видимая плашка — Material внутри SnackBar, вокруг неё отступы
    final snack = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
    final composer = tester.getRect(find.byKey(const ValueKey('composer')));
    expect(snack.bottom, lessThanOrEqualTo(composer.top));

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
    expect(find.byType(FolderPill), findsWidgets);
    expect(find.text('Борщ как у бабушки с пампушками'), findsOneWidget);
  });
}
