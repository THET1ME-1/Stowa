/// Умные места в тексте заметки без ИИ: адрес, трек-номер, промокод, пароль, карта
/// лояльности. Касанием — открыть на карте, отследить, скопировать.
library;

enum TextPlaceKind { address, tracking, promoCode, password, loyaltyCard }

class FoundPlace {
  const FoundPlace(this.kind, this.value, this.start, this.end, {this.label});

  final TextPlaceKind kind;

  /// Что копировать или искать: адрес как написан, номер карты без пробелов.
  final String value;

  /// Пароль — имя сети рядом с ним («Keenetic»), если оно есть.
  final String? label;
  final int start;
  final int end;
}

// ———————————————— адрес

const _streetWords =
    r'ул\.|улица|улицы|бул\.|бульвар|пр-т|просп\.|проспект|пер\.|переулок|шоссе|наб\.|набережная|пл\.|площадь|'
    r'вул\.|вулиця|str\.|strada|bd\.|bulevardul|șos\.|ul\.|ulica|al\.|aleja|calle|avenida|av\.|avda\.|paseo|plaza';

// «ул. Пушкина 12», «bd. Ștefan cel Mare 134», «улица Николая Зелинского, 7а»
final _streetFirst = RegExp(
  '(?<![\\p{L}])(?:$_streetWords)\\s*((?:[\\p{L}][\\p{L}.\'’-]*\\s+){0,3}?[\\p{L}][\\p{L}.\'’-]*),?\\s+(\\d+\\p{L}?(?:/\\d+)?)(?![\\p{L}\\p{N}])',
  caseSensitive: false,
  unicode: true,
);

// «Hauptstraße 5b»
final _germanStreet = RegExp(r'(?<![\p{L}])\p{Lu}[\p{L}-]*(?:straße|strasse|str\.|weg|platz|allee|gasse)\s+\d+[a-z]?(?![\p{L}\p{N}])', unicode: true);

// «221 Baker Street»
final _englishStreet = RegExp(
  r"(?<![\p{L}\p{N}])\d+[a-zA-Z]?\s+(?:\p{Lu}[\p{L}'-]*\s+){1,3}(?:Street|St\.|Avenue|Ave\.|Road|Rd\.|Boulevard|Blvd\.|Lane|Drive|Square|Way|Place)(?![\p{L}])",
  unicode: true,
);

// ———————————————— трек-номер

// международный UPU: две буквы, девять цифр, две буквы; Cainiao и YunExpress
final _tracking = RegExp(r'(?<![A-Z0-9])(?:[A-Z]{2}\d{9}[A-Z]{2}|LP\d{14}|YT\d{16})(?![A-Z0-9])');

// ———————————————— промокод

final _promo = RegExp(
  r'(?<![\p{L}])(?:промокод|промо-код|promo ?code|promocode|coupon|купон|cod promo[țt]ional|cod de reducere|kod rabatowy|kod promocyjny|gutscheincode|rabattcode|código promocional|código de descuento|cupón)[ \t:—–-]*([A-Za-z0-9][A-Za-z0-9_-]{3,19})(?![\p{L}\p{N}])',
  caseSensitive: false,
  unicode: true,
);

// ———————————————— пароль

final _password = RegExp(r'(?<![\p{L}])(?:пароль|password|passwort|parol[ăa]|has[łl]o|contraseña|pwd)(?![\p{L}])', caseSensitive: false, unicode: true);

// «от почты», «для роутера»: предлог и слово после него паролем не бывают
final _passwordRest = RegExp(
  r'^[ \t]*(?:(?:от|для|к|на|від|до|from|for|of|la|pentru|od|do|für|von|de|para)[ \t]+[^ \t\n]+[ \t]*)?([:=—–-]|is(?=[ \t]))?[ \t]*([^ \t\n]+)',
  caseSensitive: false,
);

final _network = RegExp(r'(?<![\p{L}])(?:сеть|сети|мережа|wi-?fi|network|ssid|re[țt]ea|sie[ćc]|netzwerk|red)[ \t]*[:—–-]?[ \t]*([^ \t\n,;:]+)', caseSensitive: false, unicode: true);

