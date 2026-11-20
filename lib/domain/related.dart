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

/// Слова всех заметок, разрезанные один раз, и для каждого слова — заметки, где оно есть.
///
/// Граф связей спрашивает похожие для каждой своей точки. [findRelated] на каждый вопрос
/// резал на слова всё хранилище заново и сравнивал заметку с каждой другой: на двух
/// тысячах конспектов граф считался минутами и держал поток. Здесь заметки режутся один
/// раз, а вопрос идёт только по заметкам, у которых с открытой есть общие слова.
/// Ответ тот же, что у [findRelated].
class RelatedIndex {
  RelatedIndex(List<RelatedDoc> docs) : _docs = docs {
    docs.forEach(_add);
  }

  RelatedIndex._(this._docs);

  /// То же, что конструктор, но с передышками: большое хранилище режется на слова
  /// секундами, и экран всё это время должен отвечать.
  static Future<RelatedIndex> build(List<RelatedDoc> docs) async {
    final index = RelatedIndex._(docs);
    final busy = Stopwatch()..start();
    var work = 0;
    for (final doc in docs) {
      index._add(doc);
      work += doc.text.length;
      // на часы смотрим не чаще, чем через 20 000 знаков: небольшой набор строится без таймеров
      if (work < 20000) continue;
      work = 0;
      if (busy.elapsedMilliseconds <= 8) continue;
      await Future<void>.delayed(Duration.zero);
      busy.reset();
    }
    return index;
  }

  final List<RelatedDoc> _docs;

  /// Где заметка в списке.
  final _position = <String, int>{};

  /// Основы слов каждой заметки и её сайт.
  final _stems = <Set<String>>[];

  /// В каких заметках встречается основа, по порядку списка.
  final _where = <String, List<int>>{};

  void _add(RelatedDoc doc) {
    final at = _stems.length;
    _position.putIfAbsent(doc.id, () => at);
    final own = {for (final word in meaningfulWords(doc.text)) word.stem, if (doc.site != null) 'site:${doc.site}'};
    _stems.add(own);
    for (final stem in own) {
      (_where[stem] ??= []).add(at);
    }
  }

  /// Заметки, похожие на [targetId]: сумма редкости общих слов. Не больше [limit],
  /// отклонённые не предлагаются.
  List<Related> related(String targetId, {Set<String> rejected = const {}, int limit = 3, double minScore = _minScore}) {
    final at = _position[targetId];
    if (at == null) return const [];
    // как слово написано в открытой вещи: его и показать в причине
    final shown = <String, String>{for (final word in meaningfulWords(_docs[at].text)) word.stem: word.original};
    double rarity(String stem) => log((_docs.length + 1) / _where[stem]!.length);

    // общие слова с каждой заметкой, в порядке слов открытой
    final shared = <int, List<String>>{};
    for (final stem in _stems[at]) {
      for (final other in _where[stem]!) {
        if (other != at) (shared[other] ??= []).add(stem);
      }
    }
    final found = <Related>[];
    for (final other in shared.keys.toList()..sort()) {
      final id = _docs[other].id;
      if (id == targetId || rejected.contains(id)) continue;
      var score = 0.0;
      final words = <(String, double)>[];
      var sameSite = false;
      for (final stem in shared[other]!) {
        if (stem.startsWith('site:')) {
          sameSite = true;
          score += rarity(stem) * _siteWeight;
        } else {
          final weight = rarity(stem);
          score += weight;
          words.add((shown[stem] ?? stem, weight));
        }
      }
      if (score < minScore) continue;
      words.sort((a, b) => b.$2.compareTo(a.$2));
      found.add(Related(id: id, score: score, words: [for (final (word, _) in words.take(3)) word], sameSite: sameSite));
    }
    found.sort((a, b) => b.score.compareTo(a.score));
    return found.take(limit).toList();
  }
}

/// Вещи, похожие на [targetId]: сумма редкости общих слов. Редкое общее слово
/// весит много, частое почти ничего. Не больше [limit], отклонённые не предлагаются.
///
/// Один вопрос — одна постройка указателя: много вопросов подряд задавать [RelatedIndex].
List<Related> findRelated(String targetId, List<RelatedDoc> docs, {Set<String> rejected = const {}, int limit = 3, double minScore = _minScore}) =>
    RelatedIndex(docs).related(targetId, rejected: rejected, limit: limit, minScore: minScore);
