import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_writer.dart';

/// Сверка папки и запись файлов идут в одном приложении разом. 24.11.2026 с быстрым ИИ
/// заметки двоились «Приложение Kadr (Stowa)»: правка модели ложилась посреди сверки,
/// писатель записывал файл, а сверка принимала эту запись за правку снаружи.
void main() {
  late AppDatabase db;
  late Directory root;
  late VaultReader reader;
  late VaultWriter writer;
  final now = DateTime(2026, 11, 24, 12, 31);

  setUp(() async {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_race');
    reader = VaultReader(db, root: root, clock: () => now);
    writer = VaultWriter(db, root: root, clock: () => now);
    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Приложение Kadr', body: const Value('Приложение Kadr.\nСделать адаптив'), createdAt: now, updatedAt: now),
    );
    await reader.reconcile();
    await writer.drain();
  });

  tearDown(() async {
    writer.dispose();
    await db.close();
    root.deleteSync(recursive: true);
  });

  Future<List<String>> titles() async => [for (final item in await (db.select(db.items)..where((t) => t.deletedAt.isNull())).get()) item.title]..sort();

  test('писатель держит заметку, сверка ждёт его, а не делает копию «(Stowa)»', () async {
    // модель разложила заметку: правка в базе ждёт записи
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(const ItemsCompanion(body: Value('Приложение Kadr.\nСделать адаптив под телефон')));
    // писатель другой копии приложения взял задачу и уже положил файл, но карту файлов
    // ещё не обновил — ровно этот миг видела сверка
    await db.customStatement("UPDATE vault_queue SET claimed_until = ${now.add(const Duration(seconds: 15)).millisecondsSinceEpoch} WHERE target = 'item:a'");
    final file = File(p.join(root.path, 'Приложение Kadr.md'));
    final ours = file.readAsStringSync().replaceFirst('Сделать адаптив', 'Сделать адаптив под телефон');
    file.writeAsStringSync(ours);
    file.setLastModifiedSync(now.add(const Duration(seconds: 2)));

    final scan = reader.reconcile();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    // писатель дописал: карта файлов знает его файл, задача снята
    final stat = file.statSync();
    await db.customStatement("UPDATE vault_files SET modified = ${stat.modified.millisecondsSinceEpoch}, size = ${stat.size} WHERE item_id = 'a'");
    await db.customStatement("DELETE FROM vault_queue WHERE target = 'item:a'");
    final result = await scan;

    expect(result.conflicts, 0);
    expect(await titles(), ['Приложение Kadr']);
  });

  test('пока идёт сверка, писатель заметки не пишет и возвращается после неё', () async {
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(const ItemsCompanion(body: Value('Приложение Kadr.\nправка модели')));
    final file = File(p.join(root.path, 'Приложение Kadr.md'));
    final opened = Completer<void>();
    final release = Completer<void>();
    final scan = reader.withoutScans((keep) async {
      opened.complete();
      await release.future;
    });
    await opened.future;
    await writer.drain();
    expect(file.readAsStringSync(), isNot(contains('правка модели')));
    release.complete();
    await scan;
    // писатель вернулся сам, без нового вызова
    for (var tries = 0; tries < 40 && !file.readAsStringSync().contains('правка модели'); tries++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(file.readAsStringSync(), contains('правка модели'));
    expect(await titles(), ['Приложение Kadr']);
  });
}
