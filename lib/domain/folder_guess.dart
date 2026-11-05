import 'dart:math';

import 'line_query.dart';
import 'models.dart';

/// Вещь в папке глазами угадывателя: весь её текст одной строкой и приметы,
/// которых в тексте нет: сайт ссылки, вид вещи, тип файла ([itemSignals]).
class FolderDoc {
  const FolderDoc({required this.folderId, required this.text, this.signals = const []});

  final String folderId;
  final String text;
  final List<String> signals;
}

/// Приметы вещи кроме слов. Сайт тянет так же сильно, как редкое слово: все
/// ссылки с Хабра у человека обычно в одной папке. Вид вещи — чуть слабее и только
/// когда в папке уже не меньше двух таких: одно фото не делает папку фотоальбомом.
List<String> itemSignals({required ItemKind kind, String? url, String? fileName}) {
  final host = url == null ? null : Uri.tryParse(url)?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final extension = fileName == null || !fileName.contains('.') ? null : fileName.split('.').last.toLowerCase();
  return [
    if (host != null && host.isNotEmpty) 'site:$host',
    // у заметки вид ничего не говорит: заметки есть в каждой папке
    if (kind != ItemKind.note) 'kind:${kind.name}',
    if (extension != null && extension.length <= 5 && kind == ItemKind.file) 'ext:$extension',
  ];
}

double _signalWeight(String signal) => switch (signal.split(':').first) {
  'site' || 'ext' => 1.0,
  _ => 0.8,
};

int _signalMinHits(String signal) => signal.startsWith('kind:') ? 2 : 1;

/// Куда, скорее всего, относится новая заметка, и по каким словам это видно.
class FolderGuess {
  const FolderGuess({required this.folderId, required this.words, required this.byName, required this.score});

  final String folderId;

  /// Слова из новой заметки в том виде, как написаны, самые весомые первыми.
  final List<String> words;

  /// Решило имя собственное: «Милтон», «Милтона».
  final bool byName;
  final double score;
}

final _token = RegExp(r'[\p{L}\p{N}]+', unicode: true);
final _sentenceEnd = RegExp(r'[.!?\n:;«"(—–-]');

// меньше этого — уверенности нет, папку не выбираем
const _minScore = 1.0;
// победитель должен заметно обгонять второе место
const _lead = 1.6;
const _nameWeight = 2.0;

typedef _Word = ({String stem, String original, bool name});

// когда, а не про что: «сегодня в 16:41» есть у любой вещи с напоминанием и папку не решает.
// Длинные основы ловят все формы («пятницу», «января»), короткие слова — только целиком,
// иначе «час» съел бы «часы», а «сред» — «средство».
const _timeStems = [
  'сегодн', 'завтр', 'послезавтр', 'вчераш', 'минут', 'недел', 'месяц',
  'понедельник', 'вторник', 'четверг', 'пятниц', 'суббот', 'воскресен', 'выходн',
  'январ', 'феврал', 'апрел', 'август', 'сентябр', 'октябр', 'ноябр', 'декабр',
  'напомн',
];
const _timeWords = {
  'вчера', 'утро', 'утра', 'утром', 'вечер', 'вечера', 'вечером', 'днем', 'днём', 'днями', 'ночь', 'ночи', 'ночью',
  // «часов» нет: это и время, и наручные часы
  'час', 'часа', 'часу', 'среда', 'среду', 'среды', 'март', 'марта', 'марте', 'май', 'мая', 'мае',
  'июнь', 'июня', 'июне', 'июль', 'июля', 'июле', 'через', 'потом',
};

bool _isTimeWord(String lower) => _timeWords.contains(lower) || _timeStems.any(lower.startsWith);

/// Слова текста без служебных и без адресов; имя — слово с заглавной не в начале предложения.
List<_Word> _words(String raw) {
  // адрес — не слова: «youtube», «watch», «recipes» из ссылки связали бы что угодно с чем угодно
  final text = raw.replaceAll(RegExp(r'https?://\S+|www\.\S+', caseSensitive: false), ' ');
  final words = <_Word>[];
  for (final match in _token.allMatches(text)) {
    final original = match.group(0)!;
    final lower = normalizeQuery(original);
    if (lower.length < 3 || isStopWord(lower) || _isTimeWord(lower) || RegExp(r'^\d+$').hasMatch(lower)) continue;
    final capital = original[0] != original[0].toLowerCase();
    final before = text.substring(0, match.start).trimRight();
    final startsSentence = before.isEmpty || _sentenceEnd.hasMatch(before[before.length - 1]);
    words.add((stem: stem(lower), original: original, name: capital && !startsSentence));
  }
  return words;
}

