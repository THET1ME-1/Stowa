import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/tokens.dart';
import 'package:stowa/features/item/markdown_controller.dart';

void main() {
  const source = '## План\nЭто **важно** и _тихо_\n- [x] сделано\n- пункт\n> цитата';

  // все куски по порядку, с их стилями
  List<TextSpan> flat(InlineSpan span) => [
    if (span is TextSpan && span.text != null) span,
    if (span is TextSpan) for (final child in span.children ?? const <InlineSpan>[]) ...flat(child),
  ];

  Future<List<TextSpan>> spans(WidgetTester tester) async {
    late List<TextSpan> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            result = flat(MarkdownController(text: source).buildTextSpan(context: context, style: const TextStyle(fontSize: 16), withComposing: false));
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('текст в поле тот же до буквы, меняется только вид', (tester) async {
    expect((await spans(tester)).map((span) => span.text).join(), source);
  });

  testWidgets('значки разметки приглушены, жирное жирным, сделанное зачёркнуто', (tester) async {
    final all = await spans(tester);
    TextSpan piece(String text) => all.firstWhere((span) => span.text == text);
    expect(piece('**').style!.color, Tokens.muted);
    expect(piece('важно').style!.fontWeight, FontWeight.w700);
    expect(piece('тихо').style!.fontStyle, FontStyle.italic);
    expect(piece('- [x] ').style!.color, Tokens.muted);
    expect(piece('сделано').style!.decoration, TextDecoration.lineThrough);
    expect(piece('План').style!.fontWeight, FontWeight.w700);
  });
}
