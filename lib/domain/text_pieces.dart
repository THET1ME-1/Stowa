/// Кусок длинного текста для окна правки (`WindowedTextField`).
class TextPiece {
  const TextPiece(this.start, this.end, {this.open});

  final int start;
  final int end;

  /// Блок, открытый на начале куска: ограда кода («```», «~~~~») или «$$» формулы; нет — `null`.
  /// Правила набора видят только своё окно, и этим знаком им подсказывают, что они внутри блока.
  final String? open;

  @override
  bool operator ==(Object other) => other is TextPiece && other.start == start && other.end == end && other.open == open;

  @override
  int get hashCode => Object.hash(start, end, open);

  @override
  String toString() => 'TextPiece($start, $end, $open)';
}

/// Чем закрывается блок, открытый знаком [open].
String blockCloser(String open) => open;

/// Куски длинного текста: строки подряд, примерно по [target] знаков, между кусками ровно один
/// перенос строки. [open] — блок, открытый до начала [text] (так режется окно посреди текста).
///
/// Режется только по концу строки: посреди абзаца резать нельзя, переносы строк на экране
/// поменялись бы. Строка длиннее [target] остаётся одним куском. Блок кода (``` или ~~~) режется
/// как обычный текст: кусок помнит открытую ограду ([TextPiece.open]), и окно подсказывает её
/// правилам набора. Формула (`$$`) режется, только когда доросла до четырёх [target]: просмотр
/// формулы у курсора смотрит в одно окно, а незакрытый «$$» не делает окно огромным.
List<TextPiece> textPieces(String text, {int target = 700, String? open}) {
  final pieces = <TextPiece>[];
  var pieceStart = 0;
  var pieceOpen = open;
  var lineStart = 0;
  // открытый блок: знаки ограды кода или «$$» формулы
  var block = open;
  while (true) {
    final newline = text.indexOf('\n', lineStart);
    final lineEnd = newline < 0 ? text.length : newline;
    final line = text.substring(lineStart, lineEnd).trimLeft();
    block = _after(block, line);
    if (newline < 0) break;
    final size = lineEnd - pieceStart;
    if (size >= (block == r'$$' ? target * 4 : target)) {
      pieces.add(TextPiece(pieceStart, lineEnd, open: pieceOpen));
      pieceStart = lineEnd + 1;
      pieceOpen = block;
    }
    lineStart = lineEnd + 1;
  }
  pieces.add(TextPiece(pieceStart, text.length, open: pieceOpen));
  return pieces;
}

/// Какой блок открыт после строки [line] (без отступа слева), если до неё был открыт [block].
String? _after(String? block, String line) {
  if (block == r'$$') return _mathMarks(line).isOdd ? null : block;
  if (block != null) {
    final run = _fenceRun(line, block[0]);
    return run >= block.length && line.substring(run).trim().isEmpty ? null : block;
  }
  if (line.startsWith('```') || line.startsWith('~~~')) return line.substring(0, _fenceRun(line, line[0]));
  return _mathMarks(line).isOdd ? r'$$' : null;
}

// сколько знаков [mark] подряд в начале строки
int _fenceRun(String line, String mark) {
  var run = 0;
  while (run < line.length && line[run] == mark) {
    run++;
  }
  return run;
}

// сколько «$$» в строке, кроме экранированных
int _mathMarks(String line) {
  var count = 0;
  var at = line.indexOf(r'$$');
  while (at >= 0) {
    if (at == 0 || line[at - 1] != r'\') count++;
    at = line.indexOf(r'$$', at + 2);
  }
  return count;
}
