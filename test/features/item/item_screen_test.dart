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

  testWidgets('папка сверху видна целиком', (tester) async {
    await open(tester, body: 'мысль', title: 'Мысль');
    final chip = tester.getSize(find.byType(ActionChip));
    expect(find.text('Без папки'), findsOneWidget);
    final label = tester.renderObject<RenderParagraph>(find.text('Без папки'));
    expect(label.didExceedMaxLines, isFalse);
    expect(chip.width, greaterThan(120));
  });
}
