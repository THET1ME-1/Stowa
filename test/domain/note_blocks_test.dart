import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/note_blocks.dart';

void main() {
  test('строки ленты: без строки-заголовка и пустых, пункты списка со своим номером строки', () {
    final lines = noteLinesUnderTitle('\nКупить\n- [ ] Молоко\n\n- [x] Хлеб\nв «Линелле»', 'Купить');
    expect([for (final line in lines) (line.index, line.text, line.done)], [(2, 'Молоко', false), (4, 'Хлеб', true), (5, 'в «Линелле»', null)]);
    // заголовок не из первой строки (имя файла Obsidian): первая строка — уже текст
    expect([for (final line in noteLinesUnderTitle('Первая\nВторая', 'Снаружи')) line.text], ['Первая', 'Вторая']);
  });

  test('отметка пункта переключает только свою строку, остальной текст как был', () {
    const body = 'Купить\n- [ ] Молоко\n  * [X] Хлеб\nв «Линелле»';
    expect(toggleCheckLine(body, 1), 'Купить\n- [x] Молоко\n  * [X] Хлеб\nв «Линелле»');
    expect(toggleCheckLine(body, 2), 'Купить\n- [ ] Молоко\n  * [ ] Хлеб\nв «Линелле»');
    expect(toggleCheckLine(body, 3), body);
  });

  test('строки подряд — один абзац, пустая строка начинает новый', () {
    final blocks = parseNoteBlocks('Список сокращений через\nBaaS — определение.\n\nРасширить до 40 страниц.');
    expect(blocks, hasLength(2));
    expect((blocks[0] as ParagraphBlock).text, 'Список сокращений через\nBaaS — определение.');
    expect((blocks[1] as ParagraphBlock).text, 'Расширить до 40 страниц.');
  });

  test('заголовки, пункты, нумерация, цитата', () {
    final blocks = parseNoteBlocks('## План\n- первое\n* второе\n1. раз\n2) два\n> важно');
    expect(blocks.map((block) => block.runtimeType), [HeadingBlock, BulletBlock, BulletBlock, NumberedBlock, NumberedBlock, QuoteBlock]);
    expect((blocks[0] as HeadingBlock).level, 2);
    expect((blocks[4] as NumberedBlock).number, 2);
    expect((blocks[5] as QuoteBlock).text, 'важно');
  });

  test('галочка помнит свою строку в тексте, чтобы её отметить', () {
    final blocks = parseNoteBlocks('Вылет в пятницу\n\n- [x] паспорт\n- [ ] крем');
    final checks = blocks.whereType<CheckBlock>().toList();
    expect([for (final check in checks) (check.text, check.done, check.line)], [('паспорт', true, 2), ('крем', false, 3)]);
  });

  test('жирный, курсив, зачёркнутый, код и ссылка внутри строки', () {
    final pieces = parseInline('Это **важно**, _тихо_, ~~было~~, `код` и coffee.ru/turka');
    expect([for (final piece in pieces) if (piece.bold) piece.text], ['важно']);
    expect([for (final piece in pieces) if (piece.italic) piece.text], ['тихо']);
    expect([for (final piece in pieces) if (piece.strike) piece.text], ['было']);
    expect([for (final piece in pieces) if (piece.code) piece.text], ['код']);
    expect([for (final piece in pieces) if (piece.url != null) piece.url], ['https://coffee.ru/turka']);
    expect(pieces.map((piece) => piece.text).join(), 'Это важно, тихо, было, код и coffee.ru/turka');
  });

  test('подсказка показывает разметку: жирное — жирным, галочка значком, пункт точкой', () {
    const text = 'Приложение **Togetherly**.\n- [ ] Источники\n- [x] Книги\n- пункт';
    final shown = renderMarkup(text, [(13, 10), (33, 9)]);
    expect(shown.text, 'Приложение Togetherly.\n☐ Источники\n☑ Книги\n• пункт');
    // отметки совпадений едут следом за текстом
    expect([for (final (start, length) in shown.marks) shown.text.substring(start, start + length)], ['Togetherly', 'Источники']);
    String styled(MarkupStyle style) => [for (final (start, length, kind) in shown.styles) if (kind == style) shown.text.substring(start, start + length)].join('|');
    expect(styled(MarkupStyle.bold), 'Togetherly');
    expect(styled(MarkupStyle.done), 'Книги');
  });

  test('курсив, зачёркнутый и код тоже приходят стилем', () {
    final shown = renderMarkup('_тихо_ ~~было~~ `код`', const []);
    expect(shown.text, 'тихо было код');
    expect([for (final (_, _, kind) in shown.styles) kind], [MarkupStyle.italic, MarkupStyle.strike, MarkupStyle.code]);
  });

  test('одиночная звёздочка или подчёркивание в слове — не разметка', () {
    expect(parseInline('snake_case и 2*3').single.text, 'snake_case и 2*3');
  });

  test('строка ![[имя]] — картинка между абзацами; размер Obsidian после | не мешает', () {
    final blocks = parseNoteBlocks('Плитка\n![[IMG-20261108-101500.jpg]]\nклей\n\n![[Кухня/фото.png|300]]');
    expect(blocks[0], isA<ParagraphBlock>());
    expect((blocks[1] as ImageBlock).name, 'IMG-20261108-101500.jpg');
    expect((blocks[2] as ParagraphBlock).text, 'клей');
    expect((blocks[3] as ImageBlock).name, 'Кухня/фото.png');
    // посреди строки — не картинка
    expect(parseNoteBlocks('смотри ![[x.jpg]] тут').single, isA<ParagraphBlock>());
  });

  test('имена картинок в тексте и путь вложения по имени', () {
    expect(embedNames('а\n![[a.jpg]]\nб\n![[Кухня/b.png|200]]'), ['a.jpg', 'Кухня/b.png']);
    const paths = ['Ремонт/Плитка/IMG-1.jpg', '.stowa/incoming/x/3_IMG-2.jpg', 'Ремонт/Плитка/Кухня.png'];
    expect(embedPath('IMG-1.jpg', paths), 'Ремонт/Плитка/IMG-1.jpg');
    // во входящих файл ждёт с номером порядка: имя то же
    expect(embedPath('IMG-2.jpg', paths), '.stowa/incoming/x/3_IMG-2.jpg');
    expect(embedPath('img-1.JPG', paths), 'Ремонт/Плитка/IMG-1.jpg');
    expect(embedPath('Ремонт/Плитка/Кухня.png', paths), 'Ремонт/Плитка/Кухня.png');
    expect(embedPath('нет.jpg', paths), isNull);
  });

  test('строки ленты без картинок из текста', () {
    expect([for (final line in noteLinesUnderTitle('Плитка\n![[a.jpg]]\nклей', 'Плитка')) line.text], ['клей']);
  });
}
