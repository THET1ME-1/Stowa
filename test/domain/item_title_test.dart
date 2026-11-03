import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/item_title.dart';

void main() {
  test('ссылка уходит из заголовка, если без неё остались слова', () {
    expect(titleFor('Паста с креветками https://vt.tiktok.com/ZSpasta15/'), 'Паста с креветками');
    expect(titleFor('Смотри: https://coffee.ru/turka'), 'Смотри');
    expect(titleFor('https://coffee.ru/turka\nКофе в турке'), 'Кофе в турке');
  });

  test('одна ссылка без слов остаётся заголовком', () {
    expect(titleFor('https://coffee.ru/turka'), 'https://coffee.ru/turka');
  });

  test('разметка и теги снимаются, первая буква заглавная', () {
    expect(titleFor('## купить #дом молоко'), 'Купить молоко');
  });
}
