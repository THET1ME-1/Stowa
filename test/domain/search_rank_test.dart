import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/search_query.dart';
import 'package:stowa/domain/search_rank.dart';
import 'package:stowa/domain/word_variants.dart';

SearchDoc _doc(String id, String title, {String body = '', List<String> tags = const [], String? folder, String? folderId, String deep = '', String place = '', int days = 10}) =>
    SearchDoc(id: id, title: title, body: body, tags: tags, folderName: folder, folderId: folderId, deep: deep, place: place, ageDays: days);

List<QueryWord> _words(List<String> words) => [for (final word in words) QueryWord(word, variantsOf(word))];

void main() {
  final docs = [
    _doc('wifi', 'Пароль от Wi-Fi', body: 'Сеть Keenetic, пароль zelenyi-chai-77', tags: ['код'], folder: 'Дом', folderId: 'home'),
    _doc('door', 'Код домофона', body: 'Квартира Сани: 4512', tags: ['код'], folder: 'Дом', folderId: 'home'),
    _doc('pie', 'Мама: пирог', body: '1:05', deep: 'тесто на пирог: три яйца, стакан сахара', tags: ['рецепт'], folder: 'Рецепты', folderId: 'food'),
    _doc('weather', 'Погода для пары', body: 'Виджет показывает, какая погода сейчас у второго', tags: ['togetherly', 'виджет'], folder: 'Идеи', folderId: 'ideas', days: 1),
  ];

  test('точное слово в заголовке — сильное совпадение и первое место', () {
    final hits = rankSearch(docs, _words(['пароль']));
    expect(hits.first.doc.id, 'wifi');
    expect(hits.first.strong, isTrue);
    expect(hits.first.marks[SearchField.title], [(0, 6)]);
  });

  test('начало слова и опечатка тоже находят', () {
    expect(rankSearch(docs, _words(['паро'])).first.doc.id, 'wifi');
    expect(rankSearch(docs, _words(['домафон'])).first.doc.id, 'door');
  });

  test('находит в расшифровке и тексте с картинки и говорит где', () {
    final hit = rankSearch(docs, _words(['сахар'])).single;
    expect(hit.doc.id, 'pie');
    expect(hit.where, SearchField.deep);
    expect(hit.strong, isFalse);
  });

  test('чип тега фильтрует: без слов показывает всё с тегом', () {
    expect(rankSearch(docs, [], tagFilters: ['код']).map((hit) => hit.doc.id), unorderedEquals(['wifi', 'door']));
    expect(rankSearch(docs, _words(['пароль']), tagFilters: ['рецепт']), isEmpty);
  });

  test('чип папки фильтрует', () {
    expect(rankSearch(docs, _words(['код']), folderFilter: 'food'), isEmpty);
  });

  test('из трёх слов хватает одного совпадения, из двух нужны оба', () {
    expect(rankSearch(docs, _words(['виджет', 'погоды', 'телефона'])).first.doc.id, 'weather');
    expect(rankSearch(docs, _words(['виджет', 'телефона'])), isEmpty);
  });

  test('пустой запрос ничего не ищет', () {
    expect(rankSearch(docs, []), isEmpty);
  });

  group('семь языков', () {
    final world = [
      _doc('shrimp', 'Креветки в чесночном соусе', days: 30),
      _doc('haus', 'Häuser in Berlin'),
      _doc('reteta', 'Rețetele bunicii'),
      _doc('zdjecia', 'Zdjęcia z wakacji'),
      _doc('kava', 'Кава з молоком'),
      _doc('coffee', 'Купить кофе', days: 2),
      _doc('kofe', 'kupit kofe zavtra'),
    ];

    test('другая форма слова находит и подсвечивает слово', () {
      final hit = rankSearch(world, _words(['креветками'])).single;
      expect(hit.doc.id, 'shrimp');
      expect(hit.marks[SearchField.title]!.single.$1, 0);
      expect(rankSearch(world, _words(['haus'])).single.doc.id, 'haus');
      expect(rankSearch(world, _words(['retete'])).single.doc.id, 'reteta');
      expect(rankSearch(world, _words(['zdjęciami'])).single.doc.id, 'zdjecia');
      expect(rankSearch(world, _words(['кавою'])).single.doc.id, 'kava');
    });

    test('транслит и чужая раскладка находят кириллицу, и наоборот', () {
      expect(rankSearch(world, _words(['kofe'])).map((hit) => hit.doc.id), containsAll(['coffee', 'kofe']));
      expect(rankSearch(world, _words(['rjat'])).first.doc.id, 'coffee');
      expect(rankSearch(world, _words(['кофе'])).first.doc.id, 'coffee');
      expect(rankSearch(world, _words(['кофе'])).map((hit) => hit.doc.id), contains('kofe'));
    });

    test('само слово выше варианта', () {
      final hits = rankSearch(world, _words(['кофе']));
      expect(hits.first.doc.id, 'coffee');
      expect(hits.first.score, greaterThan(hits.last.score));
    });
  });

  test('находит по месту и говорит, что по месту', () {
    final placed = [_doc('cafe', 'Список покупок', place: 'Кишинёв, улица Пушкина')];
    final hit = rankSearch(placed, _words(['кишиневе'])).single;
    expect(hit.where, SearchField.place);
  });

  test('трёхбуквенное слово текста опечаткой не считается', () {
    final priced = [_doc('sofa', 'Диван 4 500 лей')];
    expect(rankSearch(priced, _words(['клей'])), isEmpty);
    expect(rankSearch(priced, _words(['дован'])).single.doc.id, 'sofa');
  });

  test('находит в документе и говорит, на каком листе', () {
    final withFile = [
      const SearchDoc(
        id: 'xlsx',
        title: 'Смета',
        facts: [
          FactPart(FactKind.fileText, 'Аренда 500', place: 'sheet:Январь'),
          FactPart(FactKind.fileText, 'Плитка 1200\nКлей 300', place: 'sheet:Ремонт'),
        ],
      ),
    ];
    final hit = rankSearch(withFile, _words(['клей'])).single;
    expect(hit.where, SearchField.facts);
    final found = hit.foundFact!;
    expect(found.part.place, 'sheet:Ремонт');
    expect(found.part.text.substring(found.marks.single.$1, found.marks.single.$1 + found.marks.single.$2), 'Клей');
  });

  test('слово и в описании, и в субтитрах — подпись по субтитрам, с секундой', () {
    final video = [
      const SearchDoc(
        id: 'yt',
        title: 'Never Gonna Give You Up',
        facts: [
          FactPart(FactKind.description, 'Lyrics: never gonna run around and desert you'),
          FactPart(FactKind.subtitle, 'Never gonna run around and desert you', seconds: 42.5),
        ],
      ),
    ];
    final found = rankSearch(video, _words(['desert'])).single.foundFact!;
    expect(found.part.kind, FactKind.subtitle);
    expect(found.part.seconds, 42.5);
    expect(found.marks.single.$1, 'Never gonna run around and '.length);
  });

  test('отобранное фильтрами без слов — свежие первыми', () {
    final hits = rankSearch(docs, [], filtered: true);
    expect(hits, hasLength(4));
    expect(hits.first.doc.id, 'weather');
  });
}
