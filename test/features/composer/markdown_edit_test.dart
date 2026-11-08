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

  test('картинки встают на место курсора отдельными строками, курсор — после них', () {
    final middle = insertImageLines(_at('Плитка\nклей', 6), ['a.jpg', 'b.jpg']);
    expect(middle.text, 'Плитка\n![[a.jpg]]\n![[b.jpg]]\nклей');
    expect(middle.selection.baseOffset, 'Плитка\n![[a.jpg]]\n![[b.jpg]]\n'.length);

    // посреди строки — строка разрывается
    expect(insertImageLines(_at('Плиткаклей', 6), ['a.jpg']).text, 'Плитка\n![[a.jpg]]\nклей');
    // в начале пустой строки и в конце текста — без лишних переносов
    expect(insertImageLines(_at('Плитка\n', 7), ['a.jpg']).text, 'Плитка\n![[a.jpg]]\n');
    expect(insertImageLines(_at('', 0), ['a.jpg']).text, '![[a.jpg]]\n');
    // выделенное заменяется
    expect(insertImageLines(_at('Плитка старое клей', 7, 13), ['a.jpg']).text, 'Плитка \n![[a.jpg]]\n клей');
  });

  test('имя вставленного фото: дата и время, без повторов в заметке', () {
    final at = DateTime(2026, 11, 8, 10, 15, 0);
    expect(photoFileName(at, 'jpg', const {}), 'IMG-20261108-101500.jpg');
    expect(photoFileName(at, 'png', const {'img-20261108-101500.png'}), 'IMG-20261108-101500-2.png');
  });
}
