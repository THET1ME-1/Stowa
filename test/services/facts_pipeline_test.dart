import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/facts/extractor.dart';
import 'package:stowa/services/facts/extractors.dart';
import 'package:stowa/services/facts/facts_pipeline.dart';

import '../domain/photo_facts_test.dart' show jpegWithExif;

/// Извлекатель для проверки самого конвейера: считает прогоны, может падать.
class CountingExtractor extends Extractor {
  CountingExtractor({this.name = 'counting', this.version = 1, this.needsNetwork = false, this.stampSql = 'items.updated_at', this.fail = false});

  @override
  final String name;
  @override
  final int version;
  @override
  final bool needsNetwork;
  @override
  final String stampSql;
  bool fail;
  int runs = 0;

  @override
  Future<List<FactDraft>> extract(ExtractInput input) async {
    runs++;
    if (fail) throw const SocketException('нет сети');
    return [FactDraft(FactKind.description, 'прогон $runs')];
  }
}

/// Извлекатель, который читает вложения, как настоящие: нет файла на месте — пропускает.
/// Перед первым чтением может переложить файл, как писатель хранилища.
class ReadingExtractor extends Extractor {
  ReadingExtractor({this.beforeFirstRead});

  final Future<void> Function()? beforeFirstRead;
  int runs = 0;

  @override
  String get name => 'reading';
  @override
  int get version => 1;
  @override
  String get stampSql => "coalesce((SELECT group_concat(attachments.id) FROM attachments WHERE attachments.item_id = items.id), '')";
  @override
  String get appliesSql => 'EXISTS (SELECT 1 FROM attachments WHERE attachments.item_id = items.id)';

  @override
  Future<List<FactDraft>> extract(ExtractInput input) async {
    runs++;
    if (runs == 1) await beforeFirstRead?.call();
    return [
      for (final attachment in input.files)
        if (await input.fileOf(attachment).exists()) FactDraft(FactKind.description, input.nameOf(attachment)),
    ];
  }
}

