import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/home/folder_shelf.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> links(int count) async {
    for (var index = 0; index < count; index++) {
      final at = world.now.subtract(Duration(hours: index + 1));
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(
            id: 'h$index',
            kind: ItemKind.link,
            title: 'Статья $index',
            url: Value('https://habr.com/ru/articles/$index/'),
            previewSite: const Value('Хабр'),
            createdAt: at,
            updatedAt: at,
          ));
    }
  }

  Future<void> open(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  testWidgets('8 ссылок с сайта без папки — карточка; «Сделать» заводит папку, «Отменить» убирает', (tester) async {
    await links(8);
    await open(tester);
    expect(find.text('8 ссылок с habr.com без папки'), findsOneWidget);
    expect(find.text('Сделать папку «Хабр»? Новые ссылки с этого сайта будут ложиться туда сами.'), findsOneWidget);

    await tester.tap(find.text('Сделать'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(FolderShelf), matching: find.text('Хабр')), findsOneWidget);
    expect(find.byKey(const ValueKey('folder-suggest')), findsNothing);
    expect(await world.db.select(world.db.rules).get(), hasLength(1));

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(FolderShelf), matching: find.text('Хабр')), findsNothing);
    expect(await world.db.select(world.db.rules).get(), isEmpty);
  });

  testWidgets('семь ссылок — не повод; отклонённое не приходит снова', (tester) async {
    await links(7);
    await open(tester);
    expect(find.byKey(const ValueKey('folder-suggest')), findsNothing);
    await tester.pumpWidget(const SizedBox());

    await links(0);
    world.dismissedSuggestions = {'site:habr.com'};
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'h7', kind: ItemKind.link, title: 'Ещё', url: const Value('https://habr.com/ru/articles/7/'), createdAt: world.now, updatedAt: world.now));
    await open(tester);
    expect(find.byKey(const ValueKey('folder-suggest')), findsNothing);
  });
}
