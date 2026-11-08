/// Разница двух текстов по строкам: что осталось, что убрали, что добавили.
/// Для экрана истории заметки, без сети и без пакетов.
library;

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

/// Сколько строк добавлено и убрано: подпись версии в списке.
({int added, int removed}) diffCounts(List<DiffLine> lines) => (
  added: lines.where((line) => line.kind == DiffKind.added).length,
  removed: lines.where((line) => line.kind == DiffKind.removed).length,
);
