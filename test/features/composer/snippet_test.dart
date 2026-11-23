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

  // тестировщик 23.11: строка лагала — каждая карточка на каждую букву разбирала весь конспект
  test('подпись длинной заметки — кусок у найденного, с отметкой и оформлением', () {
    final before = List.filled(300, '## Раздел\nобычная строка конспекта про базы данных').join('\n');
    final after = List.filled(300, 'хвост **жирный** конспекта').join('\n');
    final source = '$before\nтут **индекс** B-дерева\n$after';
    final at = source.indexOf('индекс');
    final line = subtitleOf(source, [(at, 6)])!;
    expect(line.text.length, lessThanOrEqualTo(subtitleLimit));
    final (start, length) = line.marks.single;
    expect(line.text.substring(start, start + length), 'индекс');
    // жирное у найденного осталось жирным, а значков «**» в подписи нет
    expect(line.text, isNot(contains('**')));
    expect(line.styles.any((style) => line.text.substring(style.$1, style.$1 + style.$2) == 'индекс'), isTrue);
  });

  test('короткая заметка — подпись как раньше', () {
    const source = 'Кофе в турке, **крепкий**';
    final line = subtitleOf(source, const [(0, 4)])!;
    expect(line.text, 'Кофе в турке, крепкий');
    expect(line.marks, [(0, 4)]);
  });
}
