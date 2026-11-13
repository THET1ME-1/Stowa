import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/language_guess.dart';

void main() {
  test('чужой язык узнаётся: французский, итальянский, португальский, турецкий, чешский, китайский, арабский', () {
    for (final text in [
      'demain à neuf heures appeler la banque',
      'domani alle nove chiamare la banca e il dentista',
      'amanhã às nove ligar para o banco',
      'yarın saat dokuzda bankayı ara lütfen',
      'zítra v devět zavolat do banky',
      '明天九点给银行打电话',
      'غدا في التاسعة اتصل بالبنك',
      'αύριο στις εννέα τηλεφώνησε στην τράπεζα',
    ]) {
      expect(unsupportedLanguage(text), isTrue, reason: text);
    }
  });

  test('семь языков приложения — свои, короткое и цифры — не повод', () {
    for (final text in [
      'завтра в 9 позвонить в банк',
      'завтра о 9 подзвонити в банк і стоматологу',
      'call the bank tomorrow at nine',
      'morgen die Bank anrufen und den Zahnarzt',
      'mañana llamar al banco y al dentista',
      'jutro zadzwonić do banku i do dentysty',
      'mâine să sun la bancă și la dentist',
      'Linella',
      '14:30',
      'Andy’s Pizza',
    ]) {
      expect(unsupportedLanguage(text), isFalse, reason: text);
    }
  });
}
