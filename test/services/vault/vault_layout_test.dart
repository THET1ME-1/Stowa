import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/services/page_cache.dart';
import 'package:stowa/services/vault/vault_layout.dart';

void main() {
  test('вещь без папки — в корне, с папкой — в каталоге папки', () {
    expect(notePath(fileName: 'Купить молоко.md'), 'Купить молоко.md');
    expect(notePath(folders: ['Рецепты'], fileName: 'Карбонара.md'), 'Рецепты/Карбонара.md');
    // вложенная папка — подкаталог
    expect(notePath(folders: ['Дом', 'Ремонт', 'Кухня'], fileName: 'Плитка.md'), 'Дом/Ремонт/Кухня/Плитка.md');
    // имя папки чистится так же, как имя файла
    expect(notePath(folders: ['Дом/Сад'], fileName: 'Грядки.md'), 'Дом Сад/Грядки.md');
    expect(attachmentsDir('Рецепты/Карбонара.md'), 'Рецепты/Карбонара');
  });

  test('одно имя дважды — с номером, регистр не важен', () {
    final taken = {'рецепты/карбонара.md', 'рецепты/карбонара 2.md'};
    expect(uniqueNotePath('Рецепты/Карбонара.md', (path) => taken.contains(path.toLowerCase())), 'Рецепты/Карбонара 3.md');
    expect(uniqueNotePath('Рецепты/Борщ.md', (path) => taken.contains(path.toLowerCase())), 'Рецепты/Борщ.md');
  });

  test('служебные папки не считаются заметками', () {
    expect(isServicePath('.stowa/facts/a.json'), isTrue);
    expect(isServicePath('.trash/Рецепты/Карбонара.md'), isTrue);
    expect(isServicePath('.obsidian/workspace.json'), isTrue);
    expect(isServicePath('Рецепты/.hidden/x.md'), isTrue);
    expect(isServicePath('Рецепты/Карбонара.md'), isFalse);
  });

  test('факты, обложки, копии страниц, значки тегов и холст лежат под .stowa', () {
    expect(metaFile('tags'), '.stowa/tags.json');
    expect(factsFile('a'), '.stowa/facts/a.json');
    expect(coverFile('a', 'jpg'), '.stowa/covers/a.jpg');
    expect(pageCopyFile('a'), '.stowa/pages/a.html.gz');
    expect(tagIconFile('x.png'), '.stowa/tag-icons/x.png');
    expect(trashPath('Рецепты/Карбонара.md'), '.trash/Рецепты/Карбонара.md');
  });

  test('копия страницы пишется под .stowa, старая из pages/ ещё читается', () async {
    final root = Directory.systemTemp.createTempSync('stowa_layout');
    addTearDown(() => root.deleteSync(recursive: true));
    await savePage(root, 'a', '<title>Новая</title>');
    expect(File(p.join(root.path, '.stowa', 'pages', 'a.html.gz')).existsSync(), isTrue);
    final legacy = File(p.join(root.path, 'pages', 'b.html.gz'))..createSync(recursive: true);
    legacy.writeAsBytesSync(gzip.encode(utf8.encode('<title>Старая</title>')));
    expect(await readPage(root, 'b'), '<title>Старая</title>');
  });

  test('место вложений: корень, рядом, подкаталог, общая папка, без Obsidian', () {
    const note = 'Stowa/Покупки.md';
    expect(attachmentFolderFor(note, obsidian: true, setting: '/'), '');
    expect(attachmentFolderFor(note, obsidian: true, setting: null), '');
    expect(attachmentFolderFor(note, obsidian: true, setting: './'), 'Stowa');
    expect(attachmentFolderFor(note, obsidian: true, setting: './вложения'), 'Stowa/вложения');
    expect(attachmentFolderFor(note, obsidian: true, setting: 'Изображения'), 'Изображения');
    expect(attachmentFolderFor(note, obsidian: false, setting: null), 'Stowa');
    expect(attachmentFolderFor('Покупки.md', obsidian: false, setting: null), '');
    expect(attachmentFolderFor('Покупки.md', obsidian: true, setting: './'), '');
  });

  test('настройка вложений читается из .obsidian/app.json', () {
    final root = Directory.systemTemp.createTempSync('stowa_att');
    addTearDown(() => root.deleteSync(recursive: true));
    expect(readAttachmentSetting(root), (obsidian: false, setting: null));
    Directory(p.join(root.path, '.obsidian')).createSync();
    expect(readAttachmentSetting(root), (obsidian: true, setting: null));
    File(p.join(root.path, '.obsidian', 'app.json')).writeAsStringSync(jsonEncode({'attachmentFolderPath': 'Изображения', 'promptDelete': false}));
    expect(readAttachmentSetting(root), (obsidian: true, setting: 'Изображения'));
    File(p.join(root.path, '.obsidian', 'app.json')).writeAsStringSync('{сломан');
    expect(readAttachmentSetting(root), (obsidian: true, setting: null));
  });

  test('выбор вложений в Stowa: с Obsidian — в его app.json, без — в .stowa', () {
    final root = Directory.systemTemp.createTempSync('stowa_att');
    addTearDown(() => root.deleteSync(recursive: true));
    expect(writeAttachmentSetting(root, 'Вложения'), isTrue);
    expect(File(p.join(root.path, '.stowa', 'attachments.json')).existsSync(), isTrue);
    expect(Directory(p.join(root.path, '.obsidian')).existsSync(), isFalse);
    expect(readAttachmentSetting(root), (obsidian: false, setting: 'Вложения'));
    expect(attachmentFolderFor('Покупки.md', obsidian: false, setting: 'Вложения'), 'Вложения');

    final app = File(p.join(root.path, '.obsidian', 'app.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'attachmentFolderPath': 'Изображения', 'promptDelete': false}));
    expect(readAttachmentSetting(root), (obsidian: true, setting: 'Изображения'));
    expect(writeAttachmentSetting(root, './'), isTrue);
    final json = jsonDecode(app.readAsStringSync()) as Map;
    expect(json['attachmentFolderPath'], './');
    expect(json['promptDelete'], isFalse);
    expect(readAttachmentSetting(root), (obsidian: true, setting: './'));
  });

  test('сломанный app.json Obsidian не переписывается: остаётся байт в байт, выбор не принят', () {
    final root = Directory.systemTemp.createTempSync('stowa_att');
    addTearDown(() => root.deleteSync(recursive: true));
    final app = File(p.join(root.path, '.obsidian', 'app.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('{"attachmentFolderPath": "Изобр');
    expect(writeAttachmentSetting(root, 'Вложения'), isFalse);
    expect(app.readAsStringSync(), '{"attachmentFolderPath": "Изобр');
    // временных файлов рядом не остаётся
    expect(Directory(p.join(root.path, '.obsidian')).listSync(), hasLength(1));
  });

  test('появился Obsidian без своей настройки — выбор Stowa остаётся в силе', () {
    final root = Directory.systemTemp.createTempSync('stowa_att');
    addTearDown(() => root.deleteSync(recursive: true));
    expect(writeAttachmentSetting(root, 'Вложения'), isTrue);
    File(p.join(root.path, '.obsidian', 'app.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'promptDelete': false}));
    expect(readAttachmentSetting(root), (obsidian: true, setting: 'Вложения'));
  });

  test('имя папки вложений: пустое, «..», с точки и служебное не годится', () {
    expect(attachmentFolderNameError('Вложения'), isNull);
    expect(attachmentFolderNameError('Медиа/Фото'), isNull);
    for (final bad in ['', '  ', '..', 'a/../b', '/Вложения', '.stowa', '.trash', '.obsidian', '.скрытая', 'Медиа/.x']) {
      expect(attachmentFolderNameError(bad), isNotNull, reason: bad);
    }
  });

  test('папка вложений по умолчанию — на языке телефона', () {
    expect(defaultAttachmentFolder('ru_RU'), 'Вложения');
    expect(defaultAttachmentFolder('uk'), 'Вкладення');
    expect(defaultAttachmentFolder('de_DE'), 'Anhänge');
    expect(defaultAttachmentFolder('fr_FR'), 'Attachments');
  });

  test('упомянутые имена файлов: как поиск подстроки, с учётом регистра, не через стык двух заметок', () {
    const texts = 'Схема в ![[Pasted image 2024.png]]\u0000Обложка: "[[Книги/1984.jpg|1984.jpg]]"\u0000см. архив.tar.gz и README\u0000конец a.p\u0000ng';
    final names = ['Pasted image 2024.png', '1984.jpg', 'архив.tar.gz', 'README', 'readme', 'image 2024.png', 'Скан.png', 'a.png', 'PASTED IMAGE 2024.PNG'];
    expect(mentionedNames(texts, names), {'Pasted image 2024.png', '1984.jpg', 'архив.tar.gz', 'README', 'image 2024.png'});
  });

  test('упомянутые имена на большом хранилище — один проход по тексту, а не поиск на каждое имя', () {
    // 8 МБ текста College и 222 файла без заметки: поиск на каждое имя шёл 24 с
    final texts = List.filled(40000, 'Конспект лекции, схема ![[Вложения/схема сети.png]] и таблица.\u0000').join();
    final names = [for (var i = 0; i < 600; i++) 'Скан документа $i.png'];
    final watch = Stopwatch()..start();
    final found = mentionedNames(texts, [...names, 'схема сети.png']);
    expect(found, {'схема сети.png'});
    // поиском на каждое имя выходило 3,4 с, одним проходом — 0,1 с
    expect(watch.elapsedMilliseconds, lessThan(1000));
  });
}
