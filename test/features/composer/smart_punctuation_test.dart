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
}
