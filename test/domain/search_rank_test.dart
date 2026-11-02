import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/search_rank.dart';

SearchDoc _doc(String id, String title, {String body = '', List<String> tags = const [], String? folder, String? folderId, String deep = '', int days = 10}) =>
    SearchDoc(id: id, title: title, body: body, tags: tags, folderName: folder, folderId: folderId, deep: deep, ageDays: days);

void main() {
  final docs = [
    _doc('wifi', 'Пароль от Wi-Fi', body: 'Сеть Keenetic, пароль zelenyi-chai-77', tags: ['код'], folder: 'Дом', folderId: 'home'),
    _doc('door', 'Код домофона', body: 'Квартира Сани: 4512', tags: ['код'], folder: 'Дом', folderId: 'home'),
    _doc('pie', 'Мама: пирог', body: '1:05', deep: 'тесто на пирог: три яйца, стакан сахара', tags: ['рецепт'], folder: 'Рецепты', folderId: 'food'),
    _doc('weather', 'Погода для пары', body: 'Виджет показывает, какая погода сейчас у второго', tags: ['togetherly', 'виджет'], folder: 'Идеи', folderId: 'ideas', days: 1),
  ];

  test('точное слово в заголовке — сильное совпадение и первое место', () {
    final hits = rankSearch(docs, ['пароль']);
    expect(hits.first.doc.id, 'wifi');
    expect(hits.first.strong, isTrue);
    expect(hits.first.marks[SearchField.title], [(0, 6)]);
  });

  test('начало слова и опечатка тоже находят', () {
    expect(rankSearch(docs, ['паро']).first.doc.id, 'wifi');
    expect(rankSearch(docs, ['домафон']).first.doc.id, 'door');
  });

  test('находит в расшифровке и тексте с картинки и говорит где', () {
    final hit = rankSearch(docs, ['сахар']).single;
    expect(hit.doc.id, 'pie');
    expect(hit.where, SearchField.deep);
    expect(hit.strong, isFalse);
  });

  test('чип тега фильтрует: без слов показывает всё с тегом', () {
    expect(rankSearch(docs, [], tagFilters: ['код']).map((hit) => hit.doc.id), unorderedEquals(['wifi', 'door']));
    expect(rankSearch(docs, ['пароль'], tagFilters: ['рецепт']), isEmpty);
  });

  test('чип папки фильтрует', () {
    expect(rankSearch(docs, ['код'], folderFilter: 'food'), isEmpty);
  });

  test('из трёх слов хватает одного совпадения, из двух нужны оба', () {
    expect(rankSearch(docs, ['виджет', 'погоды', 'телефона']).first.doc.id, 'weather');
    expect(rankSearch(docs, ['виджет', 'телефона']), isEmpty);
  });

  test('пустой запрос ничего не ищет', () {
    expect(rankSearch(docs, []), isEmpty);
  });
}
