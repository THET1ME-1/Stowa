import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/documents_repository.dart';
import 'package:stowa/data/repositories/folders_repository.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/data/repositories/smart_folders_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/capture_service.dart';
import 'package:stowa/services/panel_bridge.dart';
import 'package:stowa/services/panel_db.dart';
import 'package:stowa/services/panel_writes.dart';

// STOWA-9: строка телефона в панели пишет через вкладку — у панели база только на чтение
void main() {
  late AppDatabase tab;
  late Directory root;
  late CaptureService capture;
  late PanelBridge bridge;
  late bool locked;
  var serial = 0;

  setUp(() async {
    tab = AppDatabase.memory();
    root = await Directory.systemTemp.createTemp('panel-writes');
    locked = false;
    capture = CaptureService(tab, tags: TagsRepository(tab), filesRoot: Directory(p.join(root.path, 'vault')));
    final items = ItemsRepository(tab);
    bridge = PanelBridge(
      link: PanelLink(),
      locked: () => locked,
      capture: (text) async => (id: await capture.capture(CaptureInput(text: text)), folder: null),
      undo: (id) => items.softDelete(id, DateTime.now()),
      search: (query) async => const [],
      open: (_) {},
      database: PanelDbServer(tab),
      schema: tab.schemaVersion,
      writes: PanelWrites(
        captureAll: (inputs) async {
          final ids = await capture.captureAll(inputs);
          await capture.settled();
          return ids;
        },
        append: (id, text) => items.append(id, text, DateTime.now()),
        makeFolder: (name, parent) => FoldersRepository(tab).create(name, parentId: parent),
        makeSmartFolder: (name, query) => SmartFoldersRepository(tab).create(name: name, query: query),
        makeDocument: (kind, title, folder) => DocumentsRepository(tab).create(kind, title: title, folderId: folder),
        placeFile: (name, bytes) async {
          final file = File(p.join(root.path, 'cache', '${serial++}-$name'));
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes);
          return file.path;
        },
      ),
    )..start();
  });
  tearDown(() async {
    bridge.stop();
    await tab.close();
    await root.delete(recursive: true);
  });

  Future<({PanelClient client, AppDatabase db})> panel() async {
    final client = PanelClient(PanelLink());
    addTearDown(client.close);
    final hello = await client.ask('hello');
    expect(hello?['schema'], tab.schemaVersion);
    final name = 'stowa-db-writes-${serial++}';
    expect((await client.ask('db-open', payload: {'channel': name, 'schema': tab.schemaVersion}))?['type'], 'db-ready');
    final db = await openPanelDb(name);
    addTearDown(db.close);
    return (client: client, db: db);
  }

  test('«Закинуть» в панели сохраняет вкладка — с тегом и в папку, как строка', () async {
    final (:client, :db) = await panel();
    final folder = await PanelFoldersRepository(db, client).create('книги');
    expect(folder.name, 'Книги');
    final service = PanelCaptureService(db, client, filesRoot: Directory(p.join(root.path, 'panel')));
    final id = await service.capture(CaptureInput(text: 'Прочитать «Пикник на обочине»', forcedFolderId: folder.id, forcedTagNames: const ['фантастика']));
    final row = await (tab.select(tab.items)..where((t) => t.id.equals(id))).getSingle();
    expect(row.title, contains('Пикник'));
    expect(row.folderId, folder.id);
    expect((await tab.select(tab.tags).get()).map((tag) => tag.name), contains('фантастика'));
  });

  test('вложение из панели едет байтами и ложится файлом заметки во вкладке', () async {
    final (:client, :db) = await panel();
    final picked = File(p.join(root.path, 'panel', 'photo.png'));
    await picked.parent.create(recursive: true);
    final bytes = Uint8List.fromList(List.generate(300, (index) => index % 256));
    await picked.writeAsBytes(bytes);
    final id = await PanelCaptureService(db, client, filesRoot: Directory(p.join(root.path, 'panel'))).capture(
      CaptureInput(files: [PickedFile(path: picked.path, mime: 'image/png', size: bytes.length, name: 'photo.png')]),
    );
    final attachment = await (tab.select(tab.attachments)..where((t) => t.itemId.equals(id))).getSingle();
    final stored = File(p.isAbsolute(attachment.path) ? attachment.path : p.join(root.path, 'vault', attachment.path));
    expect(await stored.readAsBytes(), bytes);
  });

  test('«Дописать», «Отменить», холст и умная папка из панели — во вкладке', () async {
    final (:client, :db) = await panel();
    final id = await capture.capture(const CaptureInput(text: 'Список покупок'));
    await PanelItemsRepository(db, client).append(id, 'молоко', DateTime.now());
    expect((await (tab.select(tab.items)..where((t) => t.id.equals(id))).getSingle()).body, contains('молоко'));
    final canvas = await PanelDocumentsRepository(db, client).create(ItemKind.canvas, title: 'План');
    expect((await (tab.select(tab.items)..where((t) => t.id.equals(canvas))).getSingle()).kind, ItemKind.canvas);
    final smart = await PanelSmartFoldersRepository(db, client).create(name: 'Шины', query: 'шины');
    expect((await tab.select(tab.smartFolders).get()).single.id, smart);
    await PanelItemsRepository(db, client).softDelete(id, DateTime.now());
    expect((await (tab.select(tab.items)..where((t) => t.id.equals(id))).getSingle()).deletedAt, isNotNull);
  });

  test('«Код на вход»: вкладка базу не отдаёт, включили код — панели узнают сразу', () async {
    final client = PanelClient(PanelLink());
    addTearDown(client.close);
    final events = <String>[];
    final listening = client.link.messages.listen((message) => events.add('${message['type']}'));
    addTearDown(listening.cancel);
    locked = true;
    expect((await client.ask('hello'))?['schema'], isNull);
    expect((await client.ask('db-open', payload: {'channel': 'stowa-db-locked', 'schema': tab.schemaVersion}))?['type'], 'db-refused');
    bridge.lockChanged();
    await pumpEventQueue();
    expect(events, contains('locked'));
  });
}
