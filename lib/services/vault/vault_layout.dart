/// Где что лежит в хранилище. Все пути — от корня хранилища, через «/»,
/// как их хранит база: так они переживают перенос хранилища в другую папку.
library;

import 'package:path/path.dart' as p;

import '../../domain/vault_note.dart' show vaultFileName;
import '../privacy/sealed_space.dart';

/// Служебная папка Stowa: факты, обложки, копии страниц, теги, правила.
const serviceFolder = '.stowa';

/// Файл по пути из базы: от корня хранилища или, у открытого скрытого, полный.
String vaultAbsolute(String root, String path) => p.isAbsolute(path) ? path : p.joinAll([root, ...path.split('/')]);

/// Корзина: удалённые вещи тем же видом, 30 дней.
const trashFolder = '.trash';

/// Файл вещи: в корне или в каталоге своей папки; вложенная папка — подкаталог.
/// [folders] — имена от верхней папки до своей.
String notePath({List<String> folders = const [], required String fileName}) => [for (final name in folders) vaultFileName(name), fileName].join('/');

/// Каталог вложений вещи: рядом с файлом, тем же именем без `.md`.
String attachmentsDir(String notePath) => notePath.endsWith('.md') ? notePath.substring(0, notePath.length - 3) : notePath;

/// Свободное имя рядом: «Карбонара.md» → «Карбонара 2.md» → «Карбонара 3.md».
/// [taken] сравнивает без учёта регистра: Android и Windows через Syncthing его не различают.
String uniqueNotePath(String wanted, bool Function(String path) taken) {
  if (!taken(wanted)) return wanted;
  final stem = attachmentsDir(wanted);
  for (var number = 2;; number++) {
    final candidate = '$stem $number.md';
    if (!taken(candidate)) return candidate;
  }
}

/// Служебное и чужое служебное (`.stowa`, `.trash`, `.obsidian`, любая папка с точкой) — не заметки.
bool isServicePath(String relative) => relative.split('/').any((part) => part.startsWith('.'));

String metaFile(String name) => '$serviceFolder/$name.json';

/// Входящие вещи: здесь файл ждёт, пока писатель не перенесёт его к заметке.
String incomingDir(String itemId) => '$serviceFolder/incoming/$itemId';

String incomingFile(String itemId, String fileName) => '${incomingDir(itemId)}/$fileName';

String factsFile(String itemId) => '$serviceFolder/facts/$itemId.json';

/// История правок заметки: снимки переживают переустановку, как факты.
String historyFile(String itemId) => '$serviceFolder/history/$itemId.json';

// у открытой скрытой заметки обложка, кадры и копии страниц лежат в открытой папке скрытого
String coverFile(String itemId, String extension) => SealedSpace.place(itemId, plainCoverFile(itemId, extension));

String plainCoverFile(String itemId, String extension) => '$serviceFolder/covers/$itemId.$extension';

/// Кадры своего ролика по шкале: `0.jpg` … `5.jpg`.
String framesDir(String itemId) => SealedSpace.place(itemId, plainFramesDir(itemId));

String plainFramesDir(String itemId) => '$serviceFolder/frames/$itemId';

String pageCopyFile(String itemId) => SealedSpace.place(itemId, plainPageCopyFile(itemId));

String plainPageCopyFile(String itemId) => '$serviceFolder/pages/$itemId.html.gz';

/// Картинка статьи по номеру среди картинок: формат читает сам декодер, расширение не нужно.
String articleImageFile(String itemId, int index) => '${articlesDir(itemId)}/$index.img';

String articlesDir(String itemId) => SealedSpace.place(itemId, plainArticlesDir(itemId));

String plainArticlesDir(String itemId) => '$serviceFolder/articles/$itemId';

/// Производные файлы заметки, которые ищутся по id, а не по пути в базе: путями от корня
/// хранилища или открытой папки. Обложка — по `cover_path` заметки.
List<String> derivedPaths(String itemId) => [
  plainFramesDir(itemId),
  plainPageCopyFile(itemId),
  plainArticlesDir(itemId),
];

String tagIconFile(String fileName) => '$serviceFolder/tag-icons/$fileName';

String trashPath(String notePath) => '$trashFolder/$notePath';
