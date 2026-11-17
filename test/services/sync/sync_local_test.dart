import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_db_state.dart';
import 'package:stowa/services/sync/sync_disk.dart';
import 'package:stowa/services/sync/sync_engine.dart';
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_sync.dart';
import 'package:stowa/services/vault/vault_writer.dart';

import 'fakes.dart';

/// Телефон: своя база, своя папка хранилища, общий сервер и ключ.
class Phone {
  Phone(FakeRemote remote, VaultKey key) {
    final reader = VaultReader(db, root: root, clock: DateTime.now);
    engine = SyncEngine(vault: DiskSyncFiles(root), remote: remote, state: DbSyncState(db), key: key, exclusive: reader.exclusively, heartbeat: reader.keepLease);
    vault = VaultSync(
      reader: reader,
      writer: VaultWriter(db, root: root, clock: DateTime.now),
      remote: () async {
        last = await engine.sync();
        return last!.pulled + last!.merged + last!.deleted > 0;
      },
    );
  }

  final db = AppDatabase.memory();
  final root = Directory.systemTemp.createTempSync('stowa_sync_phone');
  late final SyncEngine engine;
  late final VaultSync vault;
  SyncReport? last;

  Future<Item?> byTitle(String title) => (db.select(db.items)..where((t) => t.title.equals(title))).getSingleOrNull();

  Future<void> dispose() async {
    await db.close();
    root.deleteSync(recursive: true);
  }
}

void main() {
  late FakeRemote remote;
  late VaultKey key;
  late Phone a, b;

  setUp(() {
    remote = FakeRemote();
    key = VaultKey.generate();
    a = Phone(remote, key);
    b = Phone(remote, key);
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  test('заметка с одного телефона появляется в базе другого, правка возвращается', () async {
    final now = DateTime.now();
    await a.db.into(a.db.items).insert(ItemsCompanion.insert(id: 'n1', kind: ItemKind.note, title: 'Идеи', body: const Value('Идеи\nс первого телефона'), createdAt: now, updatedAt: now));
    await a.vault.run();
    expect(a.last!.error, isNull);
    expect(a.last!.pushed, greaterThan(0));

    await b.vault.run();
    final there = await b.byTitle('Идеи');
    expect(there, isNotNull);
    expect(there!.body, contains('с первого телефона'));
    expect(File(p.join(b.root.path, 'Идеи.md')).existsSync(), isTrue);

    // правка на втором телефоне: в базе, писатель кладёт в файл, движок отправляет
    await (b.db.update(b.db.items)..where((t) => t.id.equals(there.id))).write(ItemsCompanion(body: const Value('Идеи\nправка со второго'), updatedAt: Value(DateTime.now())));
    await b.vault.run();
    await a.vault.run();
    expect((await a.byTitle('Идеи'))!.body, contains('правка со второго'));
    expect(File(p.join(a.root.path, 'Идеи.md')).readAsStringSync(), contains('правка со второго'));
  });

  test('служебное хранилища доезжает: метка со второго телефона не теряется', () async {
    final now = DateTime.now();
    await a.db.into(a.db.items).insert(ItemsCompanion.insert(id: 'n1', kind: ItemKind.note, title: 'Список', body: const Value('Список'), createdAt: now, updatedAt: now));
    await a.vault.run();
    await b.vault.run();
    // временные файлы движка и писателя не уезжают
    final names = Directory(b.root.path).listSync(recursive: true).map((e) => p.basename(e.path));
    expect(names.where((n) => n.endsWith('.tmp')), isEmpty);
    expect(await b.db.select(b.db.syncEntries).get(), isNotEmpty);
  });

  test('после выхода память синхронизации стирается: следующий вход идёт как первый', () async {
    final now = DateTime.now();
    await a.db.into(a.db.items).insert(ItemsCompanion.insert(id: 'n1', kind: ItemKind.note, title: 'Идеи', body: const Value('Идеи'), createdAt: now, updatedAt: now));
    // курсор сдвигается при приёме: второй проход забирает своё же эхо
    await a.vault.run();
    await a.vault.run();
    final state = DbSyncState(a.db);
    expect(await state.cursor(), greaterThan(0));
    expect(await state.files(), isNotEmpty);
    await state.clear();
    expect(await state.cursor(), 0);
    expect(await state.files(), isEmpty);
  });
}
