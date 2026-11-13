/// Написано ли не на одном из семи языков Stowa: время и места в тексте понимаются только на них.
/// Без словарей и без ИИ: письменность, буквы чужих языков и частые служебные слова.
library;

// служебные слова семи языков приложения: «и», «the», «und», «y», «i», «și»
const _own = {
  // русский
  'и', 'в', 'во', 'не', 'на', 'я', 'что', 'с', 'по', 'это', 'как', 'а', 'но', 'к', 'у', 'за', 'из', 'от', 'до', 'для', 'мне',
  // украинский
  'і', 'й', 'та', 'що', 'це', 'як', 'але', 'від', 'мені', 'з',
  // английский
  'the', 'a', 'an', 'and', 'or', 'to', 'of', 'in', 'on', 'at', 'is', 'it', 'i', 'you', 'we', 'for', 'with', 'my', 'this', 'that', 'be', 'will',
  // немецкий
  'der', 'die', 'das', 'und', 'ist', 'nicht', 'ich', 'du', 'wir', 'mit', 'zu', 'auf', 'für', 'den', 'dem', 'ein', 'eine', 'im', 'zum', 'zur',
  // испанский
  'el', 'la', 'los', 'las', 'y', 'que', 'en', 'un', 'una', 'por', 'para', 'con', 'no', 'es', 'mi', 'se', 'al', 'del',
  // польский
  'w', 'nie', 'się', 'że', 'jest', 'jak', 'ale', 'po', 'do', 'z', 'o',
  // румынский
  'și', 'şi', 'în', 'nu', 'cu', 'de', 'pe', 'să', 'că', 'este', 'sunt',
};

// служебные слова частых чужих языков, которых нет среди своих: итальянский, французский,
// португальский, нидерландский, турецкий, скандинавские
const _foreign = {
  'il', 'gli', 'della', 'delle', 'che', 'per', 'non', 'sono', 'alle', 'alla', 'nel', 'degli',
  'le', 'les', 'des', 'et', 'est', 'une', 'pour', 'dans', 'avec', 'je', 'vous', 'nous', 'pas', 'sur', 'au', 'aux',
  'os', 'não', 'às', 'ao', 'você', 'também', 'com', 'uma',
  'het', 'een', 'van', 'niet', 'zijn', 'voor', 'ik',
  've', 'bir', 'bu', 'için', 'ile', 'çok',
  'och', 'att', 'det', 'är', 'jag', 'ikke', 'og',
};

// буквы, которых нет ни в одном из семи языков: французские, итальянские, португальские, турецкие,
// чешские, скандинавские, балтийские; кириллица сербская, македонская, белорусская
final _foreignLetters = RegExp('[àèìòùçêëïôûÿœæøåãõğıčřůěšžőűāēīūėðþѓќѕјљњћђџў]', unicode: true);

// буквы не латиницы и не кириллицы: китайский, арабский, греческий, иврит, хинди, тайский, корейский
final _otherScript = RegExp(r'[^\P{L}\p{Script=Latin}\p{Script=Cyrillic}]', unicode: true);

final _word = RegExp(r'[\p{L}]+', unicode: true);

/// Текст скорее на чужом языке: время и место в нём строка не найдёт.
/// Короткое и без служебных слов («Linella», «купить хлеб») — не повод так думать.
bool unsupportedLanguage(String text) {
  final lower = text.toLowerCase();
  if (_otherScript.allMatches(lower).length >= 2) return true;
  final words = [for (final match in _word.allMatches(lower)) match.group(0)!];
  if (words.length < 3) return false;
  final own = words.where(_own.contains).length;
  // чужая буква весит как два слова: «à», «ı», «ě» встречаются только там
  final foreign = words.where(_foreign.contains).length + 2 * _foreignLetters.allMatches(lower).length;
  return foreign > own;
}
