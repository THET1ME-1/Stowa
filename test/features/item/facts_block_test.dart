import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_panel.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> fact(String itemId, FactKind kind, String value, {String? detail, double? number, DateTime? at, int position = 0}) => world.db
      .into(world.db.facts)
      .insert(
        FactsCompanion.insert(
          id: '$itemId-$kind-$position',
          itemId: itemId,
          extractor: 'text',
          kind: kind,
          value: value,
          detail: Value(detail),
          number: Value(number),
          at: Value(at),
          position: Value(position),
        ),
      );

  testWidgets('телефон, почта и сумма из текста — кнопками на странице вещи', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Мастер', body: const Value('Мастер +373 69 123 456, ivan@mail.md, диван 4 500 лей'), createdAt: world.now, updatedAt: world.now));
    await fact('a', FactKind.phone, '+373 69 123 456', detail: '+37369123456');
    await fact('a', FactKind.email, 'ivan@mail.md', position: 1);
    await fact('a', FactKind.price, '4 500 лей', detail: 'MDL', number: 4500, position: 2);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    final chips = find.byKey(const ValueKey('item-facts'));
    expect(find.descendant(of: chips, matching: find.text('+373 69 123 456')), findsOneWidget);
    expect(find.descendant(of: chips, matching: find.text('ivan@mail.md')), findsOneWidget);
    expect(find.descendant(of: chips, matching: find.text('4 500 лей')), findsOneWidget);
    expect(find.byTooltip('Позвонить'), findsOneWidget);
  });

  testWidgets('у фото — когда и чем снято', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'p', kind: ItemKind.image, title: 'Море', createdAt: world.now, updatedAt: world.now));
    await fact('p', FactKind.takenAt, '2024-05-03', at: DateTime(2024, 5, 3, 18, 42));
    await fact('p', FactKind.camera, 'Google Pixel 8', position: 1);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'p')));
    await tester.pumpAndSettle();
    // перед «г.» intl ставит неразрывный пробел
    expect(find.textContaining(RegExp(r'^Снято 3 мая 2024\sг\. · Google Pixel 8$')), findsOneWidget);
    expect(find.byKey(const ValueKey('item-facts')), findsNothing);
  });

  testWidgets('фраза из ролика: «в субтитрах · 0:42» и кнопка с этой секунды', (tester) async {
    await world.db
        .into(world.db.items)
        .insert(
          ItemsCompanion.insert(
            id: 'y',
            kind: ItemKind.video,
            title: 'Never Gonna Give You Up',
            url: const Value('https://youtu.be/dQw4w9WgXcQ'),
            factsText: const Value('Никогда не брошу'),
            createdAt: world.now,
            updatedAt: world.now,
          ),
        );
    await world.db
        .into(world.db.facts)
        .insert(FactsCompanion.insert(id: 'y1', itemId: 'y', extractor: 'subtitles', kind: FactKind.subtitle, value: 'Никогда не брошу', number: const Value(42.5)));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'брошу');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    final panel = find.byType(LinePanel);
    expect(find.descendant(of: panel, matching: find.textContaining('в субтитрах · 0:42')), findsOneWidget);
    final jump = find.byKey(const ValueKey('result-jump'));
    expect(find.descendant(of: jump, matching: find.text('0:42')), findsOneWidget);
  });

  Future<void> link(String id, String title, String url) => world.db
      .into(world.db.items)
      .insert(ItemsCompanion.insert(id: id, kind: ItemKind.link, title: title, url: Value(url), body: Value(url), previewAt: Value(world.now), createdAt: world.now, updatedAt: world.now));

  Future<void> pageFact(String itemId, FactKind kind, String value, {double? number, String? detail, DateTime? at, int position = 0}) => world.db
      .into(world.db.facts)
      .insert(
        FactsCompanion.insert(
          id: '$itemId-${kind.name}-$position',
          itemId: itemId,
          extractor: 'page',
          kind: kind,
          value: value,
          number: Value(number),
          detail: Value(detail),
          at: Value(at),
          position: Value(position),
        ),
      );

  testWidgets('рецепт: время, порции, ингредиенты и «В список покупок» — новая заметка-список', (tester) async {
    await link('r', 'Карбонара', 'https://food.md/carbonara');
    await pageFact('r', FactKind.pageType, 'рецепт recipe', detail: 'recipe');
    await pageFact('r', FactKind.ingredient, '200 г спагетти', position: 1);
    await pageFact('r', FactKind.ingredient, 'гуанчиале', position: 2);
    await pageFact('r', FactKind.timeNeeded, '25', number: 25, position: 3);
    await pageFact('r', FactKind.servings, '2', number: 2, position: 4);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'r')));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('item-page-card'));
    expect(find.descendant(of: card, matching: find.text('25 мин')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('2 порции')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('гуанчиале')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('recipe-shopping')));
    await tester.tap(find.byKey(const ValueKey('recipe-shopping')));
    await tester.pumpAndSettle();
    final note = await (world.db.select(world.db.items)..where((t) => t.id.isNotIn(['r']))).getSingle();
    expect(note.title, 'Купить: Карбонара');
    expect(note.body, contains('- [ ] гуанчиале'));
    expect(find.text('Список покупок готов'), findsOneWidget);
  });

  testWidgets('событие: день и время, место; главы ролика; теги автора ставятся касанием', (tester) async {
    await link('e', 'Концерт', 'https://afisha.md/concert');
    await pageFact('e', FactKind.pageType, 'событие event', detail: 'event');
    await pageFact('e', FactKind.eventStart, 'x', at: DateTime(2026, 11, 20, 19), position: 1);
    await pageFact('e', FactKind.eventEnd, 'x', at: DateTime(2026, 11, 20, 22), position: 2);
    await pageFact('e', FactKind.venue, 'Palatul Național', position: 3);
    await pageFact('e', FactKind.chapter, 'Начало', number: 0, position: 4);
    await pageFact('e', FactKind.chapter, 'Припев', number: 95, position: 5);
    await pageFact('e', FactKind.hashtag, 'концерт', position: 6);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'e')));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('item-page-card'));
    expect(find.descendant(of: card, matching: find.text('Пятница, 20 ноября, 19:00–22:00')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Palatul Național')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('item-chapters')), matching: find.text('1:35')), findsOneWidget);

    await tester.tap(find.text('#концерт'));
    await tester.pumpAndSettle();
    final tags = await world.db.select(world.db.tags).get();
    expect(tags.map((tag) => tag.name), contains('концерт'));
    expect(find.byKey(const ValueKey('item-suggested-tags')), findsNothing);
  });

  testWidgets('найденное в документе подписано листом', (tester) async {
    await world.db
        .into(world.db.items)
        .insert(ItemsCompanion.insert(id: 'x', kind: ItemKind.file, title: 'Смета', factsText: const Value('Плиточный клей'), createdAt: world.now, updatedAt: world.now));
    await world.db
        .into(world.db.facts)
        .insert(FactsCompanion.insert(id: 'x1', itemId: 'x', extractor: 'file_text', kind: FactKind.fileText, value: 'Плиточный клей', detail: const Value('sheet:Ремонт')));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'клей');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(LinePanel), matching: find.textContaining('в файле, лист «Ремонт»')), findsOneWidget);
  });
}
