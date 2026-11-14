import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/home/note_timeline.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  // строка ввода закрывает низ экрана: точка держится над ней
  const inset = 150.0;
  const screen = Size(400, 800);

  ItemCard note(String id, String body, int minutes) => ItemCard(
    id: id,
    title: id,
    body: body,
    kind: ItemKind.note,
    folderId: null,
    sortState: SortState.sorted,
    createdAt: world.now.subtract(Duration(minutes: minutes)),
  );

  Future<ScrollController> open(WidgetTester tester, List<ItemCard> items, {double before = 0}) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      world.wrap(
        Scaffold(
          body: CustomScrollView(
            controller: scroll,
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: before)),
              SliverToBoxAdapter(
                child: NoteTimeline(
                  items: items,
                  filesRoot: Directory.systemTemp,
                  now: world.now,
                  bottomInset: inset,
                  onOpen: (_) {},
                  onMove: (_) {},
                  onAct: (_) {},
                  onToggle: (_, _) {},
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1200)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return scroll;
  }

  /// Где на экране середина точки заметки.
  double dotY(WidgetTester tester, String id) {
    final dot = tester.renderObject<RenderTimelineDot>(find.byKey(ValueKey('dot-$id')));
    return dot.localToGlobal(Offset(0, dot.dotCenter)).dy;
  }

  Rect cardOf(WidgetTester tester, String id) => tester.getRect(find.byKey(ValueKey('dot-$id')));

  testWidgets('карточка видна целиком — точка у её низа, как аватарка в Telegram', (tester) async {
    await open(tester, [note('short', 'Купить хлеб', 1)]);
    final card = cardOf(tester, 'short');
    expect(dotY(tester, 'short'), closeTo(card.bottom - 22, 1));
  });

  testWidgets('низ карточки под строкой ввода — точка прилипает над строкой и едет с прокруткой до верха карточки', (tester) async {
    // карточка в ленте короткая: её низ уходит под строку ввода, потому что она сама у низа экрана
    final long = List.generate(8, (index) => 'строка ${index + 1} длинной заметки, которая занимает почти весь экран').join('\n');
    final scroll = await open(tester, [note('long', long, 1), note('next', 'Ниже', 2)], before: 480);
    final edge = screen.height - inset - 22;
    // низ карточки ниже кромки строки: точка на кромке
    expect(cardOf(tester, 'long').bottom, greaterThan(edge + 22));
    expect(dotY(tester, 'long'), closeTo(edge, 1));

    // листнули немного — точка стоит на месте, карточка едет под ней
    scroll.jumpTo(10);
    await tester.pump();
    expect(dotY(tester, 'long'), closeTo(edge, 1));

    // низ карточки поднялся над кромкой — точка снова у низа карточки
    scroll.jumpTo(cardOf(tester, 'long').bottom - edge + 10 + 40);
    await tester.pump();
    final card = cardOf(tester, 'long');
    expect(dotY(tester, 'long'), closeTo(card.bottom - 22, 1));
  });

  group('текст на карточке — две строки', () {
    testWidgets('длинный текст: две строки, конец растворяется, подпись «ещё N строк»', (tester) async {
      final long = ['Заголовок заметки', ...List.generate(12, (index) => 'Абзац ${index + 1}: длинная мысль, которую целиком читают уже на странице заметки')].join('\n');
      await open(tester, [note('long', long, 1)]);
      final excerpt = tester.widget<RichText>(find.descendant(of: find.byKey(const ValueKey('excerpt-long')), matching: find.byType(RichText)).first);
      expect(excerpt.maxLines, 2);
      expect(find.byKey(const ValueKey('excerpt-fade-long')), findsOneWidget);
      expect(find.textContaining(RegExp(r'^ещё \d+ строк')), findsOneWidget);
      // карточка невысокая: заголовок и две строки
      expect(cardOf(tester, 'long').height, lessThan(200));
    });

    testWidgets('короткий текст — без растворения и подписи', (tester) async {
      await open(tester, [note('short', 'Купить хлеб\nи молоко', 1)]);
      expect(find.byKey(const ValueKey('excerpt-fade-short')), findsNothing);
      expect(find.textContaining('строк'), findsNothing);
    });

    testWidgets('список: два пункта с галочками, остальные — «ещё N»', (tester) async {
      await open(tester, [note('list', '- [ ] хлеб\n- [ ] молоко\n- [x] сыр\n- [ ] яйца\n- [ ] масло', 1)]);
      expect(find.text('хлеб', findRichText: true), findsOneWidget);
      expect(find.text('молоко', findRichText: true), findsOneWidget);
      expect(find.text('сыр', findRichText: true), findsNothing);
      expect(find.text('ещё 3'), findsOneWidget);
    });
  });

  testWidgets('верх карточки сам у кромки строки — точка не выше уровня заголовка', (tester) async {
    // карточка начинается почти у строки ввода: прилипнуть выше своего верха точка не может
    await open(tester, [note('low', 'Внизу экрана', 1)], before: screen.height - inset - 30);
    final card = cardOf(tester, 'low');
    expect(dotY(tester, 'low'), closeTo(card.top + 18, 1));
  });
}
