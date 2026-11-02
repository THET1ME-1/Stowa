import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/composer/markdown_edit.dart';

TextEditingValue _at(String text, int caret, [int? end]) =>
    TextEditingValue(text: text, selection: TextSelection(baseOffset: caret, extentOffset: end ?? caret));

void main() {
  test('заголовок и чек-лист встают в начало строки с курсором', () {
    final heading = applyMarkdown(_at('Поездка\nпаспорт', 3), MarkdownAction.heading);
    expect(heading.text, '# Поездка\nпаспорт');
    expect(heading.selection.baseOffset, 5);
    final check = applyMarkdown(_at('Поездка\nпаспорт', 12), MarkdownAction.checklist);
    expect(check.text, 'Поездка\n- [ ] паспорт');
  });

  test('жирный оборачивает выделение, без выделения ставит курсор внутрь', () {
    final wrapped = applyMarkdown(_at('вылет в пятницу', 0, 5), MarkdownAction.bold);
    expect(wrapped.text, '**вылет** в пятницу');
    expect((wrapped.selection.start, wrapped.selection.end), (0, 9));
    final empty = applyMarkdown(_at('a ', 2), MarkdownAction.code);
    expect(empty.text, 'a ``');
    expect(empty.selection.baseOffset, 3);
  });
}
