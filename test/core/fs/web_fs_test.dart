import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/fs/web_fs.dart';
import 'package:stowa/core/fs/web_store.dart';

/// Браузер «закрыли и открыли»: новая файловая система поверх того же хранилища и журнала.
Future<WebFileSystem> reopen(MemoryWebStore store, MemoryWebWal wal) async {
  final fs = WebFileSystem(store, wal: wal);
  await fs.hydrate();
  return fs;
}

Uint8List bytes(int length, [int seed = 7]) => Uint8List.fromList([for (var i = 0; i < length; i++) (i * seed) & 0xFF]);

void main() {
  late MemoryWebStore store;
  late MemoryWebWal wal;
  late WebFileSystem fs;

  setUp(() async {
    store = MemoryWebStore();
    wal = MemoryWebWal();
    fs = await reopen(store, wal);
  });

  test('заметка доживает до следующего открытия, время правки то же', () async {
    final note = fs.file('/vault/Идеи.md');
    await note.parent.create(recursive: true);
    await note.writeAsString('Идеи\nпервая');
    final modified = note.lastModifiedSync();
    await fs.flush();

    final again = await reopen(store, MemoryWebWal());
    expect(again.file('/vault/Идеи.md').readAsStringSync(), 'Идеи\nпервая');
    expect(again.file('/vault/Идеи.md').lastModifiedSync(), modified);
  });

  test('крупное вложение читается из хранилища, синхронно — понятная ошибка', () async {
    final photo = fs.file('/vault/attachments/фото.jpg');
    await photo.parent.create(recursive: true);
    final content = bytes(600 * 1024);
    await photo.writeAsBytes(content);
    await fs.flush();

    final again = await reopen(store, MemoryWebWal());
    final there = again.file('/vault/attachments/фото.jpg');
    expect(there.lengthSync(), content.length);
    expect(again.statSync(there.path).size, content.length);
    expect(await there.readAsBytes(), content);
    expect(() => there.readAsBytesSync(), throwsA(isA<FileSystemException>()));
    final streamed = await there.openRead(10, 20).expand((chunk) => chunk).toList();
    expect(streamed, content.sublist(10, 20));
  });

  test('переименование папки уносит дерево с заметками и вложениями', () async {
    await fs.directory('/vault/Дом/attachments').create(recursive: true);
    await fs.file('/vault/Дом/Ремонт.md').writeAsString('Ремонт');
    await fs.file('/vault/Дом/attachments/план.png').writeAsBytes(bytes(400 * 1024, 3));
    await fs.flush();

    await fs.directory('/vault/Дом').rename('/vault/Квартира');
    await fs.flush();

    final again = await reopen(store, MemoryWebWal());
    expect(again.directory('/vault/Дом').existsSync(), isFalse);
    expect(again.file('/vault/Квартира/Ремонт.md').readAsStringSync(), 'Ремонт');
    expect(await again.file('/vault/Квартира/attachments/план.png').readAsBytes(), bytes(400 * 1024, 3));
    expect(store.paths.where((path) => path.startsWith('/vault/Дом')), isEmpty);
  });

  test('удалённая папка не возвращается после открытия', () async {
    await fs.directory('/vault/Старое').create(recursive: true);
    await fs.file('/vault/Старое/a.md').writeAsString('a');
    await fs.flush();
    await fs.directory('/vault/Старое').delete(recursive: true);
    await fs.flush();

    final again = await reopen(store, MemoryWebWal());
    expect(again.directory('/vault/Старое').existsSync(), isFalse);
  });

  test('вкладку закрыли до записи в хранилище: правка заметки не теряется', () async {
    await fs.directory('/vault').create(recursive: true);
    await fs.file('/vault/a.md').writeAsString('было');
    await fs.flush();
    fs.file('/vault/a.md').writeAsStringSync('стало');
    await fs.file('/vault/b.md').writeAsString('новая');
    await fs.file('/vault/a.md').parent.list().toList();
    // без flush: журнал в localStorage пишется сразу
    final again = await reopen(store, wal);
    expect(again.file('/vault/a.md').readAsStringSync(), 'стало');
    expect(again.file('/vault/b.md').readAsStringSync(), 'новая');
    // и после записи в хранилище журнал пуст
    await again.flush();
    expect(wal.entries, isEmpty);
    expect(utf8.decode(await store.read('/vault/a.md')), 'стало');
  });

  test('удаление тоже переживает закрытие вкладки', () async {
    await fs.directory('/vault').create(recursive: true);
    await fs.file('/vault/a.md').writeAsString('a');
    await fs.flush();
    fs.file('/vault/a.md').deleteSync();
    final again = await reopen(store, wal);
    expect(again.file('/vault/a.md').existsSync(), isFalse);
  });

  test('временные файлы и кэш в хранилище не пишутся', () async {
    final temp = await fs.systemTempDirectory.createTemp('x');
    await fs.file('${temp.path}/t.bin').writeAsBytes(bytes(10));
    await fs.directory('/cache').create();
    await fs.file('/cache/c').writeAsString('c');
    await fs.flush();
    expect(store.paths.where((path) => !path.startsWith('/vault') && !path.startsWith('/app')), isEmpty);
  });

  test('поток записи: файл виден после закрытия и уходит в хранилище', () async {
    await fs.directory('/vault').create(recursive: true);
    final sink = fs.file('/vault/s.md').openWrite();
    sink.write('по');
    sink.write('ток');
    await sink.close();
    await fs.flush();
    expect(utf8.decode(await store.read('/vault/s.md')), 'поток');
  });

  test('копия и перенос крупного файла без чтения его в память', () async {
    await fs.directory('/vault/a').create(recursive: true);
    await fs.file('/vault/a/big.bin').writeAsBytes(bytes(700 * 1024, 5));
    await fs.flush();
    final again = await reopen(store, MemoryWebWal());
    await again.file('/vault/a/big.bin').rename('/vault/a/moved.bin');
    await again.file('/vault/a/moved.bin').copy('/vault/a/copy.bin');
    await again.flush();
    final third = await reopen(store, MemoryWebWal());
    expect(third.file('/vault/a/big.bin').existsSync(), isFalse);
    expect(await third.file('/vault/a/moved.bin').readAsBytes(), bytes(700 * 1024, 5));
    expect(await third.file('/vault/a/copy.bin').readAsBytes(), bytes(700 * 1024, 5));
  });

  test('File и Directory из dart:io отдают файлы этой системы', () async {
    await IOOverrides.runWithIOOverrides(() async {
      await Directory('/vault/x').create(recursive: true);
      File('/vault/x/n.md').writeAsStringSync('через dart:io');
      expect(FileSystemEntity.typeSync('/vault/x/n.md'), FileSystemEntityType.file);
      expect((await FileStat.stat('/vault/x/n.md')).size, utf8.encode('через dart:io').length);
      expect(Directory.systemTemp.path, isNot(startsWith('/vault')));
    }, WebIOOverrides(fs));
    await fs.flush();
    expect(utf8.decode(await store.read('/vault/x/n.md')), 'через dart:io');
  });
}
