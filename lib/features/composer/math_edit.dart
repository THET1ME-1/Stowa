/// Набор формул LaTeX, как в Latex Suite для Obsidian с настройками по умолчанию:
/// пары `$` и скобок, сокращения (`sr` → `^{2}`, `@a` → `\alpha`, `sin` → `\sin`), дробь
/// косой чертой, индекс цифрой, переход к следующему полю. Всё работает только внутри
/// формулы и не внутри `\text{…}`: обычный текст и цены не трогаются.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../domain/note_blocks.dart' show codeRanges;

/// Формула вокруг курсора: [start] и [end] — границы её текста без знаков `$`.
typedef MathAround = ({int start, int end, bool display, String tex});

// знак, где встанет курсор после сокращения; без него — в конец вставки
const _caret = '◊';

// закрывающая пара скобок
const _closing = {'{': '}', '(': ')', '[': ']'};

/// Сокращения: [word] — только с начала слова (перед ним не буква и не «\»), иначе — где
/// угодно, кроме сразу после «\». Длинные проверяются первыми.
final List<({String trigger, String replacement, bool word})> _snippets = () {
  final list = <({String trigger, String replacement, bool word})>[
    (trigger: 'sr', replacement: '^{2}', word: false),
    (trigger: 'cb', replacement: '^{3}', word: false),
    (trigger: 'rd', replacement: '^{$_caret}', word: false),
    (trigger: 'invs', replacement: '^{-1}', word: false),
    (trigger: 'ee', replacement: 'e^{$_caret}', word: false),
    (trigger: 'sq', replacement: '\\sqrt{$_caret}', word: false),
    (trigger: '//', replacement: '\\frac{$_caret}{}', word: false),
    (trigger: 'ooo', replacement: '\\infty', word: false),
    (trigger: 'xx', replacement: '\\times', word: false),
    (trigger: '**', replacement: '\\cdot', word: false),
    (trigger: '...', replacement: '\\dots', word: false),
    (trigger: '->', replacement: '\\to', word: false),
    (trigger: '!>', replacement: '\\mapsto', word: false),
    (trigger: '=>', replacement: '\\implies', word: false),
    (trigger: '=<', replacement: '\\impliedby', word: false),
    (trigger: '===', replacement: '\\equiv', word: false),
    (trigger: '!=', replacement: '\\neq', word: false),
    (trigger: '>=', replacement: '\\geq', word: false),
    (trigger: '<=', replacement: '\\leq', word: false),
    (trigger: '>>', replacement: '\\gg', word: false),
    (trigger: '<<', replacement: '\\ll', word: false),
    (trigger: '~~', replacement: '\\sim', word: false),
    (trigger: '+-', replacement: '\\pm', word: false),
    (trigger: '-+', replacement: '\\mp', word: false),
    (trigger: 'Nn', replacement: '\\cap', word: false),
    (trigger: 'UU', replacement: '\\cup', word: false),
    (trigger: 'EE', replacement: '\\exists', word: false),
    (trigger: 'AA', replacement: '\\forall', word: false),
    (trigger: 'iff', replacement: '\\iff', word: true),
    (trigger: 'inn', replacement: '\\in', word: true),
    (trigger: 'notin', replacement: '\\not\\in', word: true),
    (trigger: 'lim', replacement: '\\lim_{$_caret \\to \\infty}', word: true),
    (trigger: 'hat', replacement: '\\hat{$_caret}', word: true),
    (trigger: 'bar', replacement: '\\bar{$_caret}', word: true),
    (trigger: 'vec', replacement: '\\vec{$_caret}', word: true),
    (trigger: 'dot', replacement: '\\dot{$_caret}', word: true),
    (trigger: 'tilde', replacement: '\\tilde{$_caret}', word: true),
    (trigger: 'und', replacement: '\\underline{$_caret}', word: true),
    (trigger: 'text', replacement: '\\text{$_caret}', word: true),
    (trigger: 'set', replacement: '\\{ $_caret \\}', word: true),
    (trigger: 'norm', replacement: '\\lVert $_caret \\rVert', word: true),
    (trigger: 'par', replacement: '\\frac{\\partial $_caret}{\\partial }', word: true),
    for (final name in ['sum', 'prod', 'int', 'sin', 'cos', 'tan', 'cot', 'sec', 'csc', 'arcsin', 'arccos', 'arctan', 'sinh', 'cosh', 'tanh', 'ln', 'log', 'exp', 'min', 'max', 'det', 'gcd'])
      (trigger: name, replacement: '\\$name', word: true),
    for (final name in [
      'alpha', 'beta', 'gamma', 'Gamma', 'delta', 'Delta', 'epsilon', 'varepsilon', 'zeta', 'eta', 'theta', 'Theta', 'iota', 'kappa', 'lambda', 'Lambda', //
      'mu', 'nu', 'xi', 'Xi', 'pi', 'Pi', 'rho', 'sigma', 'Sigma', 'tau', 'upsilon', 'phi', 'Phi', 'varphi', 'chi', 'psi', 'Psi', 'omega', 'Omega',
    ])
      (trigger: name, replacement: '\\$name', word: true),
    for (final MapEntry(key: letter, value: name) in {
      'a': 'alpha', 'b': 'beta', 'g': 'gamma', 'G': 'Gamma', 'd': 'delta', 'D': 'Delta', 'e': 'epsilon', 'z': 'zeta', 't': 'theta', 'T': 'Theta', //
      'k': 'kappa', 'l': 'lambda', 'L': 'Lambda', 'm': 'mu', 's': 'sigma', 'S': 'Sigma', 'u': 'upsilon', 'f': 'phi', 'F': 'Phi', 'o': 'omega', 'O': 'Omega',
    }.entries)
      (trigger: '@$letter', replacement: '\\$name', word: false),
  ];
  return list..sort((a, b) => b.trigger.length.compareTo(a.trigger.length));
}();

