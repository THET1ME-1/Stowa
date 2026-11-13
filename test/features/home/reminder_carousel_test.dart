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

  /// Ведущая карточка — та, что по центру.
  Finder lead(String text) => find.descendant(of: find.byKey(const ValueKey('reminder-lead')), matching: find.text(text));

  /// Обычный взмах пальцем на ширину карточки: [count] вперёд, минус — назад.
  Future<void> swipe(WidgetTester tester, int count) async {
    final page = tester.getSize(find.byType(CarouselView)).width * 0.75;
    for (var step = 0; step < count.abs(); step++) {
      await tester.fling(find.byType(CarouselView), Offset(count > 0 ? -page * 0.6 : page * 0.6, 0), 800);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('несколько напоминаний — карусель M3: ведущая широкая по центру, по краям узкие полоски', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await remind('dentist', 'Зубной', const Duration(days: 2));
    await open(tester);
    expect(find.byType(CarouselView), findsOneWidget);
    expect(lead('Закинуть футболку'), findsOneWidget);
    expect(find.textContaining('ещё'), findsNothing);
    final row = tester.getRect(find.byType(CarouselView));
    final center = tester.getRect(find.byKey(const ValueKey('reminder-lead')));
    // ведущая посередине ряда, справа полоской следующая, слева по кругу последняя
    expect((center.center.dx - row.center.dx).abs(), lessThan(4));
    final right = tester.getRect(card('match'));
    final left = tester.getRect(card('dentist'));
    expect(right.left, greaterThan(center.right - 1));
    expect(left.right, lessThan(center.left + 1));
    expect(right.width, lessThan(center.width / 4));
    expect(left.width, lessThan(center.width / 4));
  });

  testWidgets('один взмах — ровно одна карточка, касание ведущей открывает её заметку', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await remind('dentist', 'Зубной', const Duration(days: 2));
    await remind('mama', 'Позвонить маме', const Duration(days: 3));
    await open(tester);
    // быстрый сильный взмах всё равно перелистывает одну
    await tester.fling(find.byType(CarouselView), const Offset(-300, 0), 4000);
    await tester.pumpAndSettle();
    expect(lead('Футбольный матч'), findsOneWidget);

    await tester.tap(lead('Футбольный матч'));
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
    expect(lead('Зубной'), findsOneWidget);
    // и дальше вперёд по кругу: первая, вторая, третья, снова первая
    await swipe(tester, 1);
    expect(lead('Закинуть футболку'), findsOneWidget);
    await swipe(tester, 2);
    expect(lead('Зубной'), findsOneWidget);
    await swipe(tester, 1);
    expect(lead('Закинуть футболку'), findsOneWidget);
    // касание ведущей и после круга открывает её заметку
    await tester.tap(lead('Закинуть футболку'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
  });

  testWidgets('раз в минуту карусель сама листает на одну; листнул рукой — минута заново', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await remind('dentist', 'Зубной', const Duration(days: 2));
    await open(tester);
    await tester.pump(const Duration(seconds: 59));
    expect(lead('Закинуть футболку'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(lead('Футбольный матч'), findsOneWidget);

    // листнул рукой через 40 секунд — следующая сама только через минуту после этого
    await tester.pump(const Duration(seconds: 40));
    await swipe(tester, 1);
    expect(lead('Зубной'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(lead('Зубной'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(lead('Закинуть футболку'), findsOneWidget);
  });

  testWidgets('касание соседней выдвигает её в центр, а не открывает: и справа, и слева', (tester) async {
    await remind('shirt', 'Закинуть футболку', const Duration(hours: 1));
    await remind('match', 'Футбольный матч', const Duration(hours: 5));
    await remind('dentist', 'Зубной', const Duration(days: 2));
    await open(tester);
    final row = tester.getRect(find.byType(CarouselView));
    // край правой соседки
    await tester.tapAt(Offset(row.right - 12, row.center.dy));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsNothing);
    expect(lead('Футбольный матч'), findsOneWidget);

    // край левой: возвращает первую
    await tester.tapAt(Offset(row.left + 12, row.center.dy));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsNothing);
    expect(lead('Закинуть футболку'), findsOneWidget);
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
