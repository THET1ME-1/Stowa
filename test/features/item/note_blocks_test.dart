import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/item/note_blocks.dart';

void main() {
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

  test('первая строка, ставшая заголовком, в тексте не повторяется', () {
    final blocks = parseNoteBlocks('Что взять на море\nкрем и шляпу', skipTitle: 'Что взять на море');
    expect((blocks.single as ParagraphBlock).text, 'крем и шляпу');
  });

  test('старый заголовок с точкой тоже узнаётся и не двоится', () {
    final blocks = parseNoteBlocks('Разработка архитектуры приложения.\nтекст', skipTitle: 'Разработка архитектуры приложения.');
    expect((blocks.single as ParagraphBlock).text, 'текст');
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

  test('одиночная звёздочка или подчёркивание в слове — не разметка', () {
    expect(parseInline('snake_case и 2*3').single.text, 'snake_case и 2*3');
  });
}