final _letter = RegExp('[A-Za-z]');

/// Куски текста, где формул быть не может: блоки ``` и `код` в строке.
List<(int, int)> _codeSpans(String text) {
  final lines = text.split('\n');
  final starts = <int>[];
  var offset = 0;
  for (final line in lines) {
    starts.add(offset);
    offset += line.length + 1;
  }
  return [
    for (final range in codeRanges(lines)) (starts[range.start], starts[range.end] + lines[range.end].length),
    for (final match in RegExp(r'`[^`\n]*`').allMatches(text)) (match.start, match.end),
  ];
}

final _display = RegExp(r'(?<!\\)\$\$([\s\S]*?)(?<!\\)\$\$');
// при наборе формула ещё не дописана: пробел перед закрывающим можно, а цифра сразу за
// открывающим — это цена («$5»)
final _inline = RegExp(r'(?<![\\$])\$(?![\s\d$])([^$\n]*?)(?<!\\)\$(?![\d$])');

// два последних разобранных текста: на каждую букву одну и ту же строку (до и после правки)
// спрашивают правило набора, типографика, полоса разметки и просмотр формулы — до шести раз
final _regionsMemo = <String, List<MathAround>>{};

/// Формулы в тексте: блочные `$$…$$` и строчные `$…$`, без кода.
List<MathAround> mathRegions(String text) {
  // без «$» формул нет: большинство заметок не разбирается вовсе
  if (!text.contains(r'$')) return const [];
  if (_regionsMemo.remove(text) case final known?) return _regionsMemo[text] = known;
  final regions = _scanRegions(text);
  if (_regionsMemo.length >= 2) _regionsMemo.remove(_regionsMemo.keys.first);
  return _regionsMemo[text] = regions;
}

List<MathAround> _scanRegions(String text) {
  final code = _codeSpans(text);
  bool inCode(int at) => code.any((span) => at >= span.$1 && at < span.$2);
  final regions = <MathAround>[];
  var masked = text;
  for (final match in _display.allMatches(text)) {
    if (inCode(match.start)) continue;
    regions.add((start: match.start + 2, end: match.end - 2, display: true, tex: match.group(1)!));
    masked = masked.replaceRange(match.start, match.end, ' ' * (match.end - match.start));
  }
  for (final match in _inline.allMatches(masked)) {
    if (inCode(match.start)) continue;
    regions.add((start: match.start + 1, end: match.end - 1, display: false, tex: match.group(1)!));
  }
  return regions;
}

