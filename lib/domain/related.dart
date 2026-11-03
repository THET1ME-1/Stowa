import 'dart:math';

import 'folder_guess.dart';

/// Вещь глазами поиска связей: её текст и сайт, если это ссылка.
class RelatedDoc {
  const RelatedDoc({required this.id, required this.text, this.site});

  final String id;
  final String text;
  final String? site;
}

/// Связанная вещь и почему: общие редкие слова (как написаны в открытой вещи) или общий сайт.
class Related {
  const Related({required this.id, required this.score, required this.words, required this.sameSite});

  final String id;
  final double score;
  final List<String> words;
  final bool sameSite;
}

/// Меньше — совпадение случайное: одно общее слово вроде «купить» связью не считается.
const _minScore = 2.0;

/// Сайт связывает сильнее слова: все статьи с Хабра у человека про одно.
const _siteWeight = 1.5;

/// Вещи, похожие на [targetId]: сумма редкости общих слов. Редкое общее слово
/// весит много, частое почти ничего. Не больше [limit], отклонённые не предлагаются.
List<Related> findRelated(String targetId, List<RelatedDoc> docs, {Set<String> rejected = const {}, int limit = 3}) {
  final target = docs.where((doc) => doc.id == targetId).firstOrNull;
  if (target == null) return const [];
  final stems = <String, Set<String>>{};
  final spread = <String, int>{};
  for (final doc in docs) {
    final own = {for (final word in meaningfulWords(doc.text)) word.stem, if (doc.site != null) 'site:${doc.site}'};
    stems[doc.id] = own;
    for (final stem in own) {
      spread[stem] = (spread[stem] ?? 0) + 1;
    }
  }
  // как слово написано в открытой вещи: его и показать в причине
  final shown = <String, String>{for (final word in meaningfulWords(target.text)) word.stem: word.original};
  final targetStems = stems[targetId]!;
  double rarity(String stem) => log((docs.length + 1) / spread[stem]!);

  final found = <Related>[];
  for (final doc in docs) {
    if (doc.id == targetId || rejected.contains(doc.id)) continue;
    final shared = targetStems.intersection(stems[doc.id]!);
    if (shared.isEmpty) continue;
    var score = 0.0;
    final words = <(String, double)>[];
    var sameSite = false;
    for (final stem in shared) {
      if (stem.startsWith('site:')) {
        sameSite = true;
        score += rarity(stem) * _siteWeight;
      } else {
        final weight = rarity(stem);
        score += weight;
        words.add((shown[stem] ?? stem, weight));
      }
    }
    if (score < _minScore) continue;
    words.sort((a, b) => b.$2.compareTo(a.$2));
    found.add(Related(id: doc.id, score: score, words: [for (final (word, _) in words.take(3)) word], sameSite: sameSite));
  }
  found.sort((a, b) => b.score.compareTo(a.score));
  return found.take(limit).toList();
}
