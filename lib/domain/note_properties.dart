import 'dart:convert';

import 'vault_note.dart';

/// Вид свойства заметки: от него зависит, чем его править.
enum PropertyKind { text, list, number, checkbox, date, other }

// так день узнаёт Obsidian
final _day = RegExp(r'^\d{4}-[01]\d-[0-3]\d$');

/// Вид по значению из файла, как его выводит Obsidian. Вложенное — [PropertyKind.other].
PropertyKind propertyKind(Object? value) => switch (value) {
  bool() => PropertyKind.checkbox,
  num() => PropertyKind.number,
  final String text when _day.hasMatch(text) => PropertyKind.date,
  String() || null => PropertyKind.text,
  final List<Object?> list when list.every((item) => item is! List && item is! Map) => PropertyKind.list,
  _ => PropertyKind.other,
};

/// Значение текстом: для поля правки и для строки блока. Пункты списка делит [separator].
String propertyText(Object? value, {String separator = '\n'}) => switch (value) {
  null => '',
  final String text => text,
  num() || bool() => '$value',
  final List<Object?> list when propertyKind(list) == PropertyKind.list => list.map(propertyText).join(separator),
  _ => jsonEncode(value),
};

/// Значение из набранного в поле. Не число там, где нужно число, — [FormatException].
/// [previous] — прежнее значение: нетронутый пункт списка остаётся числом или галочкой.
Object? propertyValue(PropertyKind kind, String text, {Object? previous}) {
  final typed = text.trim();
  switch (kind) {
    case PropertyKind.text || PropertyKind.date || PropertyKind.other:
      return typed.isEmpty ? null : typed;
    case PropertyKind.checkbox:
      return typed == 'true';
    case PropertyKind.number:
      if (typed.isEmpty) return null;
      final number = num.tryParse(typed.replaceAll(',', '.'));
      if (number == null || !number.isFinite) throw FormatException('не число', typed);
      return number;
    case PropertyKind.list:
      final before = {if (previous is List<Object?>) for (final item in previous) propertyText(item): item};
      return [
        for (final line in text.split('\n'))
          if (line.trim().isNotEmpty) before[line.trim()] ?? line.trim(),
      ];
  }
}

/// День свойства для календаря; дня, которого нет (31 февраля), нет и здесь.
DateTime? propertyDay(Object? value) {
  if (value is! String || !_day.hasMatch(value)) return null;
  final day = DateTime.parse(value);
  return propertyDayText(day) == value ? day : null;
}

/// День так, как его пишет Obsidian: 2026-03-05.
String propertyDayText(DateTime day) => '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// Набор с новым или поправленным свойством. [was] — прежнее имя: свойство остаётся на своём месте.
Map<String, Object?> withProperty(Map<String, Object?> properties, {String? was, required String name, required Object? value}) {
  if (!properties.containsKey(was)) return {...properties, name: value};
  return {for (final entry in properties.entries) if (entry.key == was) name: value else entry.key: entry.value};
}

Map<String, Object?> withoutProperty(Map<String, Object?> properties, String name) => {
  for (final entry in properties.entries)
    if (entry.key != name) entry.key: entry.value,
};

/// Можно ли завести свойство с таким именем: не пустое, не своё у Stowa и не занятое в заметке.
bool propertyNameFree(String name, {required Set<String> taken}) {
  final typed = name.trim();
  return typed.isNotEmpty && !isOwnVaultProperty(typed) && !taken.contains(typed);
}
