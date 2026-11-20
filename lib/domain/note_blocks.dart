import 'dart:math' show min;

import 'item_kind.dart';
import 'item_title.dart';
import 'note_links.dart' show noteLinkScheme, wikiLink;

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

/// Вид выноски Obsidian: свой цвет и значок. Синонимы сводятся к виду, как в Obsidian.
enum CalloutKind { note, abstract, info, todo, tip, success, question, warning, failure, danger, bug, example, quote }

const _calloutKinds = {
  'note': CalloutKind.note,
  'abstract': CalloutKind.abstract,
  'summary': CalloutKind.abstract,
  'tldr': CalloutKind.abstract,
  'info': CalloutKind.info,
  'todo': CalloutKind.todo,
  'tip': CalloutKind.tip,
  'hint': CalloutKind.tip,
  'important': CalloutKind.tip,
  'success': CalloutKind.success,
  'check': CalloutKind.success,
  'done': CalloutKind.success,
  'question': CalloutKind.question,
  'help': CalloutKind.question,
  'faq': CalloutKind.question,
  'warning': CalloutKind.warning,
  'caution': CalloutKind.warning,
  'attention': CalloutKind.warning,
  'failure': CalloutKind.failure,
  'fail': CalloutKind.failure,
  'missing': CalloutKind.failure,
  'danger': CalloutKind.danger,
  'error': CalloutKind.danger,
  'bug': CalloutKind.bug,
  'example': CalloutKind.example,
  'quote': CalloutKind.quote,
  'cite': CalloutKind.quote,
};

/// Выноска Obsidian: строка `> [!вид]± Заголовок`, под ней строки `> …`. Внутри — обычный
/// текст заметки своими блоками, в том числе другая выноска.
class CalloutBlock extends NoteBlock {
  const CalloutBlock({required this.type, required this.title, required this.fold, required this.blocks});

  /// Вид, как написан: `abstract`, `FAQ`, свой.
  final String type;

  /// Свой заголовок; null — заголовка нет, на экране имя вида.
  final String? title;

  /// `-` — свёрнута, `+` — раскрыта и сворачивается, null — не сворачивается.
  final String? fold;
  final List<NoteBlock> blocks;

  /// Неизвестный вид рисуется как заметка, с его именем.
  CalloutKind get kind => _calloutKinds[type.toLowerCase()] ?? CalloutKind.note;

  String get shownTitle => title ?? calloutTypeTitle(type);
}

/// Заголовок выноски без своего: имя вида с заглавной, как в Obsidian («Faq», «Рецепт»).
String calloutTypeTitle(String type) => type.isEmpty ? type : '${type[0].toUpperCase()}${type.substring(1).toLowerCase()}';

/// Первая строка выноски: вид, знак сворачивания, заголовок.
final calloutHead = RegExp(r'^>\s?\[!([^\]\s]+)\]([+-]?)\s*(.*)$');
final _quoteSign = RegExp(r'^> ?');
final _calloutMark = RegExp(r'^\[!([^\]\s]+)\][+-]?\s*');

/// Картинка между абзацами: строка `![[имя]]`, как пишет Obsidian. [name] — короткое
/// имя файла вложения или путь от корня хранилища.
class ImageBlock extends NoteBlock {
  const ImageBlock(this.name);
  final String name;
}

/// Блок кода между ``` или ~~~: строки внутри как есть, без разметки. [language] — слово
/// после открывающих кавычек («python», «dataviewjs»), без него — null.
class CodeBlock extends NoteBlock {
  const CodeBlock({required this.code, this.language});
  final String code;
  final String? language;
}

/// Формула LaTeX между `$$`: своей строкой по центру. [tex] — без знаков `$$`.
class MathBlock extends NoteBlock {
  const MathBlock(this.tex);
  final String tex;
}

/// Блочная формула, начатая со строки [index] знаками `$$`: её текст и последняя строка.
/// Незакрытая (второго `$$` нет до конца) — не формула, а обычный текст.
({String tex, int end})? _mathAt(List<String> lines, int index) {
  final first = lines[index].trim();
  if (!first.startsWith(r'$$')) return null;
  final head = first.substring(2);
  // в одну строку: $$E = mc^2$$
  if (head.trimRight().endsWith(r'$$') && head.trim().length > 2) {
    return (tex: head.trimRight().substring(0, head.trimRight().length - 2).trim(), end: index);
  }
  final body = <String>[if (head.trim().isNotEmpty) head.trim()];
  for (var end = index + 1; end < lines.length; end++) {
    final line = lines[end].trimRight();
    if (line.endsWith(r'$$')) {
      final tail = line.substring(0, line.length - 2).trim();
      if (tail.isNotEmpty) body.add(tail);
      return (tex: body.join('\n').trim(), end: end);
    }
    body.add(line);
  }
  return null;
}

