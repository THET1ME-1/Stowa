import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/widgets/hint_banner.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/data/hints_repository.dart';
import 'package:stowa/domain/hints.dart';

import '../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld()..hints = HintsRepository.memory(HintsState.finished.copyWith(closed: const {})));
  tearDown(() => world.dispose());

  Future<void> show(WidgetTester tester, {bool when = true}) async {
    await tester.pumpWidget(world.wrap(HintBanner(tip: Tip.catalog, when: when)));
    await tester.pumpAndSettle();
  }

  testWidgets('показывается одной фразой, «×» закрывает навсегда', (tester) async {
    await show(tester);
    expect(find.text('Зажми папку и перетащи, чтобы поменять порядок.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hint-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hint-catalog')), findsNothing);
    expect(world.hints.state.closed, contains(Tip.catalog));
    await tester.pumpWidget(const SizedBox());
    await show(tester);
    expect(find.byKey(const ValueKey('hint-catalog')), findsNothing);
  });

  testWidgets('после трёх заходов не показывается', (tester) async {
    for (var visit = 0; visit < 3; visit++) {
      await tester.pumpWidget(const SizedBox());
      await show(tester);
      expect(find.byKey(const ValueKey('hint-catalog')), findsOneWidget, reason: 'заход ${visit + 1}');
    }
    await tester.pumpWidget(const SizedBox());
    await show(tester);
    expect(find.byKey(const ValueKey('hint-catalog')), findsNothing);
  });

  testWidgets('заметка: первое открытие — подсказка над нижней панелью', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Купить молоко', createdAt: world.now, updatedAt: world.now));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Купить молоко').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hint-noteBar')), findsOneWidget);
    expect(find.text('Внизу: напомнить, метка, другая папка и «поделиться».'), findsOneWidget);
  });

  testWidgets('условие не выполнено или подсказки выключены — пусто', (tester) async {
    await show(tester, when: false);
    expect(find.byKey(const ValueKey('hint-catalog')), findsNothing);
    expect(world.hints.state.shows[Tip.catalog], isNull);
    world.hints = HintsRepository.memory(const HintsState(off: true));
    await tester.pumpWidget(const SizedBox());
    await show(tester);
    expect(find.byKey(const ValueKey('hint-catalog')), findsNothing);
  });
}
