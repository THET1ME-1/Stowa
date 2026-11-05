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
