import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/vault/vault_watch.dart';
import 'package:stowa/services/vault/vault_writer.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late VaultWatch watch;
  late int changes;
  final now = DateTime(2026, 11, 6, 10);

  setUp(() async {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_watch');
    Directory(p.join(root.path, 'Рецепты')).createSync();
    changes = 0;
    watch = VaultWatch(db, root: root, onChange: () async => changes++, settle: const Duration(milliseconds: 100));
  });
  tearDown(() async {
    await watch.stop();
    await db.close();
    root.deleteSync(recursive: true);
  });

  // ждём, пока слежка увидит событие и выждет тишину
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 600));

  test('файл, изменённый снаружи, вызывает сверку без перезапуска, и в папке тоже', () async {
    watch.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    File(p.join(root.path, 'Идеи.md')).writeAsStringSync('новое');
    await settle();
    expect(changes, 1);
    File(p.join(root.path, 'Рецепты', 'Борщ.md')).writeAsStringSync('свёкла');
    await settle();
    expect(changes, 2);
  });

  test('своя запись сверку не вызывает', () async {
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Идеи', body: const Value('Идеи'), createdAt: now, updatedAt: now));
    watch.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await VaultWriter(db, root: root, clock: () => now).drain();
    await settle();
    expect(changes, 0);
  });

  test('новая папка верхнего уровня тоже под слежкой; служебное — нет', () async {
    watch.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    Directory(p.join(root.path, 'Сад')).createSync();
    await settle();
    File(p.join(root.path, 'Сад', 'Грядки.md')).writeAsStringSync('чеснок');
    await settle();
    expect(changes, 1);
    Directory(p.join(root.path, '.stowa')).createSync();
    File(p.join(root.path, '.stowa', 'tags.json')).writeAsStringSync('{}');
    await settle();
    expect(changes, 1);
  });

  test('вложенные папки под слежкой: и готовые, и новые; каталог вложений — нет', () async {
    Directory(p.join(root.path, 'Рецепты', 'Супы')).createSync();
    File(p.join(root.path, 'Рецепты', 'Борщ.md')).writeAsStringSync('свёкла');
    Directory(p.join(root.path, 'Рецепты', 'Борщ')).createSync();
    watch.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    File(p.join(root.path, 'Рецепты', 'Супы', 'Щи.md')).writeAsStringSync('капуста');
    await settle();
    expect(changes, 1);
    Directory(p.join(root.path, 'Рецепты', 'Супы', 'Холодные')).createSync();
    await settle();
    File(p.join(root.path, 'Рецепты', 'Супы', 'Холодные', 'Окрошка.md')).writeAsStringSync('квас');
    await settle();
    expect(changes, 2);
    expect(watch.watched, isNot(contains(p.join(root.path, 'Рецепты', 'Борщ'))));
  });
}
