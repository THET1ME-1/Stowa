import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/services/notice_service.dart';

import '../../helpers/test_app.dart';

// хозяин 16.11: «Закрепить в уведомлениях. Будет на рабочем столе и на экране блокировки»
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> note() => world.db.into(world.db.items).insert(
    ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Сказать маме', body: const Value('Сказать маме\nпро субботу'), createdAt: world.now, updatedAt: world.now),
  );

  Future<DateTime?> noticeAt() async => (await world.db.select(world.db.items).getSingle()).noticeAt;

  testWidgets('«⋮» → «Закрепить в уведомлениях», плашка с «Отменить»; второй раз — «Убрать из уведомлений»', (tester) async {
    await note();
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закрепить в уведомлениях'));
    await tester.pumpAndSettle();
    expect(await noticeAt(), isNotNull);
    expect(find.text('Заметка закреплена в уведомлениях'), findsOneWidget);
    // разрешение спрашивается по действию
    expect(world.notifications.asked, 1);
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Убрать из уведомлений'));
    await tester.pumpAndSettle();
    expect(await noticeAt(), isNull);
  });

  testWidgets('главная показывает уведомление закреплённой и снимает убранную', (tester) async {
    await note();
    await world.db.update(world.db.items).write(ItemsCompanion(noticeAt: Value(world.now)));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    expect(world.notifications.pinned, {noticeNotificationId('a'): 'Сказать маме'});
    await world.db.update(world.db.items).write(const ItemsCompanion(noticeAt: Value(null)));
    await tester.pumpAndSettle();
    expect(world.notifications.pinned, isEmpty);
  });
}
