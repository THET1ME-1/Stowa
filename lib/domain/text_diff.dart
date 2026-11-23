/// Разница двух текстов по строкам: что осталось, что убрали, что добавили.
/// Для экрана истории заметки, без сети и без пакетов.
library;

import 'dart:typed_data';

/// Где одна правка поменяла текст: в прежнем тексте заменён кусок `[start, end)`, длина
/// изменилась на [delta]. Для набора: правка одна и у курсора.
class EditedRange {
  const EditedRange(this.start, this.end, this.delta);

  final int start;
  final int end;
  final int delta;

  /// Правка задела кусок прежнего текста `[from, to)`: стёрла или заменила в нём букву или
  /// вставила внутрь. Вставка у края кусок не трогает: «в 8» → «в 8 часов» — новая фраза,
  /// её узнаёт разбор, а не место правки.
  bool touches((int, int) span) => end > start ? start < span.$2 && end > span.$1 : start > span.$1 && start < span.$2;

  /// Кусок прежнего текста на его месте в новом. Задетый правкой остаётся где был.
  (int, int) shift((int, int) span) => span.$1 >= end && (end > start || span.$1 >= start) ? (span.$1 + delta, span.$2 + delta) : span;
}

/// Правка от [before] к [after]: общее начало и конец отрезаются, середина — правка.
/// Идёт по кодам букв, не собирая строк.
EditedRange editedRange(String before, String after) {
  final shortest = before.length < after.length ? before.length : after.length;
  var start = 0;
  while (start < shortest && before.codeUnitAt(start) == after.codeUnitAt(start)) {
    start++;
  }
  var tail = 0;
  while (tail < shortest - start && before.codeUnitAt(before.length - 1 - tail) == after.codeUnitAt(after.length - 1 - tail)) {
    tail++;
  }
  return EditedRange(start, before.length - tail, after.length - before.length);
}

enum DiffKind { same, added, removed }

class DiffLine {
  const DiffLine(this.kind, this.text);

  final DiffKind kind;
  final String text;
}

/// Таблица общих строк растёт как произведение длин: выше этого предела тексты
/// сравниваются целиком — всё старое убрано, всё новое добавлено.
const _maxCells = 4000000;

/// Строки [before] против [after]. Общее начало и конец отрезаются сразу,
/// середина сравнивается по самой длинной общей последовательности строк.
List<DiffLine> diffLines(String before, String after) {
  final a = before.isEmpty ? const <String>[] : before.split('\n');
  final b = after.isEmpty ? const <String>[] : after.split('\n');
  var head = 0;
  while (head < a.length && head < b.length && a[head] == b[head]) {
    head++;
  }
  var tail = 0;
  while (tail < a.length - head && tail < b.length - head && a[a.length - 1 - tail] == b[b.length - 1 - tail]) {
    tail++;
  }
  final midA = a.sublist(head, a.length - tail);
  final midB = b.sublist(head, b.length - tail);
  return [
    for (final line in a.take(head)) DiffLine(DiffKind.same, line),
    ..._middle(midA, midB),
    for (final line in a.skip(a.length - tail)) DiffLine(DiffKind.same, line),
  ];
}

List<DiffLine> _middle(List<String> a, List<String> b) {
  if (a.length * b.length > _maxCells) {
    return [for (final line in a) DiffLine(DiffKind.removed, line), for (final line in b) DiffLine(DiffKind.added, line)];
  }
  // длина общей последовательности для хвостов a[i..] и b[j..]
  final width = b.length + 1;
  final common = List<int>.filled((a.length + 1) * width, 0);
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      common[i * width + j] = a[i] == b[j] ? common[(i + 1) * width + j + 1] + 1 : _max(common[(i + 1) * width + j], common[i * width + j + 1]);
    }
  }
  final lines = <DiffLine>[];
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      lines.add(DiffLine(DiffKind.same, a[i]));
      i++;
      j++;
    } else if (common[(i + 1) * width + j] >= common[i * width + j + 1]) {
      // убранное раньше добавленного: изменённая строка читается «было → стало»
      lines.add(DiffLine(DiffKind.removed, a[i++]));
    } else {
      lines.add(DiffLine(DiffKind.added, b[j++]));
    }
  }
  for (; i < a.length; i++) {
    lines.add(DiffLine(DiffKind.removed, a[i]));
  }
  for (; j < b.length; j++) {
    lines.add(DiffLine(DiffKind.added, b[j]));
  }
  return lines;
}

int _max(int x, int y) => x > y ? x : y;

/// Кусок строки в разнице слов. [changed] — этого куска нет на другой стороне.
class WordPiece {
  const WordPiece(this.text, {this.changed = false});

  final String text;
  final bool changed;
}

/// Строка разницы для экрана. У изменённой строки, у которой нашлась пара на другой
/// стороне, — [pieces]: в них подсвечены сами слова.
class DiffRow {
  const DiffRow(this.kind, this.text, [this.pieces]);

  final DiffKind kind;
  final String text;
  final List<WordPiece>? pieces;
}

/// Слово целиком (буквы, цифры, знаки ударения), пробелы подряд или один знак.
final _tokenPattern = RegExp(r'[\p{L}\p{N}\p{M}_]+|\s+|.', unicode: true);

