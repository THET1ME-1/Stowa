import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart' show VaultMode;
import 'package:stowa/domain/known_vaults.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/vault/vault_switch.dart';

void main() {
  late Directory root;
  final now = DateTime(2026, 11, 13, 10);
  final opened = <String, AppDatabase>{};

  AppDatabase open(String name) => opened[name] ??= AppDatabase.memory();

  setUp(() => root = Directory.systemTemp.createTempSync('stowa_switch'));
  tearDown(() async {
    for (final db in opened.values) {
      await db.close();
    }
    opened.clear();
    root.deleteSync(recursive: true);
  });

  void put(String relative, String text) => File(p.join(root.path, relative))
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  KnownVault target() => KnownVault(path: root.path, mode: VaultMode.device, db: 'stowa-x');

  test('пустая база хранилища с заметками в папке собирается из папки', () async {
    put('Дом/Купить плитку.md', 'Купить плитку\nи клей');
    put('Идеи.md', 'Идея');
    var reported = false;
    final db = await prepareVaultDatabase(target(), open: open, clock: () => now, progress: (done, total) => reported = true);
    final titles = [for (final item in await db.select(db.items).get()) item.title]..sort();
    expect(titles, ['Идеи', 'Купить плитку']);
    expect((await db.select(db.folders).get()).single.name, 'Дом');
    expect(reported, isTrue);
  });

  test('знакомая база не пересобирается: открывается как есть', () async {
    final known = open('stowa-x');
    await known.into(known.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Своя', body: const Value('Своя'), createdAt: now, updatedAt: now));
    put('Новая снаружи.md', 'Новая снаружи');
    final db = await prepareVaultDatabase(target(), open: open, clock: () => now);
    expect(identical(db, known), isTrue);
    expect([for (final item in await db.select(db.items).get()) item.title], ['Своя']);
  });

  test('пустая папка — пустая база без сборки', () async {
    final db = await prepareVaultDatabase(target(), open: open, clock: () => now);
    expect(await db.select(db.items).get(), isEmpty);
  });

  test('заметки в папке ищутся без служебного .stowa', () async {
    put('.stowa/history/x.md', 'не заметка');
    expect(await folderHasNotes(root), isFalse);
    put('Заметка.md', 'Заметка');
    expect(await folderHasNotes(root), isTrue);
    expect(await folderHasNotes(Directory(p.join(root.path, 'нет такой'))), isFalse);
  });
}
