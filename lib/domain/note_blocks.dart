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

/// Картинка между абзацами: строка `![[имя]]`, как пишет Obsidian. [name] — короткое
/// имя файла вложения или путь от корня хранилища.
class ImageBlock extends NoteBlock {
  const ImageBlock(this.name);
  final String name;
}

/// Строка-картинка целиком; размер Obsidian (`|300`) отбрасывается.
final embedLine = RegExp(r'^\s*!\[\[([^\]|]+)(?:\|[^\]]*)?\]\]\s*$');

/// Имена картинок в тексте заметки по порядку.
List<String> embedNames(String body) => [
  for (final line in body.split('\n'))
    if (embedLine.firstMatch(line) case final match?) match.group(1)!.trim(),
];

final _order = RegExp(r'^\d+_');

/// Путь вложения, на которое ссылается картинка в тексте: по пути целиком или по имени
/// файла без регистра. Во входящих файл ждёт с номером порядка («3_имя») — имя то же.
String? embedPath(String name, List<String> paths) {
  final wanted = name.toLowerCase();
  for (final path in paths) {
    if (path.toLowerCase() == wanted) return path;
  }
  for (final path in paths) {
    final base = path.split('/').last.replaceFirst(_order, '').toLowerCase();
    if (base == wanted || path.toLowerCase().endsWith('/$wanted')) return path;
  }
  return null;
}

final checkLine = RegExp(r'^\s*[-*] \[([ xX])\] (.*)$');
final _heading = RegExp(r'^(#{1,3}) (.+)$');
final _bullet = RegExp(r'^\s*[-*•] (.+)$');
final _numbered = RegExp(r'^\s*(\d{1,3})[.)] (.+)$');
final _quote = RegExp(r'^> ?(.*)$');

/// Текст заметки в блоки, все строки как написаны.
List<NoteBlock> parseNoteBlocks(String body) {
  final lines = body.split('\n');
  final blocks = <NoteBlock>[];
  final paragraph = <String>[];
  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(ParagraphBlock(paragraph.join('\n')));
    paragraph.clear();
  }

  for (final (index, raw) in lines.indexed) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      flush();
      continue;
    }
    if (embedLine.firstMatch(line) case final embed?) {
      flush();
      blocks.add(ImageBlock(embed.group(1)!.trim()));
    } else if (checkLine.firstMatch(line) case final check?) {
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

/// Строка заметки в ленте главной. [done] — галочка пункта, null у обычной строки.
class NoteLine {
  const NoteLine({required this.index, required this.text, this.done});

  /// Номер строки в тексте заметки: касание пункта переключает именно её.
  final int index;
  final String text;
  final bool? done;
}

/// Непустые строки под заголовком с их номерами. Первая пропускается, только если заголовок из неё.
List<NoteLine> noteLinesUnderTitle(String body, String title) {
  final lines = body.split('\n');
  final first = lines.indexWhere((line) => line.trim().isNotEmpty);
  final skip = first >= 0 && titleIsFirstLine(body, title) ? first : -1;
  return [
    for (final (index, line) in lines.indexed)
      // картинка из текста в ленте — фото карточки, а не строка `![[…]]`
      if (index != skip && line.trim().isNotEmpty && !embedLine.hasMatch(line))
        if (checkLine.firstMatch(line) case final check?)
          NoteLine(index: index, text: check.group(2)!, done: check.group(1) != ' ')
        else
          NoteLine(index: index, text: line.trim()),
  ];
}

final _checkMark = RegExp(r'^(\s*[-*] \[)([ xX])(\] .*)$');

/// Текст с переключённой галочкой в строке [index]; отступ и значок пункта как были.
String toggleCheckLine(String body, int index) {
  final lines = body.split('\n');
  if (index < 0 || index >= lines.length) return body;
  final match = _checkMark.firstMatch(lines[index]);
  if (match == null) return body;
  lines[index] = '${match.group(1)}${match.group(2) == ' ' ? 'x' : ' '}${match.group(3)}';
  return lines.join('\n');
}

/// Оформление, которое разметка даёт тексту: значков нет, есть стиль куска.
enum MarkupStyle { bold, italic, strike, code, heading, done }

final _leadKinds = RegExp(r'^(#{1,3} |\s*[-*] \[([ xX])\] |\s*[-*•] |> ?)');

/// Разметка в оформление для коротких подсказок: текст без значков, рядом — где какой
/// стиль. Галочка становится ☐ или ☑, пункт — точкой, как на странице вещи.
/// Отметки совпадений поиска сдвигаются следом за текстом.
({String text, List<(int, int)> marks, List<(int, int, MarkupStyle)> styles}) renderMarkup(String text, List<(int, int)> marks) {
  final out = StringBuffer();
  final styles = <(int, int, MarkupStyle)>[];
  // где в новом тексте оказался каждый знак старого: по этому едут отметки
  final moved = List<int>.filled(text.length + 1, 0);
  var from = 0;
  void keep(int start, int end) {
    for (var index = start; index < end; index++) {
      moved[index] = out.length;
      out.write(text[index]);
    }
  }

  void drop(int start, int end) {
    for (var index = start; index < end; index++) {
      moved[index] = out.length;
    }
  }

  for (final line in text.split('\n')) {
    final lineEnd = from + line.length;
    final lead = _leadKinds.firstMatch(line);
    var at = from;
    MarkupStyle? lineStyle;
    if (lead != null) {
      final sign = lead.group(0)!;
      drop(from, from + sign.length);
      if (sign.startsWith('#')) {
        lineStyle = MarkupStyle.heading;
      } else if (lead.group(2) != null) {
        final done = lead.group(2) != ' ';
        out.write(done ? '☑ ' : '☐ ');
        if (done) lineStyle = MarkupStyle.done;
      } else if (!sign.startsWith('>')) {
        out.write('• ');
      }
      at = from + sign.length;
    }
    final lineStart = out.length;
    for (final match in inlineMarks.allMatches(line, at - from)) {
      keep(at, from + match.start);
      final width = match.group(1) != null || match.group(4) != null ? 2 : 1;
      final style = match.group(1) != null
          ? MarkupStyle.bold
          : match.group(4) != null
          ? MarkupStyle.strike
          : match.group(5) != null
          ? MarkupStyle.code
          : MarkupStyle.italic;
      drop(from + match.start, from + match.start + width);
      final innerStart = out.length;
      keep(from + match.start + width, from + match.end - width);
      styles.add((innerStart, out.length - innerStart, style));
      drop(from + match.end - width, from + match.end);
      at = from + match.end;
    }
    keep(at, lineEnd);
    if (lineStyle != null && out.length > lineStart) styles.add((lineStart, out.length - lineStart, lineStyle));
    if (lineEnd < text.length) {
      moved[lineEnd] = out.length;
      out.write('\n');
    }
    from = lineEnd + 1;
  }
  moved[text.length] = out.length;
  styles.sort((a, b) => a.$1.compareTo(b.$1));
  return (
    text: out.toString(),
    marks: [
      for (final (start, length) in marks)
        if (start >= 0 && start + length <= text.length) (moved[start], moved[start + length] - moved[start]),
    ],
    styles: styles,
  );
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
