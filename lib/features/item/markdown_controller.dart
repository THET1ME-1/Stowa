import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../domain/note_blocks.dart';
import '../../domain/note_links.dart' show WikiPiece, wikiPieces;

final _lineMark = RegExp(r'^(#{1,3} |\s*[-*] \[[ xX]\] |\s*[-*•] |\s*\d{1,3}[.)] |> ?)');

final _listLead = RegExp(r'^(\s*)([-*•] \[[ xX]\] |[-*•] |(\d{1,3})([.)]) )');

/// Enter в конце пункта, галочки или номера начинает следующий такой же; Enter на
/// пустом пункте снимает значок и выходит из списка. Срабатывает только на один
/// набранный перенос, вставку текста не трогает.
TextEditingValue continueLists(TextEditingValue old, TextEditingValue next) {
  final caret = next.selection.baseOffset;
  final typedNewline = next.text.length == old.text.length + 1 && caret > 0 && next.selection.isCollapsed && next.text[caret - 1] == '\n';
  if (!typedNewline) return next;
  final lineStart = next.text.lastIndexOf('\n', caret - 2) + 1;
  final line = next.text.substring(lineStart, caret - 1);
  final lead = _listLead.firstMatch(line);
  if (lead == null) return next;
  // пустой пункт: значок уходит вместе с переносом
  if (line.trim() == lead.group(0)!.trim()) {
    final text = next.text.replaceRange(lineStart, caret, '');
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: lineStart));
  }
  final number = lead.group(3);
  // следующая галочка всегда пустая: сделанной она станет сама
  final prefix = '${lead.group(1)}${number != null ? '${int.parse(number) + 1}${lead.group(4)} ' : lead.group(2)!.replaceFirst(RegExp('[xX]'), ' ')}';
  final text = next.text.replaceRange(caret, caret, prefix);
  return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: caret + prefix.length));
}

/// Поле правки с живой разметкой: значки приглушены, жирное жирным, заголовок
/// крупнее, сделанное зачёркнуто. Текст в поле тот же до буквы, меняется только вид.
class MarkdownController extends TextEditingController {
  MarkdownController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final mark = TextStyle(color: Tokens.muted);
    final children = <InlineSpan>[];
    final lines = text.split('\n');
    var offset = 0;
    for (final (index, line) in lines.indexed) {
      final lineStart = offset;
      offset += line.length + 1;
      // строка-картинка приглушена целиком: подчёркивания в имени файла — не курсив
      if (embedLine.hasMatch(line)) {
        children.add(TextSpan(text: line, style: TextStyle(color: Tokens.muted, fontSize: 14)));
        if (index < lines.length - 1) children.add(const TextSpan(text: '\n'));
        continue;
      }
      final lead = _lineMark.firstMatch(line)?.group(0) ?? '';
      final rest = line.substring(lead.length);
      var restStyle = const TextStyle();
      if (lead.startsWith('#')) {
        restStyle = const TextStyle(fontWeight: FontWeight.w700, fontSize: 19);
      } else if (lead.contains('[x]') || lead.contains('[X]')) {
        restStyle = TextStyle(color: Tokens.muted, decoration: TextDecoration.lineThrough, decorationColor: Tokens.muted);
      } else if (lead.startsWith('>')) {
        restStyle = TextStyle(color: Tokens.onSurfaceVariant);
      }
      if (lead.isNotEmpty) children.add(TextSpan(text: lead, style: mark));
      _inline(rest, lineStart + lead.length, restStyle, children);
      if (index < lines.length - 1) children.add(const TextSpan(text: '\n'));
    }
    return TextSpan(style: style, children: children);
  }

  // жирный, курсив, зачёркнутый, код: знаки по краям приглушены, середина выделена.
  // [[Ссылка]] — как в Obsidian: видно только название ссылкой, скобки и «Название|» перед
  // подписью спрятаны, пока курсор не внутри; [start] — где строка начинается во всём тексте
  void _inline(String line, int start, TextStyle base, List<InlineSpan> out) {
    final mark = base.merge(TextStyle(color: Tokens.muted, fontWeight: FontWeight.w400, fontStyle: FontStyle.normal));
    final links = wikiPieces(line);
    final caret = selection.isValid && selection.isCollapsed ? selection.baseOffset - start : -1;
    var last = 0;
    for (final match in [...inlineMarks.allMatches(line), ...links.map((piece) => piece)]..sort((a, b) => _startOf(a).compareTo(_startOf(b)))) {
      if (_startOf(match) < last) continue;
      if (match is WikiPiece) {
        if (match.start > last) out.add(TextSpan(text: line.substring(last, match.start), style: base));
        final open = caret >= match.start && caret <= match.end;
        final aside = open ? mark : base.merge(_hidden);
        out
          ..add(TextSpan(text: line.substring(match.start, match.shownStart), style: aside))
          ..add(TextSpan(text: line.substring(match.shownStart, match.shownEnd), style: base.merge(_link)))
          ..add(TextSpan(text: line.substring(match.shownEnd, match.end), style: aside));
        last = match.end;
        continue;
      }
      match as RegExpMatch;
      if (match.start > last) out.add(TextSpan(text: line.substring(last, match.start), style: base));
      final (width, inner) = switch (match) {
        _ when match.group(1) != null => (2, const TextStyle(fontWeight: FontWeight.w700)),
        _ when match.group(2) != null || match.group(3) != null => (1, const TextStyle(fontStyle: FontStyle.italic)),
        _ when match.group(4) != null => (2, const TextStyle(decoration: TextDecoration.lineThrough)),
        _ => (1, TextStyle(fontFamily: 'monospace', backgroundColor: Tokens.containerHigh)),
      };
      final whole = match.group(0)!;
      out
        ..add(TextSpan(text: whole.substring(0, width), style: mark))
        ..add(TextSpan(text: whole.substring(width, whole.length - width), style: base.merge(inner)))
        ..add(TextSpan(text: whole.substring(whole.length - width), style: mark));
      last = match.end;
    }
    if (last < line.length) out.add(TextSpan(text: line.substring(last), style: base));
  }

  static int _startOf(Object token) => token is WikiPiece ? token.start : (token as RegExpMatch).start;

  /// Спрятанные знаки ссылки: в поле они есть, на экране не занимают места.
  static const _hidden = TextStyle(fontSize: 0.01, color: Colors.transparent, letterSpacing: 0);

  TextStyle get _link => TextStyle(fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: Tokens.onSurface);
}
