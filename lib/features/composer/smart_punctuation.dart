import 'package:flutter/services.dart';

import 'math_edit.dart' show mathAround;

const _pairs = {'<<': '«', '>>': '»', '--': '—'};

/// Кавычка открывающая → своя закрывающая: прямые, ёлочки, „лапки“ (немецкие, польские,
/// румынские, украинские), “английские” и ‘одинарные’.
const _quotes = {'"': '"', "'": "'", '«': '»', '„': '“', '“': '”', '‘': '’', '‹': '›'};

// эти бывают и закрывающими (прямые, “ у немцев, ‘ у немцев): пара только с начала слова
const _ambiguous = {'"', "'", '“', '‘'};

final _closingQuotes = {..._quotes.values};

// перед открывающей: начало, пробел, скобка или другая кавычка
final _opensAfter = RegExp(r'[\s(\[{«„“‘‹"' "'" r'—–-]');

// после открывающей, чтобы ставить пару: конец, пробел или знак препинания, не буква
final _pairsBefore = RegExp(r'[\s)\]}.,;:!?»“”’›]');

/// Набранные `<<`, `>>`, `--` становятся «, » и —, как в типографике. Черта Markdown
/// `---` в начале строки остаётся чертой, код в обратных кавычках и в блоке ``` не трогается.
/// Кавычки парные: открывающая ставит закрывающую, курсор между ними; набранная закрывающая
/// перешагивает стоящую; стирание пустой пары стирает обе; кавычка поверх выделения его
/// оборачивает. Апостроф внутри слова («it's», «п'ять») пары не ставит.
/// Срабатывает только на набор и стирание одной буквы: вставка текста остаётся как есть.
TextEditingValue smartPunctuation(TextEditingValue old, TextEditingValue next) {
  if (!old.selection.isValid || !next.selection.isValid || !next.selection.isCollapsed) return next;
  if (!old.selection.isCollapsed) return _wrapSelection(old, next);
  final caret = next.selection.baseOffset;

  // стёрли открывающую в пустой паре — закрывающая уходит следом
  if (next.text.length == old.text.length - 1 && old.selection.baseOffset == caret + 1 && old.text.replaceRange(caret, caret + 1, '') == next.text) {
    final close = _quotes[old.text[caret]];
    if (close != null && next.text.startsWith(close, caret) && !_blocked(old.text, caret)) {
      return TextEditingValue(text: next.text.replaceRange(caret, caret + 1, ''), selection: TextSelection.collapsed(offset: caret));
    }
    return next;
  }

  final typedOne = next.text.length == old.text.length + 1 && caret >= 1;
  if (!typedOne || next.text.replaceRange(caret - 1, caret, '') != old.text) return next;
  final text = next.text;
  if (_blocked(text, caret)) return next;
  final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
  final line = text.substring(lineStart, caret);

  // «—» в начале строки и третий дефис — это черта «---», а не тире с дефисом
  if (line == '—-') return _replace(next, lineStart, caret, '---');
  if (line.length >= 3 && line.split('').every((char) => char == '-')) return next;

  final shown = caret >= 2 ? _pairs[text.substring(caret - 2, caret)] : null;
  if (shown != null) {
    final at = caret - 2;
    final replaced = text.replaceRange(at, caret, shown);
    // «>>» перед уже стоящей » — это шаг за неё, а не вторая кавычка
    if (shown == '»' && replaced.startsWith('»', at + 1)) return TextEditingValue(text: replaced.replaceRange(at, at + 1, ''), selection: TextSelection.collapsed(offset: at + 1));
    // «<<» открывает пару, как набранная «
    if (shown == '«' && _opens(replaced, at)) return TextEditingValue(text: replaced.replaceRange(at + 1, at + 1, '»'), selection: TextSelection.collapsed(offset: at + 1));
    return TextEditingValue(text: replaced, selection: TextSelection.collapsed(offset: at + 1));
  }

  final char = text[caret - 1];
  // закрывающая уже стоит за курсором — перешагнуть. Прямая кавычка после пробела —
  // это новая открывающая, а не конец старой
  if (_closingQuotes.contains(char) && text.startsWith(char, caret)) {
    final symmetric = _quotes[char] == char;
    final previous = caret >= 2 ? text[caret - 2] : '';
    if (!symmetric || (previous.isNotEmpty && !RegExp(r'\s').hasMatch(previous))) {
      return TextEditingValue(text: text.replaceRange(caret, caret + 1, ''), selection: TextSelection.collapsed(offset: caret));
    }
  }
  if (_quotes[char] case final close? when _opens(text, caret - 1)) {
    return TextEditingValue(text: text.replaceRange(caret, caret, close), selection: TextSelection.collapsed(offset: caret));
  }
  return next;
}

/// Кавычка в [at] открывает пару: за ней не буква (иначе закавычат слово следом), а перед
/// двусмысленной — начало слова (иначе это закрывающая или апостроф).
bool _opens(String text, int at) {
  final after = at + 1 < text.length ? text[at + 1] : '';
  if (after.isNotEmpty && !_pairsBefore.hasMatch(after)) return false;
  if (!_ambiguous.contains(text[at])) return true;
  final before = at >= 1 ? text[at - 1] : '';
  return before.isEmpty || _opensAfter.hasMatch(before);
}

/// Кавычка поверх выделения: выделенное — в кавычки, курсор за закрывающей.
TextEditingValue _wrapSelection(TextEditingValue old, TextEditingValue next) {
  final start = old.selection.start;
  final end = old.selection.end;
  final selected = old.text.substring(start, end);
  final caret = next.selection.baseOffset;
  if (caret != start + 1 || next.text.length != old.text.length - selected.length + 1) return next;
  final close = _quotes[next.text[start]];
  if (close == null || next.text.replaceRange(start, start + 1, selected) != old.text || _blocked(old.text, start)) return next;
  final text = old.text.replaceRange(start, end, '${next.text[start]}$selected$close');
  return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: start + selected.length + 2));
}

/// В коде и в формуле типографики нет: там «<<», «--» и кавычки — знаки языка.
bool _blocked(String text, int caret) {
  final lineStart = caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
  if (_inCode(text, lineStart, text.substring(lineStart, caret))) return true;
  return mathAround(text, caret) != null;
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
