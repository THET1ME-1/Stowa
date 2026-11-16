// Часть заметки по ссылке Obsidian `[[Заметка#Заголовок]]` или `[[Заметка#^метка]]`:
// так карточка холста и превью показывают только раздел, а не заметку целиком.

final _heading = RegExp(r'^(#{1,6})\s+(.+?)\s*#*\s*$');
final _fence = RegExp(r'^\s*(```|~~~)');

/// Текст раздела по [subpath] (`#Заголовок`, `#Раздел#Подраздел`, `#^метка`).
/// Пусто или раздела нет — весь текст: лучше показать заметку, чем пустую карточку.
String noteSection(String body, String? subpath) {
  final path = (subpath ?? '').trim();
  if (path.isEmpty || path == '#') return body;
  final lines = body.split('\n');
  if (path.startsWith('#^')) return _block(lines, path.substring(2).trim()) ?? body;
  final wanted = [for (final part in path.split('#')) if (part.trim().isNotEmpty) _norm(part)];
  if (wanted.isEmpty) return body;

  // заголовки вне кода: строка и уровень
  final headings = <(int line, int level, String text)>[];
  var inCode = false;
  for (final (i, line) in lines.indexed) {
    if (_fence.hasMatch(line)) inCode = !inCode;
    if (inCode) continue;
    if (_heading.firstMatch(line) case final match?) headings.add((i, match[1]!.length, _norm(match[2]!)));
  }
  // путь ищется по порядку: каждый следующий заголовок глубже и ниже предыдущего
  var from = -1;
  var level = 0;
  var end = lines.length;
  for (final name in wanted) {
    final found = headings.where((one) => one.$1 > from && one.$1 < end && one.$2 > level && one.$3 == name).firstOrNull;
    if (found == null) return body;
    from = found.$1;
    level = found.$2;
    end = headings.where((one) => one.$1 > from && one.$2 <= level).firstOrNull?.$1 ?? lines.length;
  }
  return lines.sublist(from + 1, end).join('\n').trim();
}

/// Подпись раздела для карточки: последний заголовок пути; у ^метки подписи нет.
String? sectionTitle(String? subpath) {
  final path = (subpath ?? '').trim();
  if (path.isEmpty || path.startsWith('#^')) return null;
  final parts = [for (final part in path.split('#')) if (part.trim().isNotEmpty) part.trim()];
  return parts.lastOrNull;
}

/// Абзац или пункт с меткой `^id` в конце, без самой метки.
String? _block(List<String> lines, String id) {
  final mark = RegExp(r'\s\^' + RegExp.escape(id) + r'\s*$');
  for (final (i, line) in lines.indexed) {
    if (!mark.hasMatch(' $line')) continue;
    // метка на отдельной строке относится к абзацу над ней
    if (line.trim() == '^$id') {
      var start = i;
      while (start > 0 && lines[start - 1].trim().isNotEmpty) {
        start--;
      }
      return lines.sublist(start, i).join('\n').trim();
    }
    var start = i;
    while (start > 0 && lines[start - 1].trim().isNotEmpty && !lines[start - 1].trimLeft().startsWith(RegExp(r'[-*+]\s|\d+\.\s|#'))) {
      start--;
    }
    return [...lines.sublist(start, i), line.replaceFirst(RegExp(r'\s*\^' + RegExp.escape(id) + r'\s*$'), '')].join('\n').trim();
  }
  return null;
}

String _norm(String text) => text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
