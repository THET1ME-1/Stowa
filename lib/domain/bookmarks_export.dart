import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import 'imported_note.dart';

// корневые папки браузера: «Панель закладок», «Другие закладки» — не тема закладки
const _rootMarks = {'personal_toolbar_folder', 'unfiled_bookmarks_folder'};

/// Закладки браузера в формате Netscape (его выгружают Chrome, Firefox, Яндекс, Edge, Safari):
/// каждая закладка — заметка-ссылка с названием и датой. Ближайшая папка закладки и метки
/// Firefox — теги. Не файл закладок — [FormatException].
List<ImportedNote> parseBookmarks(String source) {
  final document = html.parse(source);
  final links = document.querySelectorAll('a[href]');
  // без заголовка Netscape файл закладок узнаётся по спискам <DL> со ссылками
  final marked = source.contains('NETSCAPE-Bookmark-file') || (links.isNotEmpty && document.querySelector('dl') != null);
  if (!marked) throw const FormatException('не файл закладок');

  return [
    for (final link in links)
      if (_web(link.attributes['href'] ?? '') case final url?)
        ImportedNote(
          text: url,
          title: link.text.trim().isEmpty || link.text.trim() == url ? null : link.text.trim(),
          at: _date(link.attributes['add_date']),
          tags: [
            ?_folder(link),
            for (final tag in (link.attributes['tags'] ?? '').split(','))
              if (tag.trim().isNotEmpty) tag.trim(),
          ],
        ),
  ];
}

/// Только страницы: букмарклеты `javascript:` и запросы Firefox `place:` заметками не становятся.
String? _web(String href) {
  final url = href.trim();
  final uri = Uri.tryParse(url);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty ? url : null;
}

/// Секунды с 1970 года; иногда браузер пишет миллисекунды или микросекунды.
DateTime _date(String? raw) {
  var value = int.tryParse(raw ?? '') ?? 0;
  while (value > 100000000000) {
    value ~/= 1000;
  }
  return DateTime.fromMillisecondsSinceEpoch(value * 1000);
}

/// Название ближайшей папки закладки: заголовок `<H3>` перед её списком `<DL>`.
String? _folder(Element link) {
  for (Element? node = link.parent; node != null; node = node.parent) {
    if (node.localName != 'dl') continue;
    final title = _titleOf(node);
    if (title == null) return null;
    if (_rootMarks.any(title.attributes.containsKey)) return null;
    final name = title.text.trim();
    return name.isEmpty ? null : name;
  }
  return null;
}

// <DT><H3>Папка</H3><DL>…</DL>: заголовок — сосед списка или первый ребёнок его <DT>
Element? _titleOf(Element list) {
  final before = list.previousElementSibling;
  if (before != null && before.localName == 'h3') return before;
  final parent = list.parent;
  if (parent == null || parent.localName != 'dt') return null;
  for (final child in parent.children) {
    if (child.localName == 'h3') return child;
  }
  return null;
}
