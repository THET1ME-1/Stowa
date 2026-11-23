import 'dart:math';

import 'line_query.dart';
import 'models.dart';
import 'topics.dart';

/// Вещь в папке глазами угадывателя: весь её текст одной строкой и приметы,
/// которых в тексте нет: сайт ссылки, вид вещи, тип файла ([itemSignals]).
class FolderDoc {
  const FolderDoc({required this.folderId, required String this.text, this.signals = const [], this.id, this.stamp});

  /// Заметка, которую [FolderMemory] уже резала на слова с той же отметкой
  /// ([FolderMemory.knows]): её текст из базы не тянут.
  const FolderDoc.remembered({required String this.id, required this.folderId, required Object this.stamp, this.signals = const []}) : text = null;

  final String folderId;

  /// Текст заметки; null — только у [FolderDoc.remembered].
  final String? text;
  final List<String> signals;

  /// Чья это заметка: по id [FolderMemory] узнаёт текст, который уже резала на слова.
  /// Без id заметка режется при каждой постройке.
  final String? id;

  /// Отметка правки из базы (время, длина, теги): с ней память сверяет заметку, не глядя
  /// в текст. Без отметки текст сверяется по длине и хешу.
  final Object? stamp;
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
// слово ребёнка или питомца весит вдвое: всё, что для них, — в их папку
const _ownerWeight = 2.0;
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

// выражения собираются один раз: слова режутся у каждой заметки хранилища
final _token = RegExp(r'[\p{L}\p{N}]+', unicode: true);
final _address = RegExp(r'https?://\S+|www\.\S+', caseSensitive: false);
final _number = RegExp(r'^\d+$');
// знаки, после которых слово начинает фразу
const _sentenceEnds = '.!?:;«"(—–-';

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

// слово, как написано, → его основа; пустая строка — слово папку не решает (служебное,
// короткое, время, число). Слова повторяются из заметки в заметку: «лекция» из тысячи
// конспектов сворачивается и режется один раз. Больше — память чистится целиком
final _stemMemo = <String, String>{};
const _stemMemoSize = 100000;
// длиннее слов не бывает: это ключ, хеш или вставленный мусор, второй раз он не встретится
const _memoWord = 40;

/// Сколько слов помнит разбор: для проверки, что память не растёт от мусора.
int get folderWordsRemembered => _stemMemo.length;

String _stemFor(String original) {
  if (original.length > _memoWord) return _stemOf(original);
  final known = _stemMemo[original];
  if (known != null) return known;
  if (_stemMemo.length >= _stemMemoSize) _stemMemo.clear();
  return _stemMemo[original] = _stemOf(original);
}

String _stemOf(String original) {
  final lower = normalizeQuery(original);
  final skipped = lower.length < 3 || isStopWord(lower) || _isTimeWord(lower) || _number.hasMatch(lower);
  return skipped ? '' : stem(lower);
}

// пробелы, которые снимает `trimRight`: обычные, неразрывные, переносы строк
bool _isSpace(int unit) =>
    unit == 0x20 ||
    (unit >= 0x09 && unit <= 0x0D) ||
    unit == 0x85 ||
    unit == 0xA0 ||
    unit == 0x1680 ||
    (unit >= 0x2000 && unit <= 0x200A) ||
    unit == 0x2028 ||
    unit == 0x2029 ||
    unit == 0x202F ||
    unit == 0x205F ||
    unit == 0x3000 ||
    unit == 0xFEFF;

/// Слово с места [start] начинает фразу: перед ним, не считая пробелов, ничего нет или стоит
/// знак конца фразы. Идём назад от слова: копия всего текста до него на каждое слово
/// стоила секунд на конспекте в двадцать тысяч знаков.
bool _startsSentence(String text, int start) {
  var at = start - 1;
  while (at >= 0 && _isSpace(text.codeUnitAt(at))) {
    at--;
  }
  return at < 0 || _sentenceEnds.contains(text[at]);
}

/// Слова текста без служебных и без адресов; имя — слово с заглавной не в начале предложения.
List<_Word> _words(String raw) {
  // адрес — не слова: «youtube», «watch», «recipes» из ссылки связали бы что угодно с чем угодно
  final text = raw.replaceAll(_address, ' ');
  final words = <_Word>[];
  for (final match in _token.allMatches(text)) {
    final original = match.group(0)!;
    final base = _stemFor(original);
    if (base.isEmpty) continue;
    final capital = original[0] != original[0].toLowerCase();
    words.add((stem: base, original: original, name: capital && !_startsSentence(text, match.start)));
  }
  return words;
}

/// Продолжение мысли, а не дело: от пяти слов и не начинается с глагола-дела
/// («позвонить», «забрать»).
bool _continues(String text) {
  final tokens = [for (final match in _token.allMatches(text)) normalizeQuery(match.group(0)!)];
  if (tokens.length < 5) return false;
  return !RegExp(r'(ть|ться|чь)$').hasMatch(tokens.first);
}

/// Значимые слова текста: основа для сравнения и слово, как написано.
List<({String stem, String original})> meaningfulWords(String text) => [for (final word in _words(text)) (stem: word.stem, original: word.original)];

/// Заметка, разрезанная на слова: основы без повторов и тема, у которой больше всего слов.
typedef _Parsed = ({List<String> stems, Topic? topic});

_Parsed _parse(String text) {
  final words = _words(text);
  return (stems: {for (final word in words) word.stem}.toList(growable: false), topic: FolderIndex._mainTopic(words));
}

const _Parsed _noWords = (stems: <String>[], topic: null);

/// Заметки, уже разрезанные на слова. Угадыватель пересобирается после каждой правки в
/// базе, а резать заново нужно только то, что поменялось: на хранилище в тысячи конспектов
/// полная постройка шла секундами на каждую запись. Заметка сверяется по отметке из базы
/// ([FolderDoc.stamp]), а без неё по длине и хешу текста, как в поиске.
class FolderMemory {
  final _known = <String, (Object, _Parsed)>{};

