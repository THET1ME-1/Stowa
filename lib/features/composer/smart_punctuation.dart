import 'package:flutter/services.dart';

const _pairs = {'<<': '«', '>>': '»', '--': '—'};

/// Набранные `<<`, `>>`, `--` становятся «, » и —, как в типографике. Черта Markdown
/// `---` в начале строки остаётся чертой, код в обратных кавычках и в блоке ``` не трогается.
/// Срабатывает только на набор одной буквы: вставка текста остаётся как есть.
TextEditingValue smartPunctuation(TextEditingValue old, TextEditingValue next) {
  final caret = next.selection.baseOffset;
  final typedOne = next.text.length == old.text.length + 1 && next.selection.isCollapsed && old.selection.isCollapsed && caret >= 2;
  if (!typedOne || next.text.replaceRange(caret - 1, caret, '') != old.text) return next;
  final text = next.text;
  final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
  final line = text.substring(lineStart, caret);
  if (_inCode(text, lineStart, line)) return next;

  // «—» в начале строки и третий дефис — это черта «---», а не тире с дефисом
  if (line == '—-') return _replace(next, lineStart, caret, '---');
  if (line.length >= 3 && line.split('').every((char) => char == '-')) return next;

  final shown = _pairs[text.substring(caret - 2, caret)];
  if (shown == null) return next;
  return _replace(next, caret - 2, caret, shown);
}

TextEditingValue _replace(TextEditingValue value, int start, int end, String replacement) =>
    TextEditingValue(text: value.text.replaceRange(start, end, replacement), selection: TextSelection.collapsed(offset: start + replacement.length));

/// Курсор внутри `кода` в строке или внутри блока ```.
bool _inCode(String text, int lineStart, String line) {
  if ('`'.allMatches(line).length.isOdd && !line.trimLeft().startsWith('```')) return true;
  var fences = 0;
  for (final before in text.substring(0, lineStart).split('\n')) {
    if (before.trimLeft().startsWith('```')) fences++;
  }
  return fences.isOdd;
}
