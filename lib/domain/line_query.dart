/// Разбор строки ввода для поиска и подсказок: слово под курсором, команда,
/// слова запроса. Без Flutter, чтобы тестировалось быстро.
library;

import 'search_query.dart' show isServiceWord;
import 'word_forms.dart';

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

/// Нижний регистр, «ё» как «е», латиница без знаков над буквами.
String normalizeQuery(String text) => foldText(text);

final _markBefore = RegExp(r'(^|\s)([#@])([^\s#@]*)$');
// имя папки бывает из нескольких слов: «@Беспроводные возможности», до четырёх слов
final _folderBefore = RegExp(r'(^|\s)@([^\s#@][^#@\n]*)$');
const _folderWords = 4;
final _commandBefore = RegExp(r'^/(\S*)$');
final _wordTail = RegExp(r'^[^\s#@]*');

CaretToken? caretToken(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  final before = text.substring(0, caret);
  final folder = _folderBefore.firstMatch(before);
  final typedFolder = folder?.group(2);
  if (typedFolder != null && typedFolder.contains(' ')) {
    if (typedFolder.trim().split(RegExp(r'\s+')).length > _folderWords) return null;
    final tail = _wordTail.firstMatch(text.substring(caret))!.group(0)!.length;
    return CaretToken(kind: CaretKind.folder, query: normalizeQuery(typedFolder), start: caret - typedFolder.length - 1, end: caret + tail);
  }
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
  'в',
  'во',
  'на',
  'и',
  'с',
  'со',
  'по',
  'для',
  'что',
  'чтобы',
  'это',
  'от',
  'до',
  'из',
  'же',
  'ли',
  'не',
  'но',
  'как',
  'мне',
  'там',
  'тут',
  'его',
  'ее',
  'их',
  'про',
  'надо',
  'нужно',
  'или',
  'еще',
  'уже',
  'бы',
  'то',
  'так',
  'вот',
  'все',
  'тоже',
  'только',
  'чем',
  'где',
  'когда',
  'у',
  'к',
  'а',
  'о',
  'об',
  'the',
  'an',
  'of',
  'to',
  'in',
  'on',
  'for',
  'and',
  'or',
  'is',
  'it',
  'my',
  'at',
  'with',
};

/// Служебное слово: ни искать, ни раскладывать по нему нечего. Свой список дополняет
/// общий список семи языков.
bool isStopWord(String word) => _stopWords.contains(word) || isServiceWord(word);

/// Основа слова на любом из семи языков: окончание срезано.
String stem(String word) => stemOf(word);

/// Слова запроса: без служебных и без повторов по основе.
List<String> searchWords(String text) {
  final seen = <String>{};
  return [
    for (final word in wordsOf(text).map(foldText))
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
List<String> checklistItems(String text) => [
  for (final part in text.split(RegExp(r'[\n,]')))
    if (part.trim().isNotEmpty) part.trim(),
];

String checklistBody(List<String> items) => items.map((item) => '- [ ] $item').join('\n');
