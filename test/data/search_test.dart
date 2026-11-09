import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/structured_page.dart';
import 'package:stowa/services/facts/facts_pipeline.dart';
import 'package:stowa/services/facts/web_extractors.dart';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/highlights_repository.dart';
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

    test('факты: текст документа с листом, цена, скриншоты, автор ролика', () async {
      // смета в Excel
      final archive = Archive();
      void add(String name, String text) {
        final bytes = utf8.encode(text);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      add('xl/workbook.xml', '<workbook><sheets><sheet name="Ремонт" sheetId="1"/></sheets></workbook>');
      add('xl/sharedStrings.xml', '<sst><si><t>Плиточный клей</t></si></sst>');
      add('xl/worksheets/sheet1.xml', '<worksheet><sheetData><row><c t="s"><v>0</v></c></row></sheetData></worksheet>');
      final xlsx = File(p.join(home.path, 'smeta.xlsx'))..writeAsBytesSync(ZipEncoder().encode(archive));
      await capture.capture(CaptureInput(files: [PickedFile(path: xlsx.path, mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', size: xlsx.lengthSync())]));
      // скриншот и обычная картинка
      final shot = File(p.join(home.path, 'Screenshot_20261101.png'))..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 4, 56, 0, 0, 9, 96]);
      await capture.capture(CaptureInput(files: [PickedFile(path: shot.path, mime: 'image/png', size: shot.lengthSync())]));
      // заметки с ценой
      await capture.capture(const CaptureInput(text: 'Диван на OLX 4 500 лей'));
      await capture.capture(const CaptureInput(text: 'Кресло 12 000 лей'));
      await capture.settled();
      final facts = FactsPipeline(db, filesRoot: home, clock: () => now);
      await facts.sweep();

      // «лей» в заметках с ценой — не опечатка «клея»
      final inFile = (await find('клей')).single;
      expect(inFile.hit.where, SearchField.facts);
      expect(inFile.hit.foundFact!.part.place, 'sheet:Ремонт');
      expect((await find('мебель до 5000 лей')).map((found) => found.card.title), isEmpty, reason: 'слова «мебель» нет');
      expect((await find('диван до 5000 лей')).single.card.title, 'Диван на OLX 4 500 лей');
      expect((await find('дороже 10000 лей')).single.card.title, 'Кресло 12 000 лей');
      expect((await find('скрины')), hasLength(1));
    });

    test('по цвету: «синее» находит вещь с синим главным цветом, а не красную', () async {
      final sea = await capture.capture(const CaptureInput(text: 'Море в Одессе'));
      final dress = await capture.capture(const CaptureInput(text: 'Платье на выпускной'));
      await db.into(db.facts).insert(FactsCompanion.insert(id: 'c1', itemId: sea, extractor: 'colors', kind: FactKind.color, value: 'blue', number: const Value(0.7), detail: const Value('#1E3CC8')));
      await db.into(db.facts).insert(FactsCompanion.insert(id: 'c2', itemId: dress, extractor: 'colors', kind: FactKind.color, value: 'red', number: const Value(0.6), detail: const Value('#DC1E1E')));
      expect((await find('синее')).map((found) => found.card.id), [sea]);
      expect((await find('red')).map((found) => found.card.id), [dress]);
      expect((await find('красное платье')).map((found) => found.card.id), [dress]);
    });

    test('статьи по времени чтения, рецепт по ингредиенту и по слову «рецепт»', () async {
      Future<String> link(String title, String url) => capture.capture(CaptureInput(text: '$title\n$url'));
      final short = await link('Короткая заметка о поиске', 'https://habr.com/a/1');
      final long = await link('Длинный разбор поиска', 'https://habr.com/a/2');
      final recipe = await link('Ужин', 'https://food.md/carbonara');
      Future<void> fact(String itemId, FactKind kind, String value, {double? number, String? detail}) => db
          .into(db.facts)
          .insert(FactsCompanion.insert(id: '$itemId-$kind-$value', itemId: itemId, extractor: 'page', kind: kind, value: value, number: Value(number), detail: Value(detail)));
      await fact(short, FactKind.readingTime, '4', number: 4);
      await fact(long, FactKind.readingTime, '25', number: 25);
      await fact(recipe, FactKind.ingredient, 'гуанчиале');
      await fact(recipe, FactKind.pageType, pageTypeWords[PageType.recipe]!, detail: 'recipe');
      await db.customStatement("UPDATE items SET facts_text = 'гуанчиале\n${pageTypeWords[PageType.recipe]}' WHERE id = '$recipe'");

      expect((await find('статьи до 10 минут')).map((found) => found.card.id), [short]);
      final byIngredient = (await find('гуанчиале')).single;
      expect(byIngredient.card.id, recipe);
      expect(byIngredient.hit.foundFact!.part.kind, FactKind.ingredient);
      expect((await find('рецепт')).map((found) => found.card.id), contains(recipe));
    });

    test('статья находится по слову из своего текста, а цитата — по пометке', () async {
      final article = await capture.capture(CaptureInput(text: 'https://en.wikipedia.org/wiki/Coffee'));
      await db.into(db.facts).insert(
        FactsCompanion.insert(id: 'a', itemId: article, extractor: 'article', kind: FactKind.articleText, value: 'The legend names De Saluberrima potione as the first treatise.'),
      );
      await refreshFactsText(db, article);
      final byText = (await find('Saluberrima')).single;
      expect(byText.card.id, article);
      expect(byText.hit.foundFact!.part.kind, FactKind.articleText);

      await HighlightsRepository(db, clock: () => now).add(article, 'first treatise', position: 30, note: 'перечитать про трактат');
      final byNote = (await find('перечитать')).single;
      expect(byNote.card.id, article);
      expect(byNote.hit.foundFact!.part.kind, FactKind.highlight);
    });

    test('фото находится по тексту своего QR-кода: сеть Wi-Fi, адрес с билета', () async {
      final wifi = await capture.capture(const CaptureInput(text: 'Бумажка у роутера'));
      final ticket = await capture.capture(const CaptureInput(text: 'Билет'));
      await db.into(db.facts).insert(FactsCompanion.insert(id: 'w', itemId: wifi, extractor: 'qr', kind: FactKind.qr, value: r'WIFI:T:WPA;S:Dacha_5G;P:sunflower\;2026;;', detail: const Value('wifi')));
      await db.into(db.facts).insert(FactsCompanion.insert(id: 't', itemId: ticket, extractor: 'qr', kind: FactKind.qr, value: 'https://go.dev/doc/effective_go', detail: const Value('url')));
      await refreshFactsText(db, wifi);
      await refreshFactsText(db, ticket);

      final byNetwork = (await find('dacha')).single;
      expect(byNetwork.card.id, wifi);
      expect(byNetwork.hit.foundFact!.part.kind, FactKind.qr);
      expect((await find('wifi')).map((found) => found.card.id), contains(wifi));
      expect((await find('effective')).single.card.id, ticket);
    });

    test('на карте событие стоит там, где оно, а не где ссылку сохранили', () async {
      final concert = await capture.capture(const CaptureInput(text: 'Концерт\nhttps://afisha.md/concert'));
      await (db.update(db.items)..where((t) => t.id.equals(concert))).write(const ItemsCompanion(latitude: Value(46.0), longitude: Value(30.0), placeName: Value('Дом')));
      await db.into(db.facts).insert(FactsCompanion.insert(id: 'v1', itemId: concert, extractor: 'page', kind: FactKind.venue, value: 'Palatul Național'));
      await db.into(db.facts).insert(FactsCompanion.insert(id: 'v2', itemId: concert, extractor: 'page', kind: FactKind.venuePlace, value: 'x', number: const Value(47.02), detail: const Value('28.83')));
      final placed = await items.watchPlaced().first;
      final card = placed.firstWhere((card) => card.id == concert);
      expect((card.latitude, card.longitude, card.placeName), (47.02, 28.83, 'Palatul Național'));
    });

    test('на карте фото стоит там, где снято, а не где сохранено; без места съёмки — где сохранено', () async {
      final trip = await capture.capture(const CaptureInput(text: 'Чай в горах'));
      final plain = await capture.capture(const CaptureInput(text: 'Чек из магазина'));
      for (final id in [trip, plain]) {
        await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(latitude: Value(46.0), longitude: Value(30.0), placeName: Value('Дом')));
      }
      await db.into(db.facts).insert(FactsCompanion.insert(id: 't1', itemId: trip, extractor: 'photo', kind: FactKind.takenPlace, value: '48.3,24.5', number: const Value(48.3), detail: const Value('24.5')));
      final placed = await items.watchPlaced().first;
      final card = placed.firstWhere((card) => card.id == trip);
      // имя места сохранения к месту съёмки не относится
      expect((card.latitude, card.longitude, card.placeName), (48.3, 24.5, null));
      expect(placed.firstWhere((card) => card.id == plain).latitude, 46.0);
    });

    test('фото без места сохранения, но с местом съёмки — тоже на карте', () async {
      final trip = await capture.capture(const CaptureInput(text: 'Озеро'));
      await db.into(db.facts).insert(FactsCompanion.insert(id: 't1', itemId: trip, extractor: 'photo', kind: FactKind.takenPlace, value: '48.3,24.5', number: const Value(48.3), detail: const Value('24.5')));
      expect((await items.watchPlaced().first).map((card) => card.id), contains(trip));
    });

    test('слово находит по месту и по транслиту', () async {
      expect((await find('kishinev')).single.hit.where, SearchField.place);
      expect((await find('rjat')).single.card.title, 'Купить кофе на рынке');
    });
  });
}
