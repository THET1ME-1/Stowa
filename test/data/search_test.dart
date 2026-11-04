import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/domain/search_query.dart';
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

  Future<List<SearchResult>> find(String text, {List<String> tags = const [], (double, double)? here}) async =>
      (await items.search(query: parseSearch(text, now), tags: tags, now: now, here: here)).results;

  test('ищет по началу слова, отдаёт карточку с папкой и подсветкой', () async {
    final found = await find('паро');
    expect(found.first.card.title, 'Пароль от Wi-Fi');
    expect(found.first.card.folderName, 'Дом');
    expect(found.first.hit.marks[SearchField.title], isNotEmpty);
  });

  test('опечатка находит', () async {
    final found = await find('домафона');
    expect(found.single.card.title, 'Код домофона: 4512');
  });

  test('находит в расшифровке', () async {
    final found = await find('сахар');
    expect(found.single.card.title, 'Мама: пирог');
    expect(found.single.hit.where, SearchField.deep);
  });

  test('чип тега без слов показывает вещи с тегом', () async {
    final found = await find('', tags: ['код']);
    expect(found, hasLength(2));
  });

  test('удалённое не находится', () async {
    final found = await find('домофона');
    await items.softDelete(found.single.card.id, now);
    expect(await find('домофона'), isEmpty);
  });

  group('запрос с фильтрами', () {
    late CaptureService capture;
    var clock = now;

    setUp(() async {
      capture = CaptureService(db, tags: TagsRepository(db), filesRoot: home, clock: () => clock);
      clock = DateTime(2026, 11, 1, 19);
      final pasta = await capture.capture(const CaptureInput(text: 'https://youtu.be/pasta123 паста карбонара'));
      await (db.update(db.items)..where((t) => t.id.equals(pasta))).write(const ItemsCompanion(durationSeconds: Value(240), title: Value('Паста карбонара')));
      clock = DateTime(2026, 10, 20, 9);
      final market = await capture.capture(const CaptureInput(text: 'Купить кофе на рынке'));
      await (db.update(db.items)..where((t) => t.id.equals(market))).write(const ItemsCompanion(latitude: Value(47.0245), longitude: Value(28.8323), placeName: Value('Кишинёв, Центральный рынок')));
      clock = now;
    });

    test('вид, время и сайт отбирают, слова ищутся среди отобранного', () async {
      expect((await find('паста видео позавчера')).single.card.title, 'Паста карбонара');
      expect((await find('паста ютуб')).single.card.title, 'Паста карбонара');
      expect(await find('паста тикток'), isEmpty);
      expect((await find('ролики до 5 минут')).single.card.title, 'Паста карбонара');
      expect(await find('ролики больше 5 минут'), isEmpty);
    });

    test('фильтры без слов — свежие из отобранного', () async {
      final found = await items.search(query: parseSearch('в прошлом месяце', now), now: now);
      expect(found.results.single.card.title, 'Купить кофе на рынке');
      expect(found.query.understood, ['в прошлом месяце']);
    });

    test('рядом — в километре от телефона', () async {
      expect((await find('кофе рядом', here: (47.026, 28.835))).single.card.title, 'Купить кофе на рынке');
      final far = await items.search(query: parseSearch('кофе рядом', now), now: now, here: (46.0, 30.0));
      // фильтр ничего не дал — тот же запрос простыми словами, а слова «рядом» в тексте нет
      expect(far.query.hasFilters, isFalse);
      expect(far.results, isEmpty);
      final plain = await items.search(query: parseSearch('рынке рядом', now), now: now, here: (46.0, 30.0));
      expect(plain.results, isEmpty);
    });

    test('дома и на работе — по тому, где сохраняют ночью и в будни днём', () async {
      Future<void> at(String text, DateTime when, double latitude, double longitude) async {
        clock = when;
        final id = await capture.capture(CaptureInput(text: text));
        await (db.update(db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(latitude: Value(latitude), longitude: Value(longitude)));
      }

      for (var day = 1; day <= 4; day++) {
        await at('Сон $day', DateTime(2026, 10, day, 23), 47.0245, 28.8323);
        await at('Отчёт $day', DateTime(2026, 10, day + 4, 11), 47.0400, 28.8100);
      }
      await at('Пароль от роутера', DateTime(2026, 10, 12, 22), 47.0246, 28.8324);
      await at('Пароль от почты', DateTime(2026, 10, 13, 10), 47.0401, 28.8101);
      clock = now;
      expect((await find('пароль дома')).single.card.title, 'Пароль от роутера');
      expect((await find('пароль на работе')).single.card.title, 'Пароль от почты');
    });

    test('слово находит по месту и по транслиту', () async {
      expect((await find('kishinev')).single.hit.where, SearchField.place);
      expect((await find('rjat')).single.card.title, 'Купить кофе на рынке');
    });
  });
}
