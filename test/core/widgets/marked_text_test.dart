import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/widgets/marked_text.dart';
import 'package:stowa/domain/note_blocks.dart';

void main() {
  // все куски текста по порядку, со стилями
  List<TextSpan> pieces(WidgetTester tester) {
    final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    return [for (final child in rich.children!) child as TextSpan];
  }

  testWidgets('подсказка: жирное жирным, сделанное зачёркнуто, совпадение подсвечено', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MarkedText(
          text: 'Приложение Togetherly ☑ Книги',
          marks: [(11, 10)],
          styles: [(11, 10, MarkupStyle.bold), (22, 7, MarkupStyle.done)],
          style: TextStyle(fontSize: 14),
          markColor: Colors.white24,
        ),
      ),
    );
    final all = pieces(tester);
    expect(all.map((span) => span.text).join(), 'Приложение Togetherly ☑ Книги');
    final bold = all.firstWhere((span) => span.text == 'Togetherly');
    expect(bold.style!.fontWeight, FontWeight.w700);
    expect(bold.style!.backgroundColor, Colors.white24);
    expect(all.firstWhere((span) => span.text!.contains('Книги')).style!.decoration, TextDecoration.lineThrough);
  });
}
