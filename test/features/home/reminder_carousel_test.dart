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

  testWidgets('время с заглавной: «Завтра в 09:00», а не «завтра»', (tester) async {
    await remind('protein', 'Надо выпить протеин', const Duration(days: 1));
    await open(tester);
    expect(find.descendant(of: find.byType(ReminderCarousel), matching: find.textContaining(RegExp('^Завтра'))), findsOneWidget);
  });

  testWidgets('короткие заголовки — ряд ниже, чем с длинными: пустой полосы под текстом нет', (tester) async {
    // в тестовом шрифте буква — квадрат с кегль: заголовки взяты заведомо короткие
    await remind('protein', 'Сок', const Duration(hours: 2));
    await remind('gym', 'Зал', const Duration(hours: 3));
    await open(tester);
    final short = tester.getSize(find.byType(CarouselView)).height;
    await (world.db.update(world.db.items)..where((t) => t.id.equals('protein'))).write(const ItemsCompanion(title: Value('Футбольный матч Молдова Казахстан на арене Зимбру')));
    await tester.pumpAndSettle();
    final long = tester.getSize(find.byType(CarouselView)).height;
    expect(short, lessThan(long - 15));
  });

  Finder card(String id) => find.byKey(ValueKey('reminder-$id')).first;

  /// Листнуть на [count] карточек: шаг карусели — ширина узкой полоски.
  Future<void> swipe(WidgetTester tester, int count) async {
    final step = tester.getSize(find.byType(CarouselView)).width / 8;
    await tester.timedDrag(find.byType(CarouselView), Offset(-step * count, 0), Duration(milliseconds: 250 * count.abs()));
    await tester.pumpAndSettle();
  }

  testWidgets('несколько напоминаний — ведущая по центру, слева и справа по полоске', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await remind('dentist', 'Зубной', const Duration(days: 2));
    await open(tester);
    expect(find.byType(CarouselView), findsOneWidget);
    expect(inCarousel('Закинуть футболку'), findsOneWidget);
    // «ещё 2» больше не нужно: соседние карточки видны полосками
    expect(find.textContaining('ещё'), findsNothing);
    final carousel = tester.getRect(find.byType(CarouselView));
    final lead = tester.getRect(card('shirt'));
    // ведущая посередине ряда, справа следующая, слева по кругу последняя
    expect((lead.center.dx - carousel.center.dx).abs(), lessThan(4));
    expect(lead.width, greaterThan(tester.getSize(card('match')).width * 4));
    expect(tester.getRect(card('match')).left, greaterThan(lead.right));
    expect(tester.getRect(card('dentist')).right, lessThan(lead.left));
    // у полосок текста нет, только будильник
    expect(inCarousel('Футбольный матч'), findsNothing);
    expect(inCarousel('Зубной'), findsNothing);
  });

  testWidgets('прокрутка расширяет следующую карточку, касание ведущей открывает её заметку', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await remind('dentist', 'Зубной', const Duration(days: 2));
    await open(tester);
    await swipe(tester, 1);
    expect(inCarousel('Футбольный матч'), findsOneWidget);

    await tester.tap(inCarousel('Футбольный матч'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
    expect(find.text('Футбольный матч'), findsWidgets);
  });

  testWidgets('карусель по кругу: назад от первой — последняя, вперёд от последней — первая', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await remind('dentist', 'Зубной', const Duration(days: 2));
    await open(tester);
    // назад от первой: ведущей становится последняя
    await swipe(tester, -1);
    expect(inCarousel('Зубной'), findsOneWidget);
    // и дальше вперёд по кругу: первая, вторая, третья, снова первая
    await swipe(tester, 1);
    expect(inCarousel('Закинуть футболку'), findsOneWidget);
    await swipe(tester, 1);
    await swipe(tester, 1);
    expect(inCarousel('Зубной'), findsOneWidget);
    await swipe(tester, 1);
    expect(inCarousel('Закинуть футболку'), findsOneWidget);
    // касание ведущей и после круга открывает её заметку
    await tester.tap(inCarousel('Закинуть футболку'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
  });

  testWidgets('касание полоски выдвигает её в центр, а не открывает: и справа, и слева', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await remind('dentist', 'Зубной', const Duration(days: 2));
    await open(tester);
    await tester.tap(card('match'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsNothing);
    expect(inCarousel('Футбольный матч'), findsOneWidget);

    // слева теперь первая: касание возвращает её
    await tester.tap(card('shirt'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsNothing);
    expect(inCarousel('Закинуть футболку'), findsOneWidget);
  });

  testWidgets('галочка снимает напоминание у своей карточки, «Отменить» возвращает', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await open(tester);
    await swipe(tester, 1);
    final done = find.byTooltip('Готово');
    // галочка есть только у ведущей
    expect(done, findsOneWidget);
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
