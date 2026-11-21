import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/widgets/number_pad.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  // кнопка, которая открывает калькулятор и помнит ответ
  Future<List<int?>> open(WidgetTester tester) async {
    final answers = <int?>[];
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      world.wrap(
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async => answers.add(await showNumberPad(context, title: 'Заметность', min: 40, max: 100, unit: '%')),
              child: const Text('открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();
    return answers;
  }

  Future<void> press(WidgetTester tester, String keys) async {
    for (final key in keys.split('')) {
      await tester.tap(find.byKey(ValueKey('pad-$key')));
      await tester.pump();
    }
  }

  String board(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('pad-value'))).data!;
  FilledButton done(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const ValueKey('pad-done')));

  testWidgets('табло пустое, «Готово» погашено, пока числа нет', (tester) async {
    await open(tester);
    expect(board(tester), '—');
    expect(done(tester).onPressed, isNull);
  });

  testWidgets('больше максимума не набрать: лишняя цифра не встаёт', (tester) async {
    await open(tester);
    await press(tester, '999');
    expect(board(tester), '99');
    await press(tester, 'b');
    await press(tester, '0');
    expect(board(tester), '90');
  });

  testWidgets('меньше минимума — «Готово» погашено и подсказка о границах', (tester) async {
    await open(tester);
    await press(tester, '35');
    expect(done(tester).onPressed, isNull);
    expect(find.text('От 40 до 100 %'), findsOneWidget);
    await press(tester, 'bb45');
    expect(done(tester).onPressed, isNotNull);
  });

  testWidgets('«Готово» отдаёт число, смахнули — ничего', (tester) async {
    final answers = await open(tester);
    await press(tester, '100');
    await tester.tap(find.byKey(const ValueKey('pad-done')));
    await tester.pumpAndSettle();
    expect(answers, [100]);

    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    expect(answers, [100, null]);
  });

  testWidgets('с клавиатуры компьютера: цифры, стирание и Enter', (tester) async {
    final answers = await open(tester);
    // 6, 7, стереть, 8 с цифрового блока — 68
    for (final key in [LogicalKeyboardKey.digit6, LogicalKeyboardKey.digit7, LogicalKeyboardKey.backspace, LogicalKeyboardKey.numpad8]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    expect(board(tester), '68');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(answers, [68]);
  });
}
