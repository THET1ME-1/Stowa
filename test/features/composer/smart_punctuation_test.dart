import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/composer/smart_punctuation.dart';

TextEditingValue at(String text, [int? caret]) => TextEditingValue(text: text, selection: TextSelection.collapsed(offset: caret ?? text.length));

/// Набрать [typed] по букве поверх [start], как клавиатура.
TextEditingValue type(String start, String typed) {
  var value = at(start);
  for (final char in typed.split('')) {
    final caret = value.selection.baseOffset;
    final next = TextEditingValue(text: value.text.replaceRange(caret, caret, char), selection: TextSelection.collapsed(offset: caret + 1));
    value = smartPunctuation(value, next);
  }
  return value;
}

void main() {
  test('<< и >> становятся ёлочками, курсор за кавычкой', () {
    final value = type('', 'Он сказал <<привет>>');
    expect(value.text, 'Он сказал «привет»');
    expect(value.selection.baseOffset, value.text.length);
  });

  test('-- становится длинным тире', () {
    expect(type('', 'Москва -- столица').text, 'Москва — столица');
  });

  test('посреди текста: замена на месте курсора, хвост не трогается', () {
    final value = smartPunctuation(at('а - б', 3), at('а -- б', 4));
    expect(value.text, 'а — б');
    expect(value.selection.baseOffset, 3);
  });

  test('--- в начале строки остаётся чертой Markdown', () {
    expect(type('Текст\n', '---').text, 'Текст\n---');
    expect(type('', '---').text, '---');
  });

  test('одна скобка, один дефис и список не трогаются', () {
    expect(type('', '- пункт').text, '- пункт');
    expect(type('', 'a < b > c').text, 'a < b > c');
  });

  test('вставка целиком и выделение не трогаются', () {
    expect(smartPunctuation(at(''), at('ls --all <<EOF')).text, 'ls --all <<EOF');
    final selected = const TextEditingValue(text: 'a-b', selection: TextSelection(baseOffset: 1, extentOffset: 2));
    expect(smartPunctuation(selected, at('a-b', 2)).text, 'a-b');
  });

  test('в коде не трогает: в `обратных кавычках` и в блоке ```', () {
    expect(type('Флаг `ls ', '--all`').text, 'Флаг `ls --all`');
    expect(type('```\n', 'a << b').text, '```\na << b');
    expect(type('```\nкод\n```\n', 'а -- б').text, '```\nкод\n```\nа — б');
  });

  // хозяин 16.11: «если открытую " то сразу поставится закрытая и курсор между ними, и с «» ',
  // все виды кавычек; << превращается в « — тоже закрытие ставить»
  group('парные кавычки', () {
    String shown(TextEditingValue value) => value.text.replaceRange(value.selection.baseOffset, value.selection.baseOffset, '|');

    test('открывающая ставит закрывающую, курсор между ними', () {
      expect(shown(type('', '"')), '"|"');
      expect(shown(type('Он сказал ', '«')), 'Он сказал «|»');
      expect(shown(type('Er sagte ', '„')), 'Er sagte „|“');
      expect(shown(type('He said ', '“')), 'He said “|”');
      expect(shown(type('He said ', '‘')), 'He said ‘|’');
      expect(shown(type('слово ', "'")), "слово '|'");
    });

    test('<< становится «» с курсором внутри; дописал и >> — шаг за кавычку', () {
      expect(shown(type('Он сказал ', '<<')), 'Он сказал «|»');
      expect(shown(type('Он сказал ', '<<привет>>')), 'Он сказал «привет»|');
    });

    test('набранная закрывающая перешагивает уже стоящую', () {
      expect(shown(type('', '"текст"')), '"текст"|');
      expect(shown(type('', '«текст»')), '«текст»|');
      expect(shown(type('', '„Text“')), '„Text“|');
    });

    test('апостроф внутри слова и кавычка после слова — одна, без пары', () {
      expect(shown(type('', "it's п'ять")), "it's п'ять|");
      expect(shown(type('Пишу слово', '"')), 'Пишу слово"|');
    });

    test('кавычка прямо перед словом — одна: слово закавычат следом', () {
      final value = smartPunctuation(at('сказал привет', 7), at('сказал «привет', 8));
      expect(shown(value), 'сказал «|привет');
    });

    test('стирание открывающей в пустой паре стирает и закрывающую', () {
      final value = smartPunctuation(at('Он сказал «»', 11), at('Он сказал »', 10));
      expect(shown(value), 'Он сказал |');
      final straight = smartPunctuation(at('""', 1), at('"', 0));
      expect(shown(straight), '|');
    });

    test('кавычка поверх выделения оборачивает его, выделение остаётся на слове', () {
      const old = TextEditingValue(text: 'Он сказал привет', selection: TextSelection(baseOffset: 10, extentOffset: 16));
      final value = smartPunctuation(old, at('Он сказал «', 11));
      expect(value.text, 'Он сказал «привет»');
      expect((value.selection.start, value.selection.end), (11, 17));
    });

    // хозяин 16.11: «написать 1+6=7, выделить и нажать $ — будет формула $1+6=7$? Ещё все
    // остальные двойные форматирования *тут выделенный текст*, кавычки, код»
    group('знак поверх выделения оборачивает его, как в Obsidian', () {
      /// Выделить [from]…[to] в [text] и набрать [char] поверх, как клавиатура.
      TextEditingValue over(String text, int from, int to, String char) {
        final old = TextEditingValue(text: text, selection: TextSelection(baseOffset: from, extentOffset: to));
        final next = TextEditingValue(text: text.replaceRange(from, to, char), selection: TextSelection.collapsed(offset: from + 1));
        return smartPunctuation(old, next);
      }

      String marked(TextEditingValue value) => value.text.replaceRange(value.selection.end, value.selection.end, ']').replaceRange(value.selection.start, value.selection.start, '[');

      test('формула, курсив, код, выделение маркером, скобки', () {
        expect(marked(over('Пример 1+6=7', 7, 12, r'$')), r'Пример $[1+6=7]$');
        expect(marked(over('тут текст', 4, 9, '*')), 'тут *[текст]*');
        expect(marked(over('тут текст', 4, 9, '_')), 'тут _[текст]_');
        expect(marked(over('флаг ls', 5, 7, '`')), 'флаг `[ls]`');
        expect(marked(over('важно', 0, 5, '=')), '=[важно]=');
        expect(marked(over('см. стр', 4, 7, '(')), 'см. ([стр])');
        expect(marked(over('массив', 0, 6, '[')), '[[массив]]');
      });

      test('второй раз — двойной знак: жирный, зачёркнутый, маркер', () {
        var value = over('тут текст', 4, 9, '*');
        final old = value;
        final next = TextEditingValue(text: old.text.replaceRange(old.selection.start, old.selection.end, '*'), selection: TextSelection.collapsed(offset: old.selection.start + 1));
        value = smartPunctuation(old, next);
        expect(marked(value), 'тут **[текст]**');
        var strike = over('старое', 0, 6, '~');
        strike = smartPunctuation(strike, TextEditingValue(text: strike.text.replaceRange(strike.selection.start, strike.selection.end, '~'), selection: TextSelection.collapsed(offset: strike.selection.start + 1)));
        expect(marked(strike), '~~[старое]~~');
      });

      test('буква поверх выделения заменяет его, как раньше', () {
        expect(over('тут текст', 4, 9, 'с').text, 'тут с');
      });

      test('в коде знак заменяет выделение, обёртки нет', () {
        expect(over('`код тут`', 1, 4, '*').text, '`* тут`');
      });
    });

    test('в коде и в формуле кавычки не парные', () {
      expect(shown(type('Флаг `', "'")), "Флаг `'|");
      expect(shown(type(r'$f', "'")), r"$f'|");
    });
  });
}
