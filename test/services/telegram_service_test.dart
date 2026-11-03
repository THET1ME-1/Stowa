import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/services/capture_service.dart';
import 'package:stowa/services/telegram_service.dart';

void main() {
  late AppDatabase db;
  late Directory home;
  late Directory inbox;
  late TelegramService bot;
  late MemoryKeyStore tokens;
  final asked = <String>[];
  late List<Map<String, Object?>> updates;

  http.Response json(Object body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

  Map<String, Object?> textUpdate(int id, int from, String text) => {
    'update_id': id,
    'message': {'message_id': id, 'from': {'id': from, 'first_name': 'Саша'}, 'chat': {'id': from, 'type': 'private'}, 'date': 1793736000, 'text': text},
  };

  setUp(() async {
    db = AppDatabase.memory();
    home = Directory.systemTemp.createTempSync('stowa_tg_home');
    inbox = Directory.systemTemp.createTempSync('stowa_tg_inbox');
    SharedPreferences.setMockInitialValues({});
    tokens = MemoryKeyStore()..value = '123:abc';
    asked.clear();
    updates = [];
    final capture = CaptureService(db, tags: TagsRepository(db), filesRoot: home, clock: () => DateTime(2026, 11, 3, 12));
    bot = TelegramService(
      capture: capture,
      prefs: await SharedPreferences.getInstance(),
      tokens: tokens,
      inbox: inbox,
      http: MockClient((request) async {
        asked.add(request.url.toString());
        final path = request.url.path;
        if (path.endsWith('/getMe')) return json({'ok': true, 'result': {'id': 1, 'is_bot': true, 'first_name': 'Склад', 'username': 'my_stowa_bot'}});
        if (path.endsWith('/getUpdates')) {
          final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
          return json({'ok': true, 'result': [for (final update in updates) if ((update['update_id']! as int) >= offset) update]});
        }
        if (path.endsWith('/getFile')) return json({'ok': true, 'result': {'file_id': 'doc', 'file_path': 'documents/file_1.pdf'}});
        if (path.contains('/file/bot')) return http.Response.bytes([37, 80, 68, 70], 200);
        return http.Response('{}', 404);
      }),
    );
  });
  tearDown(() async {
    await db.close();
    home.deleteSync(recursive: true);
    if (inbox.existsSync()) inbox.deleteSync(recursive: true);
  });

  test('переслал боту — вещь в Stowa, второй опрос её не дублирует', () async {
    updates = [textUpdate(10, 42, 'купить батарейки')];
    expect(await bot.pull(), 1);
    expect(await bot.pull(), 0);
    final items = await db.select(db.items).get();
    expect(items.single.body, 'купить батарейки');
    expect(asked.last, contains('offset=11'));
  });

  test('бот слушает только хозяина — первого, кто ему написал', () async {
    updates = [textUpdate(10, 42, '/start'), textUpdate(11, 7, 'спам от чужого'), textUpdate(12, 42, 'моё')];
    await bot.pull();
    final items = await db.select(db.items).get();
    expect(items.map((item) => item.body), ['моё']);
    expect(bot.state.ownerName, 'Саша');
  });

  test('документ скачивается и ложится вложением', () async {
    updates = [
      {
        'update_id': 20,
        'message': {
          'message_id': 20,
          'from': {'id': 42, 'first_name': 'Саша'},
          'chat': {'id': 42, 'type': 'private'},
          'date': 1793736000,
          'document': {'file_id': 'doc', 'file_unique_id': 'd', 'file_name': 'Договор.pdf', 'mime_type': 'application/pdf'},
        },
      },
    ];
    await bot.pull();
    final attachment = await db.select(db.attachments).getSingle();
    expect(attachment.mime, 'application/pdf');
    expect(File('${home.path}/${attachment.path}').readAsBytesSync(), [37, 80, 68, 70]);
  });

  test('проверка токена показывает имя бота и запоминает его', () async {
    final name = await bot.connect('123:abc');
    expect(name, 'my_stowa_bot');
    expect(bot.state.botName, 'my_stowa_bot');
    expect(await tokens.read(), '123:abc');
  });

  test('без токена бот молчит и в сеть не ходит', () async {
    tokens.value = null;
    expect(await bot.pull(), 0);
    expect(asked, isEmpty);
  });
}
