import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/json_canvas.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/vault/canvas_attachments.dart';
import 'package:stowa/services/vault/vault_layout.dart';
import 'package:stowa/services/vault/vault_reader.dart';

// хозяин 22.11: «Я создал холст, 2 фото загрузил в него… Мне не надо фото видеть всё, что я
// загрузил в холст, а сам холст» — картинка холста ложится его вложением, как в Obsidian
void main() {
  late AppDatabase db;
  late Directory root;
  late CanvasAttachments attachments;
  final now = DateTime(2026, 11, 22, 19, 52);

  setUp(() {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_canvas_files');
    attachments = CanvasAttachments(db, root: root);
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  test('без выбора места — рядом с холстом, с выбором — в общей папке; файл целиком на месте', () async {
    final near = await attachments.pathFor('Дом/Мышки.canvas', 'IMG-20261122-195200.png');
    expect(near, 'Дом/IMG-20261122-195200.png');
    await attachments.write(near, Uint8List.fromList([1, 2, 3]));
    expect(File(p.join(root.path, 'Дом', 'IMG-20261122-195200.png')).readAsBytesSync(), [1, 2, 3]);
    writeAttachmentSetting(root, 'Вложения');
    expect(await attachments.pathFor('Дом/Мышки.canvas', 'IMG-20261122-195201.png'), 'Вложения/IMG-20261122-195201.png');
  });

  test('имя свободное: занятое на диске или вложением заметки получает номер', () async {
    writeAttachmentSetting(root, 'Вложения');
    File(p.join(root.path, 'Вложения', 'мышь.png'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);
    expect(await attachments.pathFor('Мышки.canvas', 'мышь.png'), 'Вложения/мышь 2.png');
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'n', kind: ItemKind.image, title: 'Коврик', createdAt: now, updatedAt: now));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'f', itemId: 'n', path: 'Фото/коврик.png', mime: 'image/png', size: 1));
    expect(await attachments.pathFor('Мышки.canvas', 'Коврик.png'), 'Вложения/Коврик 2.png');
  });

  test('картинка холста — не отдельная заметка: читатель хранилища её не заводит', () async {
    writeAttachmentSetting(root, 'Вложения');
    final path = await attachments.pathFor('Мышки.canvas', 'IMG-20261122-195200.png');
    final doc = CanvasDoc.empty().addFile(path, x: 0, y: 0, width: 320, height: 240);
    File(p.join(root.path, 'Мышки.canvas')).writeAsStringSync(doc.encode());
    await attachments.write(path, Uint8List.fromList([137, 80, 78, 71]));
    await VaultReader(db, root: root, clock: () => now).reconcile();
    final items = await db.select(db.items).get();
    expect(items.map((item) => (item.kind, item.title)), [(ItemKind.canvas, 'Мышки')]);
    expect(CanvasDoc.parse(items.single.document!).nodes.single.file, 'Вложения/IMG-20261122-195200.png');
    // заметку холста ещё раз — и снова только он
    await VaultReader(db, root: root, clock: () => now).reconcile();
    expect(await db.select(db.items).get(), hasLength(1));
  });
}
