import 'package:flutter/material.dart';

import '../../domain/note_blocks.dart';

/// Текст с оформлением из разметки заметки и подсвеченными совпадениями поиска:
/// жирное жирным, сделанное зачёркнуто, найденное на фоне, ширина букв та же.
class MarkedText extends StatelessWidget {
  const MarkedText({
    super.key,
    required this.text,
    required this.marks,
    required this.style,
    required this.markColor,
    this.styles = const [],
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  /// Короткая заметка с её оформлением, без подсветки: карточки на главной и в папке.
  factory MarkedText.note(String markdown, {required TextStyle style, int maxLines = 1, TextOverflow overflow = TextOverflow.ellipsis}) {
    final shown = renderMarkup(markdown, const []);
    return MarkedText(text: shown.text, marks: const [], styles: shown.styles, style: style, markColor: Colors.transparent, maxLines: maxLines, overflow: overflow);
  }

  /// Что с текстом длиннее [maxLines]: многоточие или обрез (карточка главной растворяет конец сама).
  final TextOverflow overflow;

  final String text;

  /// Совпадения поиска: начало и длина.
  final List<(int, int)> marks;
  final TextStyle style;
  final Color markColor;

  /// Оформление из разметки заметки: жирное, курсив, сделанное и прочее.
  final List<(int, int, MarkupStyle)> styles;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    // у каждой буквы свой набор: стили и подсветка совпадения могут лежать друг на друге
    final kinds = List<Set<MarkupStyle>>.generate(text.length, (_) => {});
    final marked = List<bool>.filled(text.length, false);
    for (final (start, length, kind) in styles) {
      for (var index = start; index < (start + length).clamp(0, text.length); index++) {
        kinds[index].add(kind);
      }
    }
    for (final (start, length) in marks) {
      for (var index = start; index < (start + length).clamp(0, text.length); index++) {
        marked[index] = true;
      }
    }
    TextStyle look(Set<MarkupStyle> set, bool mark) => TextStyle(
      fontWeight: set.contains(MarkupStyle.bold) || set.contains(MarkupStyle.heading) ? FontWeight.w700 : null,
      fontStyle: set.contains(MarkupStyle.italic) ? FontStyle.italic : null,
      decoration: set.contains(MarkupStyle.strike) || set.contains(MarkupStyle.done) ? TextDecoration.lineThrough : null,
      fontFamily: set.contains(MarkupStyle.code) ? 'monospace' : null,
      backgroundColor: mark ? markColor : null,
    );
    // соседние буквы с одинаковым видом — один кусок
    final spans = <TextSpan>[];
    var runStart = 0;
    for (var index = 1; index <= text.length; index++) {
      final same = index < text.length && marked[index] == marked[runStart] && kinds[index].length == kinds[runStart].length && kinds[index].containsAll(kinds[runStart]);
      if (same) continue;
      spans.add(TextSpan(text: text.substring(runStart, index), style: look(kinds[runStart], marked[runStart])));
      runStart = index;
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
