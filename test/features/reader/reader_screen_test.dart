import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/features/reader/reader_screen.dart';

import '../../helpers/test_app.dart';

const _url = 'https://blog.example.com/kofe';

String _page() => '<html><head><meta property="og:title" content="Кофе без турки"><meta property="og:site_name" content="Блог про кофе"></head><body><article>'
    '<p>Вода важнее зёрен, когда речь о вкусе, крепости и запахе по утрам, особенно зимой, когда за окном темно и хочется тёплого.</p>'
    '${[for (var index = 0; index < 8; index++) '<p>Абзац $index о том, как варить кофе дома без турки, если кофемашина дорогая, а вода из-под крана жёсткая, и почему помол важнее сорта, когда хочется крепкого кофе.</p>'].join()}'
    '<p>Последний абзац про чистую чашку.</p>'
    '</article></body></html>';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> link({DateTime? goneAt}) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(
        id: 'a',
        kind: ItemKind.link,
        title: 'Кофе без турки',
        url: const Value(_url),
        body: const Value(_url),
        previewAt: Value(world.now),
        goneAt: Value(goneAt),
        createdAt: world.now,
        updatedAt: world.now,
      ),
    );
    world.pages['a'] = _page();
  }

  Future<void> read(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ReaderScreen(itemId: 'a')));
    await tester.pumpAndSettle();
  }

  testWidgets('читалка: сайт, заголовок, время чтения и весь текст статьи', (tester) async {
    await link();
    await read(tester);
    expect(find.text('Блог про кофе'), findsOneWidget);
    expect(find.text('Кофе без турки'), findsOneWidget);
    expect(find.textContaining('мин чтения'), findsOneWidget);
    expect(find.textContaining('Вода важнее зёрен', findRichText: true), findsOneWidget);
    expect(find.byTooltip('Оригинал'), findsOneWidget);
    expect(find.text('Оригинал удалён · копия сохранена'), findsNothing);
  });

  testWidgets('сайт удалил страницу — над текстом сказано, что это копия', (tester) async {
    await link(goneAt: world.now);
    await read(tester);
    expect(find.text('Оригинал удалён · копия сохранена'), findsOneWidget);
  });

  testWidgets('копии нет — честно сказано и есть путь на сайт', (tester) async {
    await link();
    world.pages.remove('a');
    await read(tester);
    expect(find.text('Текст статьи не сохранился. Его можно открыть на сайте.'), findsOneWidget);
  });

  testWidgets('выделенное слово «Цитата» делает цитатой: она в базе и подсвечена', (tester) async {
    await link();
    await read(tester);
    // долгое нажатие выделяет слово, как в любом поле Android
    await tester.longPressAt(tester.getTopLeft(find.textContaining('Вода важнее', findRichText: true)) + const Offset(20, 12));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Цитата'));
    await tester.pumpAndSettle();
    final quote = (await world.db.select(world.db.highlights).getSingle()).quote;
    expect('Вода важнее зёрен', contains(quote));
    expect(find.byKey(const ValueKey('highlight-mark')), findsWidgets);
  });

  testWidgets('касание цитаты: пометка пишется, «Убрать» снимает с «Отменить»', (tester) async {
    await link();
    await world.db.into(world.db.highlights).insert(HighlightsCompanion.insert(id: 'h', itemId: 'a', quote: 'Вода важнее зёрен', createdAt: world.now));
    await read(tester);
    Future<void> tapQuote() async {
      await tester.tapOnText(find.textRange.ofSubstring('Вода важнее'));
      await tester.pumpAndSettle();
    }

    await tapQuote();
    await tester.enterText(find.byType(TextField), 'купить фильтр');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.highlights).getSingle()).note, 'купить фильтр');
    expect(find.text('купить фильтр'), findsOneWidget, reason: 'пометка видна под абзацем');

    await tapQuote();
    await tester.tap(find.text('Убрать'));
    await tester.pumpAndSettle();
    expect(await world.db.select(world.db.highlights).get(), isEmpty);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(await world.db.select(world.db.highlights).get(), hasLength(1));
  });

  testWidgets('место, где остановился, запоминается и открывается снова там же', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await link();
    await read(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final saved = (await world.db.select(world.db.items).getSingle()).readPosition;
    expect(saved, greaterThan(0.1));

    await tester.pumpWidget(world.wrap(const ReaderScreen(itemId: 'a')));
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.pixels / position.maxScrollExtent, closeTo(saved!, 0.02));
  });

  testWidgets('время чтения одно и то же на кнопке и в карточке страницы', (tester) async {
    await link();
    await world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'f', itemId: 'a', extractor: 'article', kind: FactKind.articleText, value: 'текст', number: const Value(320), detail: const Value('2')));
    // разметка страницы считает слова иначе: её 5 минут не спорят с кнопкой
    await world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'p', itemId: 'a', extractor: 'page', kind: FactKind.pageType, value: 'статья', detail: const Value('article')));
    await world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'r', itemId: 'a', extractor: 'page', kind: FactKind.readingTime, value: '5', number: const Value(5)));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    expect(find.text('Читать · 2 мин'), findsOneWidget);
    expect(find.text('2 мин чтения'), findsOneWidget);
    expect(find.text('5 мин чтения'), findsNothing);
  });

  testWidgets('страница ссылки: «Читать · N мин» открывает читалку, цитаты списком с пометкой', (tester) async {
    await link();
    await world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'f', itemId: 'a', extractor: 'article', kind: FactKind.articleText, value: 'текст', number: const Value(320), detail: const Value('2')));
    await world.db.into(world.db.highlights).insert(HighlightsCompanion.insert(id: 'h', itemId: 'a', quote: 'Вода важнее зёрен', note: const Value('купить фильтр'), createdAt: world.now));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    expect(find.text('Цитаты'), findsOneWidget);
    expect(find.text('Вода важнее зёрен'), findsOneWidget);
    expect(find.text('купить фильтр'), findsOneWidget);

    await tester.tap(find.text('Читать · 2 мин'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
  });
}
