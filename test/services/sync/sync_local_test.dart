import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_db_state.dart';
import 'package:stowa/services/sync/sync_disk.dart';
import 'package:stowa/services/sync/sync_engine.dart';
import 'package:stowa/services/sync/sync_progress.dart';
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_sync.dart';
import 'package:stowa/services/vault/vault_writer.dart';

import 'fakes.dart';

/// Телефон: своя база, своя папка хранилища, общий сервер и ключ.
class Phone {
  Phone(FakeRemote remote, VaultKey key) {
    final reader = VaultReader(db, root: root, clock: DateTime.now);
    engine = SyncEngine(vault: DiskSyncFiles(root), remote: remote, state: DbSyncState(db), key: key, exclusive: reader.exclusively, onProgress: steps.add);
    vault = VaultSync(
      reader: reader,
      writer: VaultWriter(db, root: root, clock: DateTime.now),
      remote: () async {
        last = await engine.sync();
        return last!.received;
      },
      onProgress: steps.add,
    );
  }

  final db = AppDatabase.memory();
  final root = Directory.systemTemp.createTempSync('stowa_sync_phone');
  late final SyncEngine engine;
  late final VaultSync vault;
  SyncReport? last;

  /// Ход полного прохода, как его видит экран; null — проход кончился.
  final steps = <SyncProgress?>[];

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

  test('полный проход идёт этапами: папка, приём, отправка, заметки — и гаснет в конце', () async {
    final now = DateTime.now();
    await a.db.into(a.db.items).insert(ItemsCompanion.insert(id: 'n1', kind: ItemKind.note, title: 'Идеи', body: const Value('Идеи\nс первого телефона'), createdAt: now, updatedAt: now));
    await a.vault.run();
    await b.vault.run();
    final stages = <SyncStage>[];
    for (final step in b.steps.whereType<SyncProgress>()) {
      if (stages.isEmpty || stages.last != step.stage) stages.add(step.stage);
    }
    expect(stages, [SyncStage.folder, SyncStage.receive, SyncStage.send, SyncStage.place]);
    final placed = b.steps.whereType<SyncProgress>().lastWhere((step) => step.stage == SyncStage.place);
    expect(placed.done, placed.total);
    expect(b.steps.last, isNull);
    // своё ушло, а принимать на первом телефоне нечего: раскладки нет
    expect(a.steps.whereType<SyncProgress>().map((step) => step.stage).toSet(), {SyncStage.folder, SyncStage.receive, SyncStage.send});
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

  test('два телефона: метки и заметка из Obsidian доезжают до баз, потом телефоны затихают', () async {
    final now = DateTime.now();
    await a.db.into(a.db.items).insert(ItemsCompanion.insert(id: 'n1', kind: ItemKind.note, title: 'Список', body: const Value('Список'), createdAt: now, updatedAt: now));
    await a.db.into(a.db.tags).insert(TagsCompanion.insert(id: 't-a', name: 'дом', createdAt: now));
    await a.vault.run();
    await b.vault.run();
    // метка первого — в базе второго; второй заводит свою и кладёт заметку из Obsidian
    expect((await b.db.select(b.db.tags).get()).map((t) => t.name), contains('дом'));
    await b.db.into(b.db.tags).insert(TagsCompanion.insert(id: 't-b', name: 'работа', createdAt: now));
    File(p.join(b.root.path, 'Из Obsidian.md')).writeAsStringSync('Купить хлеб\n');
    await b.vault.run();
    await a.vault.run();
    expect((await a.db.select(a.db.tags).get()).map((t) => t.name).toSet(), {'дом', 'работа'});
    expect(await a.byTitle('Из Obsidian'), isNotNull);
    expect((await b.db.select(b.db.tags).get()).map((t) => t.name).toSet(), {'дом', 'работа'});

    // ещё круги, пока всё не разойдётся, и два последних — без единого файла туда и обратно
    for (var round = 0; round < 3; round++) {
      await a.vault.run();
      await b.vault.run();
    }
    for (var round = 0; round < 2; round++) {
      for (final phone in [a, b]) {
        await phone.vault.run();
        expect(phone.last!.pushed + phone.last!.received.length, 0, reason: 'круг $round: ${phone.last}');
      }
    }
    // временные файлы движка и писателя не уезжают и не остаются
    for (final phone in [a, b]) {
      final names = Directory(phone.root.path).listSync(recursive: true).map((e) => p.basename(e.path));
      expect(names.where((n) => n.endsWith('.tmp')), isEmpty);
    }
  });

  test('файл с именем в 248 байт доезжает: временный файл приёма не длиннее предела', () async {
    const name = 'Семинар №1. Морально-этические основы профессиональной деятельности. Предпосылки возникновения этики. Моральная концепция буддизма.md';
    File(p.join(a.root.path, name)).writeAsStringSync('конспект\n');
    await a.vault.run();
    await b.vault.run();
    expect(b.last!.error, isNull);
    expect(File(p.join(b.root.path, name)).readAsStringSync(), contains('конспект'));
  });

  test('схема 21 → 22: таблицы синхронизации появляются, данные на месте', () async {
    final file = File(p.join(a.root.path, '..', 'migrate_${DateTime.now().microsecondsSinceEpoch}.db'));
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    final old = AppDatabase(NativeDatabase(file));
    final now = DateTime.now();
    await old.into(old.items).insert(ItemsCompanion.insert(id: 'x', kind: ItemKind.note, title: 'Старая', body: const Value('Старая'), createdAt: now, updatedAt: now));
    // как будто база осталась от версии со схемой 21
    await old.customStatement('DROP TABLE sync_entries');
    await old.customStatement('DROP TABLE sync_shadows');
    await old.customStatement('PRAGMA user_version = 21');
    await old.close();
    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect((await upgraded.select(upgraded.items).getSingle()).title, 'Старая');
    await upgraded.into(upgraded.syncEntries).insert(SyncEntriesCompanion.insert(file: 'f', path: 'a.md', rev: 1, hash: 'h', size: 1, mtime: 1));
    await upgraded.into(upgraded.syncShadows).insert(SyncShadowsCompanion.insert(file: 'f', body: 'текст'));
    expect(await upgraded.select(upgraded.syncEntries).get(), hasLength(1));
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
