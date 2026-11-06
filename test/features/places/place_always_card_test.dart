import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/places/place_always_card.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const Scaffold(body: PlaceAlwaysCard())));
    await tester.pumpAndSettle();
  }

  Future<void> remind(PlaceReminderKind? kind) => world.db.into(world.db.items).insert(
        ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Полить цветы', remindPlace: Value(kind), createdAt: world.now, updatedAt: world.now),
      );

  testWidgets('без напоминаний по месту карточки нет, даже без места «всегда»', (tester) async {
    await remind(null);
    await open(tester);
    expect(find.text('Нужно место «всегда»'), findsNothing);
  });

  testWidgets('напоминание по месту есть, места «всегда» нет — карточка; «Разрешить» спрашивает и убирает её', (tester) async {
    await remind(PlaceReminderKind.home);
    await open(tester);
    expect(find.text('Нужно место «всегда»'), findsOneWidget);
    await tester.tap(find.text('Разрешить'));
    await tester.pumpAndSettle();
    expect(world.placeChannel.asked, 1);
    expect(find.text('Нужно место «всегда»'), findsNothing);
  });

  testWidgets('место «всегда» уже разрешено — карточки нет', (tester) async {
    world.placeChannel.background = true;
    await remind(PlaceReminderKind.home);
    await open(tester);
    expect(find.text('Нужно место «всегда»'), findsNothing);
  });
}
