import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';

void main() {
  test('база версии 1 открывается: поля превью добавлены, вещи на месте', () async {
    final dir = Directory.systemTemp.createTempSync('stowa_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/stowa.sqlite');
    final now = DateTime(2026, 11, 3);

    // новая база, из которой убраны поля версии 2 — так выглядит база с телефона до обновления
    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'old', kind: ItemKind.link, title: 'Старая', url: const Value('https://a.b'), createdAt: now, updatedAt: now));
    await fresh.close();
    final raw = sqlite3.open(file.path);
    for (final column in ['cover_path', 'preview_text', 'preview_site', 'preview_author', 'duration_seconds', 'preview_at']) {
      raw.execute('ALTER TABLE items DROP COLUMN $column');
    }
    for (final column in ['latitude', 'longitude', 'place_name']) {
      raw.execute('ALTER TABLE items DROP COLUMN $column');
    }
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final old = await upgraded.select(upgraded.items).getSingle();
    expect(old.title, 'Старая');
    expect(old.previewAt, isNull);
    await (upgraded.update(upgraded.items)..where((t) => t.id.equals('old'))).write(const ItemsCompanion(previewSite: Value('a.b')));
    expect((await upgraded.select(upgraded.items).getSingle()).previewSite, 'a.b');
  });

  test('база версии 2 открывается: у вещей появилось место', () async {
    final dir = Directory.systemTemp.createTempSync('stowa_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/stowa.sqlite');
    final now = DateTime(2026, 11, 3);

    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'old', kind: ItemKind.note, title: 'Старая', createdAt: now, updatedAt: now));
    await fresh.close();
    final raw = sqlite3.open(file.path);
    for (final column in ['latitude', 'longitude', 'place_name']) {
      raw.execute('ALTER TABLE items DROP COLUMN $column');
    }
    raw.execute('PRAGMA user_version = 2');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await (upgraded.update(upgraded.items)..where((t) => t.id.equals('old'))).write(
      const ItemsCompanion(latitude: Value(47.02), longitude: Value(28.83), placeName: Value('Кишинёв')),
    );
    final old = await upgraded.select(upgraded.items).getSingle();
    expect(old.title, 'Старая');
    expect(old.placeName, 'Кишинёв');
  });
}
