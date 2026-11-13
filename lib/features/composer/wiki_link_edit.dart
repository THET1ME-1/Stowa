import 'package:flutter/services.dart';

import '../../domain/note_links.dart';

/// Набран второй «[» подряд — сразу дописать «]]», курсор между скобками: дальше
/// подсказка заметок. Вставку текста и уже закрытые скобки не трогает.
TextEditingValue closeWikiBrackets(TextEditingValue old, TextEditingValue next) {
  final caret = next.selection.baseOffset;
  final typedOne = next.text.length == old.text.length + 1 && next.selection.isCollapsed && caret >= 2;
  if (!typedOne || next.text[caret - 1] != '[' || next.text[caret - 2] != '[') return next;
  if (next.text.startsWith(']]', caret)) return next;
  return TextEditingValue(text: next.text.replaceRange(caret, caret, ']]'), selection: TextSelection.collapsed(offset: caret));
}

/// Выбрана заметка из подсказки: заголовок встаёт между скобками вместо набранного,
/// курсор — за «]]» (их дописывает, если не было).
TextEditingValue completeWikiLink(TextEditingValue value, String title) {
  final caret = value.selection.baseOffset;
  final query = wikiQueryAt(value.text, caret);
  if (query == null) return value;
  final closed = value.text.startsWith(']]', query.end);
  final text = value.text.replaceRange(query.start, closed ? query.end + 2 : query.end, '$title]]');
  return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: query.start + title.length + 2));
}

/// Набранное между `[[` и курсором, если подсказка нужна; иначе null.
String? wikiQueryOf(TextEditingValue value) {
  if (!value.selection.isValid || !value.selection.isCollapsed) return null;
  return wikiQueryAt(value.text, value.selection.baseOffset)?.query;
}
