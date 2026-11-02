import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/domain/search_rank.dart';
import 'package:stowa/services/capture_service.dart';

void main() {
  late AppDatabase db;
  late Directory home;
  late ItemsRepository items;
  final now = DateTime(2026, 11, 2, 12);

  setUp(() async {
    db = AppDatabase.memory();
    home = await Directory.systemTemp.createTemp('stowa_search');
    items = ItemsRepository(db);
    final capture = CaptureService(db, tags: TagsRepository(db), filesRoot: home, clock: () => now);
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'squircle'));
    await capture.capture(const CaptureInput(text: 'Пароль от Wi-Fi\nСеть Keenetic, пароль zelenyi-chai-77 #код', forcedFolderId: 'home'));
    await capture.capture(const CaptureInput(text: 'Код домофона: 4512 #код'));
    final voice = await capture.capture(const CaptureInput(text: 'Мама: пирог'));
    await (db.update(db.items)..where((t) => t.id.equals(voice))).write(const ItemsCompanion(transcript: Value('три яйца и стакан сахара')));
  });

  tearDown(() async {
    await db.close();
    await home.delete(recursive: true);
  });

  test('ищет по началу слова, отдаёт карточку с папкой и подсветкой', () async {
    final found = await items.search(words: ['паро'], now: now);
    expect(found.first.card.title, 'Пароль от Wi-Fi');
    expect(found.first.card.folderName, 'Дом');
    expect(found.first.hit.marks[SearchField.title], isNotEmpty);
  });

  test('опечатка находит', () async {
    final found = await items.search(words: ['домафона'], now: now);
    expect(found.single.card.title, 'Код домофона: 4512');
  });

  test('находит в расшифровке', () async {
    final found = await items.search(words: ['сахар'], now: now);
    expect(found.single.card.title, 'Мама: пирог');
    expect(found.single.hit.where, SearchField.deep);
  });

  test('чип тега без слов показывает вещи с тегом', () async {
    final found = await items.search(words: const [], tags: ['код'], now: now);
    expect(found, hasLength(2));
  });

  test('удалённое не находится', () async {
    final found = await items.search(words: ['домофона'], now: now);
    await items.softDelete(found.single.card.id, now);
    expect(await items.search(words: ['домофона'], now: now), isEmpty);
  });
}
