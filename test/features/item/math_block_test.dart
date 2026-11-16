import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/note_blocks.dart';
import 'package:stowa/features/item/note_body.dart';

import '../../helpers/test_app.dart';

// хозяин 16.11: «есть поддержка LaTeX формул?» — «Да делай»
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> show(WidgetTester tester, String body) async {
    await tester.pumpWidget(
      world.wrap(SingleChildScrollView(child: NoteBody(blocks: parseNoteBlocks(body), onToggle: (_) {}, onEdit: () {}, onLink: (_) {}))),
    );
    await tester.pump();
  }

  testWidgets('блочная формула рисуется формулой, знаков доллара на экране нет', (tester) async {
    await show(tester, 'Закон\n\$\$\n\\frac{a}{b} = \\sum_{i=1}^{n} x_i\n\$\$');
    expect(find.byKey(const ValueKey('math-block')), findsOneWidget);
    expect(find.byType(Math), findsOneWidget);
    expect(find.textContaining(r'$$'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('строчная формула — в строке текста, текст вокруг на месте', (tester) async {
    await show(tester, r'Скорость $v = \frac{s}{t}$ постоянна, а цена $5 и $10');
    expect(find.byType(Math), findsOneWidget);
    expect(find.textContaining('постоянна', findRichText: true), findsOneWidget);
    expect(find.textContaining(r'цена $5 и $10', findRichText: true), findsOneWidget);
  });

  testWidgets('формула, которую не понять, — исходником с подписью LaTeX, а не ошибкой', (tester) async {
    await show(tester, '\$\$\n\\frac{a}{b\n\$\$');
    expect(tester.takeException(), isNull);
    expect(find.text('LaTeX'), findsOneWidget);
    expect(find.textContaining(r'\frac{a}{b', findRichText: true), findsOneWidget);
  });

  testWidgets('широкая формула листается вбок, вёрстка не ломается', (tester) async {
    await show(tester, '\$\$${List.filled(40, 'x_{i} + ').join()}y\$\$');
    expect(tester.takeException(), isNull);
    expect(find.descendant(of: find.byKey(const ValueKey('math-block')), matching: find.byType(SingleChildScrollView)), findsOneWidget);
  });
}