/// Формула, внутри которой стоит [offset] (на её границе — тоже). Пустая пара `$|$`, только
/// что поставленная набором, — тоже формула.
MathAround? mathAround(String text, int offset) {
  if (offset < 0 || offset > text.length) return null;
  for (final region in mathRegions(text)) {
    if (offset >= region.start && offset <= region.end) return region;
  }
  final emptyPair = offset >= 1 && offset < text.length && text[offset - 1] == r'$' && text[offset] == r'$';
  final lonely = (offset < 2 || text[offset - 2] != r'$') && (offset + 1 >= text.length || text[offset + 1] != r'$');
  if (emptyPair && lonely && !_codeSpans(text).any((span) => offset > span.$1 && offset < span.$2)) {
    return (start: offset, end: offset, display: false, tex: '');
  }
  return null;
}

// курсор внутри \text{…} формулы: там обычные слова
bool _inText(String text, MathAround region, int offset) {
  final before = text.substring(region.start, offset);
  final open = before.lastIndexOf(r'\text{');
  if (open < 0) return false;
  var depth = 0;
  for (final char in before.substring(open + 5).split('')) {
    if (char == '{') depth++;
    if (char == '}') depth--;
  }
  return depth > 0;
}

TextEditingValue _set(String text, int caret) => TextEditingValue(text: text, selection: TextSelection.collapsed(offset: caret));

