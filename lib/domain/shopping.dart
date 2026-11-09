/// Список покупок из обычной заметки: «купить молоко, хлеб и яйца». Без ИИ, по словам.
library;

import 'note_blocks.dart' show checkLine;

// «купить», «buy» и переводы в начале заметки; «купил», «купите» — не список
final _start = RegExp(r'^\s*(купить|buy|купити|cumpără|de cumpărat|kaufen|kupić|comprar)(?![\p{L}])[ \t]*:?[ \t]*', caseSensitive: false, unicode: true);

// пункты в строке: запятые, точка с запятой и «и» на семи языках
final _separators = RegExp(r'\s*[,;]\s*|\s+(?:и|и ещё|and|і|та|și|i|und|y)\s+', caseSensitive: false);

// маркер пункта в строке ниже: «- хлеб», «• сыр», «2. яйца»
final _bullet = RegExp(r'^\s*(?:[-•*–]|\d+[.)])\s*');

/// Начинается ли заметка словом «купить».
bool isShoppingStart(String firstLine) => _start.hasMatch(firstLine);

/// Что купить: пункты первой строки после «купить» и строки ниже. Не список — пусто.
List<String> shoppingItems(String body) {
  final lines = body.split('\n');
  final first = _start.firstMatch(lines.first);
  if (first == null) return const [];
  return [
    for (final part in lines.first.substring(first.end).split(_separators)) ?_item(part),
    for (final line in lines.skip(1)) ?_item(line.replaceFirst(_bullet, '')),
  ];
}

String? _item(String raw) {
  final text = raw.trim().replaceAll(RegExp(r'[.!]+$'), '');
  return text.isEmpty ? null : text;
}

/// Текст заметки списком галочек: «Купить:» словом человека и пункты строками.
/// Уже галочки, не покупки или один пункт — null: переделывать нечего.
String? shoppingChecklist(String body) {
  if (body.split('\n').any(checkLine.hasMatch)) return null;
  final first = _start.firstMatch(body.split('\n').first);
  if (first == null) return null;
  final items = shoppingItems(body);
  if (items.length < 2) return null;
  final word = first.group(1)!;
  final heading = '${word[0].toUpperCase()}${word.substring(1)}:';
  return [heading, for (final item in items) '- [ ] $item'].join('\n');
}
