import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/note_blocks.dart';
import 'package:stowa/features/item/note_body.dart';

import '../../helpers/test_app.dart';

// хозяин 16.11: «красивые блоки кода и чтобы язык программирования был виден»
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

  String shown(WidgetTester tester) => tester.widget<RichText>(find.byKey(const ValueKey('code-text'))).text.toPlainText();

  testWidgets('подпись языка над блоком, код как написан, без значков разметки', (tester) async {
    await show(tester, 'До\n```python\ndef f():\n    # не заголовок\n    return **1**\n```');
    expect(find.text('Python'), findsOneWidget);
    expect(shown(tester), 'def f():\n    # не заголовок\n    return **1**');
    // подсветка: у кода больше одного цвета
    final colors = <Color?>{};
    tester.widget<RichText>(find.byKey(const ValueKey('code-text'))).text.visitChildren((span) {
      colors.add(span.style?.color);
      return true;
    });
    expect(colors.length, greaterThan(1));
  });

  testWidgets('без языка — без подписи; «Скопировать» кладёт код в буфер и на миг отвечает', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await show(tester, '```\nОн так работает\n```');
    expect(find.text('Python'), findsNothing);
    await tester.tap(find.byTooltip('Скопировать код'));
    await tester.pump();
    expect(copied, 'Он так работает');
    expect(find.byTooltip('Скопировано'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byTooltip('Скопировать код'), findsOneWidget);
  });

  testWidgets('длинный блок свёрнут, «Показать всё» раскрывает, «Свернуть» — обратно', (tester) async {
    final lines = [for (var number = 1; number <= 40; number++) 'print($number)'];
    await show(tester, '```py\n${lines.join('\n')}\n```');
    expect(find.text('Показать всё · 40 строк'), findsOneWidget);
    expect(shown(tester).split('\n').length, lessThan(40));
    await tester.tap(find.text('Показать всё · 40 строк'));
    await tester.pumpAndSettle();
    expect(shown(tester).split('\n'), hasLength(40));
    expect(find.text('Свернуть'), findsOneWidget);
  });

  testWidgets('длинная строка не ломает вёрстку, а листается вбок', (tester) async {
    await show(tester, '```sql\nSELECT ${List.filled(60, 'column_name').join(', ')} FROM t\n```');
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('code-scroll')), findsOneWidget);
  });
}
