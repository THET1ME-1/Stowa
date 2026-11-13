import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/note_links.dart';

void main() {
  test('заголовки из текста: [[…]] и [[…|подпись]], без вставок картинок и пустых', () {
    expect(wikiTitles('Пиво [[Хмель]] и [[Солод|солод ячменный]] ![[фото.jpg]] [[  ]] [[Хмель]]'), ['Хмель', 'Солод']);
    expect(wikiTitles('без ссылок'), isEmpty);
  });

  test('курсор внутри [[…]]: где запрос и что набрано', () {
    // «Купить » — 7 знаков, «[[» — 7..9, «пив» — 9..12, «]]» — 12..14
    expect(wikiQueryAt('Купить [[пив]] сегодня', 12), (start: 9, end: 12, query: 'пив'));
    expect(wikiQueryAt('Купить [[пив]] сегодня', 10), (start: 9, end: 12, query: 'пив'));
    // без закрывающих — до курсора
    expect(wikiQueryAt('Купить [[пиво', 13), (start: 9, end: 13, query: 'пиво'));
    expect(wikiQueryAt('Купить [[]]', 9), (start: 9, end: 9, query: ''));
    // за скобками, в картинке и через перенос строки — не запрос
    expect(wikiQueryAt('Купить [[пиво]] сегодня', 18), isNull);
    expect(wikiQueryAt('![[фото', 7), isNull);
    expect(wikiQueryAt('[[пиво\nи', 8), isNull);
    expect(wikiQueryAt('[[пиво]] и [[', 13), (start: 13, end: 13, query: ''));
  });

  group('поиск заметок для связи', () {
    final now = DateTime(2026, 11, 13);
    LinkTarget note(String id, String title, String text, int daysAgo) => (id: id, title: title, text: text, at: now.subtract(Duration(days: daysAgo)), kind: ItemKind.note);
    final notes = [
      note('beer', 'Пиво я очень люблю', 'и обожаю светлое', 5),
      note('hops', 'Хмель для пивоварни', 'заказать на рынке', 2),
      note('bread', 'Хлеб', 'бездрожжевой на закваске, без пива', 1),
      note('car', 'Машина', 'замена масла', 0),
    ];

    test('по словам из заголовка и текста: в заголовке важнее, все слова должны найтись', () {
      // «пив» в заголовке у двух — свежая выше; у хлеба только в тексте — ниже
      expect([for (final one in rankLinkTargets('пив', notes)) one.id], ['hops', 'beer', 'bread']);
      expect([for (final one in rankLinkTargets('пиво светлое', notes)) one.id], ['beer']);
      expect(rankLinkTargets('самолёт', notes), isEmpty);
    });

    test('пусто — свежие первыми; своя заметка не предлагается', () {
      expect([for (final one in rankLinkTargets('', notes, except: 'car')) one.id], ['bread', 'hops', 'beer']);
      expect([for (final one in rankLinkTargets('  ', notes, limit: 2)) one.id], ['car', 'bread']);
    });

    test('знаки над буквами и регистр не мешают', () {
      final cafe = [note('c', 'Café Ölmühle', 'кофе', 0)];
      expect(rankLinkTargets('cafe olm', cafe), hasLength(1));
    });
  });
}
