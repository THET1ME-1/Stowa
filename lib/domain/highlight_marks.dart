/// Где в абзаце статьи подсветить цитаты. Цитата ищется по своему тексту, а не
/// по смещению: улучшится разбор страницы — подсветка не съедет.
library;

class HighlightMark {
  const HighlightMark(this.start, this.end, this.id);

  final int start;
  final int end;
  final String id;
}

/// Короче этого кусок цитаты не ищем: «и» нашлось бы в каждом абзаце.
const _shortest = 3;

/// Отрезки цитат в [text] по порядку и без наложения. Цитата через несколько
/// абзацев (строки через `\n`) подсвечивается в каждом своей частью.
List<HighlightMark> marksIn(String text, List<({String id, String quote})> highlights) {
  final found = <HighlightMark>[];
  for (final highlight in highlights) {
    for (final part in highlight.quote.split('\n').map((line) => line.trim())) {
      if (part.length < _shortest) continue;
      final start = text.indexOf(part);
      if (start >= 0) found.add(HighlightMark(start, start + part.length, highlight.id));
    }
  }
  found.sort((a, b) => a.start.compareTo(b.start));
  final marks = <HighlightMark>[];
  var reached = 0;
  for (final mark in found) {
    final start = mark.start < reached ? reached : mark.start;
    if (start >= mark.end) continue;
    marks.add(HighlightMark(start, mark.end, mark.id));
    reached = mark.end;
  }
  return marks;
}

/// Где цитата в тексте статьи, знаков от начала: по ней цитаты идут по порядку.
/// Не нашлась — в конец.
int quotePosition(String plainText, String quote) {
  final first = quote.split('\n').map((line) => line.trim()).firstWhere((line) => line.isNotEmpty, orElse: () => '');
  final at = first.isEmpty ? -1 : plainText.indexOf(first);
  return at < 0 ? plainText.length : at;
}
