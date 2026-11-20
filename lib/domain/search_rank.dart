import 'dart:math';
import 'dart:typed_data';

import 'language_guess.dart' show guessLanguage;
import 'line_query.dart';
import 'models.dart';
import 'search_query.dart';
import 'word_forms.dart';

/// Где в вещи нашлось слово. Глубже — описание от ИИ, текст с картинки и расшифровка;
/// факты — то, что достали извлекатели: текст документа, автор и описание страницы.
enum SearchField { title, tags, folder, body, deep, place, facts, url }

const _weights = {
  SearchField.title: 3.0,
  SearchField.tags: 2.4,
  SearchField.folder: 1.4,
  SearchField.body: 1.2,
  SearchField.deep: 1.1,
  SearchField.place: 1.1,
  SearchField.facts: 1.05,
  SearchField.url: 1.0,
};

/// Кусок фактов вещи для поиска: вид, место в документе (`sheet:Ремонт`), текст и,
/// у субтитров и глав, с какой секунды ролика это звучит.
class FactPart {
  const FactPart(this.kind, this.text, {this.place, this.seconds});

  final FactKind kind;
  final String text;
  final String? place;
  final double? seconds;
}

/// Вещь глазами поиска: все поля, по которым ищется.
class SearchDoc {
  const SearchDoc({
    required this.id,
    required this.title,
    this.body = '',
    this.tags = const [],
    this.folderName,
    this.folderId,
    this.deep = '',
    this.place = '',
    this.facts = const [],
    this.url = '',
    this.ageDays = 0,
  });

  /// Факты по порядку; в поле они идут через перевод строки.
  final List<FactPart> facts;

  /// Какой факт под меткой поля фактов: где нашлось и с какого места его текст.
  ({FactPart part, int offset})? factAt(int position) {
    var offset = 0;
    for (final part in facts) {
      if (position < offset + part.text.length) return (part: part, offset: offset);
      offset += part.text.length + 1;
    }
    return null;
  }

  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final String? folderName;
  final String? folderId;
  final String deep;

  /// Где сохранено: «Кишинёв, улица Пушкина».
  final String place;
  final String url;
  final int ageDays;

  String field(SearchField field) => switch (field) {
    SearchField.title => title,
    SearchField.tags => tags.join(' '),
    SearchField.folder => folderName ?? '',
    SearchField.body => body,
    SearchField.deep => deep,
    SearchField.place => place,
    SearchField.facts => facts.map((part) => part.text).join('\n'),
    SearchField.url => url,
  };
}

typedef TextMark = (int start, int length);

class SearchHit {
  const SearchHit({required this.doc, required this.score, required this.matched, required this.strong, required this.marks});

  final SearchDoc doc;
  final double score;

  /// Сколько слов запроса нашлось.
  final int matched;

  /// Короткий запрос целиком совпал с заголовком: кнопка открывает найденное, а не сохраняет.
  final bool strong;

  /// Найденные куски по полям, чтобы подсветить.
  final Map<SearchField, List<TextMark>> marks;

  /// Что показать под заголовком: глубокий текст, если нашлось там, потом текст вещи,
  /// потом документ и страница, потом место.
  SearchField? get where => marks.containsKey(SearchField.deep)
      ? SearchField.deep
      : marks.containsKey(SearchField.body)
      ? SearchField.body
      : marks.containsKey(SearchField.facts)
      ? SearchField.facts
      : marks.containsKey(SearchField.place)
      ? SearchField.place
      : null;

  /// Нашлось в фактах: какой это факт, его текст и метки внутри него. Из нескольких
  /// найденных главнее тот, что ведёт к месту: фраза ролика с секундой, потом лист документа.
  ({FactPart part, List<TextMark> marks})? get foundFact {
    final all = marks[SearchField.facts];
    if (all == null || all.isEmpty) return null;
    ({FactPart part, int offset})? best;
    for (final mark in all) {
      final found = doc.factAt(mark.$1);
      if (found == null) continue;
      if (best == null || _factRank(found.part) < _factRank(best.part)) best = found;
    }
    if (best == null) return null;
    final start = best.offset;
    final end = start + best.part.text.length;
    return (
      part: best.part,
      marks: [
        for (final mark in all)
          if (mark.$1 >= start && mark.$1 < end) (mark.$1 - start, mark.$2),
      ],
    );
  }
}

