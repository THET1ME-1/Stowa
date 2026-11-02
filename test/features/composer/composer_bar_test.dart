import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/composer/composer_bar.dart';
import 'package:stowa/features/composer/line_controller.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  late LineController line;
  late FocusNode focus;

  setUp(() {
    world = TestWorld();
    line = LineController(clock: () => world.now);
    focus = FocusNode();
  });
  tearDown(() async {
    line.dispose();
    focus.dispose();
    await world.dispose();
  });

  Future<void> pump(WidgetTester tester, {void Function(String id, DateTime? at)? onSaved}) async {
    // дерево снимается раньше, чем освобождается фокус
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(Align(
      alignment: Alignment.bottomCenter,
      child: ComposerBar(line: line, focusNode: focus, onSaved: onSaved),
    )));
  }

  testWidgets('дата в строке становится чипом напоминания, крестик его снимает', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '23 декабря 13:00 зубной');
    await tester.pumpAndSettle();
    expect(find.text('Напомню 23 декабря в 13:00'), findsOneWidget);

    await tester.tap(find.byTooltip('Не напоминать'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Напомню'), findsNothing);
  });

  testWidgets('дописанный тег встаёт чипом над строкой', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'рецепт #еда ');
    await tester.pumpAndSettle();
    expect(find.text('еда'), findsOneWidget);
    expect(line.text, 'рецепт ');
  });

  testWidgets('«Закинуть» сохраняет вещь и очищает строку', (tester) async {
    String? savedId;
    DateTime? savedAt;
    await pump(tester, onSaved: (id, at) {
      savedId = id;
      savedAt = at;
    });
    expect(find.text('Закинуть'), findsNothing);

    await tester.enterText(find.byType(TextField), '23 декабря 13:00 зубной');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закинуть'));
    await tester.pumpAndSettle();

    expect(line.text, isEmpty);
    expect(savedId, isNotNull);
    expect(savedAt, DateTime(2026, 12, 23, 13));
    final item = await (world.db.select(world.db.items)).getSingle();
    expect(item.title, 'Зубной');
    expect(item.reminderAt, DateTime(2026, 12, 23, 13));
  });

  testWidgets('на узком экране с крупным шрифтом ничего не вылезает', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'позвонить маме завтра в 19:30 #семья #важное #дом ');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
