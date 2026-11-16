/// Где что лежит в хранилище. Все пути — от корня хранилища, через «/»,
/// как их хранит база: так они переживают перенос хранилища в другую папку.
library;

import 'dart:convert';
import 'dart:io';

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

/// Каталог вложений вещи: рядом с файлом, тем же именем без `.md`. Так Stowa клала вложения
/// до 16.11.2026; новые кладутся по [attachmentFolderFor], старые читаются и остаются на месте.
String attachmentsDir(String notePath) => notePath.endsWith('.md') ? notePath.substring(0, notePath.length - 3) : notePath;

String _obsidianApp(Directory root) => p.join(root.path, '.obsidian', 'app.json');

String _stowaChoice(Directory root) => p.join(root.path, serviceFolder, 'attachments.json');

/// Значение `attachmentFolderPath` из файла; файла нет, он сломан или ключа нет — null.
String? _settingIn(String path) {
  try {
    final json = jsonDecode(File(path).readAsStringSync());
    final value = json is Map ? json['attachmentFolderPath'] : null;
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  } on Object {
    return null;
  }
}

/// Куда класть вложения, по старшинству: ключ `attachmentFolderPath` в `.obsidian/app.json`
/// (одна настройка на Obsidian и Stowa) → выбор Stowa в `.stowa/attachments.json` → умолчание.
/// Появившийся Obsidian без своего ключа выбор Stowa не сбрасывает.
/// [obsidian] — в хранилище есть `.obsidian`.
({bool obsidian, String? setting}) readAttachmentSetting(Directory root) {
  final obsidian = Directory(p.join(root.path, '.obsidian')).existsSync();
  return (obsidian: obsidian, setting: (obsidian ? _settingIn(_obsidianApp(root)) : null) ?? _settingIn(_stowaChoice(root)));
}

/// Выбор места вложений из настроек Stowa. С Obsidian — в его `app.json` слиянием: прочие
/// его ключи остаются как были; без — в `.stowa/attachments.json`. Пишется через временный
/// файл и переименование: убитый посреди записи процесс не оставит файл недописанным.
/// Файл Obsidian есть, но не читается словарём (Syncthing дописывает, сломан) — не трогается
/// вовсе, иначе пропали бы остальные настройки Obsidian: false.
bool writeAttachmentSetting(Directory root, String value) {
  final obsidian = Directory(p.join(root.path, '.obsidian')).existsSync();
  final file = File(obsidian ? _obsidianApp(root) : _stowaChoice(root));
  var json = <String, Object?>{};
  if (file.existsSync()) {
    try {
      final old = jsonDecode(file.readAsStringSync());
      if (old is! Map) throw const FormatException('не словарь');
      json = {for (final MapEntry(:key, :value) in old.entries) '$key': value};
    } on Object {
      if (obsidian) return false;
      // свой служебный файл сломан: его можно написать заново
    }
  }
  json['attachmentFolderPath'] = value;
  file.parent.createSync(recursive: true);
  final temp = File('${file.path}.stowa-tmp');
  temp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json), flush: true);
  temp.renameSync(file.path);
  return true;
}

/// Что не так с именем общей папки вложений из поля; годится — null. Пустое, `..`, с ведущим
/// `/`, с точки (служебные `.stowa`, `.trash`, `.obsidian` и скрытые) — нельзя: файлы в каталоге
/// с точкой чтение хранилища не видит и короткое имя `![[фото.jpg]]` там не найдёт.
String? attachmentFolderNameError(String name) {
  final value = name.trim();
  if (value.isEmpty) return 'empty';
  if (value.startsWith('/')) return 'absolute';
  for (final part in value.split('/')) {
    if (part.trim().isEmpty) return 'empty';
    if (part == '..' || part == '.') return 'dots';
    if (part.startsWith('.')) return 'hidden';
  }
  return null;
}

/// Умолчание для записи хранилища: язык приложения, если выбран, иначе телефона.
String Function() attachmentsDefaultFor(String? appLanguage) => () => defaultAttachmentFolder(appLanguage ?? Platform.localeName);

/// Имя общей папки вложений по умолчанию — на языке телефона.
String defaultAttachmentFolder(String locale) => switch (locale.split(RegExp('[_-]')).first.toLowerCase()) {
  'ru' => 'Вложения',
  'uk' => 'Вкладення',
  'ro' => 'Atașamente',
  'pl' => 'Załączniki',
  'de' => 'Anhänge',
  'es' => 'Adjuntos',
  _ => 'Attachments',
};

/// Каталог новых вложений заметки [notePath] (от корня, '' — корень), как у Obsidian:
/// `/` — корень, `./` — рядом с заметкой, `./имя` — подкаталог рядом, `имя` — общая папка.
/// Настройки нет: с Obsidian — корень, как у него самого; без Obsidian — рядом с заметкой.
String attachmentFolderFor(String notePath, {required bool obsidian, String? setting}) {
  final near = p.posix.dirname(notePath) == '.' ? '' : p.posix.dirname(notePath);
  final value = setting?.trim();
  if (value == null || value.isEmpty) return obsidian ? '' : near;
  if (value == '/') return '';
  if (value == '.' || value == './') return near;
  if (value.startsWith('./')) {
    final sub = value.substring(2).replaceAll(RegExp(r'^/+|/+$'), '');
    return [if (near.isNotEmpty) near, if (sub.isNotEmpty) sub].join('/');
  }
  return value.replaceAll(RegExp(r'^/+|/+$'), '');
}

/// Свободное имя рядом: «Карбонара.md» → «Карбонара 2.md» → «Карбонара 3.md».
/// [taken] сравнивает без учёта регистра: Android и Windows через Syncthing его не различают.
String uniqueNotePath(String wanted, bool Function(String path) taken) {
  if (!taken(wanted)) return wanted;
  // расширение своё: у холста «План 2.canvas», у заметки «План 2.md», у рисунка «План 2.excalidraw.md»
  final drawing = wanted.toLowerCase().endsWith('.excalidraw.md');
  final dot = drawing ? wanted.length - '.excalidraw.md'.length : wanted.lastIndexOf('.');
  final hasExtension = dot > wanted.lastIndexOf('/');
  final stem = hasExtension ? wanted.substring(0, dot) : wanted;
  final extension = hasExtension ? wanted.substring(dot) : '';
  for (var number = 2;; number++) {
    final candidate = '$stem $number$extension';
    if (!taken(candidate)) return candidate;
  }
}

/// Холст Obsidian или база — файл, который Stowa показывает своим экраном.
bool isDocumentPath(String relative) => relative.endsWith('.canvas') || relative.endsWith('.base');

/// Файл сам по себе (картинка, PDF, запись): не заметка, не холст и не база.
bool isLoosePath(String relative) => !relative.endsWith('.md') && !isDocumentPath(relative);

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
