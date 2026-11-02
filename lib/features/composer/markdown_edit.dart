import 'package:flutter/widgets.dart';

enum MarkdownAction { heading, bold, italic, strike, bullets, checklist, quote, code }

const _prefixes = {MarkdownAction.heading: '# ', MarkdownAction.bullets: '- ', MarkdownAction.checklist: '- [ ] ', MarkdownAction.quote: '> '};

const _wraps = {MarkdownAction.bold: '**', MarkdownAction.italic: '_', MarkdownAction.strike: '~~', MarkdownAction.code: '`'};

/// Кнопка панели разметки: знак строки встаёт в её начало, знак слова оборачивает выделение.
TextEditingValue applyMarkdown(TextEditingValue value, MarkdownAction action) {
  final text = value.text;
  final selection = value.selection.isValid ? value.selection : TextSelection.collapsed(offset: text.length);
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
