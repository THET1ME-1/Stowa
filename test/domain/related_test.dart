import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/related.dart';

void main() {
  final docs = [
    const RelatedDoc(id: 'borsch', text: 'Борщ со свёклой, рецепт бабушки'),
    const RelatedDoc(id: 'beet', text: 'Свёкла на рынке подешевела, купить на борщ'),
    const RelatedDoc(id: 'bread', text: 'Купить хлеб'),
    const RelatedDoc(id: 'bank', text: 'Позвонить в банк про карту'),
    const RelatedDoc(id: 'gc1', text: 'Сборщик мусора', site: 'habr.com'),
    const RelatedDoc(id: 'gc2', text: 'Как устроен Flutter', site: 'habr.com'),
    const RelatedDoc(id: 'mail', text: 'Письмо от банка'),
    const RelatedDoc(id: 'gift', text: 'Идея для подарка'),
  ];

  group('указатель похожих: слова заметок режутся один раз на все вопросы', () {
    // хранилище, где у заметок есть и общие, и свои слова
    List<RelatedDoc> library(int size) => [
      for (var index = 0; index < size; index++)
        RelatedDoc(
          id: 'n$index',
          text: 'конспект лекции тема${index % 37} раздел${index % 11} понятие$index ${List.generate(60, (word) => 'слово${(index * 7 + word) % 400}').join(' ')}',
          site: index % 9 == 0 ? 'habr.com' : null,
        ),
    ];

    test('отвечает то же, что поиск по одной заметке', () {
      final index = RelatedIndex(docs);
      for (final doc in docs) {
        final byIndex = index.related(doc.id);
        final alone = findRelated(doc.id, docs);
        String told(Related one) => '${one.id} ${one.score} ${one.words} ${one.sameSite}';
        expect(byIndex.map(told).toList(), alone.map(told).toList(), reason: doc.id);
      }
      expect(index.related('borsch').single.id, 'beet');
      expect(index.related('нет такой'), isEmpty);
    });

    test('на большом наборе ответы те же, порядок тот же', () {
      final many = library(120);
      final index = RelatedIndex(many);
      for (final id in ['n0', 'n7', 'n59', 'n119']) {
        expect([for (final one in index.related(id, limit: 5, minScore: 0.5)) one.id], [for (final one in findRelated(id, many, limit: 5, minScore: 0.5)) one.id], reason: id);
      }
    });

    test('отклонённую связь не предлагает', () {
      expect(RelatedIndex(docs).related('borsch', rejected: {'beet'}), isEmpty);
    });

    test('граф на шестьсот заметок: похожие для каждой считаются за секунды, а не за минуты', () {
      // прежде на каждую точку графа заново резались на слова все заметки хранилища
      final many = library(600);
      final watch = Stopwatch()..start();
      final index = RelatedIndex(many);
      var found = 0;
      for (final doc in many) {
        found += index.related(doc.id).length;
      }
      expect(found, greaterThan(0));
      expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
    });

    test('постройка с передышками отвечает так же и не держит поток', () async {
      final many = library(600);
      var done = false;
      var breathed = false;
      Timer.run(() => breathed = !done);
      final index = await RelatedIndex.build(many);
      done = true;
      expect(breathed, isTrue);
      expect([for (final one in index.related('n7')) one.id], [for (final one in RelatedIndex(many).related('n7')) one.id]);
    });
  });

  test('связаны вещи с общими редкими словами, причина — эти слова', () {
    final related = findRelated('borsch', docs);
    expect(related.map((one) => one.id), ['beet']);
    expect(related.single.words, containsAll(['Борщ', 'свёклой']));
  });

  test('общий сайт тоже связь', () {
    final related = findRelated('gc1', docs);
    expect(related.map((one) => one.id), ['gc2']);
    expect(related.single.sameSite, isTrue);
  });

  test('одно частое слово («купить») связью не считается', () {
    expect(findRelated('bread', docs), isEmpty);
  });

  test('отклонённую связь не предлагаем', () {
    expect(findRelated('borsch', docs, rejected: {'beet'}), isEmpty);
  });

  test('служебные слова других языков и куски адресов связью не считаются', () {
    final english = [
      const RelatedDoc(id: 'recipe', text: 'How to make this carbonara https://www.bbcgoodfood.com/recipes/carbonara'),
      const RelatedDoc(id: 'song', text: 'This is how we make it https://www.youtube.com/watch?v=x'),
      const RelatedDoc(id: 'run', text: 'Running club https://www.meetup.com/club'),
      const RelatedDoc(id: 'other', text: 'Купить хлеб'),
    ];
    expect(findRelated('recipe', english), isEmpty);
    expect(findRelated('run', english), isEmpty);
  });
}
