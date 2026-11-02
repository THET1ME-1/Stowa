import 'dart:math';

import 'line_query.dart';

/// Вещь в папке глазами угадывателя: весь её текст одной строкой.
class FolderDoc {
  const FolderDoc({required this.folderId, required this.text});

  final String folderId;
  final String text;
}

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

/// Слова текста без служебных; имя — слово с заглавной не в начале предложения.
List<_Word> _words(String text) {
  final words = <_Word>[];
  for (final match in _token.allMatches(text)) {
    final original = match.group(0)!;
    final lower = normalizeQuery(original);
    if (lower.length < 3 || isStopWord(lower) || RegExp(r'^\d+$').hasMatch(lower)) continue;
    final capital = original[0] != original[0].toLowerCase();
    final before = text.substring(0, match.start).trimRight();
    final startsSentence = before.isEmpty || _sentenceEnd.hasMatch(before[before.length - 1]);
    words.add((stem: stem(lower), original: original, name: capital && !startsSentence));
  }
  return words;
}

/// Умный разбор без сети: какие слова уже живут в какой папке. Слово, которое
/// есть только в одной папке, тянет туда сильно, общее для всех — почти никак,
/// имя героя — вдвое сильнее обычного слова.
class FolderIndex {
  FolderIndex(List<FolderDoc> docs) : _docs = docs.length {
    for (final doc in docs) {
      final stems = {for (final word in _words(doc.text)) word.stem};
      for (final stem in stems) {
        _spread[stem] = (_spread[stem] ?? 0) + 1;
        final hits = _hits.putIfAbsent(doc.folderId, () => {});
        hits[stem] = (hits[stem] ?? 0) + 1;
      }
    }
  }

  final int _docs;

  /// В скольких вещях встречается основа слова.
  final _spread = <String, int>{};

  /// Сколько вещей папки содержат основу.
  final _hits = <String, Map<String, int>>{};

  FolderGuess? guess(String text) {
    if (_docs == 0) return null;
    final scores = <String, double>{};
    final evidence = <String, List<(String, double, bool)>>{};
    final seen = <String>{};
    for (final word in _words(text)) {
      if (!seen.add(word.stem)) continue;
      final spread = _spread[word.stem];
      if (spread == null) continue;
      // редкость слова по всей базе
      final rarity = log((_docs + 1) / spread);
      for (final MapEntry(key: folder, value: hits) in _hits.entries) {
        final count = hits[word.stem];
        if (count == null) continue;
        // какая доля вещей с этим словом лежит именно в этой папке
        final weight = rarity * (count / spread) * (word.name ? _nameWeight : 1);
        scores[folder] = (scores[folder] ?? 0) + weight;
        evidence.putIfAbsent(folder, () => []).add((word.original, weight, word.name));
      }
    }
    if (scores.isEmpty) return null;
    final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1].value : 0.0;
    if (best.value < _minScore || best.value < second * _lead) return null;
    final proof = [...evidence[best.key]!]..sort((a, b) => b.$2.compareTo(a.$2));
    return FolderGuess(folderId: best.key, words: [for (final (word, _, _) in proof.take(3)) word], byName: proof.first.$3, score: best.value);
  }
}
