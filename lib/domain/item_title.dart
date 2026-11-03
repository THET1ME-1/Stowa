const titleLimit = 80;

final _markdownLead = RegExp(r'^(#{1,6}\s+|- \[[ xX]\]\s+|[-*>]\s+)');
final _inlineTag = RegExp(r'(?<![\p{L}\p{N}_#])#[\p{L}_][\p{L}\p{N}_]*', unicode: true);
final _url = RegExp(r'(?:https?://|www\.)\S+', caseSensitive: false);
final _danglingPunctuation = RegExp(r'[\s:—–-]+$');

// имена, которые придумала камера или телефон, а не человек
final _machineName = RegExp(
  r'^(img|vid|pxl|dsc|dcim|mvimg|screenshot|скриншот|снимок экрана|photo|image|video|signal|telegram|whatsapp|photo_|pic|wp)[\s_\-]?[\w\-\s.]*\d{4}|^[\d_\-\s.]+$',
  caseSensitive: false,
);
final _screenshotName = RegExp(r'^(screenshot|скриншот|снимок экрана|screen shot)', caseSensitive: false);

/// Снимок экрана по имени файла: подпись «Скриншот», а не «Фото».
bool isScreenshotName(String fileName) => _screenshotName.hasMatch(fileName.trim());

// имя файла в заголовок: без расширения; машинное — пусто, подпись даст экран
String _fileTitle(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final bare = (dot > 0 ? fileName.substring(0, dot) : fileName).trim();
  if (bare.isEmpty || _machineName.hasMatch(bare)) return '';
  return bare[0].toUpperCase() + bare.substring(1);
}

/// Заголовок вещи: первая строка без разметки и тегов, с заглавной буквы,
/// не длиннее [titleLimit]. Без текста — имя первого файла, если его давал человек.
String titleFor(String text, {String? fileName}) {
  final lines = [
    for (final raw in text.split('\n')) raw.trim().replaceFirst(_markdownLead, '').replaceAll(_inlineTag, '').replaceAll(RegExp(r'\s+'), ' ').trim(),
  ];
  // ссылка в заголовке не читается: берём слова вокруг неё, а голую ссылку оставляем как есть
  final words = lines.map((line) => line.replaceAll(_url, ' ').replaceAll(RegExp(r'\s+'), ' ').replaceAll(_danglingPunctuation, '').trim());
  final line = words.firstWhere((clean) => clean.isNotEmpty, orElse: () => '');
  if (line.isEmpty) {
    final bare = lines.firstWhere((clean) => clean.isNotEmpty, orElse: () => '');
    if (bare.isNotEmpty) return bare;
    return fileName == null ? text.trim() : _fileTitle(fileName);
  }
  var title = line;
  if (title.length > titleLimit) {
    final cut = title.substring(0, titleLimit - 1);
    final space = cut.lastIndexOf(' ');
    title = '${space > titleLimit ~/ 2 ? cut.substring(0, space) : cut}…';
  }
  return title[0].toUpperCase() + title.substring(1);
}