  /// Сколько раз заметку пришлось резать на слова; взятое из памяти не считается.
  int parsed = 0;

  /// Сколько заметок помнится.
  int get size => _known.length;

  /// Помнится ли заметка [id] с отметкой [stamp]: тогда её текст из базы тянуть незачем.
  bool knows(String id, Object stamp) => _known[id]?.$1 == stamp;

  // [asked] — кого спросила эта постройка: остальных в хранилище больше нет
  _Parsed _of(FolderDoc doc, Set<String> asked) {
    final id = doc.id;
    final text = doc.text;
    if (id == null) {
      parsed++;
      return _parse(text ?? '');
    }
    final stamp = doc.stamp ?? (text == null ? null : (text.length, text.hashCode));
    final known = _known[id];
    if (known != null && known.$1 == stamp) {
      asked.add(id);
      return known.$2;
    }
    // обещали, что память заметку знает, а её там уже нет: слов не выдумываем и пустоту
    // не запоминаем — следующая постройка спросит текст заново
    if (text == null || stamp == null) return _noWords;
    asked.add(id);
    parsed++;
    final fresh = _parse(text);
    _known[id] = (stamp, fresh);
    return fresh;
  }

  // постройка кончилась: заметки, о которых она не спросила, забываются
  void _settle(Set<String> asked) {
    if (asked.length != _known.length) _known.removeWhere((id, _) => !asked.contains(id));
  }
}

// во что обходится слово из памяти рядом со знаком текста, который ещё резать
const _stemCost = 4;
// на часы смотрим не чаще, чем через столько работы: небольшой набор строится без передышек
const _paceStep = 20000;
// дольше этого подряд поток не держим: кадр и чужие события ждут своей очереди
const _paceBudget = Duration(milliseconds: 8);

/// Счёт работы постройки: когда пора дать потоку передышку.
class _Pace {
  _Pace(this._wait);

  // передышка снаружи: человек печатает — постройка ждёт, пока он не занят
  final Future<void> Function()? _wait;
  final _busy = Stopwatch()..start();
  var _work = 0;

  /// Работы прибавилось на [cost]; true — пора отдохнуть.
  bool spent(int cost) {
    _work += cost;
    if (_work < _paceStep) return false;
    _work = 0;
    return _busy.elapsed > _paceBudget;
  }

