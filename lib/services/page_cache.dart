import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Копия страницы ссылки, сжатая: превью скачивает её один раз, а извлекатели
/// читают отсюда. Улучшили разбор — старые ссылки перечитаются без сети.
/// В резервную копию не идёт: её можно скачать заново.
File pageFile(Directory filesRoot, String itemId) => File(p.join(filesRoot.path, 'pages', '$itemId.html.gz'));

Future<void> savePage(Directory filesRoot, String itemId, String html) async {
  final file = pageFile(filesRoot, itemId);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(gzip.encode(utf8.encode(html)), flush: true);
}

/// Копия есть и читается — текст страницы, иначе null.
Future<String?> readPage(Directory filesRoot, String itemId) async {
  final file = pageFile(filesRoot, itemId);
  if (!await file.exists()) return null;
  try {
    return utf8.decode(gzip.decode(await file.readAsBytes()), allowMalformed: true);
  } on FormatException {
    return null;
  }
}
