import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/place_cue.dart';

const _places = <KnownPlace>[(id: 'sasha', name: 'Sasha', kind: PlaceKind.guests, label: null)];

PlaceReminderKind? kindOf(String text) => parsePlaceCue(text, places: _places)?.kind;

void expectKinds(Map<String, PlaceReminderKind> cases) {
  for (final MapEntry(key: text, value: kind) in cases.entries) {
    expect(kindOf(text), kind, reason: text);
  }
}

void expectNone(List<String> texts) {
  for (final text in texts) {
    expect(parsePlaceCue(text, places: _places), isNull, reason: text);
  }
}

void main() {
  test('английский', () {
    expectKinds({
      'when I pass by the pharmacy buy vitamins': PlaceReminderKind.pharmacy,
      'when I get to work send the report': PlaceReminderKind.work,
      'on my way home pick up the parcel': PlaceReminderKind.home,
      'stop by the store for milk': PlaceReminderKind.shop,
      "when I'm at the gym bring a towel": PlaceReminderKind.sport,
      'when I visit Sasha return the book': PlaceReminderKind.place,
      'walking past the cafe grab a coffee': PlaceReminderKind.food,
    });
    expectNone(['I passed the pharmacy yesterday', "I'm at the store now", 'I work at the office', 'pass the salt']);
  });

  test('немецкий', () {
    expectKinds({
      'wenn ich an der Apotheke vorbeigehe, Vitamine kaufen': PlaceReminderKind.pharmacy,
      'wenn ich im Fitnessstudio bin, Handtuch mitnehmen': PlaceReminderKind.sport,
      'auf dem Weg nach Hause Paket abholen': PlaceReminderKind.home,
      'ich gehe morgen zum Supermarkt': PlaceReminderKind.shop,
      'wenn ich zur Arbeit komme, Bericht schicken': PlaceReminderKind.work,
    });
    expectNone(['ich war in der Apotheke', 'ich arbeite im Büro']);
  });

  test('испанский', () {
    expectKinds({
      'cuando pase por la farmacia comprar vitaminas': PlaceReminderKind.pharmacy,
      'cuando llegue al trabajo enviar el informe': PlaceReminderKind.work,
      'de camino a casa recoger el paquete': PlaceReminderKind.home,
      'voy al supermercado mañana': PlaceReminderKind.shop,
      'cuando esté en el gimnasio llevar toalla': PlaceReminderKind.sport,
    });
    expectNone(['estuve en la farmacia', 'trabajo en la oficina']);
  });

  test('польский', () {
    expectKinds({
      'gdy będę przechodzić obok apteki kupić witaminy': PlaceReminderKind.pharmacy,
      'jak dojadę do pracy wysłać raport': PlaceReminderKind.work,
      'po drodze do domu odebrać paczkę': PlaceReminderKind.home,
      'wpadnę do sklepu po mleko': PlaceReminderKind.shop,
      'gdy będę na siłowni wziąć ręcznik': PlaceReminderKind.sport,
    });
    expectNone(['byłem w aptece', 'pracuję w biurze']);
  });

  test('румынский', () {
    expectKinds({
      'când trec pe lângă farmacie să cumpăr vitamine': PlaceReminderKind.pharmacy,
      'când ajung la serviciu să trimit raportul': PlaceReminderKind.work,
      'în drum spre casă să iau coletul': PlaceReminderKind.home,
      'mă duc la magazin după lapte': PlaceReminderKind.shop,
      'când sunt la sală să iau prosopul': PlaceReminderKind.sport,
    });
    expectNone(['am fost la farmacie', 'lucrez la birou']);
  });

  test('украинский', () {
    expectKinds({
      'коли проходитиму повз аптеку купити вітаміни': PlaceReminderKind.pharmacy,
      'коли прийду на роботу надіслати звіт': PlaceReminderKind.work,
      'дорогою додому забрати посилку': PlaceReminderKind.home,
      'зайду в магазин по молоко': PlaceReminderKind.shop,
      'коли буду в спортзалі взяти рушник': PlaceReminderKind.sport,
    });
    expectNone(['був в аптеці', 'працюю в офісі']);
  });

  test('из заголовка уходит весь оборот', () {
    String rest(String text) => parsePlaceCue(text, places: _places)!.restOf(text);
    expect(rest('when I pass by the pharmacy buy vitamins'), 'buy vitamins');
    expect(rest('cuando pase por la farmacia comprar vitaminas'), 'comprar vitaminas');
    expect(rest('wenn ich an der Apotheke vorbeigehe, Vitamine kaufen'), 'Vitamine kaufen');
  });
}
