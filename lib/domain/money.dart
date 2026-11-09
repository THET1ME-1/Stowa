/// Деньги в тексте на семи языках: «35 лей», «€20», «2 000 ₽», «$19.99», «150 zł».
///
/// Сумма без валюты деньгами не считается: «500» может быть чем угодно.
library;

import 'package:intl/intl.dart';

import 'word_forms.dart';

/// Найденная сумма и её место в тексте вместе с валютой.
class Money {
  const Money({required this.amount, required this.currency, required this.start, required this.end});

  final double amount;

  /// Код валюты: MDL, RUB, UAH, USD, EUR, PLN, GBP, RON.
  final String currency;
  final int start;
  final int end;
}

const _symbols = {r'$': 'USD', '€': 'EUR', '£': 'GBP', '₽': 'RUB', '₴': 'UAH'};

// слова валют свёрнутыми: точные формы и начала (склонения)
const _exact = {
  'MDL': {'лей', 'лея', 'леев', 'lei', 'leu', 'mdl'},
  'RUB': {'руб', 'р', 'rub', 'rur'},
  'UAH': {'грн', 'uah'},
  'USD': {'usd', 'долл', 'бакс', 'бакса', 'баксов'},
  'EUR': {'eur', 'евро', 'євро', 'euro', 'euros'},
  'PLN': {'zl', 'pln'},
  'GBP': {'gbp'},
  'RON': {'ron'},
};
const _prefixes = {
  'RUB': ['рубл'],
  'UAH': ['гривн', 'гривен', 'гривень'],
  'USD': ['доллар', 'dollar'],
  'PLN': ['zlot', 'злот'],
  'GBP': ['фунт', 'pound'],
};

/// Валюта по слову или знаку. Не валюта — null.
String? currencyOf(String token) {
  final symbol = _symbols[token];
  if (symbol != null) return symbol;
  final word = foldText(token).replaceAll('.', '');
  for (final entry in _exact.entries) {
    if (entry.value.contains(word)) return entry.key;
  }
  for (final entry in _prefixes.entries) {
    if (entry.value.any(word.startsWith)) return entry.key;
  }
  return null;
}

// число с пробелами между тысячами и точкой или запятой: «2 000», «1.500,50», «19.99»
final _number = RegExp(r'\d+(?:[   ]\d{3})*(?:[.,]\d+)*');
final _wordAfter = RegExp(r'^[   ]?([$€£₽₴]|[\p{L}]+\.?)', unicode: true);
final _wordBefore = RegExp(r'([$€£₽₴]|[\p{L}]+)[   ]?$', unicode: true);
final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Сумма из записи числа: последний разделитель с одной-двумя цифрами после — дробь,
/// остальные — тысячи. «1.500» и «1,500» — тысяча пятьсот.
double? parseAmount(String raw) {
  final text = raw.replaceAll(RegExp(r'[   ]'), '');
  final lastDot = text.lastIndexOf('.');
  final lastComma = text.lastIndexOf(',');
  final last = lastDot > lastComma ? lastDot : lastComma;
  if (last < 0) return double.tryParse(text);
  final separator = text[last];
  final tail = text.length - last - 1;
  final once = separator.allMatches(text).length == 1;
  final decimal = (lastDot >= 0 && lastComma >= 0) || (once && tail >= 1 && tail <= 2);
  if (!decimal) return double.tryParse(text.replaceAll(RegExp('[.,]'), ''));
  final whole = text.substring(0, last).replaceAll(RegExp('[.,]'), '');
  return double.tryParse('$whole.${text.substring(last + 1)}');
}

/// Все суммы с валютой в тексте, по порядку.
List<Money> findMoney(String text) {
  final found = <Money>[];
  for (final match in _number.allMatches(text)) {
    // цифра внутри слова или числа («A4», «v2»): не сумма
    if (match.start > 0 && _letterOrDigit.hasMatch(text[match.start - 1])) continue;
    final amount = parseAmount(match.group(0)!);
    if (amount == null) continue;
    final after = _wordAfter.firstMatch(text.substring(match.end));
    final afterCurrency = after == null ? null : currencyOf(after.group(1)!);
    if (afterCurrency != null) {
      found.add(Money(amount: amount, currency: afterCurrency, start: match.start, end: match.end + after!.group(0)!.length));
      continue;
    }
    final before = _wordBefore.firstMatch(text.substring(0, match.start));
    final beforeCurrency = before == null ? null : currencyOf(before.group(1)!);
    // перед суммой валюта только целым словом: «вход €20», но не «руб» внутри «клуб»
    if (beforeCurrency != null && (before!.start == 0 || !_letterOrDigit.hasMatch(text[before.start - 1]))) {
      found.add(Money(amount: amount, currency: beforeCurrency, start: before.start, end: match.end));
    }
  }
  return found;
}

/// Суммы по валютам: «4 200 лей» и «18 950 лей» — «23 150 лей». Большая сумма первой.
List<(double, String)> sumByCurrency(Iterable<(double, String)> prices) {
  final sums = <String, double>{};
  for (final (amount, currency) in prices) {
    sums[currency] = (sums[currency] ?? 0) + amount;
  }
  return [for (final entry in sums.entries) (entry.value, entry.key)]..sort((a, b) => b.$1.compareTo(a.$1));
}

// знак перед суммой, как пишут доллары и евро; остальные валюты — после
const _signBefore = {'USD': r'$', 'EUR': '€', 'GBP': '£'};
const _signAfter = {'RUB': '₽', 'UAH': '₴', 'PLN': 'zł', 'RON': 'lei'};

/// Итог для человека: «23 150 лей · €40». Целое — без копеек.
String formatTotal(List<(double, String)> total, String locale) => [
  for (final (amount, currency) in total)
    () {
      final number = NumberFormat(amount == amount.roundToDouble() ? '#,##0' : '#,##0.00', locale).format(amount);
      if (_signBefore[currency] case final sign?) return '$sign$number';
      // лей по-русски и по-украински — «лей», на остальных — «lei»
      final after = currency == 'MDL' ? (locale.startsWith('ru') || locale.startsWith('uk') ? 'лей' : 'lei') : _signAfter[currency] ?? currency;
      return '$number $after';
    }(),
].join(' · ');