void main() {
  late AppDatabase db;
  late Directory home;
  var now = DateTime(2026, 11, 5, 12);
  var online = true;

  setUp(() async {
    db = AppDatabase.memory();
    home = await Directory.systemTemp.createTemp('stowa_facts');
    now = DateTime(2026, 11, 5, 12);
    online = true;
  });

  tearDown(() async {
    await db.close();
    await home.delete(recursive: true);
  });

  FactsPipeline pipeline(List<Extractor> extractors) => FactsPipeline(db, filesRoot: home, clock: () => now, extractors: extractors, online: () async => online);

  Future<void> note(String id, String body, {ItemKind kind = ItemKind.note, String? url}) async {
    await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: kind, title: body.split('\n').first, body: Value(body), url: Value(url), createdAt: now, updatedAt: now));
  }

  Future<void> attach(String id, String name, List<int> bytes, String mime, {int? width, int? height}) async {
    final relative = p.join('attachments', id, '0_$name');
    final file = File(p.join(home.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: '$id-$name', itemId: id, path: relative, mime: mime, size: bytes.length, width: Value(width), height: Value(height)));
  }

  Future<List<Fact>> factsOf(String id) => (db.select(db.facts)..where((t) => t.itemId.equals(id))).get();
  Future<String> factsText(String id) async => (await (db.select(db.items)..where((t) => t.id.equals(id))).getSingle()).factsText;

  group('конвейер', () {
    test('прогоняет вещь один раз, пока она не изменилась', () async {
      await note('a', 'текст');
      final counting = CountingExtractor();
      final facts = pipeline([counting]);
      await facts.runItem('a');
      await facts.runItem('a');
      await facts.sweep();
      expect(counting.runs, 1);
      expect((await factsOf('a')).single.value, 'прогон 1');
    });

    test('правка вещи — прогон заново, факты заменяются, а не копятся', () async {
      await note('a', 'текст');
      final counting = CountingExtractor();
      final facts = pipeline([counting]);
      await facts.runItem('a');
      now = now.add(const Duration(minutes: 1));
      await ItemsRepository(db).setBody('a', 'новый текст', now);
      await facts.sweep();
      expect(counting.runs, 2);
      expect((await factsOf('a')).map((fact) => fact.value), ['прогон 2']);
    });

    test('извлекатель зависит только от своего: правка текста не трогает разбор файлов', () async {
      await note('a', 'текст');
      final files = CountingExtractor(name: 'files', stampSql: "coalesce((SELECT group_concat(id) FROM attachments WHERE item_id = items.id), '')");
      final facts = pipeline([files]);
      await facts.runItem('a');
      now = now.add(const Duration(minutes: 1));
      await ItemsRepository(db).setBody('a', 'другой текст', now);
      await facts.sweep();
      expect(files.runs, 1);
      await attach('a', 'list.txt', utf8.encode('x'), 'text/plain');
      await facts.sweep();
      expect(files.runs, 2);
    });

    test('новая версия извлекателя разбирает старые вещи заново', () async {
      await note('a', 'текст');
      await note('b', 'ещё');
      await pipeline([CountingExtractor()]).sweep();
      final improved = CountingExtractor(version: 2);
      await pipeline([improved]).sweep();
      expect(improved.runs, 2);
    });

    test('упавший местный извлекатель не крутится вечно и не стирает чужие факты', () async {
      await note('a', 'кофе 35 лей');
      final broken = CountingExtractor(name: 'broken', fail: true);
      final facts = pipeline([TextExtractor(), broken]);
      await facts.runItem('a');
      await facts.sweep();
      expect(broken.runs, 1);
      expect((await factsOf('a')).single.kind, FactKind.price);
      final run = await (db.select(db.extractorRuns)..where((t) => t.extractor.equals('broken'))).getSingle();
      expect(run.error, contains('нет сети'));
    });

    test('сетевой — только при сети и с отсрочкой после неудачи', () async {
      await note('a', 'ссылка', kind: ItemKind.link, url: 'https://a.md');
      final page = CountingExtractor(name: 'page', needsNetwork: true);
      final facts = pipeline([page]);
      await facts.runItem('a');
      expect(page.runs, 0, reason: 'местный проход сетевых не трогает');
      online = false;
      await facts.sweepNetwork();
      expect(page.runs, 0);
      online = true;
      page.fail = true;
      await facts.sweepNetwork();
      await facts.sweepNetwork();
      expect(page.runs, 1, reason: 'после неудачи ждёт отсрочку');
      now = now.add(const Duration(hours: 1));
      page.fail = false;
      await facts.sweepNetwork();
      expect(page.runs, 2);
      expect((await factsOf('a')).single.value, 'прогон 2');
    });

    test('удалённые вещи не разбираются', () async {
      await note('a', 'кофе 35 лей');
      await ItemsRepository(db).softDelete('a', now);
      final counting = CountingExtractor();
      await pipeline([counting]).sweep();
      expect(counting.runs, 0);
    });
  });

  group('файл переехал посреди разбора', () {
    // писатель хранилища: файл переименован сразу, путь в базе — через [lag]
    Future<void> moveAttachment(String id, String name, {Duration lag = Duration.zero}) async {
      final row = await (db.select(db.attachments)..where((t) => t.id.equals('$id-$name'))).getSingle();
      final target = p.join('Заметка', name);
      await Directory(p.join(home.path, 'Заметка')).create(recursive: true);
      await File(p.join(home.path, row.path)).rename(p.join(home.path, target));
      Future<void> write() => (db.update(db.attachments)..where((t) => t.id.equals(row.id))).write(AttachmentsCompanion(path: Value(target)));
      if (lag == Duration.zero) {
        await write();
      } else {
        unawaited(Future.delayed(lag, write));
      }
    }

    test('правило разбирает файл на новом месте, а не записывает «пусто»', () async {
      await note('a', '');
      await attach('a', 'море.jpg', [1, 2, 3], 'image/jpeg');
      final reading = ReadingExtractor(beforeFirstRead: () => moveAttachment('a', 'море.jpg'));
      await pipeline([reading]).runItem('a');
      expect([for (final fact in await factsOf('a')) fact.value], ['море.jpg']);
      expect(reading.runs, 2);
    });

    test('путь в базе пишется позже переименования — правило дожидается его', () async {
      await note('a', '');
      await attach('a', 'море.jpg', [1, 2, 3], 'image/jpeg');
      final reading = ReadingExtractor(beforeFirstRead: () => moveAttachment('a', 'море.jpg', lag: const Duration(milliseconds: 400)));
      await pipeline([reading]).runItem('a');
      expect([for (final fact in await factsOf('a')) fact.value], ['море.jpg']);
    });

    test('файла нет совсем — один прогон с ожиданием, без зацикливания', () async {
      await note('a', '');
      await attach('a', 'море.jpg', [1, 2, 3], 'image/jpeg');
      await File(p.join(home.path, 'attachments', 'a', '0_море.jpg')).delete();
      final reading = ReadingExtractor();
      final facts = pipeline([reading]);
      await facts.runItem('a');
      await facts.sweep();
      expect(reading.runs, 1);
      expect(await factsOf('a'), isEmpty);
      expect(await (db.select(db.extractorRuns)..where((t) => t.extractor.equals('reading'))).getSingleOrNull(), isNotNull);
    });
  });

  group('извлекатели', () {
    test('текст: деньги, телефон, почта, ссылка — и всё это ищется', () async {
      await note('a', 'Мастер Иван +373 69 123 456, ivan@mail.md\nДиван 4 500 лей, смотри www.mobila.md/divan');
      await pipeline([TextExtractor()]).runItem('a');
      final facts = await factsOf('a');
      final price = facts.firstWhere((fact) => fact.kind == FactKind.price);
      expect(price.number, 4500);
      expect(price.detail, 'MDL');
      expect(facts.firstWhere((fact) => fact.kind == FactKind.phone).detail, '+37369123456');
      expect(facts.firstWhere((fact) => fact.kind == FactKind.email).value, 'ivan@mail.md');
      expect(facts.firstWhere((fact) => fact.kind == FactKind.link).value, 'https://www.mobila.md/divan');
      expect(await factsText('a'), contains('4 500 лей'));
    });

    test('текст: адрес самой ссылки фактом не дублируется', () async {
      await note('a', 'https://habr.com/ru/articles/1/', kind: ItemKind.link, url: 'https://habr.com/ru/articles/1/');
      await pipeline([TextExtractor()]).runItem('a');
      expect(await factsOf('a'), isEmpty);
    });

    test('документ: текст по листам, ищется, разбор в отдельном потоке', () async {
      await note('a', '');
      final archive = Archive();
      void add(String name, String text) {
        final bytes = utf8.encode(text);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      add('xl/workbook.xml', '<workbook><sheets><sheet name="Ремонт" sheetId="1"/></sheets></workbook>');
      add('xl/sharedStrings.xml', '<sst><si><t>Плитка</t></si></sst>');
      add('xl/worksheets/sheet1.xml', '<worksheet><sheetData><row><c t="s"><v>0</v></c><c><v>1200</v></c></row></sheetData></worksheet>');
      await attach('a', 'remont.xlsx', ZipEncoder().encode(archive), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      await pipeline([FileTextExtractor()]).runItem('a');
      final fact = (await factsOf('a')).single;
      expect(fact.kind, FactKind.fileText);
      expect(fact.detail, 'sheet:Ремонт');
      expect(fact.value, 'Плитка 1200');
      expect(await factsText('a'), contains('Плитка'));
    });

    test('фото: дата съёмки, камера, место; скриншот по имени', () async {
      await note('a', '', kind: ItemKind.image);
      await attach('a', 'IMG_1.jpg', jpegWithExif(make: 'Google', model: 'Pixel 8', taken: '2024:05:03 18:42:10', place: (47.0245, 28.8323)), 'image/jpeg');
      await note('b', '', kind: ItemKind.image);
      await attach('b', 'Screenshot_20261105.png', [0x89, 0x50, 0x4E, 0x47], 'image/png', width: 1080, height: 2400);
      await pipeline([PhotoExtractor()]).sweep();
      final photo = await factsOf('a');
      expect(photo.firstWhere((fact) => fact.kind == FactKind.takenAt).at, DateTime(2024, 5, 3, 18, 42, 10));
      expect(photo.firstWhere((fact) => fact.kind == FactKind.camera).value, 'Google Pixel 8');
      expect(photo.firstWhere((fact) => fact.kind == FactKind.takenPlace).number, closeTo(47.0245, 0.0001));
      expect(photo.any((fact) => fact.kind == FactKind.screenshot), isFalse);
      expect((await factsOf('b')).single.kind, FactKind.screenshot);
    });

    test('ссылка: автор, сайт и описание страницы ищутся', () async {
      await note('a', 'https://youtu.be/x', kind: ItemKind.video, url: 'https://youtu.be/x');
      await (db.update(db.items)..where((t) => t.id.equals('a'))).write(
        ItemsCompanion(previewAuthor: const Value('вДудь'), previewText: const Value('Интервью о кино и жизни'), previewAt: Value(now)),
      );
      await pipeline([LinkExtractor()]).runItem('a');
      final facts = await factsOf('a');
      expect(facts.map((fact) => fact.kind), containsAll([FactKind.author, FactKind.site, FactKind.description]));
      expect(facts.firstWhere((fact) => fact.kind == FactKind.site).value, 'YouTube');
      expect(await factsText('a'), allOf(contains('вДудь'), contains('Интервью')));
    });
  });
}
