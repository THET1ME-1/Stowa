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
}