final _fenceOpen = RegExp(r'^\s{0,3}(`{3,}|~{3,})\s*([^`\s]*)');

/// Блок кода в строках текста: [start] — строка открывающих кавычек, [end] — последняя
/// строка блока (закрывающие кавычки, если [closed]). Незакрытый идёт до конца текста.
typedef CodeRange = ({int start, int end, bool closed, String? language});

List<CodeRange> codeRanges(List<String> lines) {
  final ranges = <CodeRange>[];
  var index = 0;
  while (index < lines.length) {
    final open = _fenceOpen.firstMatch(lines[index]);
    if (open == null) {
      index++;
      continue;
    }
    final fence = open.group(1)!;
    final language = open.group(2)!.isEmpty ? null : open.group(2);
    // закрывают только те же знаки, не меньше числом, и ничего больше в строке
    final close = RegExp('^\\s{0,3}${RegExp.escape(fence[0])}{${fence.length},}\\s*\$');
    var end = index + 1;
    while (end < lines.length && !close.hasMatch(lines[end])) {
      end++;
    }
    final closed = end < lines.length;
    ranges.add((start: index, end: closed ? end : lines.length - 1, closed: closed, language: language));
    index = end + 1;
  }
  return ranges;
}

/// Номера строк внутри блоков кода вместе со строками кавычек: в них нет ни галочек,
/// ни картинок, ни заголовков.
Set<int> codeLines(List<String> lines) => {
  for (final range in codeRanges(lines))
    for (var index = range.start; index <= range.end; index++) index,
};

/// Строка-картинка целиком; размер Obsidian (`|300`) отбрасывается.
final embedLine = RegExp(r'^\s*!\[\[([^\]|]+)(?:\|[^\]]*)?\]\]\s*$');

/// Имена картинок в тексте заметки по порядку; `![[…]]` внутри блока кода — не картинка.
List<String> embedNames(String body) {
  final lines = body.split('\n');
  final code = codeLines(lines);
  return [
    for (final (index, line) in lines.indexed)
      if (!code.contains(index))
        if (embedLine.firstMatch(line) case final match?) match.group(1)!.trim(),
  ];
}

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

