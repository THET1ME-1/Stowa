/// Разбор строки ввода для поиска и подсказок: слово под курсором, команда,
/// слова запроса. Без Flutter, чтобы тестировалось быстро.
library;

/// Встроенные команды строки. Плагины встанут рядом с ними.
enum LineCommand { remind, task, list, find, inbox }

enum CaretKind { tag, folder, command }

/// Что набирается под курсором: `#тег`, `@папка` или `/команда`.
class CaretToken {
  const CaretToken({required this.kind, required this.query, required this.start, required this.end});

  final CaretKind kind;

  /// Набранное без знака, в нижнем регистре.
  final String query;

  /// Кусок текста, который заменит выбранная подсказка, вместе со знаком.
  final int start;
  final int end;
}

String normalizeQuery(String text) => text.toLowerCase().replaceAll('ё', 'е');

final _markBefore = RegExp(r'(^|\s)([#@])([^\s#@]*)$');
final _commandBefore = RegExp(r'^/(\S*)$');
final _wordTail = RegExp(r'^[^\s#@]*');

CaretToken? caretToken(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  final before = text.substring(0, caret);
  final mark = _markBefore.firstMatch(before);
  if (mark != null) {
    final typed = mark.group(3)!;
    final tail = _wordTail.firstMatch(text.substring(caret))!.group(0)!.length;
    return CaretToken(
      kind: mark.group(2) == '#' ? CaretKind.tag : CaretKind.folder,
      query: normalizeQuery(typed),
      start: caret - typed.length - 1,
      end: caret + tail,
    );
  }
  final command = _commandBefore.firstMatch(before);
  if (command != null) {
    final tail = RegExp(r'^\S*').firstMatch(text.substring(caret))!.group(0)!.length;
    return CaretToken(kind: CaretKind.command, query: normalizeQuery(command.group(1)!), start: 0, end: caret + tail);
  }
  return null;
}

final _commandAtStart = RegExp(r'^/(\S+)\s*');

/// Команда в начале строки и текст после неё. Ключи команд на всех языках
/// сразу: русскую команду узнаёт и английский интерфейс.
({LineCommand? command, String rest}) parseCommand(String text, Map<LineCommand, List<String>> keys) {
  final match = _commandAtStart.firstMatch(text);
  if (match == null) return (command: null, rest: text);
  final typed = normalizeQuery(match.group(1)!);
  for (final entry in keys.entries) {
    if (entry.value.any((key) => normalizeQuery(key) == typed)) {
      return (command: entry.key, rest: text.substring(match.end));
    }
  }
  return (command: null, rest: text);
}

const _stopWords = {
  'в', 'во', 'на', 'и', 'с', 'со', 'по', 'для', 'что', 'чтобы', 'это', 'от', 'до', 'из', 'же', 'ли', 'не', 'но', 'как',
  'мне', 'там', 'тут', 'его', 'ее', 'их', 'про', 'надо', 'нужно', 'или', 'еще', 'уже', 'бы', 'то', 'так', 'вот', 'все',
  'тоже', 'только', 'чем', 'где', 'когда', 'у', 'к', 'а', 'о', 'об',
  'the', 'an', 'of', 'to', 'in', 'on', 'for', 'and', 'or', 'is', 'it', 'my', 'at', 'with',
};

/// Служебное слово: ни искать, ни раскладывать по нему нечего.
bool isStopWord(String word) => _stopWords.contains(word);

final _wordSplit = RegExp(r'[^a-zа-я0-9]+');
final _latinOrDigit = RegExp(r'[0-9a-z]');
final _ending = RegExp(r'(ами|ями|ого|его|ому|ему|ыми|ими|ая|яя|ое|ее|ые|ие|ой|ей|ий|ый|ом|ем|ам|ям|ах|ях|ую|юю|ов|ев|у|ю|а|я|ы|и|е|о|ь)$');

/// Основа русского слова: окончание срезается, короткие и латинские слова как есть.
String stem(String word) {
  if (word.length < 5 || _latinOrDigit.hasMatch(word)) return word;
  return word.replaceFirst(_ending, '');
}

/// Слова запроса: без служебных и без повторов по основе.
List<String> searchWords(String text) {
  final seen = <String>{};
  return [
    for (final word in normalizeQuery(text).split(_wordSplit))
      if (word.length >= 2 && !_stopWords.contains(word) && seen.add(stem(word))) word,
  ];
}

/// Слова отличаются не больше чем на одну букву: лишняя, пропущенная или другая.
bool nearWords(String a, String b) {
  if ((a.length - b.length).abs() > 1) return false;
  var i = 0, j = 0, edits = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      i++;
      j++;
      continue;
    }
    if (++edits > 1) return false;
    if (a.length > b.length) {
      i++;
    } else if (b.length > a.length) {
      j++;
    } else {
      i++;
      j++;
    }
  }
  return edits + (a.length - i) + (b.length - j) <= 1;
}

/// Пункты для «/список»: каждая строка или запятая.
List<String> checklistItems(String text) =>
    [for (final part in text.split(RegExp(r'[\n,]'))) if (part.trim().isNotEmpty) part.trim()];

String checklistBody(List<String> items) => items.map((item) => '- [ ] $item').join('\n');
