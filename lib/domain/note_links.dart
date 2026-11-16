/// Связи заметок руками: `[[Заголовок]]` в тексте и поиск заметки, с которой связать.
/// Устройство — `docs/specs/2026-11-13-note-links-design.md`.
library;

import 'dart:convert';

import 'models.dart';
import 'word_forms.dart' show foldText, wordsOf;

/// `[[Заметка]]` и `[[Заметка|подпись]]`, но не вставка картинки `![[фото.jpg]]`.
/// Группа 1 — заголовок, группа 2 — подпись.
final wikiLink = RegExp(r'(?<!!)\[\[([^\]|#\n]+)(?:#[^\]|\n]*)?(?:\|([^\]\n]*))?\]\]');

// любая ссылка Obsidian: [[цель#раздел|подпись]] и вставка ![[цель]]; группа 2 — цель
final _anyWiki = RegExp(r'(!?\[\[)([^\]|#\n]+)((?:#[^\]|\n]*)?(?:\|[^\]\n]*)?\]\])');

// ссылка markdown [текст](цель) и [текст](<цель с пробелами>); группа 2 — цель
final _markdownLink = RegExp(r'(\]\()(<[^>\n]+>|[^)\s]+)(\))');

/// Как сослаться на [to] вместо [from] в том же виде, что [target]: короткое имя остаётся
/// коротким, путь — путём, с «.md» или без, как было. Не та цель — null.
String? _retarget(String target, String from, String to) {
  final note = from.toLowerCase().endsWith('.md');
  String strip(String path) => note ? path.substring(0, path.length - 3) : path;
  final name = from.split('/').last;
  final wanted = target.trim();
  final lower = wanted.toLowerCase();
  final withExtension = !note || lower.endsWith('.md');
  final bare = note && withExtension ? wanted.substring(0, wanted.length - 3) : wanted;
  final toName = to.split('/').last;
  if (!wanted.contains('/')) {
    if (bare.toLowerCase() != strip(name).toLowerCase()) return null;
    return withExtension ? toName : strip(toName);
  }
  if (bare.toLowerCase() != strip(from).toLowerCase()) return null;
  return withExtension ? to : strip(to);
}

/// Ссылки на переименованный или переложенный файл следуют за ним, как в Obsidian с «Всегда
/// обновлять ссылки»: `[[Имя]]`, `[[Имя#Раздел|подпись]]`, `[[папка/Имя]]`, вставки `![[…]]`,
/// ссылки markdown `[текст](путь.md)`. [from] и [to] — пути от корня хранилища. Вид ссылки
/// остаётся, поэтому перенос в другую папку трогает только ссылки с путём.
String renameLinks(String text, {required String from, required String to}) {
  if (from == to) return text;
  final wiki = text.replaceAllMapped(_anyWiki, (match) {
    final target = _retarget(match.group(2)!, from, to);
    return target == null ? match.group(0)! : '${match.group(1)}$target${match.group(3)}';
  });
  return wiki.replaceAllMapped(_markdownLink, (match) {
    final raw = match.group(2)!;
    final angled = raw.startsWith('<');
    final encoded = !angled && raw.contains('%');
    final inner = angled ? raw.substring(1, raw.length - 1) : raw;
    final hash = inner.indexOf('#');
    final path = hash < 0 ? inner : inner.substring(0, hash);
    final tail = hash < 0 ? '' : inner.substring(hash);
    final decoded = encoded ? _percentDecoded(path) : path;
    if (decoded == null) return match.group(0)!;
    final target = _retarget(decoded, from, to);
    if (target == null) return match.group(0)!;
    final written = encoded ? target.replaceAll(' ', '%20') : target;
    return '${match.group(1)}${angled ? '<$written$tail>' : '$written$tail'}${match.group(3)}';
  });
}

