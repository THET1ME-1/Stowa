import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/composer/markdown_edit.dart';
import 'package:stowa/features/composer/wiki_link_edit.dart';

TextEditingValue at(String text, [int? caret]) => TextEditingValue(text: text, selection: TextSelection.collapsed(offset: caret ?? text.length));

void main() {
  test('второй «[» подряд дописывает «]]», курсор между скобками', () {
    final next = closeWikiBrackets(at('Купить ['), at('Купить [['));
    expect(next.text, 'Купить [[]]');
    expect(next.selection.baseOffset, 9);
  });

  test('одна скобка, вставка текста и уже закрытые — не трогает', () {
    expect(closeWikiBrackets(at('a'), at('a[')).text, 'a[');
    // вставили «[[x]]» целиком
    expect(closeWikiBrackets(at(''), at('[[x]]')).text, '[[x]]');
    // «]]» уже стоит за курсором
    expect(closeWikiBrackets(at('[]]', 1), at('[[]]', 2)).text, '[[]]');
  });

  test('выбор из подсказки ставит заголовок между скобками, курсор — за «]]»', () {
    final done = completeWikiLink(at('Купить [[пив]] сегодня', 12), 'Пиво я очень люблю');
    expect(done.text, 'Купить [[Пиво я очень люблю]] сегодня');
    expect(done.selection.baseOffset, 'Купить [[Пиво я очень люблю]]'.length);
    // без закрывающих — дописывает их
    final open = completeWikiLink(at('Купить [[пив'), 'Пиво');
    expect(open.text, 'Купить [[Пиво]]');
    expect(open.selection.baseOffset, open.text.length);
  });

  test('кнопка «Связь» вставляет [[]] с курсором внутри; выделенное слово становится запросом', () {
    final empty = applyMarkdown(at('Купить '), MarkdownAction.link);
    expect(empty.text, 'Купить [[]]');
    expect(empty.selection.baseOffset, 9);
    final word = applyMarkdown(const TextEditingValue(text: 'Купить пиво', selection: TextSelection(baseOffset: 7, extentOffset: 11)), MarkdownAction.link);
    expect(word.text, 'Купить [[пиво]]');
    expect(word.selection.baseOffset, 13);
  });
}
