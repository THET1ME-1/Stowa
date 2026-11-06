import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/trash_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/page_cache.dart';

void main() {
  late AppDatabase db;
  late Directory home;
  late TrashRepository trash;
  final now = DateTime(2026, 11, 3, 12);

  setUp(() {
    db = AppDatabase.memory();
    home = Directory.systemTemp.createTempSync('stowa_trash');
    trash = TrashRepository(db, filesRoot: home);
  });
  tearDown(() async {
    await db.close();
    home.deleteSync(recursive: true);
  });

  Future<void> add(String id, {DateTime? deletedAt, String title = 'Вещь'}) async {
    await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.image, title: title, createdAt: now, updatedAt: now, deletedAt: Value(deletedAt), coverPath: Value('covers/$id.jpg')));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'f$id', itemId: id, path: 'attachments/$id/0_a.jpg', mime: 'image/jpeg', size: 3));
    File('${home.path}/attachments/$id/0_a.jpg')
      ..createSync(recursive: true)
      ..writeAsStringSync('jpg');
    File('${home.path}/covers/$id.jpg')
      ..createSync(recursive: true)
      ..writeAsStringSync('jpg');
  }

  test('в корзине только удалённое, свежее сверху', () async {
    await add('live');
    await add('old', deletedAt: now.subtract(const Duration(days: 2)), title: 'Старое');
    await add('new', deletedAt: now, title: 'Новое');
    final entries = await trash.watch().first;
    expect(entries.map((entry) => entry.title), ['Новое', 'Старое']);
    expect(entries.first.thumbPath, 'attachments/new/0_a.jpg');
    expect(await trash.watchCount().first, 2);
  });

  test('«Вернуть» достаёт вещь из корзины', () async {
    await add('a', deletedAt: now);
    await trash.restore('a');
    expect(await trash.watch().first, isEmpty);
    expect((await db.select(db.items).getSingle()).deletedAt, isNull);
  });

  test('стереть навсегда: строки и файлы уходят, живые не трогаются', () async {
    await add('live');
    await add('a', deletedAt: now);
    // файл, который ещё лежит во входящих
    File('${home.path}/.stowa/incoming/a/1_b.jpg').createSync(recursive: true);
    await trash.purge('a');
    expect(Directory('${home.path}/.stowa/incoming/a').existsSync(), isFalse);
    expect((await db.select(db.items).get()).map((item) => item.id), ['live']);
    expect((await db.select(db.attachments).get()).map((file) => file.itemId), ['live']);
    expect(Directory('${home.path}/attachments/a').existsSync(), isFalse);
    expect(File('${home.path}/covers/a.jpg').existsSync(), isFalse);
    expect(File('${home.path}/attachments/live/0_a.jpg').existsSync(), isTrue);
  });

  test('стереть навсегда: факты, прогоны извлекателей и копия страницы тоже уходят', () async {
    await add('a', deletedAt: now);
    await db.into(db.facts).insert(FactsCompanion.insert(id: 'x', itemId: 'a', extractor: 'text', kind: FactKind.price, value: '5 лей'));
    await db.into(db.extractorRuns).insert(ExtractorRunsCompanion.insert(itemId: 'a', extractor: 'text', version: 1));
    await savePage(home, 'a', '<html></html>');
    await trash.purge('a');
    expect(await db.select(db.facts).get(), isEmpty);
    expect(await db.select(db.extractorRuns).get(), isEmpty);
    expect(pageFile(home, 'a').existsSync(), isFalse);
  });

  test('старше 30 дней стирается само, свежее остаётся', () async {
    await add('old', deletedAt: now.subtract(const Duration(days: 31)));
    await add('fresh', deletedAt: now.subtract(const Duration(days: 3)));
    final removed = await trash.purgeExpired(now);
    expect(removed, 1);
    expect((await db.select(db.items).get()).map((item) => item.id), ['fresh']);
  });

  test('очистить корзину целиком', () async {
    await add('a', deletedAt: now);
    await add('b', deletedAt: now);
    await add('live');
    expect(await trash.purgeAll(), 2);
    expect((await db.select(db.items).get()).map((item) => item.id), ['live']);
  });
}
