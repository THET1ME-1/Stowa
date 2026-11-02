import 'dart:math';

import 'line_query.dart';

/// Где в вещи нашлось слово. Глубже — описание от ИИ, текст с картинки и расшифровка.
enum SearchField { title, tags, folder, body, deep, url }

const _weights = {SearchField.title: 3.0, SearchField.tags: 2.4, SearchField.folder: 1.4, SearchField.body: 1.2, SearchField.deep: 1.1, SearchField.url: 1.0};

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
    this.url = '',
    this.ageDays = 0,
  });

  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final String? folderName;
  final String? folderId;
  final String deep;
  final String url;
  final int ageDays;

  String field(SearchField field) => switch (field) {
    SearchField.title => title,
    SearchField.tags => tags.join(' '),
    SearchField.folder => folderName ?? '',
    SearchField.body => body,
    SearchField.deep => deep,
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

  /// Что показать под заголовком: глубокий текст, если нашлось там, иначе текст вещи.
  SearchField? get where => marks.containsKey(SearchField.deep)
      ? SearchField.deep
      : marks.containsKey(SearchField.body)
      ? SearchField.body
      : null;
}

final _word = RegExp(r'[a-zа-я0-9]+');

// куски текста, где слово начинается так же или отличается одной буквой
({double strength, List<TextMark> marks}) _hitsIn(String text, String query) {
  final base = stem(query);
  var strength = 0.0;
  final marks = <TextMark>[];
  for (final match in _word.allMatches(normalizeQuery(text))) {
    final word = match.group(0)!;
    var hit = 0.0;
    var length = 0;
    if (word.startsWith(base)) {
      hit = word == query || word == base ? 1 : 0.9;
      length = base.length;
      while (length < word.length && length < query.length && word[length] == query[length]) {
        length++;
      }
    } else if (query.length >= 4 &&
        (nearWords(word.substring(0, min(word.length, query.length)), query) || nearWords(word.substring(0, min(word.length, query.length + 1)), query))) {
      hit = 0.6;
      length = min(word.length, query.length);
    }
    if (hit > 0) {
      marks.add((match.start, length));
      strength = max(strength, hit);
    }
  }
  return (strength: strength, marks: marks);
}

/// Лучшие вещи по словам запроса. Чипы тегов и папки — строгий фильтр.
List<SearchHit> rankSearch(List<SearchDoc> docs, List<String> words, {List<String> tagFilters = const [], String? folderFilter, int limit = 6}) {
  if (words.isEmpty && tagFilters.isEmpty && folderFilter == null) return const [];
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
    hits.add(SearchHit(doc: doc, score: total / max(1, words.length) + 0.5 / (1 + doc.ageDays / 14), matched: matched, strong: strong, marks: marks));
  }
  hits.sort((a, b) => b.score.compareTo(a.score));
  return hits.take(limit).toList();
}