  Future<void> rest() async {
    await Future<void>.delayed(Duration.zero);
    await _wait?.call();
    _busy.reset();
  }
}

/// Умный разбор без сети: какие слова уже живут в какой папке. Слово, которое
/// есть только в одной папке, тянет туда сильно, общее для всех — почти никак,
/// имя героя — вдвое сильнее обычного слова.
class FolderIndex {
  /// [labels] — имена папок: по ним темы и совпадение с именем. [rejected] — заметки,
  /// которые человек вынул из этих папок: их слова от папки отталкивают. [memory] —
  /// заметки, разрезанные на слова прошлой постройкой: заново режутся только правленые.
  ///
  /// Считает всё разом и держит поток: для небольших наборов. Всё хранилище — [build].
  FolderIndex(List<FolderDoc> docs, {List<FolderLabel> labels = const [], List<FolderDoc> rejected = const [], FolderMemory? memory}) : _docs = docs.length {
    final asked = <String>{};
    for (final doc in docs) {
      _learn(doc, memory, asked);
    }
    memory?._settle(asked);
    _nameFolders(labels);
    for (final doc in rejected) {
      _pushAway(doc);
    }
  }

  FolderIndex._(this._docs);

  /// То же, что конструктор, но с передышками: хранилище в тысячи конспектов режется на
  /// слова секундами, и всё это время строка ввода и поиск должны отвечать. Небольшой набор
  /// строится без единой передышки.
  static Future<FolderIndex> build(
    List<FolderDoc> docs, {
    List<FolderLabel> labels = const [],
    List<FolderDoc> rejected = const [],
    FolderMemory? memory,
    Future<void> Function()? wait,
  }) async {
    final index = FolderIndex._(docs.length);
    final asked = <String>{};
    final pace = _Pace(wait);
    for (final doc in docs) {
      if (pace.spent(index._learn(doc, memory, asked))) await pace.rest();
    }
    memory?._settle(asked);
    index._nameFolders(labels);
    for (final doc in rejected) {
      if (pace.spent(index._pushAway(doc))) await pace.rest();
    }
    return index;
  }

  // сколько заметок папки про какую тему: нужно только до [_nameFolders]
  final _docTopics = <String, Map<Topic, int>>{};

  /// Заметка папки: её слова и приметы идут в счёт папки. Отдаёт, сколько работы это стоило.
  int _learn(FolderDoc doc, FolderMemory? memory, Set<String> asked) {
    _sizes[doc.folderId] = (_sizes[doc.folderId] ?? 0) + 1;
    final text = doc.text ?? '';
    final cutBefore = memory?.parsed;
    final parsed = memory == null ? _parse(text) : memory._of(doc, asked);
    final cut = memory == null || memory.parsed != cutBefore;
    Map<String, int>? hits;
    void count(String stem) {
      _spread[stem] = (_spread[stem] ?? 0) + 1;
      final inFolder = hits ??= _hits.putIfAbsent(doc.folderId, () => {});
      inFolder[stem] = (inFolder[stem] ?? 0) + 1;
    }

    parsed.stems.forEach(count);
    // приметы живут рядом со словами: с двоеточием они ни с одной основой не совпадут
    for (final signal in doc.signals.toSet()) {
      if (signal.contains(':') || !parsed.stems.contains(signal)) count(signal);
    }
    if (parsed.topic case final topic?) {
      final counts = _docTopics.putIfAbsent(doc.folderId, () => {});
      counts[topic] = (counts[topic] ?? 0) + 1;
    }
    weight += parsed.stems.length;
    return parsed.stems.length * _stemCost + (cut ? text.length : 0);
  }

  /// Тема папки — по имени, а без него по тому, про что её заметки.
  void _nameFolders(List<FolderLabel> labels) {
    for (final label in labels) {
      _nameStems[label.id] = {for (final word in _words(label.name)) if (word.stem.length >= 3) word.stem};
      _nameForms[label.id] = {for (final word in _words(label.name)) normalizeQuery(word.original)};
      for (final topic in topicsOfName(label.name)) {
        _topics.putIfAbsent(label.id, () => {})[topic] = 1.0;
      }
    }
    for (final MapEntry(key: folder, value: counts) in _docTopics.entries) {
      final size = _sizes[folder] ?? 0;
      if (size < 2) continue;
      for (final MapEntry(key: topic, value: count) in counts.entries) {
        final share = count / size;
        final topics = _topics.putIfAbsent(folder, () => {});
        if (share >= _topicShare && share > (topics[topic] ?? 0)) topics[topic] = share;
      }
    }
    _docTopics.clear();
  }

