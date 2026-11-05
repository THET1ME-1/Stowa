import 'dart:math';

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

  /// Нашлось в фактах: какой это факт, его текст и метки внутри него.
  ({FactPart part, List<TextMark> marks})? get foundFact {
    final all = marks[SearchField.facts];
    if (all == null || all.isEmpty) return null;
    final found = doc.factAt(all.first.$1);
    if (found == null) return null;
    final end = found.offset + found.part.text.length;
    return (
      part: found.part,
      marks: [
        for (final mark in all)
          if (mark.$1 >= found.offset && mark.$1 < end) (mark.$1 - found.offset, mark.$2),
      ],
    );
  }
}

/// Насколько слово текста похоже на вариант запроса: само слово, его форма,
/// набранное начало, общее начало основы, опечатка. Ноль — не похоже.
const _exact = 1.0;
const _form = 0.95;
const _typed = 0.9;
const _stemStart = 0.75;
const _typo = 0.6;

/// Короче основа формой не считается: «паро» — это начало «пароля», а не форма «пары».
const _formStem = 4;

// куски текста, где нашлось слово запроса в любом из его вариантов
({double strength, List<TextMark> marks}) _hitsIn(String text, QueryWord query) {
  var strength = 0.0;
  final marks = <TextMark>[];
  final folded = foldText(text);
  for (final match in wordMatches(folded)) {
    final word = match.group(0)!;
    var best = 0.0;
    var length = 0;
    for (final (index, variant) in query.variants.indexed) {
      final wanted = variant.text;
      final base = stemOf(wanted);
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
      } else if (index == 0 &&
          wanted.length >= 4 &&
          // короткое слово текста — не опечатка длинного запроса: «лей» не «клей»
          word.length >= 4 &&
          (nearWords(word.substring(0, min(word.length, wanted.length)), wanted) || nearWords(word.substring(0, min(word.length, wanted.length + 1)), wanted))) {
        // опечатку ищем только у самого слова: у транслита и раскладки она даёт шум
        hit = _typo;
        span = min(word.length, wanted.length);
      }
      hit *= variant.weight;
      if (hit > best) {
        best = hit;
        length = span;
      }
    }
    if (best > 0) {
      marks.add((match.start, length));
      strength = max(strength, best);
    }
  }
  return (strength: strength, marks: marks);
}

/// Свежесть: прибавка, которая разводит равные совпадения в пользу новых.
double _freshness(SearchDoc doc) => 0.5 / (1 + doc.ageDays / 14);

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
  for (final doc in docs) {
    if (folderFilter != null && doc.folderId != folderFilter) continue;
    final own = doc.tags.map(normalizeQuery).toList();
    if (!tagFilters.every((tag) => own.any((name) => name.startsWith(normalizeQuery(tag))))) continue;

    var total = tagFilters.length * 2.0;
    var matched = 0;
    var strong = words.isNotEmpty && words.length <= 3;
    final marks = <SearchField, List<TextMark>>{};
    for (final word in words) {
      var best = 0.0;
      var bestStrength = 0.0;
      SearchField? bestField;
      for (final field in SearchField.values) {
        final found = _hitsIn(doc.field(field), word);
        if (found.strength == 0) continue;
        marks.putIfAbsent(field, () => []).addAll(found.marks);
        final weighted = found.strength * _weights[field]!;
        if (weighted > best) {
          best = weighted;
          bestStrength = found.strength;
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
  hits.sort((a, b) => b.score.compareTo(a.score));
  return hits.take(limit).toList();
}
