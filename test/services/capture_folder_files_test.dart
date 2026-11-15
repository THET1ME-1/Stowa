import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/features/composer/picked_files.dart';
import 'package:stowa/services/capture_service.dart';
import 'package:stowa/services/vault/vault_writer.dart';

// жалоба 15.11: в папке закидывается одна фотка из трёх выбранных
void main() {
  late AppDatabase db;
  late Directory root;
  late Directory gallery;
  late CaptureService capture;
  final now = DateTime(2026, 11, 15, 12);

  setUp(() async {
    db = AppDatabase.memory();
    root = await Directory.systemTemp.createTemp('stowa_vault');
    gallery = await Directory.systemTemp.createTemp('stowa_gallery');
    capture = CaptureService(db, tags: TagsRepository(db), filesRoot: root, clock: () => now);
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'trip', name: 'Поездка', icon: 'folder', shape: 'squircle'));
  });
  tearDown(() async {
    await capture.settled();
    await db.close();
    await root.delete(recursive: true);
    await gallery.delete(recursive: true);
  });

  Future<List<PickedFile>> photos(List<String> names) async => [
    for (final (i, name) in names.indexed)
      await () async {
        final file = File(p.join(gallery.path, '$i', name));
        await file.create(recursive: true);
        await file.writeAsBytes(List.filled(1000 + i, i));
        return PickedFile(path: file.path, mime: 'image/jpeg', size: await file.length());
      }(),
  ];

  for (final folder in [null, 'trip']) {
    for (final names in [['a.jpg', 'b.jpg', 'c.jpg'], ['photo.jpg', 'photo.jpg', 'photo.jpg']]) {
      test('три фото ${folder == null ? 'без папки' : 'в папке'}, имена ${names.join(',')}: три вложения и три файла', () async {
        final id = await capture.capture(CaptureInput(files: await photos(names), forcedFolderId: folder));
        await capture.settled();
        await VaultWriter(db, root: root, clock: () => now).drain();
        final saved = (await ItemsRepository(db).get(id))!;
        expect(saved.attachments, hasLength(3));
        for (final one in saved.attachments) {
          expect(File(p.join(root.path, one.path)).existsSync(), isTrue, reason: one.path);
        }
        expect({for (final one in saved.attachments) one.path}, hasLength(3));
      });
    }
  }
}