  /// Заметка, которую человек из папки вынул: её слова от папки отталкивают.
  int _pushAway(FolderDoc doc) {
    final text = doc.text ?? '';
    final pushes = _rejected.putIfAbsent(doc.folderId, () => {});
    for (final stem in {for (final word in _words(text)) word.stem}) {
      pushes[stem] = (pushes[stem] ?? 0) + 1;
    }
    return text.length;
  }

  /// Сколько слов заметок сложено в угадыватель: мера того, во что обходится постройка.
  /// По ней поток решает, давать ли передышку перед следующей пересборкой.
  int weight = 0;

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

  /// Основы слов заметок по первой букве: среди них ищется опечатка.
  late final _spreadByFirst = () {
    final buckets = <String, List<String>>{};
    for (final key in _spread.keys) {
      if (key.isNotEmpty && !key.contains(':')) buckets.putIfAbsent(key[0], () => []).add(key);
    }
    return buckets;
  }();

  /// Сколько вещей папки содержат основу.
  final _hits = <String, Map<String, int>>{};

  /// [series] — папка, куда легли две прошлые заметки подряд: мысль, скорее всего, оттуда же.
  // последняя догадка: строка спрашивает тот же текст на каждый кадр, пока его разбирают
  (String, String, String?)? _lastAsked;
  FolderGuess? _lastGuess;

  FolderGuess? guess(String text, {List<String> signals = const [], String? series}) {
    final asked = (text, signals.join('\u0000'), series);
    if (asked == _lastAsked) return _lastGuess;
    _lastAsked = asked;
    return _lastGuess = _guess(text, signals: signals, series: series);
  }

  FolderGuess? _guess(String text, {required List<String> signals, String? series}) {
    final (:scores, :evidence, named: _) = _score(text, signals, series: series);
    if (scores.isEmpty) return null;
    final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1].value : 0.0;
    if (best.value < _minScore || best.value < second * _lead) return null;
    final proof = [...evidence[best.key]!]..sort((a, b) => b.$2.compareTo(a.$2));
    return FolderGuess(
      folderId: best.key,
      // вид вещи и тип файла словами не назвать: в причину идут слова и сайт.
      // Слово бывает уликой дважды (по заметкам папки и по теме) — в причине оно одно
      words: {for (final (word, _, _) in proof) if (word.isNotEmpty) word}.take(3).toList(),
      byName: proof.first.$3,
      score: best.value,
    );
  }

