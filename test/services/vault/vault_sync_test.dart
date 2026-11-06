import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_sync.dart';
import 'package:stowa/services/vault/vault_writer.dart';

void main() {
  test('сверка: сперва забирает правку снаружи, потом пишет своё — обе версии целы', () async {
    final db = AppDatabase.memory();
    final root = Directory.systemTemp.createTempSync('stowa_vault');
    addTearDown(() async {
      await db.close();
      root.deleteSync(recursive: true);
    });
    final now = DateTime(2026, 11, 6, 10);
    final sync = VaultSync(reader: VaultReader(db, root: root, clock: () => now), writer: VaultWriter(db, root: root, clock: () => now));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Идеи', body: const Value('Идеи\nодин'), createdAt: now, updatedAt: now));
    await sync.run();
    final file = File(p.join(root.path, 'Идеи.md'));
    file.writeAsStringSync(file.readAsStringSync().replaceFirst('один', 'с компьютера'));
    file.setLastModifiedSync(DateTime.now().add(const Duration(minutes: 5)));
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(const ItemsCompanion(body: Value('Идеи\nв приложении')));
    await sync.run();
    expect(file.readAsStringSync(), contains('с компьютера'));
    final copy = File(p.join(root.path, 'Идеи (Stowa).md'));
    expect(copy.readAsStringSync(), contains('в приложении'));
    expect(await db.select(db.vaultQueue).get(), isEmpty);
  });
}