// «Речь%20защита.md» → «Речь защита.md». Uri.decodeComponent не пускает кириллицу как есть,
// а Obsidian кодирует только пробелы и знаки; битая запись — null
String? _percentDecoded(String text) {
  final bytes = <int>[];
  for (var index = 0; index < text.length; index++) {
    if (text[index] == '%' && index + 2 < text.length) {
      final byte = int.tryParse(text.substring(index + 1, index + 3), radix: 16);
      if (byte == null) return null;
      bytes.add(byte);
      index += 2;
    } else {
      bytes.addAll(utf8.encode(text[index]));
    }
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}

/// Карточки холста `.canvas` на переименованный файл: поле `"file"` — путь от корня.
String renameCanvasFile(String canvas, {required String from, required String to}) {
  if (from == to) return canvas;
  final escaped = RegExp.escape(jsonEncodeString(from));
  return canvas.replaceAllMapped(RegExp('("file"\\s*:\\s*)$escaped'), (match) => '${match.group(1)}${jsonEncodeString(to)}');
}

/// Строка в кавычках JSON, как её пишет холст.
String jsonEncodeString(String value) => '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// Ссылка на заметку в разобранном тексте: касание открывает заметку с этим заголовком.
const noteLinkScheme = 'stowa-note:';

/// Ссылка `[[…]]` в тексте по кускам для живой разметки, как у Obsidian: [shownStart]..[shownEnd] —
/// что видно ссылкой (подпись, иначе название), остальное от [start] до [end] прячется,
/// пока курсор не внутри.
typedef WikiPiece = ({int start, int end, int shownStart, int shownEnd});

List<WikiPiece> wikiPieces(String text) => [
  for (final match in wikiLink.allMatches(text))
    if (match.group(2) case final label? when label.trim().isNotEmpty)
      (start: match.start, end: match.end, shownStart: match.end - 2 - label.length, shownEnd: match.end - 2)
    else
      (start: match.start, end: match.end, shownStart: match.start + 2, shownEnd: match.start + 2 + match.group(1)!.length),
];

/// Заголовок для глаз: `[[Название|подпись]]` показывается подписью, `[[Название]]` — названием.
/// Сам заголовок не меняется: по нему заметку находят ссылки и первая строка текста.
String shownTitle(String title) =>
    title.contains('[[') ? title.replaceAllMapped(wikiLink, (match) => (match.group(2)?.trim().isNotEmpty ?? false) ? match.group(2)!.trim() : match.group(1)!.trim()) : title;

/// Заголовки из `[[…]]` по порядку, без повторов и пустых.
List<String> wikiTitles(String text) {
  final titles = <String>[];
  for (final match in wikiLink.allMatches(text)) {
    final title = match.group(1)!.trim();
    if (title.isNotEmpty && !titles.contains(title)) titles.add(title);
  }
  return titles;
}

/// Курсор внутри `[[…`: где набранное между скобками и что набрано. Не внутри — null.
/// Запрос кончается на `]]` или на курсоре, если закрывающих нет; перенос строки его обрывает.
({int start, int end, String query})? wikiQueryAt(String text, int caret) {
  if (caret < 2 || caret > text.length) return null;
  final open = text.lastIndexOf('[[', caret - 2);
  if (open < 0) return null;
  // картинка, а не ссылка
  if (open > 0 && text[open - 1] == '!') return null;
  final start = open + 2;
  final before = text.substring(start, caret);
  // между «[[» и курсором уже закрыли или перешли на новую строку
  if (before.contains(']]') || before.contains('\n') || before.contains('[[')) return null;
  final close = text.indexOf(']]', caret);
  final newline = text.indexOf('\n', caret);
  final end = close >= 0 && (newline < 0 || close < newline) ? close : caret;
  return (start: start, end: end, query: text.substring(start, end));
}

/// Заметка, с которой можно связать: что показать в списке и по чему искать.
typedef LinkTarget = ({String id, String title, String text, DateTime at, ItemKind kind});

/// Заметки по словам набранного: каждое слово должно начинать слово заголовка или текста;
/// в заголовке весит вдвое. Равные — свежие выше. Пусто — просто свежие.
List<LinkTarget> rankLinkTargets(String query, List<LinkTarget> targets, {String? except, int limit = 5}) {
  final wanted = wordsOf(foldText(query));
  final scored = <(LinkTarget, int)>[];
  for (final target in targets) {
    if (target.id == except) continue;
    if (wanted.isEmpty) {
      scored.add((target, 0));
      continue;
    }
    final title = wordsOf(foldText(target.title));
    final text = wordsOf(foldText(target.text));
    var score = 0;
    var all = true;
    for (final word in wanted) {
      if (title.any((one) => one.startsWith(word))) {
        score += 2;
      } else if (text.any((one) => one.startsWith(word))) {
        score += 1;
      } else {
        all = false;
        break;
      }
    }
    if (all) scored.add((target, score));
  }
  scored.sort((a, b) => a.$2 != b.$2 ? b.$2.compareTo(a.$2) : b.$1.at.compareTo(a.$1.at));
  return [for (final (target, _) in scored.take(limit)) target];
}