// чем меньше, тем полезнее подпись: секунда ролика, лист документа, ингредиент — точнее, чем «на странице»
int _factRank(FactPart part) => switch (part.kind) {
  FactKind.subtitle || FactKind.chapter => 0,
  FactKind.fileText || FactKind.highlight => 1,
  FactKind.ingredient => 2,
  FactKind.venue || FactKind.address => 3,
  _ => 4,
};

/// Насколько слово текста похоже на вариант запроса: само слово, его форма,
/// набранное начало, общее начало основы, опечатка. Ноль — не похоже.
const _exact = 1.0;
const _form = 0.95;
const _typed = 0.9;
const _stemStart = 0.75;
const _typo = 0.6;

/// Короче основа формой не считается: «паро» — это начало «пароля», а не форма «пары».
const _formStem = 4;

/// Слова поля заметки: свёрнутый текст и границы слов парами (начало, конец). Свёртка
/// длину не меняет — начала совпадают с исходным текстом.
typedef _Tokens = (String folded, Int32List spans);

_Tokens _tokens(String text) {
  final folded = foldText(text);
  final matches = wordMatches(folded).toList();
  final spans = Int32List(matches.length * 2);
  for (final (index, match) in matches.indexed) {
    spans[index * 2] = match.start;
    spans[index * 2 + 1] = match.end;
  }
  return (folded, spans);
}

/// Строка ищет на каждое нажатие, а заметки между нажатиями не меняются: разрезанный текст
/// и язык заметки помнятся, пока текст тот же (сверка по длине и хешу). Память — границы
/// слов числами, без копий слов.
final _fieldMemory = <(String, SearchField), (int, int, _Tokens)>{};

/// Сколько текстов разрезано на слова с запуска (взятое из памяти не считается): по нему
/// видно, что прогрев поиска сделал своё дело.
int searchTextsCut = 0;
final _languageMemory = <String, (int, int, String?)>{};
const _memoryLimit = 20000;

_Tokens _fieldTokens(SearchDoc doc, SearchField field) {
  final text = doc.field(field);
  final key = (doc.id, field);
  final known = _fieldMemory[key];
  if (known != null && known.$1 == text.length && known.$2 == text.hashCode) return known.$3;
  if (_fieldMemory.length > _memoryLimit) _fieldMemory.clear();
  final tokens = _tokens(text);
  searchTextsCut++;
  _fieldMemory[key] = (text.length, text.hashCode, tokens);
  return tokens;
}

/// Насколько слово текста похоже на слово запроса и сколько знаков подсветить. Одно и то же
/// слово встречается в заметках тысячи раз — ответ помнится на весь поиск (ключ — слово).
typedef _Memo = Map<String, (double, int)>;

// варианты слова запроса с готовыми основами: основа варианта не пересчитывается на каждое слово текста
List<(String, String, double)> _variantsOf(QueryWord query) => [for (final variant in query.variants) (variant.text, stemOf(variant.text), variant.weight)];

(double, int) _likeness(String word, List<(String, String, double)> variants, String? language) {
  var best = 0.0;
  var length = 0;
  for (final (index, (wanted, base, weight)) in variants.indexed) {
    var hit = 0.0;
    var span = 0;
    if (word == wanted) {
      hit = _exact;
      span = word.length;
    } else if (word.startsWith(base)) {
      final form = base.length >= _formStem && stemOf(word) == base;
      final typed = word.startsWith(wanted);
      hit = form ? _form : (typed ? _typed : _stemStart);
      span = typed ? wanted.length : base.length;
      while (span < word.length && span < wanted.length && word[span] == wanted[span]) {
        span++;
      }
    } else if (language != null && _sameLanguageStem(word, wanted, language)) {
      hit = _form;
      span = word.length;
    } else if (index == 0 &&
        wanted.length >= 4 &&
        // короткое слово текста — не опечатка длинного запроса: «лей» не «клей»
        word.length >= 4 &&
        (nearWords(word.substring(0, min(word.length, wanted.length)), wanted) || nearWords(word.substring(0, min(word.length, wanted.length + 1)), wanted))) {
      // опечатку ищем только у самого слова: у транслита и раскладки она даёт шум
      hit = _typo;
      span = min(word.length, wanted.length);
    }
    hit *= weight;
    if (hit > best) {
      best = hit;
      length = span;
    }
  }
  return (best, length);
}

