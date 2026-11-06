import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/return_plan.dart';
import 'package:stowa/features/folder/folder_cards.dart';
import 'package:stowa/features/returns/return_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld(now: DateTime(2026, 11, 6, 20, 30)));
  tearDown(() => world.dispose());

  Future<void> note(String title, DateTime created, {ItemKind kind = ItemKind.note, int? seconds, String? folder, String? body}) => world.db.into(world.db.items).insert(
        ItemsCompanion.insert(
          id: title,
          kind: kind,
          title: title,
          body: Value(body ?? title),
          url: Value(kind == ItemKind.note ? null : 'https://youtu.be/$title'),
          durationSeconds: Value(seconds),
          folderId: Value(folder),
          createdAt: created,
          updatedAt: created,
        ),
      );

  Future<void> open(WidgetTester tester, ReturnKind kind) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(ReturnScreen(kind: kind)));
    await tester.pumpAndSettle();
  }

  test('касание уведомления: экран возврата, заметка или, как у старых напоминаний, голый id', () {
    expect(notificationTarget('return:watchLater'), (kind: ReturnKind.watchLater, itemId: null));
    expect(notificationTarget('return:onThisDay'), (kind: ReturnKind.onThisDay, itemId: null));
    expect(notificationTarget('note:abc'), (kind: null, itemId: 'abc'));
    expect(notificationTarget('7c1e0b6a-1111'), (kind: null, itemId: '7c1e0b6a-1111'));
    expect(notificationTarget('return:чепуха'), (kind: null, itemId: null));
  });

  testWidgets('«Посмотреть потом»: сколько и на сколько минут, ролики списком, касание открывает', (tester) async {
    await note('Турка за 5 минут', world.now.subtract(const Duration(days: 1)), kind: ItemKind.video, seconds: 754);
    await note('Плов', world.now.subtract(const Duration(days: 2)), kind: ItemKind.video, seconds: 600);
    await open(tester, ReturnKind.watchLater);
    expect(find.text('Посмотреть потом'), findsOneWidget);
    expect(find.text('2 ролика — 23 минуты'), findsOneWidget);
    expect(find.text('Турка за 5 минут'), findsOneWidget);
    await tester.tap(find.text('Плов'));
    await tester.pumpAndSettle();
    // открытый ролик ушёл из очереди
    expect((await (world.db.select(world.db.items)..where((t) => t.id.equals('Плов'))).getSingle()).openedAt, isNotNull);
  });

  testWidgets('пустая очередь так и говорит', (tester) async {
    await open(tester, ReturnKind.watchLater);
    expect(find.text('Очередь пуста: всё свежее уже посмотрено.'), findsOneWidget);
  });

  testWidgets('«В этот день»: «Год назад» и заметки того дня', (tester) async {
    await note('Борщ бабушкин', DateTime(2025, 11, 6, 9));
    await note('Плов', DateTime(2025, 11, 6, 10));
    await open(tester, ReturnKind.onThisDay);
    expect(find.text('Год назад'), findsOneWidget);
    expect(find.text('Борщ бабушкин'), findsOneWidget);
    expect(find.text('Плов'), findsOneWidget);
  });

  testWidgets('короткая заметка во всю ширину, как ролик, а не по своему тексту', (tester) async {
    await note('Чай', DateTime(2025, 11, 6, 9));
    await note('Плов', DateTime(2025, 11, 6, 10), kind: ItemKind.video, seconds: 600);
    await open(tester, ReturnKind.onThisDay);
    final noteCard = tester.getRect(find.ancestor(of: find.text('Чай'), matching: find.byType(FolderItemCard)));
    final videoCard = tester.getRect(find.ancestor(of: find.text('Плов'), matching: find.byType(FolderItemCard)));
    expect((noteCard.left, noteCard.width), (videoCard.left, videoCard.width));
  });

  testWidgets('сводка недели: не открыты и без папки', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Рецепты', icon: 'folder', shape: 'pill'));
    await note('Идея', world.now.subtract(const Duration(days: 1)));
    await note('Рецепт', world.now.subtract(const Duration(days: 2)), folder: 'food');
    await open(tester, ReturnKind.week);
    expect(find.text('Неделя в Stowa'), findsOneWidget);
    expect(find.text('За неделю 2 заметки: 2 не открыты, 1 без папки'), findsOneWidget);
    expect(find.text('Не открыты'), findsOneWidget);
    // «Идея» и в «Не открыты», и в «Без папки»; «Рецепт» — только в первом
    await tester.scrollUntilVisible(find.text('Идея').last, 100);
    expect(find.text('Идея'), findsNWidgets(2));
    expect(find.text('Рецепт'), findsOneWidget);
  });

  testWidgets('покупки: списки с неотмеченными пунктами', (tester) async {
    await note('Купить: Борщ', world.now, body: 'Купить: Борщ\n- [ ] свёкла\n- [ ] морковь');
    await open(tester, ReturnKind.shopping);
    expect(find.text('Купить'), findsOneWidget);
    expect(find.text('Купить: Борщ'), findsOneWidget);
  });
}
