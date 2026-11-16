import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/composer/markdown_edit.dart';
import 'package:stowa/features/composer/math_edit.dart';
import 'package:stowa/features/composer/smart_punctuation.dart';

// хозяин 16.11: «нет умного форматирования формул?» — «Сделай». Образец — Latex Suite
// с настройками по умолчанию, он стоит в хранилище College.

/// Текст с курсором «|» → значение поля.
TextEditingValue at(String marked) {
  final caret = marked.indexOf('|');
  return TextEditingValue(text: marked.replaceFirst('|', ''), selection: TextSelection.collapsed(offset: caret));
}

/// Значение поля → текст с курсором «|».
String shown(TextEditingValue value) => value.text.replaceRange(value.selection.baseOffset, value.selection.baseOffset, '|');

/// Набрать [typed] по одной букве, как клавиатура, через правку формул.
String type(String start, String typed) {
  var value = at(start);
  for (final char in typed.split('')) {
    final caret = value.selection.baseOffset;
    final next = TextEditingValue(text: value.text.replaceRange(caret, caret, char), selection: TextSelection.collapsed(offset: caret + 1));
    value = mathInput(value, next);
  }
  return shown(value);
}

/// Стереть букву перед курсором.
String backspace(String start) {
  final value = at(start);
  final caret = value.selection.baseOffset;
  final next = TextEditingValue(text: value.text.replaceRange(caret - 1, caret, ''), selection: TextSelection.collapsed(offset: caret - 1));
  return shown(mathInput(value, next));
}

