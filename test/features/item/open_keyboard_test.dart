import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

// тестировщик 23.11: «при открытии любой заметки клавиатура дёргано открывается и закрывается»
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> note(String id, String body) => world.db.into(world.db.items).insert(ItemsCompanion.insert(
        id: id,
        kind: ItemKind.note,
        title: body.split('\n').first,
        body: Value(body),
        createdAt: world.now.subtract(const Duration(hours: 1)),
        updatedAt: world.now.subtract(const Duration(hours: 1)),
      ));

  // команды клавиатуре: показать, спрятать, подключить и отключить поле
  List<String> keyboard(WidgetTester tester) => [
        for (final call in tester.testTextInput.log)
          if (const {'TextInput.show', 'TextInput.hide', 'TextInput.setClient', 'TextInput.clearClient'}.contains(call.method)) call.method,
      ];

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  testWidgets('заметка открывается с главной — клавиатуру никто не зовёт', (tester) async {
    await note('a', 'Ремонт\nкупить плитку');
    await open(tester);
    tester.testTextInput.log.clear();
    await tester.tap(find.text('Ремонт'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
    expect(keyboard(tester), isEmpty);
  });

  for (final length in [20, 4000]) {
    testWidgets('правка заметки в $length знаков: клавиатура встаёт один раз и не прячется', (tester) async {
      await note('a', 'Ремонт\n${List.filled(length ~/ 20, 'купить плитку, клей').join('\n')}');
      await open(tester);
      await tester.tap(find.text('Ремонт'));
      await tester.pumpAndSettle();
      tester.testTextInput.log.clear();
      await tester.tap(find.byTooltip('Править'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final calls = [
        for (final call in tester.testTextInput.log)
          if (call.method.startsWith('TextInput.') && call.method != 'TextInput.setEditingState' && call.method != 'TextInput.setEditableSizeAndTransform' && call.method != 'TextInput.setMarkedTextRect' && call.method != 'TextInput.setCaretRect' && call.method != 'TextInput.setStyle' && call.method != 'TextInput.setSelectionRects') call.method,
      ];
      expect(calls.where((call) => call == 'TextInput.show'), hasLength(1));
      expect(calls.where((call) => call == 'TextInput.hide' || call == 'TextInput.clearClient'), isEmpty);
      expect(calls.where((call) => call == 'TextInput.setClient' || call == 'TextInput.updateConfig'), hasLength(1));
    });
  }

  // тестировщик 23.11: «почему вибраций нет при удержании заметки или удалении» — удары Flutter на
  // Android (KEYBOARD_TAP) многие телефоны не передают, нужен системный LONG_PRESS
  testWidgets('долгое нажатие на заметку и «Удалить» вибрируют системным долгим нажатием', (tester) async {
    await note('a', 'Ремонт\nкупить плитку');
    await open(tester);
    final buzz = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') buzz.add(call.arguments as String?);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.longPress(find.text('Ремонт'));
    await tester.pumpAndSettle();
    // без вида удара: это HapticFeedback.vibrate() — LONG_PRESS на Android
    expect(buzz, [null]);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(buzz, [null, null]);
  });

  testWidgets('строка была в фокусе, открыл заметку — клавиатура прячется один раз и не встаёт снова', (tester) async {
    await note('a', 'Ремонт\nкупить плитку');
    await open(tester);
    await tester.showKeyboard(find.descendant(of: find.byType(LineDock), matching: find.byType(TextField)));
    await tester.pumpAndSettle();
    tester.testTextInput.log.clear();
    await tester.tap(find.text('Ремонт'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
    expect(keyboard(tester).where((call) => call == 'TextInput.show'), isEmpty);
    expect(keyboard(tester).where((call) => call == 'TextInput.setClient'), isEmpty);
  });
}
