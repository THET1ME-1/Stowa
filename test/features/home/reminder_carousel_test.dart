import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/home/reminder_carousel.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> remind(String id, String title, Duration later) async {
    final at = world.now.subtract(const Duration(hours: 1));
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: id,
          kind: ItemKind.note,
          title: title,
          body: Value(title),
          sortState: const Value(SortState.sorted),
          reminderAt: Value(world.now.add(later)),
          createdAt: at,
          updatedAt: at,
        ));
  }

  Future<void> open(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  Finder inCarousel(String text) => find.descendant(of: find.byType(ReminderCarousel), matching: find.text(text));

  testWidgets('одно напоминание — одна карточка на всю ширину, касание открывает заметку', (tester) async {
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await open(tester);
    expect(inCarousel('Футбольный матч'), findsOneWidget);
    expect(find.byType(CarouselView), findsNothing);

    await tester.tap(inCarousel('Футбольный матч'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
  });

  testWidgets('несколько напоминаний — карусель: ведущая широкая с текстом, следующие полосками', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await remind('dentist', 'Зубной', const Duration(days: 2));
    await open(tester);
    expect(find.byType(CarouselView), findsOneWidget);
    expect(inCarousel('Закинуть футболку'), findsOneWidget);
    // «ещё 2» больше не нужно: следующие карточки видны полосками
    expect(find.textContaining('ещё'), findsNothing);
    double width(String id) => tester.getSize(find.byKey(ValueKey('reminder-$id'))).width;
    // большая, средняя, узкая — как в галерее M3
    expect(width('shirt'), greaterThan(width('match') * 1.4));
    expect(width('match'), greaterThan(width('dentist') * 2));
    // у полоски текста нет, только значок и время
    expect(inCarousel('Футбольный матч'), findsNothing);
  });

  testWidgets('прокрутка расширяет следующую карточку, касание ведущей открывает её заметку', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await remind('dentist', 'Зубной', const Duration(days: 2));
    await open(tester);
    // на одну карточку: на ширину ведущей
    final lead = tester.getSize(find.byKey(const ValueKey('reminder-shirt'))).width;
    await tester.timedDrag(find.byType(CarouselView), Offset(-lead, 0), const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(inCarousel('Футбольный матч'), findsOneWidget);

    await tester.tap(inCarousel('Футбольный матч'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
    expect(find.text('Футбольный матч'), findsWidgets);
  });

  testWidgets('касание полоски выдвигает её вперёд, а не открывает', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('reminder-match')));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsNothing);
    expect(inCarousel('Футбольный матч'), findsOneWidget);
  });

  testWidgets('галочка снимает напоминание у своей карточки, «Отменить» возвращает', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await open(tester);
    // палец ведёт плавно: мгновенный рывок карусель с прилипанием возвращает назад
    await tester.timedDrag(find.byType(CarouselView), const Offset(-300, 0), const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final done = find.descendant(of: find.byKey(const ValueKey('reminder-match')), matching: find.byTooltip('Готово'));
    await tester.tap(done);
    await tester.pumpAndSettle();
    Future<Item> read(String id) => (world.db.select(world.db.items)..where((t) => t.id.equals(id))).getSingle();
    expect((await read('match')).reminderAt, isNull);
    expect((await read('shirt')).reminderAt, isNotNull);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect((await read('match')).reminderAt, isNotNull);
  });

  testWidgets('карусель влезает в 320 точек при крупном шрифте', (tester) async {
    await remind('match', 'Футбольный матч Молдова Казахстан на арене Зимбру', const Duration(hours: 5));
    await remind('shirt', 'Закинуть футболку в пакет с тканью', const Duration(hours: 6));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