void main() {
  group('где формула', () {
    test('внутри строчной и блочной формулы и пустой паре; цены и код — не формула', () {
      expect(mathAround(r'x $a+b$ y', 4)?.tex, 'a+b');
      expect(mathAround(r'x $a+b$ y', 1), isNull);
      expect(mathAround('\$\$\n\\frac{a}{b}\n\$\$', 5)?.display, isTrue);
      expect(mathAround(r'текст $|$'.replaceFirst('|', ''), 7)?.tex, '');
      expect(mathAround(r'Цена $5 и $10', 6), isNull);
      expect(mathAround('```\n\$a\$\n```', 5), isNull);
    });
  });

  group('пары', () {
    test('доллар ставит пару, второй делает блок, Enter раскрывает блок', () {
      expect(type('Скорость |', r'$'), r'Скорость $|$');
      expect(type(r'Скорость $|$', r'$'), r'Скорость $$|$$');
      expect(type(r'$$|$$', '\n'), '\$\$\n|\n\$\$');
    });

    test('закрывающий доллар перешагивается; цифра сразу после доллара — это цена, пара снимается', () {
      expect(type(r'$a|$', r'$'), r'$a$|');
      expect(type('Цена |', r'$5'), r'Цена $5|');
    });

    test('пробел сразу после доллара снимает пару; после буквы или цифры пары нет', () {
      expect(type('Стоит |', r'$ 5'), r'Стоит $ 5|');
      expect(type('Цена US|', r'$'), r'Цена US$|');
      expect(type('Цена 5|', r'$'), r'Цена 5$|');
    });

    test('скобки внутри формулы закрываются, закрывающая перешагивается, вне формулы — нет', () {
      expect(type(r'$|$', '{'), r'${|}$');
      expect(type(r'${a|}$', '}'), r'${a}|$');
      expect(type(r'$|$', '('), r'$(|)$');
      expect(type('текст |', '('), 'текст (|');
    });

    test('стирание открывающей стирает и пустую пару', () {
      expect(backspace(r'x $|$'), 'x |');
      expect(backspace(r'${|}$'), r'$|$');
    });
  });

  group('сокращения', () {
    test('степени, корень, дробь, знаки', () {
      expect(type(r'$x|$', 'sr'), r'$x^{2}|$');
      expect(type(r'$x|$', 'cb'), r'$x^{3}|$');
      expect(type(r'$|$', 'sq'), r'$\sqrt{|}$');
      expect(type(r'$|$', '//'), r'$\frac{|}{}$');
      expect(type(r'$a |$', '->'), r'$a \to|$');
      expect(type(r'$a |$', '<='), r'$a \leq|$');
      expect(type(r'$a |$', '!='), r'$a \neq|$');
      expect(type(r'$a |$', 'xx'), r'$a \times|$');
      expect(type(r'$a |$', '**'), r'$a \cdot|$');
      expect(type(r'$|$', 'ooo'), r'$\infty|$');
      expect(type(r'$|$', '+-'), r'$\pm|$');
    });

    test('греческие: @буква и имя целиком; имя внутри другого слова не срабатывает', () {
      expect(type(r'$|$', '@a'), r'$\alpha|$');
      expect(type(r'$|$', '@D'), r'$\Delta|$');
      expect(type(r'$|$', 'beta'), r'$\beta|$');
      expect(type(r'$|$', 'theta'), r'$\theta|$');
      expect(type(r'$|$', 'pi'), r'$\pi|$');
    });

    test('функции получают обратную черту, уже набранная команда не трогается', () {
      expect(type(r'$|$', 'sin'), r'$\sin|$');
      expect(type(r'$|$', 'arcsin'), r'$\arcsin|$');
      expect(type(r'$|$', 'ln'), r'$\ln|$');
      expect(type(r'$|$', r'\sqrt'), r'$\sqrt|$');
      expect(type(r'$|$', r'\sum'), r'$\sum|$');
    });

    test('индекс цифрой: x1 → x_{1}, вторая цифра — внутрь', () {
      expect(type(r'$|$', 'x1'), r'$x_{1}|$');
      expect(type(r'$|$', 'x12'), r'$x_{12}|$');
      expect(type(r'$|$', r'\log2'), r'$\log2|$');
    });

    test('вне формулы и внутри \\text{} ничего не срабатывает', () {
      expect(type('текст |', 'sr -> pi x1 a/'), 'текст sr -> pi x1 a/|');
      expect(type(r'$\text{|}$', 'sin pi'), r'$\text{sin pi|}$');
    });
  });

  group('дробь косой чертой', () {
    test('слово, скобка и команда уходят в числитель', () {
      expect(type(r'$|$', 'a/'), r'$\frac{a}{|}$');
      expect(type(r'$|$', '(x+1)/'), r'$\frac{x+1}{|}$');
      expect(type(r'$y = |$', '2x/'), r'$y = \frac{2x}{|}$');
      expect(type(r'$|$', r'\pi/'), r'$\frac{\pi}{|}$');
      expect(type(r'$|$', 'x^{2}/'), r'$\frac{x^{2}}{|}$');
    });
  });

  group('переход по полям', () {
    test('из числителя — в знаменатель, из знаменателя — за дробь, из конца — за формулу', () {
      expect(shown(mathTabOut(at(r'$\frac{a|}{}$'))), r'$\frac{a}{|}$');
      expect(shown(mathTabOut(at(r'$\frac{a}{b|}$'))), r'$\frac{a}{b}|$');
      expect(shown(mathTabOut(at(r'$\frac{a}{b}|$'))), r'$\frac{a}{b}$|');
      expect(shown(mathTabOut(at('\$\$\nx|\n\$\$'))), '\$\$\nx\n\$\$|');
      expect(shown(mathTabOut(at('вне |формулы'))), 'вне |формулы');
    });
  });

  group('кнопка «Формула»', () {
    test('выделенное оборачивается, без выделения — пустая пара с курсором внутри', () {
      expect(applyMarkdown(const TextEditingValue(text: 'E=mc^2', selection: TextSelection(baseOffset: 0, extentOffset: 6)), MarkdownAction.math).text, r'$E=mc^2$');
      expect(shown(applyMarkdown(at('x |'), MarkdownAction.math)), r'x $|$');
    });
  });

  group('типографика не трогает формулы', () {
    test('<< и -- внутри формулы остаются знаками', () {
      final value = at(r'$a <|$');
      final next = TextEditingValue(text: r'$a <<$', selection: const TextSelection.collapsed(offset: 5));
      expect(smartPunctuation(value, next).text, r'$a <<$');
    });
  });
}
