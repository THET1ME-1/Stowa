// Время на языках, которые разбирают таблицы CLDR, а не свои: французский, итальянский,
// португальский, турецкий, нидерландский, шведский, чешский, венгерский, финский,
// индонезийский, японский, китайский, корейский, греческий, арабский, хинди, вьетнамский.
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/reminder_parser.dart';

// понедельник, 2 ноября 2026, 10:00
final now = DateTime(2026, 11, 2, 10);

DateTime? at(String text) => parseReminder(text, now)?.at;

void expectAll(Map<String, DateTime> cases) {
  for (final MapEntry(key: text, value: expected) in cases.entries) {
    expect(at(text), expected, reason: text);
  }
}

void expectNone(List<String> texts) {
  for (final text in texts) {
    expect(parseReminder(text, now), isNull, reason: text);
  }
}

final tomorrow9 = DateTime(2026, 11, 3, 9);
final inTwoHours = DateTime(2026, 11, 2, 12);

void main() {
  test('французский', () {
    expectAll({
      'demain appeler la banque': tomorrow9,
      'demain à 9h appeler la banque': tomorrow9,
      'demain à 9h30 appeler la banque': DateTime(2026, 11, 3, 9, 30),
      'demain soir cinéma': DateTime(2026, 11, 3, 19),
      'demain à 9h du soir': DateTime(2026, 11, 3, 21),
      'après-demain dentiste': DateTime(2026, 11, 4, 9),
      'apres demain dentiste': DateTime(2026, 11, 4, 9),
      'dans 2 heures sortir le gâteau': inTwoHours,
      'vendredi à 14:30 dentiste': DateTime(2026, 11, 6, 14, 30),
      'le 23 décembre à 13h': DateTime(2026, 12, 23, 13),
      'ce soir appeler maman': DateTime(2026, 11, 2, 19),
    });
    expectNone(['j’ai 2 ans', 'le soir je lis', 'à 9 personnes on mange']);
  });

  test('итальянский', () {
    expectAll({
      'domani alle 9 chiamare la banca': tomorrow9,
      'domani sera cinema': DateTime(2026, 11, 3, 19),
      'tra 2 ore spegnere il forno': inTwoHours,
      'venerdì alle 14:30': DateTime(2026, 11, 6, 14, 30),
      'dopodomani parrucchiere': DateTime(2026, 11, 4, 9),
      'stasera pizza': DateTime(2026, 11, 2, 19),
    });
    expectNone(['la sera è bella', 'alle 9 persone piace']);
  });

  test('португальский', () {
    expectAll({
      'amanhã às 9 ligar para o banco': tomorrow9,
      'amanha as 9 ligar para o banco': tomorrow9,
      'em 2 horas desligar o forno': inTwoHours,
      'sexta-feira às 14:30': DateTime(2026, 11, 6, 14, 30),
      'amanhã de manhã correr': tomorrow9,
    });
  });

  test('турецкий', () {
    expectAll({
      'yarın saat 9 bankayı ara': tomorrow9,
      'yarin saat 9 bankayi ara': tomorrow9,
      'yarın akşam sinema': DateTime(2026, 11, 3, 19),
      '2 saat sonra fırını kapat': inTwoHours,
      'cuma 14:30 dişçi': DateTime(2026, 11, 6, 14, 30),
    });
    // «Cuma» — ещё и имя: без времени не напоминание
    expectNone(['Cuma bey geldi']);
  });

  test('нидерландский, шведский, финский', () {
    expectAll({
      'morgen om 9 uur de bank bellen': tomorrow9,
      'over 2 uur de oven uit': inTwoHours,
      'vrijdag om 14:30': DateTime(2026, 11, 6, 14, 30),
      'i morgon kl. 9 ringa banken': tomorrow9,
      'om 2 timmar stäng av ugnen': inTwoHours,
      'huomenna klo 9 soita pankkiin': tomorrow9,
    });
  });

  test('чешский и венгерский', () {
    expectAll({
      'zítra v 9 zavolat do banky': tomorrow9,
      'za 2 hodiny vypnout troubu': inTwoHours,
      // «reggel» по CLDR — с 6 до 9, позднее утро — «délelőtt»
      'holnap reggel futás': DateTime(2026, 11, 3, 8),
      '2 óra múlva kapcsold ki a sütőt': inTwoHours,
    });
    // «ma» — венгерское «сегодня», но во французском «моя»
    expectNone(['ma voiture est rouge']);
  });

  test('индонезийский', () {
    expectAll({
      'besok jam 9 telepon bank': tomorrow9,
      'dalam 2 jam matikan oven': inTwoHours,
    });
  });

  test('японский, китайский, корейский', () {
    expectAll({
      '明日9時に銀行': tomorrow9,
      '2時間後にオーブンを止める': inTwoHours,
      '明日の午後3時に会議': DateTime(2026, 11, 3, 15),
      '明天下午3点开会': DateTime(2026, 11, 3, 15),
      '2小时后关烤箱': inTwoHours,
      '내일 오후 3시 회의': DateTime(2026, 11, 3, 15),
      '12月23日に歯医者': DateTime(2026, 12, 23, 9),
    });
  });

  test('греческий, арабский, хинди, вьетнамский', () {
    expectAll({
      'αύριο στις 9 τράπεζα': tomorrow9,
      'غدا الساعة 9 البنك': tomorrow9,
      'कल 9 बजे बैंक': tomorrow9,
      'ngày mai lúc 9 giờ gọi ngân hàng': tomorrow9,
    });
  });

  test('свои семь языков не путаются с чужими таблицами', () {
    expectAll({
      // «sera» по-итальянски вечер, а по-испански «будет»
      'mañana será otro día': tomorrow9,
      'morgen um 9 Uhr': tomorrow9,
      'завтра в 9 позвонить': tomorrow9,
      'tomorrow at 9': tomorrow9,
      '5 marzo cumpleaños': DateTime(2027, 3, 5, 9),
    });
    expectNone(['Leo is my cat', 'version 1.5 is out', 'я сутра не ел']);
  });
}