/// Предел таблицы общих слов: строка-абзац на пару тысяч слов ещё сравнивается.
const _maxWordCells = 1000000;

/// Пара строк похожа, если общих слов не меньше этой доли: иначе подсветка залила бы
/// всю строку и только мешала.
const _pairShare = 0.3;

/// Слова [before] против [after]: что убрано из первой строки и что добавлено во вторую.
(List<WordPiece>, List<WordPiece>) diffWords(String before, String after) {
  final words = _diffWords(before, after);
  return (words.before, words.after);
}

({List<WordPiece> before, List<WordPiece> after, double share}) _diffWords(String before, String after) {
  final a = [for (final match in _tokenPattern.allMatches(before)) match[0]!];
  final b = [for (final match in _tokenPattern.allMatches(after)) match[0]!];
  final changedA = List<bool>.filled(a.length, true);
  final changedB = List<bool>.filled(b.length, true);
  var head = 0;
  while (head < a.length && head < b.length && a[head] == b[head]) {
    changedA[head] = changedB[head] = false;
    head++;
  }
  var tail = 0;
  while (tail < a.length - head && tail < b.length - head && a[a.length - 1 - tail] == b[b.length - 1 - tail]) {
    changedA[a.length - 1 - tail] = changedB[b.length - 1 - tail] = false;
    tail++;
  }
  final rowsA = a.length - head - tail, rowsB = b.length - head - tail;
  if (rowsA > 0 && rowsB > 0 && rowsA * rowsB <= _maxWordCells) {
    // общие слова середины: та же таблица, что у строк
    final width = rowsB + 1;
    final common = Int32List((rowsA + 1) * width);
    for (var i = rowsA - 1; i >= 0; i--) {
      for (var j = rowsB - 1; j >= 0; j--) {
        common[i * width + j] = a[head + i] == b[head + j] ? common[(i + 1) * width + j + 1] + 1 : _max(common[(i + 1) * width + j], common[i * width + j + 1]);
      }
    }
    var i = 0, j = 0;
    while (i < rowsA && j < rowsB) {
      if (a[head + i] == b[head + j]) {
        changedA[head + i] = changedB[head + j] = false;
        i++;
        j++;
      } else if (common[(i + 1) * width + j] >= common[i * width + j + 1]) {
        i++;
      } else {
        j++;
      }
    }
  }
  var same = 0, wordsA = 0, wordsB = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i].trim().isEmpty) continue;
    wordsA++;
    if (!changedA[i]) same++;
  }
  for (final word in b) {
    if (word.trim().isNotEmpty) wordsB++;
  }
  final most = _max(wordsA, wordsB);
  return (before: _pieces(a, changedA), after: _pieces(b, changedB), share: most == 0 ? 1.0 : same / most);
}

// подряд идущие куски одного вида — одним куском; пробел между двумя заменёнными
// словами — часть замены: «[пятницу утром]», а не «[пятницу] [утром]»
List<WordPiece> _pieces(List<String> tokens, List<bool> changed) {
  for (var i = 1; i < tokens.length - 1; i++) {
    if (!changed[i] && tokens[i].trim().isEmpty && changed[i - 1] && changed[i + 1]) changed[i] = true;
  }
  final pieces = <WordPiece>[];
  final run = StringBuffer();
  for (var i = 0; i < tokens.length; i++) {
    if (i > 0 && changed[i] != changed[i - 1]) {
      pieces.add(WordPiece(run.toString(), changed: changed[i - 1]));
      run.clear();
    }
    run.write(tokens[i]);
  }
  if (tokens.isNotEmpty) pieces.add(WordPiece(run.toString(), changed: changed.last));
  return pieces;
}

/// Разница строк для экрана: убранная и добавленная строки рядом становятся парой, и в
/// паре подсвечены сами слова. Непохожие строки пары не получают.
List<DiffRow> diffRows(String before, String after) {
  final lines = diffLines(before, after);
  final rows = <DiffRow>[];
  var index = 0;
  while (index < lines.length) {
    if (lines[index].kind != DiffKind.removed) {
      rows.add(DiffRow(lines[index].kind, lines[index].text));
      index++;
      continue;
    }
    final removed = <DiffLine>[], added = <DiffLine>[];
    while (index < lines.length && lines[index].kind == DiffKind.removed) {
      removed.add(lines[index++]);
    }
    while (index < lines.length && lines[index].kind == DiffKind.added) {
      added.add(lines[index++]);
    }
    final pairs = [
      for (var k = 0; k < removed.length && k < added.length; k++)
        if (_diffWords(removed[k].text, added[k].text) case final words when words.share >= _pairShare) words else null,
    ];
    for (final (k, line) in removed.indexed) {
      rows.add(DiffRow(DiffKind.removed, line.text, k < pairs.length ? pairs[k]?.before : null));
    }
    for (final (k, line) in added.indexed) {
      rows.add(DiffRow(DiffKind.added, line.text, k < pairs.length ? pairs[k]?.after : null));
    }
  }
  return rows;
}

/// Сколько строк добавлено и убрано: подпись версии в списке.
({int added, int removed}) diffCounts(List<DiffLine> lines) => (
  added: lines.where((line) => line.kind == DiffKind.added).length,
  removed: lines.where((line) => line.kind == DiffKind.removed).length,
);
