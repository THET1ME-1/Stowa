import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/place_cue.dart';

void main() {
  PlaceReminderKind? kindOf(String text) => parsePlaceCue(text)?.kind;
  String? restOf(String text) => parsePlaceCue(text)?.restOf(text);

  test('дом на семи языках: с «напомни» или «когда приду»', () {
    for (final text in [
      'напомни дома купить хлеб',
      'купить хлеб, когда приду домой',
      'дома напомни про счётчики',
      'remind me at home to call mom',
      'call mom when I get home',
      'нагадай вдома полити квіти',
      'полити квіти, коли прийду додому',
      'amintește-mi acasă să sun la bancă',
      'sun la bancă când ajung acasă',
      'przypomnij mi w domu o rachunkach',
      'zapłacić rachunki, jak wrócę do domu',
      'erinnere mich zu Hause an die Rechnung',
      'Rechnung zahlen, wenn ich nach Hause komme',
      'recuérdame en casa regar las plantas',
      'regar las plantas cuando llegue a casa',
    ]) {
      expect(kindOf(text), PlaceReminderKind.home, reason: text);
    }
  });

  test('работа, здесь и магазин', () {
    expect(kindOf('напомни на работе отдать ключи'), PlaceReminderKind.work);
    expect(kindOf('отдать ключи, когда приду на работу'), PlaceReminderKind.work);
    expect(kindOf('remind me at work about the report'), PlaceReminderKind.work);
    expect(kindOf('erinnere mich auf der Arbeit an den Bericht'), PlaceReminderKind.work);
    expect(kindOf('напомни тут купить кофе'), PlaceReminderKind.point);
    expect(kindOf('купить кофе, когда буду здесь'), PlaceReminderKind.point);
    expect(kindOf('remind me here to buy coffee'), PlaceReminderKind.point);
    expect(kindOf('recuérdame aquí comprar café'), PlaceReminderKind.point);
    expect(kindOf('в магазине напомни купить молоко'), PlaceReminderKind.shop);
    expect(kindOf('купить молоко, когда зайду в магазин'), PlaceReminderKind.shop);
    expect(kindOf('remind me at the store to buy milk'), PlaceReminderKind.shop);
    expect(kindOf('przypomnij mi w sklepie o mleku'), PlaceReminderKind.shop);
  });

  test('место без просьбы напомнить — не напоминание', () {
    for (final text in [
      'купил молоко дома',
      'работаю на работе до шести',
      'here is the link',
      'тут лежит паспорт',
      'в магазине скидки на кофе',
      'I left my keys at home',
      'Ich bin zu Hause',
    ]) {
      expect(parsePlaceCue(text), isNull, reason: text);
    }
  });

  test('из заголовка уходят и место, и «напомни»', () {
    expect(restOf('напомни дома купить хлеб'), 'купить хлеб');
    expect(restOf('купить хлеб, когда приду домой'), 'купить хлеб');
    expect(restOf('remind me at home to call mom'), 'to call mom');
    expect(restOf('в магазине напомни купить молоко'), 'купить молоко');
    expect(restOf('Напомни здесь: купить кофе'), 'купить кофе');
  });

  group('без «напомни»: глагол движения и место', () {
    const places = <KnownPlace>[
      (id: 'sasha', name: 'Саша', kind: PlaceKind.guests, label: null),
      (id: 'uni', name: 'Универ', kind: PlaceKind.study, label: null),
      (id: 'linella', name: 'Linella на Ботанике', kind: PlaceKind.shop, label: null),
      (id: 'office', name: 'Офис', kind: PlaceKind.work, label: null),
    ];
    PlaceCue? cue(String text) => parsePlaceCue(text, places: places);

    test('вид места по слову: двадцать с лишним оборотов', () {
      for (final (text, kind) in [
        ('буду проходить мимо магазина, купить хлеб', PlaceReminderKind.shop),
        ('проходя мимо аптеки, взять витамины', PlaceReminderKind.pharmacy),
        ('пройду мимо кафе — забрать кружку', PlaceReminderKind.food),
        ('проеду мимо рынка, купить яблоки', PlaceReminderKind.shop),
        ('буду проезжать возле продуктового магазина', PlaceReminderKind.shop),
        ('буду подходить к дому — вынести мусор', PlaceReminderKind.home),
        ('подъеду к работе, отдать пропуск', PlaceReminderKind.work),
        ('зайду в магазин за молоком', PlaceReminderKind.shop),
        ('загляну в аптеку за пластырем', PlaceReminderKind.pharmacy),
        ('забегу в супермаркет', PlaceReminderKind.shop),
        ('заеду на работу за ноутбуком', PlaceReminderKind.work),
        ('когда приду домой, полить цветы', PlaceReminderKind.home),
        ('вернусь домой — позвонить маме', PlaceReminderKind.home),
        ('когда буду в зале, взять полотенце', PlaceReminderKind.sport),
        ('по дороге в аптеку купить бахилы', PlaceReminderKind.pharmacy),
        ('по пути домой забрать посылку', PlaceReminderKind.home),
        ('Завтра я иду в гости к другу, взять настолку', PlaceReminderKind.guests),
        ('пойду в спортзал, не забыть кроссовки', PlaceReminderKind.sport),
        ('поеду на курсы, взять тетрадь', PlaceReminderKind.study),
        ('буду в ресторане — спросить про банкет', PlaceReminderKind.food),
        ('схожу в бассейн, взять шапочку', PlaceReminderKind.sport),
        ('если окажусь в кофейне, купить зёрна', PlaceReminderKind.food),
        ('доберусь до работы — распечатать договор', PlaceReminderKind.work),
        ('в гостях у Маши отдать книгу', PlaceReminderKind.guests),
        ('буду дома, проверить счётчики', PlaceReminderKind.home),
      ]) {
        expect(cue(text)?.kind, kind, reason: text);
      }
    });

    test('своё место по имени — у него одного, в любой форме', () {
      for (final (text, id) in [
        ('завтра буду у Саши, отдать книгу', 'sasha'),
        ('когда пойду к Саше, взять зарядку', 'sasha'),
        ('буду в универе — сдать реферат', 'uni'),
        ('зайду в Linella за хлебом', 'linella'),
        ('приду в офис, подписать акт', 'office'),
      ]) {
        final found = cue(text);
        expect((found?.kind, found?.placeId), (PlaceReminderKind.place, id), reason: text);
      }
      expect(cue('завтра буду у Саши')?.placeName, 'Саша');
    });

    test('свой вид по слову: одно место вида — оно само, несколько — все места вида', () {
      const one = <KnownPlace>[(id: 'd', name: 'Дача у озера', kind: PlaceKind.other, label: 'Дача')];
      final single = parsePlaceCue('на выходных поеду на дачу, взять семена', places: one);
      expect((single?.kind, single?.placeId, single?.placeName), (PlaceReminderKind.place, 'd', 'Дача у озера'));

      const two = <KnownPlace>[
        (id: 'd1', name: 'Дача родителей', kind: PlaceKind.other, label: 'Дача'),
        (id: 'd2', name: 'Дача Саши', kind: PlaceKind.other, label: 'Дача'),
      ];
      final both = parsePlaceCue('когда буду на даче, полить огурцы', places: two);
      expect((both?.kind, both?.placeId, both?.placeName), (PlaceReminderKind.place, 'kind:Дача', 'Дача'));
      expect(kindOfWord('универ'), PlaceKind.study);
      expect(kindOfWord('Аптеке'), PlaceKind.pharmacy);
    });

    test('прошедшее время, глагол вместо места и место без движения — не напоминание', () {
      for (final text in [
        'зашёл в магазин и купил хлеб',
        'был в аптеке, всё дорого',
        'работаю в офисе до шести',
        'завтра буду работать до вечера',
        'пойду спать пораньше',
        'буду в восторге, если получится',
        'купил молоко дома',
      ]) {
        expect(cue(text), isNull, reason: text);
      }
    });

    test('из заголовка уходит весь оборот вместе с «когда» и «я»', () {
      String rest(String text) => cue(text)!.restOf(text);
      expect(rest('Когда буду проходить мимо магазина, купить хлеб'), 'купить хлеб');
      expect(rest('я иду в гости к другу, взять настолку'), 'взять настолку');
      expect(rest('купить хлеб, если зайду в магазин'), 'купить хлеб');
    });
  });

  test('где место в тексте: его подчёркивает строка', () {
    final cue = parsePlaceCue('купить хлеб, когда приду домой')!;
    expect('купить хлеб, когда приду домой'.substring(cue.start, cue.end), 'когда приду домой');
  });
}
