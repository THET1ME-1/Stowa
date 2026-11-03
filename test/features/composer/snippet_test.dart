import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/composer/line_panel.dart';

void main() {
  test('подсказка начинается за слово до найденного, чтобы оно влезло и рядом с кнопкой', () {
    const text = 'Дипломная работа. Разработка кроссплатформенного мобильного приложения Togetherly.';
    final at = text.indexOf('Togetherly');
    final snippet = snippetOf(text, [(at, 10)]);
    expect(snippet, '…приложения Togetherly.');
    final (start, length) = snippetMarks(text, [(at, 10)]).single;
    expect(snippet.substring(start, start + length), 'Togetherly');
  });

  test('найденное близко к началу — подсказка с начала', () {
    expect(snippetOf('Кофе в турке', [(0, 4)]), 'Кофе в турке');
  });
}
