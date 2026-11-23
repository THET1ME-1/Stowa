import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/text_diff.dart';

void main() {
  String show(List<DiffLine> lines) => [
    for (final line in lines) '${switch (line.kind) { DiffKind.same => ' ', DiffKind.added => '+', DiffKind.removed => '-' }}${line.text}',
  ].join('\n');

  group('место одной правки', () {
    // «пить в 8 вечера»: время — кусок (7, 8)
    const before = 'пить в 8 вечера';

    test('стёртая цифра времени задевает его, буква в другом слове — нет', () {
      expect(editedRange(before, 'пить в  вечера').touches((7, 8)), isTrue);
      expect(editedRange(before, 'пиить в 8 вечера').touches((7, 8)), isFalse);
    });

    test('вставка внутрь задевает, вставка у края — нет', () {
      expect(editedRange('в 10', 'в 120').touches((2, 4)), isTrue);
      expect(editedRange('в 10', 'в 10 утра').touches((2, 4)), isFalse);
    });

    test('кусок после правки сдвигается на её длину, до правки остаётся', () {
      final edit = editedRange(before, 'ну, пить в 8 вечера');
      expect(edit.shift((7, 8)), (11, 12));
      expect(editedRange(before, 'пить в 8 вечера!').shift((7, 8)), (7, 8));
    });

    test('одинаковые буквы на стыке не путают место', () {
      final edit = editedRange('аааа', 'ааааа');
      expect((edit.start, edit.end, edit.delta), (4, 4, 1));
    });
  });

  test('одинаковые строки остаются, убранные и добавленные помечены', () {
    final diff = diffLines('Ремонт\nкупить клей\nплитка', 'Ремонт\nплитка\nзатирка');
    expect(show(diff), ' Ремонт\n-купить клей\n плитка\n+затирка');
  });

  test('изменённая строка — убранная и добавленная рядом', () {
    expect(show(diffLines('а\nб\nв', 'а\nБ\nв')), ' а\n-б\n+Б\n в');
  });

  test('пусто с одной стороны', () {
    expect(show(diffLines('', 'новое')), '+новое');
    expect(show(diffLines('старое', '')), '-старое');
    expect(diffLines('', ''), isEmpty);
  });

  test('огромный текст не вешает: без поиска общих строк', () {
    final a = List.generate(5000, (index) => 'строка $index').join('\n');
    final b = List.generate(5000, (index) => 'строка ${index + 1}').join('\n');
    final started = DateTime.now();
    final diff = diffLines(a, b);
    expect(DateTime.now().difference(started).inSeconds, lessThan(3));
    expect(diff.where((line) => line.kind == DiffKind.added), isNotEmpty);
  });

  test('сводка: сколько строк добавлено и убрано', () {
    final diff = diffLines('а\nб', 'а\nв\nг');
    expect(diffCounts(diff), (added: 2, removed: 1));
  });

  // изменённая строка подсвечивает сами слова: [] — кусок, которого нет на другой стороне
  group('разница слов', () {
    String marked(List<WordPiece> pieces) => [for (final piece in pieces) piece.changed ? '[${piece.text}]' : piece.text].join();

    test('слово заменено в середине строки', () {
      final (before, after) = diffWords('купить молоко и хлеб', 'купить кефир и хлеб');
      expect(marked(before), 'купить [молоко] и хлеб');
      expect(marked(after), 'купить [кефир] и хлеб');
    });

    test('знак препинания — отдельный кусок, кириллица и ё — слово целиком', () {
      final (before, after) = diffWords('Привет, мир', 'Привет! мир');
      expect(marked(before), 'Привет[,] мир');
      expect(marked(after), 'Привет[!] мир');
      final (_, word) = diffWords('ещё раз', 'еще раз');
      expect(marked(word), '[еще] раз');
    });

    test('подряд заменённые слова — одним куском вместе с пробелом между ними', () {
      final (before, after) = diffWords('встреча в пятницу утром у входа', 'встреча в субботу вечером у входа');
      expect(marked(before), 'встреча в [пятницу утром] у входа');
      expect(marked(after), 'встреча в [субботу вечером] у входа');
    });

    test('строки разницы: убранная и добавленная рядом становятся парой', () {
      final rows = diffRows('а\nкупить молоко\nб', 'а\nкупить кефир\nб');
      expect([for (final row in rows) row.kind], [DiffKind.same, DiffKind.removed, DiffKind.added, DiffKind.same]);
      expect(marked(rows[1].pieces!), 'купить [молоко]');
      expect(marked(rows[2].pieces!), 'купить [кефир]');
      expect(rows.first.pieces, isNull);
    });

    test('без пары и без общего — строка целиком, без подсветки слов', () {
      final rows = diffRows('а\nодин\nдва\nб', 'а\nодин раз\nб');
      expect(marked(rows[1].pieces!), 'один');
      expect(marked(rows[3].pieces!), 'один[ раз]');
      expect(rows[2].pieces, isNull);
      final other = diffRows('совсем другое', 'ничего общего тут');
      expect(other.every((row) => row.pieces == null), isTrue);
    });

    test('длинная строка не вешает', () {
      final a = List.generate(20000, (index) => 'слово$index').join(' ');
      final b = List.generate(20000, (index) => 'слово${index + 3}').join(' ');
      final started = DateTime.now();
      diffRows(a, b);
      expect(DateTime.now().difference(started).inSeconds, lessThan(3));
    });
  });
}
