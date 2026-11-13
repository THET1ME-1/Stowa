import 'package:flutter/widgets.dart';

enum MarkdownAction { heading, bold, italic, strike, bullets, checklist, quote, code, link }

const _prefixes = {MarkdownAction.heading: '# ', MarkdownAction.bullets: '- ', MarkdownAction.checklist: '- [ ] ', MarkdownAction.quote: '> '};

const _wraps = {MarkdownAction.bold: '**', MarkdownAction.italic: '_', MarkdownAction.strike: '~~', MarkdownAction.code: '`'};

/// Кнопка панели разметки: знак строки встаёт в её начало, знак слова оборачивает выделение.
TextEditingValue applyMarkdown(TextEditingValue value, MarkdownAction action) {
  final text = value.text;
  final selection = value.selection.isValid ? value.selection : TextSelection.collapsed(offset: text.length);
  // «Связь»: [[выделенное]], курсор перед «]]» — выделенное слово сразу ищется в подсказке
  if (action == MarkdownAction.link) {
    final selected = text.substring(selection.start, selection.end);
    return TextEditingValue(
      text: text.replaceRange(selection.start, selection.end, '[[$selected]]'),
      selection: TextSelection.collapsed(offset: selection.start + 2 + selected.length),
    );
  }
  final prefix = _prefixes[action];
  if (prefix != null) {
    final lineStart = selection.start == 0 ? 0 : text.lastIndexOf('\n', selection.start - 1) + 1;
    return TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: selection.extentOffset + prefix.length),
    );
  }
  final wrap = _wraps[action]!;
  final start = selection.start;
  final end = selection.end;
  final next = text.substring(0, start) + wrap + text.substring(start, end) + wrap + text.substring(end);
  return TextEditingValue(
    text: next,
    selection: start == end ? TextSelection.collapsed(offset: start + wrap.length) : TextSelection(baseOffset: start, extentOffset: end + wrap.length * 2),
  );
}

/// Картинки на место курсора: каждая своей строкой `![[имя]]`, выделенное заменяется.
/// Курсор встаёт в начало строки после них — писать дальше можно сразу.
TextEditingValue insertImageLines(TextEditingValue value, List<String> names) {
  final text = value.text;
  final selection = value.selection.isValid ? value.selection : TextSelection.collapsed(offset: text.length);
  final before = text.substring(0, selection.start);
  final after = text.substring(selection.end);
  final lead = before.isEmpty || before.endsWith('\n') ? '' : '\n';
  final block = [for (final name in names) '![[$name]]'].join('\n');
  final tail = after.startsWith('\n') ? after : '\n$after';
  return TextEditingValue(
    text: '$before$lead$block$tail',
    selection: TextSelection.collapsed(offset: before.length + lead.length + block.length + 1),
  );
}

/// Имя вставленного фото: дата и время съёмки в заметку, как у камеры. [taken] — имена
/// вложений заметки в нижнем регистре: второе фото в ту же секунду получает «-2».
String photoFileName(DateTime at, String extension, Set<String> taken) {
  String two(int value) => value.toString().padLeft(2, '0');
  final stem = 'IMG-${at.year}${two(at.month)}${two(at.day)}-${two(at.hour)}${two(at.minute)}${two(at.second)}';
  var name = '$stem.$extension';
  for (var number = 2; taken.contains(name.toLowerCase()); number++) {
    name = '$stem-$number.$extension';
  }
  return name;
}
