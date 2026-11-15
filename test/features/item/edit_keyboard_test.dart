import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

/// Шаг «08-правка-заметки» прохода по экранам на iPhone: правка с открытой клавиатурой
/// не должна переполнять экран (симулятор iPhone 15 Pro, 15.11.2026: переполнение на 45 точек).
void main() {
  late TestWorld world;
  // настоящие шрифты: служебный шрифт тестов ниже, и ряды фиксированной высоты в нём помещаются
  setUpAll(() async {
    for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
      final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
      await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  /// iPhone 15 Pro: 393 × 852 точки, вырез сверху 59, полоска снизу 34, клавиатура с подсказками [keyboard].
  Future<void> iPhone(WidgetTester tester, {required double keyboard}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    tester.view.viewPadding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
    addTearDown(tester.view.reset);
  }

  testWidgets('как в проходе: заметка из ленты главной, «Править», клавиатура — главная под ней тоже цела', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.note,
          title: 'Купить батарейки для пульта',
          body: const Value('Купить батарейки для пульта'),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    await iPhone(tester, keyboard: 0);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Купить батарейки для пульта').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Править'));
    for (var keyboard = 0.0; keyboard <= 346; keyboard += 4) {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: 'клавиатура $keyboard точек');
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('клавиатура выезжает плавно — ни на одном шаге правка не переполняется', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.note,
          title: 'Купить батарейки для пульта',
          body: const Value('Купить батарейки для пульта'),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    await iPhone(tester, keyboard: 0);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Править'));
    // на iPhone клавиатура выезжает кадрами: отступ снизу растёт по чуть-чуть
    for (var keyboard = 0.0; keyboard <= 346; keyboard += 4) {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
      await tester.pump(const Duration(milliseconds: 16));
      final error = tester.takeException();
      expect(error, isNull, reason: 'клавиатура $keyboard точек');
    }
  });

  for (final keyboard in [0.0, 308.0, 346.0]) {
    testWidgets('правка заметки с клавиатурой $keyboard точек помещается', (tester) async {
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(
            id: 'a',
            kind: ItemKind.note,
            title: 'Купить батарейки для пульта',
            body: const Value('Купить батарейки для пульта'),
            createdAt: world.now,
            updatedAt: world.now,
          ));
      await iPhone(tester, keyboard: 0);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Править'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
