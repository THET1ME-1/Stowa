import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/copying_bar.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  // ролик, который ещё копирует окно «Поделиться»: задача занята им, главное окно её не трогает
  Future<void> copyingVideo() async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'v', kind: ItemKind.video, title: 'Отпуск', createdAt: world.now, updatedAt: world.now));
    await world.db
        .into(world.db.fileJobs)
        .insert(
          FileJobsCompanion.insert(
            id: 'j',
            itemId: 'v',
            position: 0,
            source: '/storage/DCIM/otpusk.mp4',
            target: 'attachments/v/0_otpusk.mp4',
            mime: 'video/mp4',
            size: 900 * 1024 * 1024,
            createdAt: world.now,
            claimedBy: const Value('share'),
            claimedUntil: Value(world.now.add(const Duration(minutes: 5)).millisecondsSinceEpoch),
          ),
        );
  }

  testWidgets('карточка с файлом, который ещё ложится, — с полоской; систему просят доделать', (tester) async {
    await copyingVideo();
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    expect(find.byType(CopyingBar), findsOneWidget);
    expect(world.fileWorkAsked, greaterThan(0));
  });

  testWidgets('страница вещи говорит, что файл сохраняется, и когда можно удалить оригинал', (tester) async {
    await copyingVideo();
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'v')));
    await tester.pumpAndSettle();
    expect(find.text('Сохраняю файл'), findsOneWidget);
    expect(find.textContaining('оригинал можно удалить'), findsOneWidget);
  });
}
