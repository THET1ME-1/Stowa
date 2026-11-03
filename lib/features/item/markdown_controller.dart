import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import 'note_blocks.dart';

final _lineMark = RegExp(r'^(#{1,3} |\s*[-*] \[[ xX]\] |\s*[-*•] |\s*\d{1,3}[.)] |> ?)');

/// Поле правки с живой разметкой: значки приглушены, жирное жирным, заголовок
/// крупнее, сделанное зачёркнуто. Текст в поле тот же до буквы, меняется только вид.
class MarkdownController extends TextEditingController {
  MarkdownController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    const mark = TextStyle(color: Tokens.muted);
    final children = <InlineSpan>[];
    final lines = text.split('\n');
    for (final (index, line) in lines.indexed) {
      final lead = _lineMark.firstMatch(line)?.group(0) ?? '';
      final rest = line.substring(lead.length);
      var restStyle = const TextStyle();
      if (lead.startsWith('#')) {
        restStyle = const TextStyle(fontWeight: FontWeight.w700, fontSize: 19);
      } else if (lead.contains('[x]') || lead.contains('[X]')) {
        restStyle = const TextStyle(color: Tokens.muted, decoration: TextDecoration.lineThrough, decorationColor: Tokens.muted);
      } else if (lead.startsWith('>')) {
        restStyle = const TextStyle(color: Tokens.onSurfaceVariant);
      }
      if (lead.isNotEmpty) children.add(TextSpan(text: lead, style: mark));
      _inline(rest, restStyle, children);
      if (index < lines.length - 1) children.add(const TextSpan(text: '\n'));
    }
    return TextSpan(style: style, children: children);
  }

  // жирный, курсив, зачёркнутый, код: знаки по краям приглушены, середина выделена
  void _inline(String line, TextStyle base, List<InlineSpan> out) {
    final mark = base.merge(const TextStyle(color: Tokens.muted, fontWeight: FontWeight.w400, fontStyle: FontStyle.normal));
    var last = 0;
    for (final match in inlineMarks.allMatches(line)) {
      if (match.start > last) out.add(TextSpan(text: line.substring(last, match.start), style: base));
      final (width, inner) = switch (match) {
        _ when match.group(1) != null => (2, const TextStyle(fontWeight: FontWeight.w700)),
        _ when match.group(2) != null || match.group(3) != null => (1, const TextStyle(fontStyle: FontStyle.italic)),
        _ when match.group(4) != null => (2, const TextStyle(decoration: TextDecoration.lineThrough)),
        _ => (1, const TextStyle(fontFamily: 'monospace', backgroundColor: Tokens.containerHigh)),
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
}
