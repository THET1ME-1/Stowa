const titleLimit = 80;

final _markdownLead = RegExp(r'^(#{1,6}\s+|- \[[ xX]\]\s+|[-*>]\s+)');
final _inlineTag = RegExp(r'(?<![\p{L}\p{N}_#])#[\p{L}_][\p{L}\p{N}_]*', unicode: true);

/// Заголовок вещи: первая строка без разметки и тегов, с заглавной буквы,
/// не длиннее [titleLimit]. Без текста — имя первого файла.
String titleFor(String text, {String? fileName}) {
  final line = text
      .split('\n')
      .map((raw) => raw.trim().replaceFirst(_markdownLead, '').replaceAll(_inlineTag, '').replaceAll(RegExp(r'\s+'), ' ').trim())
      .firstWhere((clean) => clean.isNotEmpty, orElse: () => '');
  if (line.isEmpty) return fileName ?? text.trim();
  var title = line;
  if (title.length > titleLimit) {
    final cut = title.substring(0, titleLimit - 1);
    final space = cut.lastIndexOf(' ');
    title = '${space > titleLimit ~/ 2 ? cut.substring(0, space) : cut}…';
  }
  return title[0].toUpperCase() + title.substring(1);
}
