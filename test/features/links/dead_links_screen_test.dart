import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/home/note_timeline.dart';
import 'package:stowa/features/links/dead_links_screen.dart';
import 'package:stowa/services/link_checker.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> link(String id, String title, {bool gone = true, bool copy = false}) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(
        id: id,
        kind: ItemKind.link,
        title: title,
        url: Value('https://$id.md/page'),
        goneAt: Value(gone ? world.now : null),
        createdAt: world.now,
        updatedAt: world.now,
      ),
    );
    if (copy) {
      await world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'f$id', itemId: id, extractor: 'article', kind: FactKind.articleText, value: 'текст'));
    }
  }

  Future<void> open(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const DeadLinksScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('битые ссылки списком: «Оставить» убирает из списка, заметка остаётся', (tester) async {
    await link('a', 'Рецепт плова', copy: true);
    await link('b', 'Живая статья', gone: false);
    await open(tester);
    expect(find.text('Рецепт плова'), findsOneWidget);
    expect(find.text('Оригинал удалён · копия сохранена'), findsOneWidget);
    expect(find.text('Живая статья'), findsNothing);

    await tester.tap(find.text('Оставить'));
    await tester.pumpAndSettle();
    expect(find.text('Рецепт плова'), findsNothing);
    expect(find.text('Все ссылки открываются'), findsOneWidget);
    final kept = await world.db.select(world.db.items).get();
    expect(kept.firstWhere((item) => item.id == 'a').goneKept, isTrue);
    expect(kept.firstWhere((item) => item.id == 'a').deletedAt, isNull);
  });

  testWidgets('«Удалить» кладёт заметку в корзину, «Отменить» возвращает', (tester) async {
    await link('a', 'Рецепт плова');
    await open(tester);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.items).getSingle()).deletedAt, isNotNull);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.items).getSingle()).deletedAt, isNull);
  });

  testWidgets('«Проверить сейчас» находит умершую страницу', (tester) async {
    world.linkReplies['https://a.md/page'] = LinkReply.missing;
    await link('a', 'Рецепт плова', gone: false);
    await link('b', 'Живая статья', gone: false);
    await open(tester);
    expect(find.text('Все ссылки открываются'), findsOneWidget);
    await tester.tap(find.text('Проверить сейчас'));
    await tester.pumpAndSettle();
    expect(find.text('Рецепт плова'), findsOneWidget);
    expect(find.text('Ссылка не открывается'), findsOneWidget);
  });

  testWidgets('в ленте у мёртвой ссылки с копией — «Оригинал удалён · копия сохранена»', (tester) async {
    await link('a', 'Рецепт плова', copy: true);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(NoteTimeline), matching: find.text('Оригинал удалён · копия сохранена')), findsOneWidget);
  });
}
