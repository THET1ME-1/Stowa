import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/ai_worker.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  var now = DateTime(2026, 11, 3, 12);
  var calls = 0;
  late http.Response Function(Map<String, Object?> body) reply;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
    await settings.saveKey('sk-test');
    now = DateTime(2026, 11, 3, 12);
    calls = 0;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Еда', icon: 'restaurant', shape: 'pill'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'mine', name: 'Моё', icon: 'folder', shape: 'pill'));
  });
  tearDown(() => db.close());

  http.Response answer(Map<String, Object?> json) => http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {
            'content': jsonEncode({'folder_id': null, 'new_folder': null, 'tags': <String>[], 'new_tags': <Object?>[], 'title': null, 'description': 'описание', 'reminder': null, 'links': <Object?>[], ...json}),
          },
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  AiWorker worker() => AiWorker(
    db,
    settings: settings,
    http: MockClient((request) async {
      calls++;
      return reply(jsonDecode(request.body) as Map<String, Object?>);
    }),
    clock: () => now,
    timeZone: 'Europe/Chisinau',
  );

  Future<String> add(String text, {String? folder, SortedBy by = SortedBy.none}) async {
    final id = 'i${await db.items.count().getSingle()}';
    await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: text, body: Value(text), folderId: Value(folder), sortedBy: Value(by), createdAt: now, updatedAt: now));
    await db.into(db.aiJobs).insert(AiJobsCompanion.insert(itemId: id, kind: 'sort', nextTryAt: now));
    return id;
  }

  Future<Item> item(String id) => (db.select(db.items)..where((t) => t.id.equals(id))).getSingle();

  test('после runOnce вещь в папке с sortedBy ai, теги и описание записаны, задача снята', () async {
    reply = (_) => answer({'folder_id': 'food', 'tags': ['рецепт']});
    final id = await add('Борщ постный');
    final report = await worker().runOnce();
    expect(report.sorted, 1);
    final saved = await item(id);
    expect(saved.folderId, 'food');
    expect(saved.sortedBy, SortedBy.ai);
    expect(saved.sortState, SortState.sorted);
    expect(saved.aiDescription, 'описание');
    final tags = await db.select(db.itemTags).get();
    expect(tags.single.source, TagSource.ai);
    expect(await db.select(db.aiJobs).get(), isEmpty);
  });

  test('ответ пришёл после ручного переноса — папка и теги не тронуты, описание записано', () async {
    reply = (_) => answer({'folder_id': 'food', 'tags': ['рецепт']});
    final id = await add('Борщ', folder: 'mine', by: SortedBy.user);
    await worker().runOnce();
    final saved = await item(id);
    expect(saved.folderId, 'mine');
    expect(saved.sortedBy, SortedBy.user);
    expect(saved.aiDescription, isNotNull);
    expect(await db.select(db.itemTags).get(), isEmpty);
  });

  test('401 ставит очередь на паузу и больше не зовёт клиента', () async {
    reply = (_) => http.Response('{}', 401);
    await add('a');
    await add('b');
    await worker().runOnce();
    expect(calls, 1);
    expect(settings.ai.paused, isTrue);
    await worker().runOnce();
    expect(calls, 1);
  });

  test('смена ключа снимает паузу', () async {
    reply = (_) => http.Response('{}', 401);
    await add('a');
    await worker().runOnce();
    await settings.saveKey('sk-new');
    reply = (_) => answer({});
    await worker().runOnce();
    expect(calls, 2);
  });

  test('429 переносит задачу на retryAfter', () async {
    reply = (_) => http.Response('{}', 429, headers: {'retry-after': '30'});
    await add('a');
    await worker().runOnce();
    expect(settings.ai.retryAt, now.add(const Duration(seconds: 30)));
    await worker().runOnce();
    expect(calls, 1);
    now = now.add(const Duration(seconds: 31));
    await worker().runOnce();
    expect(calls, 2);
  });

  test('битый ответ: sortState failed, попытка +1, следующая через 2^n минут, не больше 6 часов', () async {
    reply = (_) => http.Response(jsonEncode({'choices': [{'message': {'content': 'не JSON'}}]}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    final id = await add('a');
    await worker().runOnce();
    final job = await db.select(db.aiJobs).getSingle();
    expect(job.attempts, 1);
    expect(job.nextTryAt, now.add(const Duration(minutes: 2)));
    expect((await item(id)).sortState, SortState.failed);
    expect(nextTryDelay(20), const Duration(hours: 6));
  });

  test('модель думала слишком долго — вещь ждёт повтора, а очередь идёт дальше', () async {
    reply = (body) {
      if (jsonEncode(body).contains('долгая')) throw TimeoutException('думает');
      return answer({'folder_id': 'food'});
    };
    final slow = await add('долгая мысль');
    final quick = await add('Борщ');
    final report = await worker().runOnce();
    expect(report.stopped, isNull);
    expect((await item(quick)).folderId, 'food');
    final job = await db.select(db.aiJobs).getSingle();
    expect(job.itemId, slow);
    expect(job.attempts, 1);
    expect(job.nextTryAt, now.add(const Duration(minutes: 2)));
  });

  test('новая папка от ИИ заводится с createdByAi', () async {
    reply = (_) => answer({'new_folder': {'name': 'Дача', 'icon': 'yard'}});
    final id = await add('Посадить чеснок');
    await worker().runOnce();
    final folder = await (db.select(db.folders)..where((t) => t.name.equals('Дача'))).getSingle();
    expect(folder.createdByAi, isTrue);
    expect((await item(id)).folderId, folder.id);
  });

  test('drain разбирает всю очередь, даже больше десяти вещей за раз', () async {
    reply = (_) => answer({'folder_id': 'food'});
    for (var index = 0; index < 12; index++) {
      await add('Рецепт $index');
    }
    await worker().drain();
    expect(await db.select(db.aiJobs).get(), isEmpty);
    final placed = await (db.select(db.items)..where((t) => t.folderId.equals('food'))).get();
    expect(placed, hasLength(12));
  });

  test('свежая ссылка без превью ждёт его, а не уходит модели голым адресом', () async {
    reply = (_) => answer({'folder_id': 'food'});
    final id = await add('https://example.com/borsch');
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(url: Value('https://example.com/borsch')));
    await worker().runOnce();
    expect(calls, 0);
    expect((await db.select(db.aiJobs).getSingle()).nextTryAt.isAfter(now), isTrue);
    now = now.add(const Duration(minutes: 3));
    await worker().runOnce();
    expect(calls, 1);
  });

  test('человек переложил вещь, пока модель думала, — его решение остаётся', () async {
    late String id;
    reply = (_) {
      // ответ ещё в пути, а человек уже перенёс вещь
      db.customStatement("UPDATE items SET folder_id = 'mine', sorted_by = 'user' WHERE id = '$id'");
      return answer({'folder_id': 'food'});
    };
    id = await add('Борщ');
    await worker().runOnce();
    final saved = await item(id);
    expect(saved.folderId, 'mine');
    expect(saved.sortedBy, SortedBy.user);
  });

  test('ИИ положил вещь в папку — об этом приходит событие для плашки', () async {
    reply = (_) => answer({'folder_id': 'food'});
    final id = await add('Борщ');
    final run = worker();
    final events = <AiSorted>[];
    final subscription = run.sorted.listen(events.add);
    await run.runOnce();
    await subscription.cancel();
    expect(events.single.itemId, id);
    expect(events.single.folderName, 'Еда');
  });

  group('голосовые', () {
    late Directory files;
    setUp(() => files = Directory.systemTemp.createTempSync('stowa_voice'));
    tearDown(() => files.deleteSync(recursive: true));

    Future<String> addVoice({String? folder, SortedBy by = SortedBy.none}) async {
      final id = await add('', folder: folder, by: by);
      await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(kind: Value(ItemKind.voice)));
      File('${files.path}/voice.m4a').writeAsBytesSync([1, 2, 3]);
      await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'a$id', itemId: id, path: 'voice.m4a', mime: 'audio/mp4', size: 3));
      return id;
    }

    AiWorker voiceWorker(List<String> paths) => AiWorker(
      db,
      settings: settings,
      http: MockClient((request) async {
        calls++;
        paths.add(request.url.path);
        if (request.url.path.endsWith('/audio/transcriptions')) {
          return http.Response(jsonEncode({'text': 'купить рассаду томатов'}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return reply(jsonDecode(request.body) as Map<String, Object?>);
      }),
      clock: () => now,
      timeZone: 'Europe/Chisinau',
      filesRoot: files,
    );

    test('с моделью речи голосовое сперва расшифровывается, потом раскладывается по тексту', () async {
      await settings.setSpeechModel('openai/whisper-1');
      String? sent;
      reply = (body) {
        sent = jsonEncode(body);
        return answer({'folder_id': 'food'});
      };
      final id = await addVoice();
      final paths = <String>[];
      await voiceWorker(paths).runOnce();
      expect(paths.first, endsWith('/audio/transcriptions'));
      final saved = await item(id);
      expect(saved.transcript, 'купить рассаду томатов');
      expect(saved.folderId, 'food');
      expect(sent, contains('рассаду томатов'));
    });

    test('без модели речи разложенное голосовое не тратит запрос', () async {
      reply = (_) => answer({});
      await addVoice(folder: 'mine', by: SortedBy.similar);
      await voiceWorker([]).runOnce();
      expect(calls, 0);
      expect(await db.select(db.aiJobs).get(), isEmpty);
    });
  });

  test('без ключа очередь не идёт вовсе', () async {
    await settings.saveKey(null);
    reply = (_) => answer({});
    await add('a');
    await worker().runOnce();
    expect(calls, 0);
  });

  test('в «Без папки» стало 4 вещи — предлагаются новые папки', () async {
    final ids = [for (final text in ['Чеснок посадить', 'Полить огурцы', 'Купить семена', 'Позвонить маме']) await add(text, by: SortedBy.user)];
    await db.delete(db.aiJobs).go();
    reply = (body) => jsonEncode(body).contains('stowa_sort')
        ? answer({})
        : http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode({'folders': [{'name': 'Огород', 'icon': 'yard', 'item_ids': ids.take(3).toList()}]})}}]}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    await (db.update(db.items)).write(const ItemsCompanion(sortedBy: Value(SortedBy.none)));
    final report = await worker().runCluster();
    expect(report, 1);
    final garden = await (db.select(db.folders)..where((t) => t.name.equals('Огород'))).getSingle();
    expect(garden.createdByAi, isTrue);
    expect((await item(ids[0])).folderId, garden.id);
    expect((await item(ids[3])).folderId, isNull);
  });
}