const _notSecrets = {'wi-fi', 'wifi', 'пароль', 'password', 'от', 'на', 'для'};

// ———————————————— карта лояльности

final _card = RegExp(
  r'(?<![\p{L}])(?:карт[аыуе]|карточк[аиуе]|card|cardul|karta|karte|tarjeta)((?:[ \t]+[^\s\d:]+){0,3})[ \t]*:?[ \t]*(\d[\d \-]{6,24}\d)(?![\p{N}])',
  caseSensitive: false,
  unicode: true,
);

/// Все умные места текста по порядку, без перекрытий: номер карты — не трек и не промокод.
List<FoundPlace> findTextPlaces(String text) {
  final candidates = [..._cards(text), ..._trackings(text), ..._passwords(text), ..._promos(text), ..._addresses(text)];
  final taken = <FoundPlace>[];
  for (final one in candidates) {
    if (taken.any((other) => one.start < other.end && other.start < one.end)) continue;
    taken.add(one);
  }
  return taken..sort((a, b) => a.start.compareTo(b.start));
}

Iterable<FoundPlace> _addresses(String text) sync* {
  for (final pattern in [_streetFirst, _germanStreet, _englishStreet]) {
    for (final match in pattern.allMatches(text)) {
      yield FoundPlace(TextPlaceKind.address, match.group(0)!, match.start, match.end);
    }
  }
}

Iterable<FoundPlace> _trackings(String text) sync* {
  for (final match in _tracking.allMatches(text)) {
    yield FoundPlace(TextPlaceKind.tracking, match.group(0)!, match.start, match.end);
  }
}

Iterable<FoundPlace> _promos(String text) sync* {
  for (final match in _promo.allMatches(text)) {
    final code = match.group(1)!;
    // «SALE20», «WINTER-25», «HERBST15»: цифра или заглавные — код, а не слово
    if (!RegExp(r'\d').hasMatch(code) && code != code.toUpperCase()) continue;
    yield FoundPlace(TextPlaceKind.promoCode, code, match.end - code.length, match.end);
  }
}

Iterable<FoundPlace> _passwords(String text) sync* {
  for (final match in _password.allMatches(text)) {
    final lineEnd = text.indexOf('\n', match.end);
    final rest = text.substring(match.end, lineEnd < 0 ? text.length : lineEnd);
    final found = _passwordRest.firstMatch(rest);
    if (found == null) continue;
    var value = found.group(2)!;
    while (value.isNotEmpty && '.,;)»"'.contains(value[value.length - 1])) {
      value = value.substring(0, value.length - 1);
    }
    if (value.length < 4 || _notSecrets.contains(value.toLowerCase())) continue;
    // без двоеточия паролем считается только похожее на пароль: цифра, знак или Заглавные
    final marked = found.group(1) != null;
    final looksSecret = RegExp(r'[\d\W_]').hasMatch(value.replaceAll(RegExp(r'\p{L}', unicode: true), '')) ||
        (RegExp(r'[a-z]').hasMatch(value) && RegExp(r'[A-Z]').hasMatch(value));
    if (!marked && !looksSecret) continue;
    final start = match.end + found.start + found.group(0)!.length - found.group(2)!.length;
    yield FoundPlace(TextPlaceKind.password, value, start, start + value.length, label: _networkBefore(text, match.start));
  }
}

// имя сети в той же строке перед словом «пароль»: «Сеть Keenetic, пароль …»
String? _networkBefore(String text, int at) {
  final lineStart = at == 0 ? 0 : text.lastIndexOf('\n', at - 1) + 1;
  String? name;
  for (final match in _network.allMatches(text.substring(lineStart, at))) {
    final value = match.group(1)!;
    if (!_notSecrets.contains(value.toLowerCase())) name = value;
  }
  return name;
}

Iterable<FoundPlace> _cards(String text) sync* {
  for (final match in _card.allMatches(text)) {
    final raw = match.group(2)!;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8 || digits.length > 19) continue;
    yield FoundPlace(TextPlaceKind.loyaltyCard, digits, match.end - raw.length, match.end);
  }
}
