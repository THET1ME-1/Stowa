import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/core/fs/web_fs.dart';
import 'package:stowa/core/fs/web_store.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_db_state.dart';
import 'package:stowa/services/sync/sync_disk.dart';
import 'package:stowa/services/sync/sync_engine.dart';
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_sync.dart';
import 'package:stowa/services/vault/vault_writer.dart';

import '../../services/sync/fakes.dart';

/// Телефонный код хранилища и синхронизации без правок, но файлы — браузерные.
class Tab {
  Tab(this.fs, FakeRemote remote, VaultKey key) {
    root = Directory('/vault')..createSync(recursive: true);
    final reader = VaultReader(db, root: root, clock: DateTime.now);
    engine = SyncEngine(vault: DiskSyncFiles(root), remote: remote, state: DbSyncState(db), key: key, exclusive: reader.exclusively);
    vault = VaultSync(
      reader: reader,
      writer: VaultWriter(db, root: root, clock: DateTime.now),
      remote: () async {
        last = await engine.sync();
        return last!.received;
      },
    );
  }

  final WebFileSystem fs;
  final db = AppDatabase.memory();
  late final Directory root;
  late final SyncEngine engine;
  late final VaultSync vault;
  SyncReport? last;

  Future<Item?> byTitle(String title) => (db.select(db.items)..where((t) => t.title.equals(title))).getSingleOrNull();
}

void main() {
  test('заметка пишется файлом, уходит синхронизацией и доживает до нового открытия вкладки', () async {
    final remote = FakeRemote();
    final key = VaultKey.generate();
    final storeA = MemoryWebStore();
    final fsA = WebFileSystem(storeA, wal: MemoryWebWal());
    await fsA.hydrate();
    final fsB = WebFileSystem(MemoryWebStore(), wal: MemoryWebWal());
    await fsB.hydrate();

    final a = IOOverrides.runWithIOOverrides(() => Tab(fsA, remote, key), WebIOOverrides(fsA));
    final b = IOOverrides.runWithIOOverrides(() => Tab(fsB, remote, key), WebIOOverrides(fsB));
    addTearDown(() async {
      await a.db.close();
      await b.db.close();
    });

    final now = DateTime.now();
    await IOOverrides.runWithIOOverrides(() async {
      await a.db.into(a.db.items).insert(ItemsCompanion.insert(id: 'n1', kind: ItemKind.note, title: 'Идеи', body: const Value('Идеи\nиз браузера'), createdAt: now, updatedAt: now));
      await a.vault.run();
      expect(a.last!.error, isNull);
      expect(a.last!.pushed, greaterThan(0));
      expect(File('/vault/Идеи.md').readAsStringSync(), contains('из браузера'));
    }, WebIOOverrides(fsA));

    await IOOverrides.runWithIOOverrides(() async {
      await b.vault.run();
      expect((await b.byTitle('Идеи'))!.body, contains('из браузера'));
      // правка во второй вкладке возвращается в первую
      final there = (await b.byTitle('Идеи'))!;
      await (b.db.update(b.db.items)..where((t) => t.id.equals(there.id))).write(ItemsCompanion(body: const Value('Идеи\nправка'), updatedAt: Value(DateTime.now())));
      await b.vault.run();
    }, WebIOOverrides(fsB));

    await IOOverrides.runWithIOOverrides(() async {
      await a.vault.run();
      expect((await a.byTitle('Идеи'))!.body, contains('правка'));
      // временных файлов приёма не осталось
      final names = Directory('/vault').listSync(recursive: true).map((e) => p.basename(e.path));
      expect(names.where((n) => n.endsWith('.tmp')), isEmpty);
    }, WebIOOverrides(fsA));

    // вкладку закрыли и открыли: всё из хранилища браузера
    await fsA.flush();
    final reopened = WebFileSystem(storeA, wal: MemoryWebWal());
    await reopened.hydrate();
    expect(reopened.file('/vault/Идеи.md').readAsStringSync(), contains('правка'));
    List<String> listing(WebFileSystem fs) => [for (final entity in fs.directory('/vault').listSync(recursive: true)) entity.path]..sort();
    expect(listing(reopened), listing(fsA));
  });
}
