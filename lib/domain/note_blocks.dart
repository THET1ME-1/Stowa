import 'item_kind.dart';
import 'item_title.dart';

/// Кусок текста заметки, как его рисует страница вещи.
sealed class NoteBlock {
  const NoteBlock();
}

/// Строки подряд без пустой между ними: перенос внутри сохраняется.
class ParagraphBlock extends NoteBlock {
  const ParagraphBlock(this.text);
  final String text;
}

class HeadingBlock extends NoteBlock {
  const HeadingBlock(this.level, this.text);
  final int level;
  final String text;
}

class BulletBlock extends NoteBlock {
  const BulletBlock(this.text);
  final String text;
}

class NumberedBlock extends NoteBlock {
  const NumberedBlock(this.number, this.text);
  final int number;
  final String text;
}

/// Галочка помнит номер строки в тексте: касание переключает именно её.
class CheckBlock extends NoteBlock {
  const CheckBlock({required this.text, required this.done, required this.line});
  final String text;
  final bool done;
  final int line;
}

class QuoteBlock extends NoteBlock {
  const QuoteBlock(this.text);
  final String text;
}

final checkLine = RegExp(r'^\s*[-*] \[([ xX])\] (.*)$');
final _heading = RegExp(r'^(#{1,3}) (.+)$');
final _bullet = RegExp(r'^\s*[-*•] (.+)$');
final _numbered = RegExp(r'^\s*(\d{1,3})[.)] (.+)$');
final _quote = RegExp(r'^> ?(.*)$');

/// Текст заметки в блоки. [skipTitle]: первая строка, если из неё сделан заголовок, не повторяется.
List<NoteBlock> parseNoteBlocks(String body, {String? skipTitle}) {
  final lines = body.split('\n');
  final blocks = <NoteBlock>[];
  final paragraph = <String>[];
  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(ParagraphBlock(paragraph.join('\n')));
    paragraph.clear();
  }

  var titleSkipped = skipTitle == null;
  for (final (index, raw) in lines.indexed) {
    final line = raw.trimRight();
    if (!titleSkipped && line.trim().isNotEmpty) {
      titleSkipped = true;
      // строку с галочкой оставляем: без неё задачу не отметить
      if (!checkLine.hasMatch(line) && isTitleLine(line, skipTitle!)) continue;
    }
    if (line.trim().isEmpty) {
      flush();
      continue;
    }
    if (checkLine.firstMatch(line) case final check?) {
      flush();
      blocks.add(CheckBlock(text: check.group(2)!, done: check.group(1) != ' ', line: index));
    } else if (_heading.firstMatch(line) case final heading?) {
      flush();
      blocks.add(HeadingBlock(heading.group(1)!.length, heading.group(2)!));
    } else if (_bullet.firstMatch(line) case final bullet?) {
      flush();
      blocks.add(BulletBlock(bullet.group(1)!));
    } else if (_numbered.firstMatch(line) case final numbered?) {
      flush();
      blocks.add(NumberedBlock(int.parse(numbered.group(1)!), numbered.group(2)!));
    } else if (_quote.firstMatch(line) case final quote?) {
      flush();
      blocks.add(QuoteBlock(quote.group(1)!));
    } else {
      paragraph.add(line);
    }
  }
  flush();
  return blocks;
}

final _lineLead = RegExp(r'^(#{1,3} |\s*[-*] \[[ xX]\] |\s*[-*•] |> ?)', multiLine: true);

/// Текст без значков разметки для подсказок поиска; отметки совпадений сдвигаются следом.
(String, List<(int, int)>) stripMarkup(String text, List<(int, int)> marks) {
  // какие куски убрать: значки в начале строк и по краям выделения
  final cuts = <(int, int)>[
    for (final match in _lineLead.allMatches(text)) (match.start, match.end - match.start),
    for (final match in inlineMarks.allMatches(text)) ...() {
      final width = match.group(1) != null || match.group(4) != null ? 2 : 1;
      return [(match.start, width), (match.end - width, width)];
    }(),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  int moved(int offset) => offset - cuts.where((cut) => cut.$1 < offset).fold(0, (sum, cut) => sum + cut.$2);
  final plain = StringBuffer();
  var last = 0;
  for (final (start, length) in cuts) {
    if (start < last) continue;
    plain.write(text.substring(last, start));
    last = start + length;
  }
  plain.write(text.substring(last));
  return (plain.toString(), [for (final (start, length) in marks) (moved(start), length)]);
}

/// Кусок строки с его выделением.
typedef InlinePiece = ({String text, bool bold, bool italic, bool strike, bool code, String? url});

// выделение только по краям слова: «snake_case» и «2*3» остаются как есть
/// Строчная разметка: 1 — жирный, 2 и 3 — курсив, 4 — зачёркнутый, 5 — код.
final inlineMarks = RegExp(r'\*\*(.+?)\*\*|(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])|(?<!\w)_(?!\s)(.+?)(?<!\s)_(?!\w)|~~(.+?)~~|`(.+?)`');

/// Строка в куски: жирный, курсив, зачёркнутый, код, ссылки.
List<InlinePiece> parseInline(String text) {
  final pieces = <InlinePiece>[];
  void plain(String part) {
    var last = 0;
    for (final match in urlMatches(part)) {
      if (match.start > last) pieces.add((text: part.substring(last, match.start), bold: false, italic: false, strike: false, code: false, url: null));
      final raw = match.group(0)!;
      pieces.add((text: raw, bold: false, italic: false, strike: false, code: false, url: raw.contains('://') ? raw : 'https://$raw'));
      last = match.end;
    }
    if (last < part.length) pieces.add((text: part.substring(last), bold: false, italic: false, strike: false, code: false, url: null));
  }

  var last = 0;
  for (final match in inlineMarks.allMatches(text)) {
    if (match.start > last) plain(text.substring(last, match.start));
    final bold = match.group(1);
    final italic = match.group(2) ?? match.group(3);
    final strike = match.group(4);
    final code = match.group(5);
    pieces.add((text: bold ?? italic ?? strike ?? code!, bold: bold != null, italic: italic != null, strike: strike != null, code: code != null, url: null));
    last = match.end;
  }
  if (last < text.length) plain(text.substring(last));
  return pieces;
}
