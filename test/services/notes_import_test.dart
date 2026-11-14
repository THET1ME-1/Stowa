import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/services/capture_service.dart';
import 'package:stowa/services/notes_import.dart';

void main() {
  late AppDatabase db;
  late Directory home;
  late Directory export;
  late CaptureService capture;
  late NotesImport import;

  setUp(() async {
    db = AppDatabase.memory();
    home = await Directory.systemTemp.createTemp('stowa_home');
    export = await Directory.systemTemp.createTemp('stowa_export');
    capture = CaptureService(db, tags: TagsRepository(db), filesRoot: home, clock: () => DateTime(2026, 11, 14, 12));
    import = NotesImport(db, capture);
  });

  tearDown(() async {
    await capture.settled();
    await db.close();
    await home.delete(recursive: true);
    await export.delete(recursive: true);
  });

  Future<File> write(String relative, String text) async {
    final file = File(p.join(export.path, relative));
    await file.parent.create(recursive: true);
    return file.writeAsString(text);
  }

  Future<List<Item>> notes() => (db.select(db.items)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  group('Google Keep', () {
    const created = 1683885600000000;

    test('заметки с датой Keep, ярлыки — теги, закреплённая закреплена, картинка .jpeg находится как .jpg', () async {
      await write(
        'Takeout/Keep/Борщ.json',
        jsonEncode({
          'title': 'Борщ',
          'textContent': 'свёкла',
          'labels': [
            {'name': 'Рецепты'},
          ],
          'createdTimestampUsec': created,
        }),
      );
      await write(
        'Takeout/Keep/Море.json',
        jsonEncode({
          'textContent': 'море',
          'isPinned': true,
          'attachments': [
            {'filePath': '1a2b.jpeg', 'mimetype': 'image/jpeg'},
          ],
          'createdTimestampUsec': created + 3600000000,
        }),
      );
      await write('Takeout/Keep/Старое.json', jsonEncode({'textContent': 'удалено', 'isTrashed': true, 'createdTimestampUsec': created}));
      await File(p.join(export.path, 'Takeout/Keep/1a2b.jpg')).writeAsBytes(List.filled(2048, 1));
      await write('Takeout/Keep/Labels.txt', 'Рецепты');

      final steps = <(int, int)>[];
      final report = await import.run(ImportSource.keep, export.path, progress: (done, total) => steps.add((done, total)));
      await capture.settled();

      expect((report.added, report.repeated, report.filesMissing), (2, 0, 0));
      expect(steps.last, (2, 2));
      final [borsch, sea] = await notes();
      expect(borsch.createdAt, DateTime.fromMicrosecondsSinceEpoch(created));
      expect(borsch.body, 'Борщ\nсвёкла');
      expect((await ItemsRepository(db).get(borsch.id))!.tags.keys, contains('рецепты'));
      expect(sea.pinnedAt, isNotNull);
      expect((await ItemsRepository(db).get(sea.id))!.attachments.single.mime, 'image/jpeg');
    });

    test('повторный перенос не двоит', () async {
      await write('Keep/a.json', jsonEncode({'textContent': 'купить кофе', 'createdTimestampUsec': created}));
      await import.run(ImportSource.keep, export.path);
      final again = await import.run(ImportSource.keep, export.path);
      expect((again.added, again.repeated), (0, 1));
      expect(await notes(), hasLength(1));
    });

    test('в папке нет заметок Keep — ошибка', () async {
      await write('result.json', jsonEncode({'name': 'Saved Messages', 'messages': []}));
      expect(() => import.run(ImportSource.keep, export.path), throwsA(isA<NotesImportError>()));
    });
  });

  test('закладки: ссылки с названием и датой, папка — тег', () async {
    final file = await write('bookmarks.html', '''
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<DL><p>
  <DT><H3 PERSONAL_TOOLBAR_FOLDER="true">Панель закладок</H3>
  <DL><p>
    <DT><H3>Рецепты</H3>
    <DL><p>
      <DT><A HREF="https://eda.ru/borsch" ADD_DATE="1683885600">Борщ бабушкин</A>
    </DL><p>
  </DL><p>
</DL>
''');
    final report = await import.run(ImportSource.bookmarks, file.path);
    expect(report.added, 1);
    final note = (await notes()).single;
    expect(note.title, 'Борщ бабушкин');
    expect(note.url, 'https://eda.ru/borsch');
    expect(note.createdAt, DateTime.fromMillisecondsSinceEpoch(1683885600 * 1000));
    expect((await ItemsRepository(db).get(note.id))!.tags.keys, contains('рецепты'));
  });

  test('закладки: чужой файл — ошибка', () async {
    final file = await write('page.html', '<html><body>Привет</body></html>');
    expect(() => import.run(ImportSource.bookmarks, file.path), throwsA(isA<NotesImportError>()));
  });

  group('Obsidian', () {
    test('файлы .md — заметки, подпапки — папки Stowa, картинка из текста — вложение, служебные папки мимо', () async {
      await write('Рецепты/Супы/Борщ.md', '---\ncreated: 2023-05-12T10:00:00\ntags: [еда]\n---\nСвёкла и капуста\n\n![[borsch.png]]\n');
      await write('Идеи.md', 'Заметки ссылаются друг на друга');
      await write('.obsidian/workspace.md', 'служебное');
      await File(p.join(export.path, 'Вложения', 'borsch.png')).create(recursive: true).then((file) => file.writeAsBytes(List.filled(1024, 3)));

      final report = await import.run(ImportSource.markdown, export.path);
      await capture.settled();

      expect(report.added, 2);
      final all = await notes();
      final borsch = all.firstWhere((note) => note.title == 'Борщ');
      expect(borsch.createdAt, DateTime(2023, 5, 12, 10));
      expect(borsch.body, contains('Свёкла и капуста'));
      final full = (await ItemsRepository(db).get(borsch.id))!;
      expect(full.tags.keys, contains('еда'));
      expect(full.attachments.single.mime, 'image/png');
      final folder = await (db.select(db.folders)..where((t) => t.id.equals(borsch.folderId!))).getSingle();
      expect(folder.name, 'Супы');
      final parent = await (db.select(db.folders)..where((t) => t.id.equals(folder.parentId!))).getSingle();
      expect(parent.name, 'Рецепты');
      expect(all.firstWhere((note) => note.title == 'Идеи').folderId, isNull);
    });

    test('та же папка Obsidian второй раз — папки не множатся, заметки не двоятся', () async {
      await write('Рецепты/Борщ.md', '---\ncreated: 2023-05-12T10:00:00\n---\nСвёкла');
      await import.run(ImportSource.markdown, export.path);
      final again = await import.run(ImportSource.markdown, export.path);
      expect((again.added, again.repeated), (0, 1));
      expect(await db.select(db.folders).get(), hasLength(1));
    });

    test('папка без .md — ошибка', () async {
      await write('a.txt', 'текст');
      expect(() => import.run(ImportSource.markdown, export.path), throwsA(isA<NotesImportError>()));
    });
  });

  test('mymind: карточки из cards.csv, файл по имени — вложение', () async {
    await write('cards.csv', 'title,url,content,tags,created,file\nБорщ,https://eda.ru/borsch,свёкла,рецепты,2023-05-12T10:00:00Z,\nМоре,,,,2023-05-13T10:00:00Z,sea.jpg\n');
    await File(p.join(export.path, 'sea.jpg')).writeAsBytes(List.filled(2048, 1));

    final report = await import.run(ImportSource.mymind, export.path);
    await capture.settled();

    expect(report.added, 2);
    final [borsch, sea] = await notes();
    expect(borsch.createdAt.isAtSameMomentAs(DateTime.utc(2023, 5, 12, 10)), isTrue);
    expect(borsch.url, 'https://eda.ru/borsch');
    expect((await ItemsRepository(db).get(sea.id))!.attachments.single.mime, 'image/jpeg');
  });

  test('mymind: нет cards.csv — ошибка', () async {
    expect(() => import.run(ImportSource.mymind, export.path), throwsA(isA<NotesImportError>()));
  });
}
