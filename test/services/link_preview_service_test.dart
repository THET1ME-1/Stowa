import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/link_preview_service.dart';

void main() {
  late AppDatabase db;
  late Directory home;
  final now = DateTime(2026, 11, 3, 12);
  final requests = <Uri>[];

  setUp(() {
    db = AppDatabase.memory();
    home = Directory.systemTemp.createTempSync('stowa_preview');
    requests.clear();
  });
  tearDown(() async {
    await db.close();
    home.deleteSync(recursive: true);
  });

  Future<void> addLink(String url, {String? title, ItemKind kind = ItemKind.link}) => db.into(db.items).insert(ItemsCompanion.insert(
        id: 'a',
        kind: kind,
        title: title ?? url,
        body: Value(url),
        url: Value(url),
        createdAt: now,
        updatedAt: now,
      ));

  Future<Item> item() => db.select(db.items).getSingle();

  LinkPreviewService service(Map<String, FetchReply> replies) => LinkPreviewService(
        db,
        filesRoot: home,
        clock: () => now,
        fetch: (uri) async {
          requests.add(uri);
          final reply = replies[uri.toString()];
          if (reply == null) throw const SocketException('нет сети');
          return reply;
        },
      );

  FetchReply page(String html) => FetchReply(200, utf8.encode(html), 'text/html; charset=utf-8');
  final png = FetchReply(200, base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='), 'image/png');

  test('ссылка получает заголовок страницы, описание, сайт и обложку', () async {
    await addLink('https://habr.com/ru/articles/845872/');
    await service({
      'https://habr.com/ru/articles/845872/': page('<meta property="og:title" content="Сборщик мусора"><meta property="og:description" content="Поколения"><meta property="og:image" content="https://habr.com/i.png"><meta property="og:site_name" content="Хабр">'),
      'https://habr.com/i.png': png,
    }).fetchFor('a');
    final saved = await item();
    expect(saved.title, 'Сборщик мусора');
    expect(saved.previewText, 'Поколения');
    expect(saved.previewSite, 'Хабр');
    expect(saved.previewAt, now);
    expect(File('${home.path}/${saved.coverPath}').existsSync(), isTrue);
  });

  test('заголовок, который человек поменял, остаётся', () async {
    await addLink('https://habr.com/x', title: 'Почитать про GC');
    await service({'https://habr.com/x': page('<title>Чужой</title>')}).fetchFor('a');
    expect((await item()).title, 'Почитать про GC');
  });

  test('ролик YouTube: oEmbed даёт заголовок и автора, обложка крупная, если есть', () async {
    await addLink('https://youtu.be/dQw4w9WgXcQ', kind: ItemKind.video);
    final oembed = Uri.https('www.youtube.com', '/oembed', {'url': 'https://youtu.be/dQw4w9WgXcQ', 'format': 'json'}).toString();
    await service({
      oembed: FetchReply(200, utf8.encode(jsonEncode({'title': 'Never Gonna', 'author_name': 'Rick Astley', 'provider_name': 'YouTube', 'thumbnail_url': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg'})), 'application/json'),
      'https://youtu.be/dQw4w9WgXcQ': page('<meta itemprop="duration" content="PT3M33S">'),
      'https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg': png,
    }).fetchFor('a');
    final saved = await item();
    expect(saved.title, 'Never Gonna');
    expect(saved.previewAuthor, 'Rick Astley');
    expect(saved.durationSeconds, 213);
    expect(saved.coverPath, isNotNull);
    expect(requests.map((uri) => uri.toString()), isNot(contains('https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg')));
  });

  test('нет сети: превью не отмечено, попробуем потом', () async {
    await addLink('https://habr.com/x');
    final done = await service({}).fetchFor('a');
    expect(done, isFalse);
    expect((await item()).previewAt, isNull);
  });

  test('страницы нет (404): больше не спрашиваем, адрес остаётся заголовком', () async {
    await addLink('https://habr.com/gone');
    await service({'https://habr.com/gone': const FetchReply(404, [], 'text/html')}).fetchFor('a');
    final saved = await item();
    expect(saved.previewAt, now);
    expect(saved.title, 'https://habr.com/gone');
  });

  test('обложка не скачалась — превью всё равно записано без неё', () async {
    await addLink('https://habr.com/x');
    await service({'https://habr.com/x': page('<meta property="og:title" content="T"><meta property="og:image" content="https://habr.com/none.png">')}).fetchFor('a');
    final saved = await item();
    expect(saved.title, 'T');
    expect(saved.coverPath, isNull);
  });
}
