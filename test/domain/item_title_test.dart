import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/item_title.dart';

void main() {
  test('заголовок из первой строки узнаётся, свой заголовок — нет', () {
    expect(titleIsFirstLine('Борщ\nСвёкла 2 шт', 'Борщ'), isTrue);
    expect(titleIsFirstLine('\nразработка архитектуры.\nтекст', 'Разработка архитектуры'), isTrue);
    expect(titleIsFirstLine('Свёкла 2 шт', 'Борщ'), isFalse);
    expect(titleIsFirstLine('', 'Голосовое'), isFalse);
  });

  test('строка, которую правка унесла в заголовок, возвращается в текст', () {
    expect(bodyWithTitleLine('Свёкла 2 шт\nМорковь', 'Борщ'), 'Борщ\nСвёкла 2 шт\nМорковь');
    expect(bodyWithTitleLine('', 'Купить хлеб'), 'Купить хлеб');
    // строка на месте — чинить нечего
    expect(bodyWithTitleLine('Борщ\nСвёкла', 'Борщ'), isNull);
    // заголовок взят из середины строки: дата ушла, слово в тексте есть
    expect(bodyWithTitleLine('23 декабря 13:00 зубной', 'Зубной'), isNull);
    // копия при конфликте названа по-своему, текст у неё целый
    expect(bodyWithTitleLine('Борщ\nСвёкла', 'Борщ (Stowa)'), isNull);
  });

  test('строка из одной точки не роняет заголовок: берётся следующая, а без неё — сама точка', () {
    expect(titleFor('.\nвторая строка'), 'Вторая строка');
    expect(titleFor('.'), '.');
    expect(titleFor('https://eda.ru/borsch .'), 'https://eda.ru/borsch .');
  });

  test('ссылка уходит из заголовка, если без неё остались слова', () {
    expect(titleFor('Паста с креветками https://vt.tiktok.com/ZSpasta15/'), 'Паста с креветками');
    expect(titleFor('Смотри: https://coffee.ru/turka'), 'Смотри');
    expect(titleFor('https://coffee.ru/turka\nКофе в турке'), 'Кофе в турке');
  });

  test('одна ссылка без слов остаётся заголовком', () {
    expect(titleFor('https://coffee.ru/turka'), 'https://coffee.ru/turka');
  });

  test('имя файла: машинное в заголовок не идёт, человеческое — без расширения', () {
    expect(titleFor('', fileName: 'IMG_20261103_154512.jpg'), '');
    expect(titleFor('', fileName: 'Screenshot_20261103-154512_Chrome.png'), '');
    expect(titleFor('', fileName: 'PXL_20261103_154512345.MP.jpg'), '');
    expect(titleFor('', fileName: '1730645112345.jpg'), '');
    expect(titleFor('', fileName: 'VID-20261103-WA0007.mp4'), '');
    expect(titleFor('', fileName: 'Договор аренды.pdf'), 'Договор аренды');
    expect(titleFor('', fileName: 'отчёт по лабе 3.docx'), 'Отчёт по лабе 3');
  });

  test('скриншот узнаётся по имени файла', () {
    expect(isScreenshotName('Screenshot_20261103-154512_Chrome.png'), isTrue);
    expect(isScreenshotName('Снимок экрана 2026-11-03.png'), isTrue);
    expect(isScreenshotName('IMG_20261103_154512.jpg'), isFalse);
  });

  test('точка в конце заголовка снимается, многоточие и вопрос остаются', () {
    expect(titleFor('Разработка архитектуры приложения.'), 'Разработка архитектуры приложения');
    expect(titleFor('И что дальше...'), 'И что дальше...');
    expect(titleFor('Куда поехать?'), 'Куда поехать?');
  });

  test('разметка и теги снимаются, первая буква заглавная', () {
    expect(titleFor('## купить #дом молоко'), 'Купить молоко');
  });
}