  /// Ярлыки, к которым текст тянет не меньше [minScore], у которых уже не меньше
  /// [minSize] вещей. Для тегов: у вещи их бывает несколько, поэтому второе место
  /// первому не мешает.
  ///
  /// [namedScore] — ярлык тянет своё имя или тема не меньше этого: такой подходит и без
  /// [minSize] вещей, как папка «Работа» с первой заметки (теги: «#работа» — заметке о работе).
  List<String> strong(String text, {List<String> signals = const [], double minScore = 1.5, int minSize = 2, double? namedScore}) {
    final (:scores, :named, evidence: _) = _score(text, signals);
    bool sure(String label, double score) =>
        (score >= minScore && (_sizes[label] ?? 0) >= minSize) || (namedScore != null && (named[label] ?? 0) >= namedScore);
    final picked = scores.entries.where((entry) => sure(entry.key, entry.value)).toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final entry in picked) entry.key];
  }

  /// Папки по похожести, лучшие первыми, даже без уверенности: подсказки «Разобрать».
  List<String> rank(String text, {List<String> signals = const []}) {
    final scores = _score(text, signals).scores;
    return [for (final entry in scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value))) entry.key];
  }

  // named — та часть счёта, что от имени папки и её темы, без соседей
  ({Map<String, double> scores, Map<String, double> named, Map<String, List<(String, double, bool)>> evidence}) _score(
    String text,
    List<String> signals, {
    String? series,
  }) {
    final scores = <String, double>{};
    final named = <String, double>{};
    final evidence = <String, List<(String, double, bool)>>{};
    void push(String folder, String shown, double weight, {bool name = false}) {
      scores[folder] = (scores[folder] ?? 0) + weight;
      evidence.putIfAbsent(folder, () => []).add((shown, weight, name));
    }

    void pushNamed(String folder, String shown, double weight) {
      push(folder, shown, weight);
      named[folder] = (named[folder] ?? 0) + weight;
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
      // слова нет в заметках — может, это опечатка знакомого: «космадесантники»
      final known = _spread.containsKey(word.stem) ? word.stem : typoMatch(word.stem, _spreadByFirst[word.stem.isEmpty ? '' : word.stem[0]] ?? const []);
      if (known != null) add(known, word.original, word.name ? _nameWeight : 1, name: word.name);
    }
    for (final signal in signals.toSet()) {
      add(signal, signal.startsWith('site:') ? signal.substring(5) : '', _signalWeight(signal), minHits: _signalMinHits(signal));
    }

    // имя папки прямо в заметке: «плитка для ремонта» — папка «Ремонт»
    final shownOf = <String, String>{for (final word in words.reversed) word.stem: word.original};
    for (final MapEntry(key: folder, value: stems) in _nameStems.entries) {
      // имя целиком или с опечаткой: «Wrahammer» — папка «Warhammer»
      final matched = {for (final stem in stems) ?(shownOf.containsKey(stem) ? stem : typoMatch(stem, shownOf.keys))};
      for (final stem in matched) {
        final shown = shownOf[stem]!;
        // «работал на врага» — не про папку «Работа»: глагол от её имени
        if (_nameForms[folder]!.any((form) => isVerbOf(normalizeQuery(shown), form))) continue;
        // слово уже тянет сюда как слово темы папки: «машине» у «Машины» не считается дважды.
        // Имя без темы («Дача») — по-прежнему сильный знак
        if (topicsOfWord(shown).any((topic) => _topics[folder]?.containsKey(topic) ?? false)) continue;
        pushNamed(folder, shown, _nameMatchWeight);
      }
    }

    // тема: «молоко» тянет в папку продуктов, «предаст» и «злодей» — в книгу
    final topicWords = <Topic, List<String>>{};
    for (final shown in shownOf.values) {
      for (final topic in topicsOfWord(shown)) {
        topicWords.putIfAbsent(topic, () => []).add(shown);
      }
    }
    // слабые слова: по одному ничего не решают, «зал, ноги и пресс» вместе — тренировка.
    // Есть явное слово другой темы («болит спина и ноги») — слабые молчат
    final weak = <Topic, List<String>>{};
    for (final shown in shownOf.values) {
      for (final topic in weakTopicsOfWord(shown)) {
        weak.putIfAbsent(topic, () => []).add(shown);
      }
    }
    for (final MapEntry(key: topic, value: found) in weak.entries) {
      final backed = topicWords.containsKey(topic);
      final alone = found.length >= 2 && topicWords.keys.every((other) => other == topic);
      if (backed || alone) topicWords.putIfAbsent(topic, () => []).addAll(found);
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
        // вещь ребёнка или зверя — в его папку: «сыну форму для футбола», «котёнку прививку»
        final owner = topic == Topic.kids || topic == Topic.pets ? _ownerWeight : 1.0;
        for (final shown in found.take(_topicCap)) {
          pushNamed(folder, shown, _topicWeight * affinity * owner);
        }
      }
    }

    // серия: две прошлые заметки легли сюда — у этой папки фора. Одной форы хватает только
    // продолжению мысли: короткое дело («позвонить маме») просто записали следом
    if (series != null && (scores.containsKey(series) || _continues(text))) push(series, '', _seriesWeight);

    // слова заметок, которые человек из папки вынул, от неё отталкивают
    for (final MapEntry(key: folder, value: pushes) in _rejected.entries) {
      final against = [for (final stem in shownOf.keys) ?pushes[stem]].fold(0, (sum, count) => sum + count);
      if (against > 0 && scores.containsKey(folder)) scores[folder] = scores[folder]! - _rejectWeight * min(against, _topicCap);
    }
    return (scores: scores, named: named, evidence: evidence);
  }
}
