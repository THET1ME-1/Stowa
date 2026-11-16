import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/code_language.dart';
import 'package:stowa/domain/note_blocks.dart';

void main() {
  // хозяин 16.11: «красивые блоки кода и чтобы язык программирования был виден»
  group('блоки кода', () {
    test('язык после кавычек, строки внутри как есть, без разметки', () {
      final blocks = parseNoteBlocks('До\n```python\ndef f():\n    # не заголовок\n    - [ ] не галочка\n\n    return 1\n```\nПосле');
      expect(blocks, hasLength(3));
      final code = blocks[1] as CodeBlock;
      expect(code.language, 'python');
      expect(code.code, 'def f():\n    # не заголовок\n    - [ ] не галочка\n\n    return 1');
      expect((blocks[2] as ParagraphBlock).text, 'После');
    });

    test('без языка, тильдами, незакрытый — до конца текста', () {
      expect((parseNoteBlocks('```\nОн так работает\n```').single as CodeBlock).language, isNull);
      expect((parseNoteBlocks('~~~sql\nSELECT 1\n~~~').single as CodeBlock).code, 'SELECT 1');
      expect((parseNoteBlocks('```js\nlet a\nlet b').single as CodeBlock).code, 'let a\nlet b');
      // закрывает только та же черта не короче открывающей
      expect((parseNoteBlocks('````md\n```\nвнутри\n```\n````').single as CodeBlock).code, '```\nвнутри\n```');
    });

    test('галочка внутри кода не переключается, картинка внутри кода — не картинка', () {
      const body = '```\n- [ ] пункт\n![[фото.jpg]]\n```\n- [ ] настоящий';
      expect(toggleCheckLine(body, 1), body);
      expect(embedNames(body), isEmpty);
      expect((parseNoteBlocks(body).last as CheckBlock).line, 4);
    });

    test('в ленте строки кавычек не показываются', () {
      final lines = noteLinesUnderTitle('Заметка\n```python\nprint(1)\n```', 'Заметка');
      expect(lines.map((line) => line.text), ['print(1)']);
    });
  });

  // хозяин 16.11: «есть поддержка LaTeX формул?» — в College 210 блочных формул в 53 заметках
  group('формулы', () {
    test('блочная формула на своих строках, в одну строку и с текстом на строках знаков', () {
      final blocks = parseNoteBlocks('Закон\n\$\$\n\\frac{a}{b} = c\n\\sum x\n\$\$\nДальше\n\$\$E = mc^2\$\$\n\$\$x +\ny\$\$');
      expect((blocks[1] as MathBlock).tex, '\\frac{a}{b} = c\n\\sum x');
      expect((blocks[2] as ParagraphBlock).text, 'Дальше');
      expect((blocks[3] as MathBlock).tex, 'E = mc^2');
      expect((blocks[4] as MathBlock).tex, 'x +\ny');
    });

    test('незакрытая формула — обычный текст; формула внутри кода — код', () {
      expect(parseNoteBlocks('\$\$\nx\nтекст').first, isA<ParagraphBlock>());
      expect(parseNoteBlocks('```\n\$\$\nx\n\$\$\n```').single, isA<CodeBlock>());
    });

    test('строчная формула — кусок с формулой, цены и знаки доллара — текст', () {
      final pieces = parseInline(r'Скорость $v = \frac{s}{t}$, а не $5 и $10, и не \$x\$');
      final math = [for (final piece in pieces) if (piece.math) piece.text];
      expect(math, [r'v = \frac{s}{t}']);
      expect(pieces.map((piece) => piece.text).join(), contains(r'а не $5 и $10'));
    });

    test('формула в строке рядом с кодом и жирным; внутри `кода` не формула', () {
      final pieces = parseInline(r'**жирно** $x^2$ и `$y$`');
      expect([for (final piece in pieces) if (piece.math) piece.text], ['x^2']);
      expect([for (final piece in pieces) if (piece.code) piece.text], [r'$y$']);
      expect([for (final piece in parseInline(r'итог $$a+b$$ тут')) if (piece.math) piece.text], ['a+b']);
    });
  });

  group('подпись языка', () {
    test('известные — красиво, псевдонимы — тем же языком, неизвестные — как написаны', () {
      expect(codeLanguage('python').label, 'Python');
      expect(codeLanguage('cpp').label, 'C++');
      expect(codeLanguage('c#').label, 'C#');
      expect(codeLanguage('js').label, 'JavaScript');
      expect(codeLanguage('js').highlight, 'javascript');
      expect(codeLanguage('dataviewjs').label, 'DataviewJS');
      expect(codeLanguage('dataviewjs').highlight, 'javascript');
      expect(codeLanguage('plsql').highlight, 'sql');
      expect(codeLanguage('html').highlight, 'xml');
      expect(codeLanguage('custom-frames').label, 'custom-frames');
      expect(codeLanguage('custom-frames').highlight, isNull);
      expect(codeLanguage('Python {.numberLines}').label, 'Python');
    });
  });

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

  test('в подсказке строки-картинки не видны, отметки совпадений едут следом', () {
    const text = 'Море у дома\n![[sea.jpg]]\nкупаться утром';
    final shown = renderMarkup(text, [(text.indexOf('утром'), 5)]);
    expect(shown.text, 'Море у дома\nкупаться утром');
    expect([for (final (start, length) in shown.marks) shown.text.substring(start, start + length)], ['утром']);
    expect(renderMarkup('Море\n![[sea.jpg]]', const []).text, 'Море');
  });

  test('[[Заметка]] — ссылка на заметку без скобок; подпись после | показывается вместо заголовка', () {
    final pieces = parseInline('Купить [[Пиво]] и [[Хлеб|хлебушек]], ![[фото.jpg]] не трогать');
    expect([for (final piece in pieces) if (piece.url != null) (piece.text, piece.url)], [('Пиво', 'stowa-note:Пиво'), ('хлебушек', 'stowa-note:Хлеб')]);
    expect(pieces.map((piece) => piece.text).join(), 'Купить Пиво и хлебушек, ![[фото.jpg]] не трогать');
    // в подсказках и карточках — тоже без скобок
    expect(renderMarkup('Купить [[Пиво]]', const []).text, 'Купить Пиво');
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
