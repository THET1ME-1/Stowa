/// Связи заметок руками: `[[Заголовок]]` в тексте и поиск заметки, с которой связать.
/// Устройство — `docs/specs/2026-11-13-note-links-design.md`.
library;

import 'models.dart';
import 'word_forms.dart' show foldText, wordsOf;

/// `[[Заметка]]` и `[[Заметка|подпись]]`, но не вставка картинки `![[фото.jpg]]`.
/// Группа 1 — заголовок, группа 2 — подпись.
final wikiLink = RegExp(r'(?<!!)\[\[([^\]|#\n]+)(?:#[^\]|\n]*)?(?:\|([^\]\n]*))?\]\]');

/// Ссылка на заметку в разобранном тексте: касание открывает заметку с этим заголовком.
const noteLinkScheme = 'stowa-note:';

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
