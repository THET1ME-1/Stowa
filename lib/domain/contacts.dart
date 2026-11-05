/// Телефоны, почта и ссылки в тексте заметки: касанием позвонить, написать, открыть.
library;

class FoundPhone {
  const FoundPhone(this.text, this.dial, this.start, this.end);

  /// Как написано: «+373 69 123 456».
  final String text;

  /// Для набора: только цифры и плюс.
  final String dial;
  final int start;
  final int end;
}

class FoundEmail {
  const FoundEmail(this.address, this.start, this.end);

  final String address;
  final int start;
  final int end;
}

class FoundLink {
  const FoundLink(this.url, this.start, this.end);

  /// Всегда со схемой: «www.site.md» становится «https://www.site.md».
  final String url;
  final int start;
  final int end;
}

// плюс или цифра, дальше цифры с пробелами, дефисами, точками и скобками
final _phone = RegExp(r'(?<![\p{L}\p{N}])(\+?\(?\d[\d \-(). ]{6,}\d)(?![\p{L}\p{N}])', unicode: true);
final _date = RegExp(r'^\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4}$');
final _moneyAfter = RegExp(r'^\s?([$€£₽₴]|лей|lei|руб|грн|zł|eur|usd)', caseSensitive: false);

/// Телефоны: от 9 до 15 цифр. Дата, сумма с валютой и время телефоном не считаются.
List<FoundPhone> findPhones(String text) {
  final found = <FoundPhone>[];
  for (final match in _phone.allMatches(text)) {
    final raw = match.group(1)!;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9 || digits.length > 15) continue;
    if (_date.hasMatch(raw.trim())) continue;
    if (_moneyAfter.hasMatch(text.substring(match.end))) continue;
    final dial = '${raw.trimLeft().startsWith('+') ? '+' : ''}$digits';
    found.add(FoundPhone(raw, dial, match.start, match.end));
  }
  return found;
}

final _email = RegExp(r"[\w.+\-]+@[\w\-]+(?:\.[\w\-]+)+", unicode: true);

List<FoundEmail> findEmails(String text) => [
  for (final match in _email.allMatches(text)) FoundEmail(match.group(0)!, match.start, match.end),
];

final _link = RegExp(r'(?:https?://|www\.)[^\s<>"«»]+', caseSensitive: false);

/// Ссылки без хвостовой пунктуации: точка или скобка в конце предложения — не часть адреса.
List<FoundLink> findLinks(String text) {
  final found = <FoundLink>[];
  for (final match in _link.allMatches(text)) {
    var raw = match.group(0)!;
    while (raw.isNotEmpty && '.,;:!?)]}'.contains(raw[raw.length - 1])) {
      raw = raw.substring(0, raw.length - 1);
    }
    final url = raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw;
    found.add(FoundLink(url, match.start, match.start + raw.length));
  }
  return found;
}
