/// День съёмки по имени файла: камера и скриншоты Android, Pixel, Samsung, Telegram, WhatsApp
/// пишут дату в имя. Нужна там, где EXIF нет: ролики, PNG-скриншоты, пересланное.
library;

// «IMG_20260715_183012», «Screenshot_20261106-141205», «PXL_20240503_184210123»
final _compact = RegExp(r'(?<!\d)(\d{4})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})');

// «photo_2024-05-03_18-42-10», «Screenshot_2024-05-03-18-42-10-123»
final _dashed = RegExp(r'(?<!\d)(\d{4})-(\d{2})-(\d{2})[ _-](\d{2})[-.](\d{2})[-.](\d{2})');

// «IMG-20240503-WA0001»: у WhatsApp только день
final _whatsApp = RegExp(r'(?<!\d)(\d{4})(\d{2})(\d{2})-WA\d', caseSensitive: false);

/// Когда снято, по имени файла; в имени даты нет или она невозможная — null.
DateTime? shotDateFromName(String fileName) {
  for (final pattern in [_compact, _dashed, _whatsApp]) {
    final match = pattern.firstMatch(fileName);
    if (match == null) continue;
    final parts = [for (var index = 1; index <= match.groupCount; index++) int.parse(match.group(index)!)];
    final date = _valid(parts);
    if (date != null) return date;
  }
  return null;
}

// год, месяц, день и, если есть, часы, минуты, секунды; DateTime сам переносит 32 марта в апрель
DateTime? _valid(List<int> parts) {
  final [year, month, day, ...time] = parts;
  final hour = time.isEmpty ? 0 : time[0];
  final minute = time.isEmpty ? 0 : time[1];
  final second = time.isEmpty ? 0 : time[2];
  if (year < 1990 || year > 2100 || month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (hour > 23 || minute > 59 || second > 59) return null;
  final date = DateTime(year, month, day, hour, minute, second);
  return date.month == month ? date : null;
}
