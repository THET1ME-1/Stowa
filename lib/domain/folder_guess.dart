import 'dart:math';

import 'line_query.dart';
import 'models.dart';
import 'topics.dart';

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

/// Сколько длится серия: две заметки подряд за это время в одной папке.
const seriesWindow = Duration(minutes: 15);

/// Папка серии: две последние заметки (новые первыми) легли в неё за [seriesWindow] —
/// следующая мысль, скорее всего, оттуда же: идеи книги пишутся пачкой. Нет серии — null.
String? seriesOf(List<({String? folderId, DateTime at})> latest, DateTime now) {
  if (latest.length < 2) return null;
  final folder = latest.first.folderId;
  if (folder == null || latest[1].folderId != folder) return null;
  return now.difference(latest[1].at) <= seriesWindow ? folder : null;
}

/// Папка с именем: по имени видно, про что она, ещё до первой заметки в ней.
class FolderLabel {
  const FolderLabel(this.id, this.name);

  final String id;
  final String name;
}

// слово заметки — имя папки в любой форме: «плитка для ремонта» и папка «Ремонт».
// Самый сильный знак намерения: перевешивает и пару слов чужой темы («на даче огурцы»)
const _nameMatchWeight = 4.0;
// слово темы папки: «молоко» и папка «Продукты»; больше трёх слов одной темы не копится
const _topicWeight = 1.1;
const _topicCap = 4;
// две прошлые заметки подряд легли в одну папку: заметка без единого признака уходит
// туда же (идея книги без «книжных» слов), а любой признак другой папки серию перебивает
const _seriesWeight = 1.0;
// человек вынул из папки заметку с этим словом: слово отталкивает от неё
const _rejectWeight = 0.8;
// тема папки по её заметкам: не меньше двух заметок и такая доля из них
const _topicShare = 0.4;

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
  /// [labels] — имена папок: по ним темы и совпадение с именем. [rejected] — заметки,
  /// которые человек вынул из этих папок: их слова от папки отталкивают.
  FolderIndex(List<FolderDoc> docs, {List<FolderLabel> labels = const [], List<FolderDoc> rejected = const []}) : _docs = docs.length {
    final docTopics = <String, Map<Topic, int>>{};
    for (final doc in docs) {
      _sizes[doc.folderId] = (_sizes[doc.folderId] ?? 0) + 1;
      final words = _words(doc.text);
      // приметы живут рядом со словами: с двоеточием они ни с одной основой не совпадут
      final stems = {for (final word in words) word.stem, ...doc.signals};
      for (final stem in stems) {
        _spread[stem] = (_spread[stem] ?? 0) + 1;
        final hits = _hits.putIfAbsent(doc.folderId, () => {});
        hits[stem] = (hits[stem] ?? 0) + 1;
      }
      if (_mainTopic(words) case final topic?) {
        final counts = docTopics.putIfAbsent(doc.folderId, () => {});
        counts[topic] = (counts[topic] ?? 0) + 1;
      }
    }
    // тема папки — по имени, а без него по тому, про что её заметки
    for (final label in labels) {
      _nameStems[label.id] = {for (final word in _words(label.name)) if (word.stem.length >= 3) word.stem};
      _nameForms[label.id] = {for (final word in _words(label.name)) normalizeQuery(word.original)};
      for (final topic in topicsOfName(label.name)) {
        _topics.putIfAbsent(label.id, () => {})[topic] = 1.0;
      }
    }
    for (final MapEntry(key: folder, value: counts) in docTopics.entries) {
      final size = _sizes[folder] ?? 0;
      if (size < 2) continue;
      for (final MapEntry(key: topic, value: count) in counts.entries) {
        final share = count / size;
        final topics = _topics.putIfAbsent(folder, () => {});
        if (share >= _topicShare && share > (topics[topic] ?? 0)) topics[topic] = share;
      }
    }
    for (final doc in rejected) {
      final pushes = _rejected.putIfAbsent(doc.folderId, () => {});
      for (final stem in {for (final word in _words(doc.text)) word.stem}) {
        pushes[stem] = (pushes[stem] ?? 0) + 1;
      }
    }
  }

  // про что заметка: тема, у которой больше всего слов; ничьей и пустоты нет
  static Topic? _mainTopic(List<_Word> words) {
    final counts = <Topic, int>{};
    final seen = <String>{};
    for (final word in words) {
      if (!seen.add(word.stem)) continue;
      for (final topic in topicsOfWord(word.original)) {
        counts[topic] = (counts[topic] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    final ranked = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ranked.length > 1 && ranked[1].value == ranked.first.value ? null : ranked.first.key;
  }

  final int _docs;

  /// Основы слов имени папки.
  final _nameStems = <String, Set<String>>{};

  /// Слова имени папки целиком: от них отличается глагол с той же основой.
  final _nameForms = <String, Set<String>>{};

  /// Темы папки и насколько папка про них: по имени — 1, по заметкам — их доля.
  final _topics = <String, Map<Topic, double>>{};

  /// Сколько вынутых человеком заметок папки несли основу.
  final _rejected = <String, Map<String, int>>{};

  /// Сколько вещей у каждого ярлыка.
  final _sizes = <String, int>{};

  /// В скольких вещях встречается основа слова.
  final _spread = <String, int>{};

  /// Сколько вещей папки содержат основу.
  final _hits = <String, Map<String, int>>{};

  /// [series] — папка, куда легли две прошлые заметки подряд: мысль, скорее всего, оттуда же.
  FolderGuess? guess(String text, {List<String> signals = const [], String? series}) {
    final (:scores, :evidence) = _score(text, signals, series: series);
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

  ({Map<String, double> scores, Map<String, List<(String, double, bool)>> evidence}) _score(String text, List<String> signals, {String? series}) {
    final scores = <String, double>{};
    final evidence = <String, List<(String, double, bool)>>{};
    void push(String folder, String shown, double weight, {bool name = false}) {
      scores[folder] = (scores[folder] ?? 0) + weight;
      evidence.putIfAbsent(folder, () => []).add((shown, weight, name));
    }

    void add(String stem, String shown, double factor, {bool name = false, int minHits = 1}) {
      final spread = _spread[stem];
      if (spread == null || _docs == 0) return;
      // редкость слова по всей базе
      final rarity = log((_docs + 1) / spread);
      for (final MapEntry(key: folder, value: hits) in _hits.entries) {
        final count = hits[stem];
        if (count == null || count < minHits) continue;
        // какая доля вещей с этим словом лежит именно в этой папке
        push(folder, shown, rarity * (count / spread) * factor, name: name);
      }
    }

    final words = _words(text);
    final seen = <String>{};
    for (final word in words) {
      if (!seen.add(word.stem)) continue;
      add(word.stem, word.original, word.name ? _nameWeight : 1, name: word.name);
    }
    for (final signal in signals.toSet()) {
      add(signal, signal.startsWith('site:') ? signal.substring(5) : '', _signalWeight(signal), minHits: _signalMinHits(signal));
    }

    // имя папки прямо в заметке: «плитка для ремонта» — папка «Ремонт»
    final shownOf = <String, String>{for (final word in words.reversed) word.stem: word.original};
    for (final MapEntry(key: folder, value: stems) in _nameStems.entries) {
      for (final stem in stems.where(shownOf.containsKey)) {
        final shown = shownOf[stem]!;
        // «работал на врага» — не про папку «Работа»: глагол от её имени
        if (_nameForms[folder]!.any((form) => isVerbOf(normalizeQuery(shown), form))) continue;
        push(folder, shown, _nameMatchWeight);
      }
    }

    // тема: «молоко» тянет в папку продуктов, «предаст» и «злодей» — в книгу
    final topicWords = <Topic, List<String>>{};
    for (final shown in shownOf.values) {
      for (final topic in topicsOfWord(shown)) {
        topicWords.putIfAbsent(topic, () => []).add(shown);
      }
    }
    // 18+ перебивает всё: «nsfw арт посмотреть» — не кино
    if (topicWords[Topic.adult] case final adult?) {
      topicWords
        ..clear()
        ..[Topic.adult] = adult;
    }
    // готовка делает продукты ингредиентами: «сырники: творог, мука, жарить» — рецепт
    if ((topicWords[Topic.cooking]?.length ?? 0) >= 2 && topicWords.containsKey(Topic.groceries)) {
      topicWords[Topic.cooking]!.addAll(topicWords.remove(Topic.groceries)!);
    }
    // «купить», «заказать» — о покупке чего-то: видно, чего именно, — решает это
    if (topicWords.containsKey(Topic.shopping) && topicWords.keys.any((topic) => topic != Topic.shopping)) {
      topicWords.remove(Topic.shopping);
    }
    for (final MapEntry(key: folder, value: topics) in _topics.entries) {
      for (final MapEntry(key: topic, value: affinity) in topics.entries) {
        final found = topicWords[topic];
        if (found == null) continue;
        for (final shown in found.take(_topicCap)) {
          push(folder, shown, _topicWeight * affinity);
        }
      }
    }

    // серия: две прошлые заметки легли сюда — у этой папки фора
    if (series != null) push(series, '', _seriesWeight);

    // слова заметок, которые человек из папки вынул, от неё отталкивают
    for (final MapEntry(key: folder, value: pushes) in _rejected.entries) {
      final against = [for (final stem in shownOf.keys) ?pushes[stem]].fold(0, (sum, count) => sum + count);
      if (against > 0 && scores.containsKey(folder)) scores[folder] = scores[folder]! - _rejectWeight * min(against, _topicCap);
    }
    return (scores: scores, evidence: evidence);
  }
}
