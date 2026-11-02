import 'tag_name.dart';

// решётка не в середине слова, первая буква тега — не цифра
final _tag = RegExp(r'(?<![\p{L}\p{N}_#])#([\p{L}_][\p{L}\p{N}_]*)', unicode: true);
final _hexColor = RegExp(r'^[0-9a-fA-F]{6}$');

/// Теги, написанные прямо в тексте, уже нормализованные, без повторов,
/// в порядке появления. Цвет вида #FF0000 тегом не считается.
List<String> extractInlineTags(String text) {
  final tags = <String>[];
  for (final match in _tag.allMatches(text)) {
    final raw = match.group(1)!;
    if (_hexColor.hasMatch(raw)) continue;
    final name = normalizeTagName(raw);
    if (!tags.contains(name)) tags.add(name);
  }
  return tags;
}