/// Текст заметки в блоки, все строки как написаны. [lineOffset] — номер первой строки [body]
/// в тексте заметки: у текста внутри выноски галочка переключает свою строку всего текста.
List<NoteBlock> parseNoteBlocks(String body, {int lineOffset = 0}) {
  final lines = body.split('\n');
  final blocks = <NoteBlock>[];
  final paragraph = <String>[];
  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(ParagraphBlock(paragraph.join('\n')));
    paragraph.clear();
  }

  final code = {for (final range in codeRanges(lines)) range.start: range};
  var skipTo = -1;
  for (final (index, raw) in lines.indexed) {
    if (index <= skipTo) continue;
    // блок кода: строки между кавычками как есть
    if (code[index] case final range?) {
      flush();
      final last = range.closed ? range.end - 1 : range.end;
      blocks.add(CodeBlock(code: lines.sublist(index + 1, last + 1).join('\n'), language: range.language));
      skipTo = range.end;
      continue;
    }
    if (_mathAt(lines, index) case final math?) {
      flush();
      blocks.add(MathBlock(math.tex));
      skipTo = math.end;
      continue;
    }
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
      blocks.add(CheckBlock(text: check.group(2)!, done: check.group(1) != ' ', line: lineOffset + index));
    } else if (_heading.firstMatch(line) case final heading?) {
      flush();
      blocks.add(HeadingBlock(heading.group(1)!.length, heading.group(2)!));
    } else if (_bullet.firstMatch(line) case final bullet?) {
      flush();
      blocks.add(BulletBlock(bullet.group(1)!));
    } else if (_numbered.firstMatch(line) case final numbered?) {
      flush();
      blocks.add(NumberedBlock(int.parse(numbered.group(1)!), numbered.group(2)!));
    } else if (calloutHead.firstMatch(line) case final head?) {
      flush();
      // строки выноски — подряд идущие с «>»; знак снимается один раз, внутри бывает своя выноска
      var end = index;
      while (end + 1 < lines.length && lines[end + 1].trimLeft().startsWith('>')) {
        end++;
      }
      final inner = [for (var at = index + 1; at <= end; at++) lines[at].trimLeft().replaceFirst(_quoteSign, '')];
      final title = head.group(3)!.trim();
      blocks.add(
        CalloutBlock(
          type: head.group(1)!,
          title: title.isEmpty ? null : title,
          fold: head.group(2)!.isEmpty ? null : head.group(2),
          blocks: parseNoteBlocks(inner.join('\n'), lineOffset: lineOffset + index + 1),
        ),
      );
      skipTo = end;
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
/// Блоки-запросы плагинов Obsidian: Dataview, Tasks и встроенный поиск.
const _queryLanguages = {'dataview', 'dataviewjs', 'tasks', 'query'};

List<NoteLine> noteLinesUnderTitle(String body, String title) {
  if (repeatsTitle(body, title)) return const [];
  final lines = body.split('\n');
  final first = lines.indexWhere((line) => line.trim().isNotEmpty);
  final skip = first >= 0 && titleIsFirstLine(body, title) ? first : -1;
  // строки кавычек блока кода в ленте не нужны, код внутри — как текст. Запрос Dataview —
  // вызов плагина Obsidian, а не текст заметки: в ленте его нет целиком
  final ranges = codeRanges(lines);
  final fences = {
    for (final range in ranges)
      if (_queryLanguages.contains(range.language?.toLowerCase()))
        for (var line = range.start; line <= range.end; line++) line
      else ...[range.start, if (range.closed) range.end],
  };
  final code = codeLines(lines);
  return [
    for (final (index, line) in lines.indexed)
      // картинка из текста в ленте — фото карточки, а не строка `![[…]]`
      // строка из одних «$$» — знаки блочной формулы, не текст
      if (index != skip && !fences.contains(index) && line.trim().isNotEmpty && line.trim() != r'$$' && (code.contains(index) || !embedLine.hasMatch(line)))
        if (code.contains(index) ? null : checkLine.firstMatch(line) case final check?)
          NoteLine(index: index, text: check.group(2)!, done: check.group(1) != ' ')
        else
          NoteLine(index: index, text: line.trim()),
  ];
}

// галочка бывает и внутри выноски: «> - [ ] дело»
final _checkMark = RegExp(r'^((?:\s*> ?)*\s*[-*] \[)([ xX])(\] .*)$');

/// Текст с переключённой галочкой в строке [index]; отступ и значок пункта как были.
String toggleCheckLine(String body, int index) {
  final lines = body.split('\n');
  if (index < 0 || index >= lines.length) return body;
  // «- [ ]» внутри блока кода — текст кода, не дело
  if (codeLines(lines).contains(index)) return body;
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
    // строка-картинка в подсказке не видна: у карточки своё фото
    if (embedLine.hasMatch(line)) {
      drop(from, min(lineEnd + 1, text.length));
      from = lineEnd + 1;
      continue;
    }
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
    // выноска: вместо «[!abstract]» — её заголовок жирным, без него — имя вида
    var calloutTitle = '';
    if (lead != null && lead.group(0)!.startsWith('>')) {
      if (_calloutMark.firstMatch(line.substring(at - from)) case final mark?) {
        drop(at, at + mark.end);
        at += mark.end;
        if (line.substring(at - from).trim().isEmpty) calloutTitle = calloutTypeTitle(mark.group(1)!);
        lineStyle = MarkupStyle.bold;
      }
    }
    final lineStart = out.length;
    out.write(calloutTitle);
    // разметка и [[ссылки]] по порядку; наложившиеся не берутся
    final found = <(int start, int end, int innerStart, int innerEnd, MarkupStyle? style)>[
      for (final match in inlineMarks.allMatches(line, at - from))
        if ((match.group(1) != null || match.group(4) != null || match.group(6) != null ? 2 : 1) case final width)
          (
            match.start,
            match.end,
            match.start + width,
            match.end - width,
            match.group(1) != null
                ? MarkupStyle.bold
                : match.group(4) != null
                ? MarkupStyle.strike
                // формула в подсказке и ленте — исходником моноширинным, как код
                : match.group(5) != null || match.group(6) != null || match.group(7) != null
                ? MarkupStyle.code
                : MarkupStyle.italic,
          ),
      // [[Заметка]] — видна без скобок, [[Заметка|подпись]] — подписью
      for (final match in wikiLink.allMatches(line, at - from))
        if (match.group(2) case final label? when label.trim().isNotEmpty)
          (match.start, match.end, match.end - 2 - label.length, match.end - 2, null)
        else
          (match.start, match.end, match.start + 2, match.start + 2 + match.group(1)!.length, null),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    var lastEnd = at - from;
    for (final (start, end, innerStart, innerEnd, style) in found) {
      if (start < lastEnd) continue;
      keep(at, from + start);
      drop(from + start, from + innerStart);
      final shownStart = out.length;
      keep(from + innerStart, from + innerEnd);
      if (style != null) styles.add((shownStart, out.length - shownStart, style));
      drop(from + innerEnd, from + end);
      at = from + end;
      lastEnd = end;
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
  // картинка последней строкой оставила бы перенос в конце
  var shown = out.toString();
  while (shown.endsWith('\n') && !text.endsWith('\n')) {
    shown = shown.substring(0, shown.length - 1);
  }
  int clamp(int value) => min(value, shown.length);
  return (
    text: shown,
    marks: [
      for (final (start, length) in marks)
        if (start >= 0 && start + length <= text.length) (clamp(moved[start]), clamp(moved[start + length]) - clamp(moved[start])),
    ],
    styles: [for (final (start, length, kind) in styles) if (start < shown.length) (start, clamp(start + length) - start, kind)],
  );
}

/// Кусок строки с его выделением.
/// [math] — формула LaTeX, [text] у неё — исходник без знаков `$`.
typedef InlinePiece = ({String text, bool bold, bool italic, bool strike, bool code, String? url, bool math});

// выделение только по краям слова: «snake_case» и «2*3» остаются как есть. Формула — как
// в Obsidian: после открывающего `$` и перед закрывающим нет пробела, за закрывающим нет
// цифры, `\$` — просто знак. Поэтому «$5 и $10» — текст. `$$…$$` внутри строки — тоже формула
/// Строчная разметка: 1 — жирный, 2 и 3 — курсив, 4 — зачёркнутый, 5 — код, 6 и 7 — формула.
final inlineMarks = RegExp(
  r'\*\*(.+?)\*\*|(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])|(?<!\w)_(?!\s)(.+?)(?<!\s)_(?!\w)|~~(.+?)~~|`(.+?)`'
  r'|(?<![\\$])\$\$(?!\s)(.+?)(?<![\s\\])\$\$|(?<![\\$\w])\$(?![\s$])([^$\n]*?[^\s\\$])\$(?![\d$])',
);

InlinePiece _piece(String text, {bool bold = false, bool italic = false, bool strike = false, bool code = false, String? url, bool math = false}) =>
    (text: text, bold: bold, italic: italic, strike: strike, code: code, url: url, math: math);

/// Строка в куски: жирный, курсив, зачёркнутый, код, ссылки и `[[заметки]]` — ссылкой
/// `stowa-note:Заголовок`, видна подписью или заголовком без скобок.
List<InlinePiece> parseInline(String text) {
  final pieces = <InlinePiece>[];
  var last = 0;
  for (final match in wikiLink.allMatches(text)) {
    if (match.start > last) pieces.addAll(_parseMarks(text.substring(last, match.start)));
    final title = match.group(1)!.trim();
    final label = match.group(2)?.trim();
    pieces.add(_piece(label == null || label.isEmpty ? title : label, url: '$noteLinkScheme$title'));
    last = match.end;
  }
  if (last < text.length) pieces.addAll(_parseMarks(text.substring(last)));
  return pieces;
}

List<InlinePiece> _parseMarks(String text) {
  final pieces = <InlinePiece>[];
  void plain(String part) {
    var last = 0;
    for (final match in urlMatches(part)) {
      if (match.start > last) pieces.add(_piece(part.substring(last, match.start)));
      final raw = match.group(0)!;
      pieces.add(_piece(raw, url: raw.contains('://') ? raw : 'https://$raw'));
      last = match.end;
    }
    if (last < part.length) pieces.add(_piece(part.substring(last)));
  }

  var last = 0;
  for (final match in inlineMarks.allMatches(text)) {
    if (match.start > last) plain(text.substring(last, match.start));
    final bold = match.group(1);
    final italic = match.group(2) ?? match.group(3);
    final strike = match.group(4);
    final code = match.group(5);
    final math = match.group(6) ?? match.group(7);
    pieces.add(_piece(bold ?? italic ?? strike ?? code ?? math!, bold: bold != null, italic: italic != null, strike: strike != null, code: code != null, math: math != null));
    last = match.end;
  }
  if (last < text.length) plain(text.substring(last));
  return pieces;
}