/// Правка при наборе одной буквы или стирании одной: пары, сокращения, дробь, индекс.
/// Вставку и выделение не трогает.
TextEditingValue mathInput(TextEditingValue old, TextEditingValue next) {
  if (!old.selection.isValid || !next.selection.isValid || !old.selection.isCollapsed || !next.selection.isCollapsed) return next;
  final caret = next.selection.baseOffset;
  final text = next.text;

  // стёрли одну букву перед курсором: пустая пара уходит целиком
  if (text.length == old.text.length - 1 && old.selection.baseOffset == caret + 1 && old.text.replaceRange(caret, caret + 1, '') == text) {
    final gone = old.text[caret];
    final pair = gone == r'$' ? r'$' : _closing[gone];
    if (pair != null && text.startsWith(pair, caret) && (gone == r'$' || mathAround(old.text, caret + 1) != null)) {
      return _set(text.replaceRange(caret, caret + 1, ''), caret);
    }
    return next;
  }

  final typedOne = text.length == old.text.length + 1 && caret >= 1 && text.replaceRange(caret - 1, caret, '') == old.text;
  if (!typedOne) return next;
  final char = text[caret - 1];
  final at = caret - 1;
  final region = mathAround(old.text, at);

  if (char == r'$') {
    if (at >= 1 && old.text[at - 1] == r'\') return next;
    // в пустой паре второй «$» делает блок: $$|$$
    if (region != null && !region.display && region.tex.isEmpty && old.text.startsWith(r'$', at)) {
      return _set(text.replaceRange(caret, caret, r'$'), caret);
    }
    // закрывающий уже стоит — перешагнуть
    if (region != null && old.text.startsWith(r'$', at)) return _set(old.text, caret);
    // после буквы или цифры («US$», «5$») это знак валюты, а не начало формулы
    final previous = at >= 1 ? old.text[at - 1] : '';
    if (RegExp(r'[\p{L}\d]', unicode: true).hasMatch(previous)) return next;
    if (region == null && !_codeSpans(old.text).any((span) => at > span.$1 && at < span.$2)) {
      return _set(text.replaceRange(caret, caret, r'$'), caret);
    }
    return next;
  }
  if (region == null) return next;

  // цифра или пробел сразу в пустой паре: это цена («$5», «$ 5»), а не формула — пара снимается
  final emptyInline = !region.display && region.tex.isEmpty && at >= 1 && old.text[at - 1] == r'$' && old.text.startsWith(r'$', at);
  if (emptyInline && RegExp(r'[\d\s]').hasMatch(char) && char != '\n') return _set(text.replaceRange(caret, caret + 1, ''), caret);

  // Enter в пустом блоке $$|$$ — блок на своих строках
  if (char == '\n' && region.display && region.tex.isEmpty) return _set(text.replaceRange(caret, caret, '\n'), caret);

  if (_inText(old.text, region, at)) return next;

  // скобки: закрывающая встаёт следом, набранная закрывающая перешагивает уже стоящую
  if (_closing[char] case final close?) return _set(text.replaceRange(caret, caret, close), caret);
  if (_closing.containsValue(char) && text.startsWith(char, caret)) return _set(text.replaceRange(caret, caret + 1, ''), caret);

  final before = text.substring(0, caret);
  for (final snippet in _snippets) {
    if (!before.endsWith(snippet.trigger)) continue;
    final start = caret - snippet.trigger.length;
    if (start < region.start) continue;
    final previous = start > 0 ? text[start - 1] : '';
    if (previous == r'\') continue;
    if (snippet.word && _letter.hasMatch(previous)) continue;
    return _insert(text, start, caret, snippet.replacement);
  }

  // дробь косой чертой: то, что перед ней, уходит в числитель
  if (char == '/') {
    final numerator = _numerator(text, region.start, at);
    if (numerator != null) {
      final content = text.substring(numerator.start, numerator.end);
      return _insert(text, numerator.from, caret, '\\frac{$content}{$_caret}');
    }
  }

  // индекс цифрой: x1 → x_{1}, x_{1}2 → x_{12}
  if (RegExp(r'\d').hasMatch(char) && at >= region.start + 1) {
    final previous = text[at - 1];
    final beforePrevious = at >= 2 ? text[at - 2] : '';
    if (_letter.hasMatch(previous) && at - 1 >= region.start && !_letter.hasMatch(beforePrevious) && beforePrevious != r'\') {
      return _insert(text, at - 1, caret, '${previous}_{$char}');
    }
    final grown = RegExp(r'(?<![A-Za-z\\])([A-Za-z])_\{(\d+)\}$').firstMatch(text.substring(region.start, at));
    if (grown != null) {
      final start = region.start + grown.start;
      return _insert(text, start, caret, '${grown.group(1)}_{${grown.group(2)}$char}');
    }
  }
  return next;
}

TextEditingValue _insert(String text, int start, int end, String replacement) {
  final mark = replacement.indexOf(_caret);
  final clean = replacement.replaceFirst(_caret, '');
  return _set(text.replaceRange(start, end, clean), start + (mark < 0 ? clean.length : mark));
}

/// Числитель перед «/» в [at]: скобка `( … )` целиком (без самих скобок) или слитный кусок
/// из букв, цифр, команд и `^{…}`/`_{…}`. Пусто — null.
({int from, int start, int end})? _numerator(String text, int regionStart, int at) {
  if (at <= regionStart) return null;
  if (text[at - 1] == ')') {
    var depth = 0;
    for (var index = at - 1; index >= regionStart; index--) {
      if (text[index] == ')') depth++;
      if (text[index] == '(') depth--;
      if (depth == 0) return index + 1 < at - 1 ? (from: index, start: index + 1, end: at - 1) : null;
    }
    return null;
  }
  var index = at;
  var depth = 0;
  while (index > regionStart) {
    final char = text[index - 1];
    if (char == '}') {
      depth++;
    } else if (char == '{') {
      if (depth == 0) break;
      depth--;
    } else if (depth == 0 && !RegExp(r'[A-Za-z0-9\\^_.]').hasMatch(char)) {
      break;
    }
    index--;
  }
  return index < at ? (from: index, start: index, end: at) : null;
}

/// Клавиша Tab в поле [field]: в формуле — к следующему полю, вне формулы — дальше по
/// обычному кругу фокуса.
KeyEventResult mathTabKey(TextEditingController field, KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
  if (event.logicalKey != LogicalKeyboardKey.tab || HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
  final value = field.value;
  if (!value.selection.isValid || mathAround(value.text, value.selection.extentOffset) == null) return KeyEventResult.ignored;
  field.value = mathTabOut(value);
  return KeyEventResult.handled;
}

/// К следующему полю: из `\frac{a|}{}` — в знаменатель, из последнего поля — за скобку, из
/// конца формулы — за её закрывающие знаки. Вне формулы ничего не делает.
TextEditingValue mathTabOut(TextEditingValue value) {
  if (!value.selection.isValid) return value;
  final text = value.text;
  final caret = value.selection.extentOffset;
  final region = mathAround(text, caret);
  if (region == null) return value;
  var depth = 0;
  for (var index = caret; index < region.end; index++) {
    final char = text[index];
    if (_closing.containsKey(char)) depth++;
    if (_closing.containsValue(char)) {
      if (depth == 0) {
        var to = index + 1;
        if (to < text.length && text[to] == '{') to++;
        return _set(text, to);
      }
      depth--;
    }
  }
  return _set(text, region.end + (region.display ? 2 : 1));
}
