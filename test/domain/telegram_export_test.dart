import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/telegram_export.dart';

Map<String, Object?> _message(int id, int unix, {Object? text = '', Map<String, Object?> extra = const {}}) => {
  'id': id,
  'type': 'message',
  'date_unixtime': '$unix',
  'from': 'Саша',
  'text': text is String ? text : '',
  'text_entities': text is List ? text : [if (text is String && text.isNotEmpty) {'type': 'plain', 'text': text}],
  ...extra,
};

Map<String, Object?> _saved(List<Object?> messages) => {'name': 'Saved Messages', 'type': 'saved_messages', 'id': 1, 'messages': messages};

void main() {
  test('сообщение — заметка с датой сообщения', () {
    final notes = parseTelegramExport(_saved([_message(1, 1683885600, text: 'Купить кофе в турке')]));
    expect(notes.single.text, 'Купить кофе в турке');
    expect(notes.single.at, DateTime.fromMillisecondsSinceEpoch(1683885600 * 1000));
    expect(notes.single.files, isEmpty);
  });

  test('оформление Telegram становится разметкой, ссылка под словом — словом и адресом', () {
    final notes = parseTelegramExport(_saved([
      _message(1, 100, text: [
        {'type': 'bold', 'text': 'Борщ'},
        {'type': 'plain', 'text': '\nрецепт '},
        {'type': 'text_link', 'text': 'тут', 'href': 'https://eda.ru/borsch'},
        {'type': 'plain', 'text': ', '},
        {'type': 'italic', 'text': 'вкусно'},
        {'type': 'plain', 'text': ' '},
        {'type': 'link', 'text': 'https://t.me/x'},
        {'type': 'plain', 'text': ' '},
        {'type': 'hashtag', 'text': '#суп'},
      ]),
    ]));
    expect(notes.single.text, '**Борщ**\nрецепт тут (https://eda.ru/borsch), _вкусно_ https://t.me/x #суп');
  });

  test('файлы: фото, документ с типом, голосовое с длиной', () {
    final notes = parseTelegramExport(_saved([
      _message(1, 100, extra: {'photo': 'photos/photo_1@12-05-2023.jpg', 'width': 800, 'height': 600}),
      _message(2, 200, text: 'договор', extra: {'file': 'files/Договор.pdf', 'file_name': 'Договор.pdf', 'mime_type': 'application/pdf'}),
      _message(3, 300, extra: {'file': 'voice_messages/audio_1.ogg', 'media_type': 'voice_message', 'mime_type': 'audio/ogg', 'duration_seconds': 12}),
    ]));
    expect([for (final note in notes) for (final file in note.files) (file.path, file.mime, file.seconds)], [
      ('photos/photo_1@12-05-2023.jpg', 'image/jpeg', null),
      ('files/Договор.pdf', 'application/pdf', null),
      ('voice_messages/audio_1.ogg', 'audio/ogg', 12),
    ]);
    expect(notes[1].text, 'договор');
  });

  test('альбом — одна заметка: подряд, одна секунда, подпись у одного', () {
    final notes = parseTelegramExport(_saved([
      _message(1, 100, text: 'Море', extra: {'photo': 'photos/a.jpg'}),
      _message(2, 100, extra: {'photo': 'photos/b.jpg'}),
      _message(3, 101, extra: {'photo': 'photos/c.jpg'}),
      // через минуту — уже другое сообщение
      _message(4, 160, extra: {'photo': 'photos/d.jpg'}),
    ]));
    expect(notes.length, 2);
    expect(notes.first.text, 'Море');
    expect([for (final file in notes.first.files) file.path], ['photos/a.jpg', 'photos/b.jpg', 'photos/c.jpg']);
    expect([for (final file in notes.last.files) file.path], ['photos/d.jpg']);
  });

  test('две подписи в одну секунду — два сообщения, не альбом', () {
    final notes = parseTelegramExport(_saved([
      _message(1, 100, text: 'первое', extra: {'photo': 'photos/a.jpg'}),
      _message(2, 100, text: 'второе', extra: {'photo': 'photos/b.jpg'}),
    ]));
    expect(notes.map((note) => note.text), ['первое', 'второе']);
  });

  test('стикер, служебное и пустое пропускаются; невыгруженный файл — мимо, текст остаётся', () {
    final notes = parseTelegramExport(_saved([
      _message(1, 100, extra: {'file': 'stickers/s.webp', 'media_type': 'sticker', 'mime_type': 'image/webp'}),
      {'id': 2, 'type': 'service', 'date_unixtime': '200', 'action': 'pin_message', 'text': ''},
      _message(3, 300),
      _message(4, 400, text: 'видео с концерта', extra: {'file': '(File not included. Change data exporting settings to download.)', 'media_type': 'video_file', 'mime_type': 'video/mp4'}),
    ]));
    final note = notes.singleWhere((note) => note.text.isNotEmpty || note.files.isNotEmpty);
    expect(note.text, 'видео с концерта');
    expect(note.files, isEmpty);
    expect(note.filesMissing, 1);
  });

  test('выгрузка всех данных: берётся «Избранное» из списка чатов', () {
    final notes = parseTelegramExport({
      'about': 'Here is the data you requested.',
      'chats': {
        'about': '…',
        'list': [
          {'name': 'Мама', 'type': 'personal_chat', 'id': 2, 'messages': [_message(1, 100, text: 'привет')]},
          _saved([_message(1, 100, text: 'моё')]),
        ],
      },
    });
    expect(notes.map((note) => note.text), ['моё']);
  });

  test('не выгрузка Telegram — ошибка, а не пустой перенос', () {
    expect(() => parseTelegramExport({'hello': 1}), throwsFormatException);
    expect(() => parseTelegramExport('строка'), throwsFormatException);
  });
}
