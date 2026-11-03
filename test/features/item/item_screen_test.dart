import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester, {required String body, required String title}) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.note,
          title: title,
          body: Value(body),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
  }

  testWidgets('у задачи видна галочка, касание её ставит', (tester) async {
    await open(tester, body: '- [ ] купить молоко', title: 'Купить молоко');
    expect(find.text('купить молоко'), findsOneWidget);
    await tester.tap(find.text('купить молоко'));
    await tester.pumpAndSettle();
    final item = await world.db.select(world.db.items).getSingle();
    expect(item.body, '- [x] купить молоко');
  });

  Future<Item> saved() => world.db.select(world.db.items).getSingle();

  testWidgets('карандаш открывает правку: заголовок и текст меняются, «Готово» сохраняет', (tester) async {
    await open(tester, body: 'Дипломная работа\nКлючевые слова оставить', title: 'Дипломная работа');
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Архитектура приложения');
    await tester.enterText(find.byType(TextField).last, 'Ключевые слова оставить\nМинимум 20 источников');
    await tester.tap(find.byTooltip('Готово'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect((await saved()).title, 'Архитектура приложения');
    expect((await saved()).body, 'Ключевые слова оставить\nМинимум 20 источников');
    expect(find.text('Архитектура приложения'), findsOneWidget);
  });

  testWidgets('касание по тексту тоже открывает правку', (tester) async {
    await open(tester, body: 'Мысль\nвторая строка мысли', title: 'Мысль');
    await tester.tap(find.textContaining('вторая строка'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('набранное сохраняется само, без «Готово»', (tester) async {
    await open(tester, body: 'Мысль', title: 'Мысль');
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Мысль\nдописал');
    await tester.pump(const Duration(seconds: 2));
    expect((await saved()).body, 'Мысль\nдописал');
  });

  testWidgets('панель правки: чек-лист ставит «- [ ] » в начало строки', (tester) async {
    await open(tester, body: 'купить хлеб', title: 'Покупки');
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    final body = find.byType(TextField).last;
    await tester.tap(body);
    tester.widget<TextField>(body).controller!.selection = const TextSelection.collapsed(offset: 3);
    await tester.tap(find.byTooltip('Чек-лист'));
    await tester.pump();
    expect(tester.widget<TextField>(body).controller!.text, '- [ ] купить хлеб');
  });

  testWidgets('разметка видна: жирное жирным, пункт с точкой, без звёздочек', (tester) async {
    await open(tester, body: 'План\nЭто **важно**\n- первое', title: 'План');
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('важно', findRichText: true), findsOneWidget);
    expect(find.textContaining('первое', findRichText: true), findsOneWidget);
  });

  testWidgets('папка сверху видна целиком', (tester) async {
    await open(tester, body: 'мысль', title: 'Мысль');
    final chip = tester.getSize(find.byType(ActionChip));
    expect(find.text('Без папки'), findsOneWidget);
    final label = tester.renderObject<RenderParagraph>(find.text('Без папки'));
    expect(label.didExceedMaxLines, isFalse);
    expect(chip.width, greaterThan(120));
  });
}