// одна основа по правилам языка заметки; короткая основа формой не считается, как и у своих языков
bool _sameLanguageStem(String word, String wanted, String language) {
  if (word.length < _formStem || wanted.length < _formStem) return false;
  final stem = languageStem(word, language);
  return stem != null && stem.length >= 3 && stem == languageStem(wanted, language);
}

// язык заметки по началу её текста: длинной статье хватит первых двух тысяч знаков
String? _docLanguage(SearchDoc doc) {
  final whole = '${doc.title}\n${doc.body}';
  final sample = whole.length > 2000 ? whole.substring(0, 2000) : whole;
  final known = _languageMemory[doc.id];
  if (known != null && known.$1 == sample.length && known.$2 == sample.hashCode) return known.$3;
  if (_languageMemory.length > _memoryLimit) _languageMemory.clear();
  final guessed = guessLanguage(sample);
  final language = hasLanguageStems(guessed) ? guessed : null;
  _languageMemory[doc.id] = (sample.length, sample.hashCode, language);
  return language;
}

/// Свежесть: прибавка, которая разводит равные совпадения в пользу новых.
double _freshness(SearchDoc doc) => 0.5 / (1 + doc.ageDays / 14);

/// Порядок найденного: очки, у равных — id, чтобы поиск целиком и порциями давал одно и то же.
int compareHits(SearchHit a, SearchHit b) {
  final byScore = b.score.compareTo(a.score);
  return byScore != 0 ? byScore : a.doc.id.compareTo(b.doc.id);
}

/// Лучшие вещи по словам запроса. Чипы тегов и папки — строгий фильтр.
/// Без слов, но с [filtered] (вещи уже отобраны по дате, виду, месту) — свежие первыми.
List<SearchHit> rankSearch(
  List<SearchDoc> docs,
  List<QueryWord> words, {
  List<String> tagFilters = const [],
  String? folderFilter,
  bool filtered = false,
  int limit = 6,
}) {
  if (words.isEmpty && tagFilters.isEmpty && folderFilter == null && !filtered) return const [];
  final hits = <SearchHit>[];
  final need = words.length <= 2 ? words.length : max(1, (words.length / 3).ceil());
  final variants = [for (final word in words) _variantsOf(word)];
  // ответы по словам текста — на каждое слово запроса и язык заметки свои
  final memos = <(int, String?), _Memo>{};
  for (final doc in docs) {
    if (folderFilter != null && doc.folderId != folderFilter) continue;
    final own = doc.tags.map(normalizeQuery).toList();
    if (!tagFilters.every((tag) => own.any((name) => name.startsWith(normalizeQuery(tag))))) continue;

    var total = tagFilters.length * 2.0;
    var matched = 0;
    var strong = words.isNotEmpty && words.length <= 3;
    final marks = <SearchField, List<TextMark>>{};
    final language = words.isEmpty ? null : _docLanguage(doc);
    final docMemos = [for (var index = 0; index < words.length; index++) memos[(index, language)] ??= {}];
    // каждое слово поля сверяется со всеми словами запроса за один проход; сила — лучшее
    // совпадение слова запроса в поле, метки — куски, где нашлось
    final strength = [for (final _ in words) <SearchField, double>{}];
    for (final field in words.isEmpty ? const <SearchField>[] : SearchField.values) {
      final (folded, spans) = _fieldTokens(doc, field);
      for (var at = 0; at < spans.length; at += 2) {
        final start = spans[at];
        final word = folded.substring(start, spans[at + 1]);
        for (var index = 0; index < words.length; index++) {
          final (best, length) = docMemos[index][word] ??= _likeness(word, variants[index], language);
          if (best <= 0) continue;
          marks.putIfAbsent(field, () => []).add((start, length));
          if (best > (strength[index][field] ?? 0)) strength[index][field] = best;
        }
      }
    }
    for (var index = 0; index < words.length; index++) {
      var best = 0.0;
      var bestStrength = 0.0;
      SearchField? bestField;
      for (final MapEntry(key: field, value: found) in strength[index].entries) {
        final weighted = found * _weights[field]!;
        if (weighted > best) {
          best = weighted;
          bestStrength = found;
          bestField = field;
        }
      }
      if (best > 0) {
        matched++;
        total += best;
      }
      if (bestField != SearchField.title || bestStrength < 0.9) strong = false;
    }
    if (matched < need) continue;
    hits.add(SearchHit(doc: doc, score: total / max(1, words.length) + _freshness(doc), matched: matched, strong: strong, marks: marks));
  }
  hits.sort(compareHits);
  return hits.take(limit).toList();
}
