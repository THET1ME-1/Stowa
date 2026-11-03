import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/telegram_updates.dart';

TelegramUpdates fixture(String name) => parseUpdates(jsonDecode(File('test/fixtures/telegram/$name.json').readAsStringSync()) as Map<String, Object?>);

void main() {
  test('пересланное фото с подписью: текст подписи и самое крупное фото', () {
    final batch = fixture('forwarded_caption');
    final message = batch.messages.single;
    expect(message.text, 'Паста с креветками за 15 минут');
    expect(message.files.single.fileId, 'big');
    expect(message.files.single.mime, 'image/jpeg');
    expect(message.date, DateTime.fromMillisecondsSinceEpoch(1793736000 * 1000));
    expect(batch.lastUpdateId, 100);
  });

  test('альбом из трёх фото — одна вещь с тремя вложениями', () {
    final batch = fixture('album');
    final message = batch.messages.single;
    expect(message.files.map((file) => file.fileId), ['a1', 'b1', 'c1']);
    expect(message.text, 'Дача, июль');
    expect(batch.lastUpdateId, 202);
  });

  test('стикеры, команды и правки пропускаются, но offset двигается за них', () {
    final batch = fixture('skipped');
    expect(batch.messages.map((message) => message.text), ['купить батарейки']);
    expect(batch.lastUpdateId, 303);
    // /start тоже говорит, кто хозяин бота
    expect(batch.senders.first.id, 42);
  });

  test('ссылка, спрятанная под словами, попадает в текст', () {
    final message = fixture('text_link').messages.single;
    expect(message.text, contains('https://habr.com/ru/articles/123/'));
    expect(message.text, startsWith('Почитать вот эту статью'));
  });

  test('документ и голосовое — файлы со своими именами и типами, отправитель известен', () {
    final batch = fixture('files');
    final document = batch.messages[0].files.single;
    expect(document.fileName, 'Договор.pdf');
    expect(document.mime, 'application/pdf');
    final voice = batch.messages[1].files.single;
    expect(voice.mime, 'audio/ogg');
    expect(voice.fileName, endsWith('.ogg'));
    expect(batch.messages[2].fromId, 7);
  });

  test('пустой ответ — ни сообщений, ни сдвига', () {
    final batch = parseUpdates({'ok': true, 'result': <Object?>[]});
    expect(batch.messages, isEmpty);
    expect(batch.lastUpdateId, isNull);
  });
}