/// Значимые слова текста: основа для сравнения и слово, как написано.
List<({String stem, String original})> meaningfulWords(String text) => [for (final word in _words(text)) (stem: word.stem, original: word.original)];

/// Умный разбор без сети: какие слова уже живут в какой папке. Слово, которое
/// есть только в одной папке, тянет туда сильно, общее для всех — почти никак,
/// имя героя — вдвое сильнее обычного слова.
class FolderIndex {
  FolderIndex(List<FolderDoc> docs) : _docs = docs.length {
    for (final doc in docs) {
      _sizes[doc.folderId] = (_sizes[doc.folderId] ?? 0) + 1;
      // приметы живут рядом со словами: с двоеточием они ни с одной основой не совпадут
      final stems = {for (final word in _words(doc.text)) word.stem, ...doc.signals};
      for (final stem in stems) {
        _spread[stem] = (_spread[stem] ?? 0) + 1;
        final hits = _hits.putIfAbsent(doc.folderId, () => {});
        hits[stem] = (hits[stem] ?? 0) + 1;
      }
    }
  }

  final int _docs;

  /// Сколько вещей у каждого ярлыка.
  final _sizes = <String, int>{};

  /// В скольких вещях встречается основа слова.
  final _spread = <String, int>{};

  /// Сколько вещей папки содержат основу.
  final _hits = <String, Map<String, int>>{};

  FolderGuess? guess(String text, {List<String> signals = const []}) {
    final (:scores, :evidence) = _score(text, signals);
    if (scores.isEmpty) return null;
    final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1].value : 0.0;
    if (best.value < _minScore || best.value < second * _lead) return null;
    final proof = [...evidence[best.key]!]..sort((a, b) => b.$2.compareTo(a.$2));
    return FolderGuess(
      folderId: best.key,
      // вид вещи и тип файла словами не назвать: в причину идут слова и сайт
      words: [for (final (word, _, _) in proof.where((one) => one.$1.isNotEmpty).take(3)) word],
      byName: proof.first.$3,
      score: best.value,
    );
  }

  /// Ярлыки, к которым текст тянет не меньше [minScore], у которых уже не меньше
  /// [minSize] вещей. Для тегов: у вещи их бывает несколько, поэтому второе место
  /// первому не мешает.
  List<String> strong(String text, {List<String> signals = const [], double minScore = 1.5, int minSize = 2}) {
    final scores = _score(text, signals).scores;
    final picked = scores.entries.where((entry) => entry.value >= minScore && (_sizes[entry.key] ?? 0) >= minSize).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final entry in picked) entry.key];
  }

  /// Папки по похожести, лучшие первыми, даже без уверенности: подсказки «Разобрать».
  List<String> rank(String text, {List<String> signals = const []}) {
    final scores = _score(text, signals).scores;
    return [for (final entry in scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value))) entry.key];
  }

  ({Map<String, double> scores, Map<String, List<(String, double, bool)>> evidence}) _score(String text, List<String> signals) {
    final scores = <String, double>{};
    final evidence = <String, List<(String, double, bool)>>{};
    if (_docs == 0) return (scores: scores, evidence: evidence);
    void add(String stem, String shown, double factor, {bool name = false, int minHits = 1}) {
      final spread = _spread[stem];
      if (spread == null) return;
      // редкость слова по всей базе
      final rarity = log((_docs + 1) / spread);
      for (final MapEntry(key: folder, value: hits) in _hits.entries) {
        final count = hits[stem];
        if (count == null || count < minHits) continue;
        // какая доля вещей с этим словом лежит именно в этой папке
        final weight = rarity * (count / spread) * factor;
        scores[folder] = (scores[folder] ?? 0) + weight;
        evidence.putIfAbsent(folder, () => []).add((shown, weight, name));
      }
    }

    final seen = <String>{};
    for (final word in _words(text)) {
      if (!seen.add(word.stem)) continue;
      add(word.stem, word.original, word.name ? _nameWeight : 1, name: word.name);
    }
    for (final signal in signals.toSet()) {
      add(signal, signal.startsWith('site:') ? signal.substring(5) : '', _signalWeight(signal), minHits: _signalMinHits(signal));
    }
    return (scores: scores, evidence: evidence);
  }
}
