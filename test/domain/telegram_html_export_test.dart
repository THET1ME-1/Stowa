import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/telegram_export.dart';

// страница выгрузки, как её пишет Telegram Desktop: разметка та же, текст выдуман
String _page(String messages) => '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"/><title>Exported Data</title></head>
<body><div class="page_wrap">
 <div class="page_header"><div class="content"><div class="text bold">
Саша
 </div></div></div>
 <div class="page_body chat_page"><div class="history">
$messages
 </div></div>
</div></body></html>''';

String _message(int id, String date, {String text = '', String media = '', bool joined = false, String extra = ''}) => '''
     <div class="message default clearfix${joined ? ' joined' : ''}" id="message$id">
      <div class="body">
       <div class="pull_right date details" title="$date">
12:00
       </div>
       <div class="from_name">
Саша
       </div>
$extra
${media.isEmpty ? '' : '       <div class="media_wrap clearfix">\n$media\n       </div>'}
${text.isEmpty ? '' : '       <div class="text">\n$text\n       </div>'}
      </div>
     </div>''';

const _service = '''
     <div class="message service" id="message-1">
      <div class="body details">
12 мая 2023
      </div>
     </div>''';

void main() {
  test('сообщение — заметка с датой из подсказки, пояс учтён', () {
    final notes = parseTelegramHtml([_page(_service + _message(1, '12.05.2023 10:00:00 GMT+02:00', text: 'Купить кофе в турке'))]);
    expect(notes.single.text, 'Купить кофе в турке');
    expect(notes.single.at, DateTime.utc(2023, 5, 12, 8).toLocal());
  });

  test('оформление: жирный, курсив, ссылка под словом, голая ссылка, хэштег, перенос строки, кавычки', () {
    const text = '<strong>Борщ</strong><br>рецепт <a href="https://eda.ru/borsch">тут</a>, <em>вкусно</em> &amp; &quot;просто&quot; '
        '<a href="https://t.me/x">https://t.me/x</a><br><br><a href="" onclick="return ShowHashtag(&quot;суп&quot;)">#суп</a> '
        '<a href="" onclick="return ShowNotLoadedEmoji();">🔥</a>';
    final notes = parseTelegramHtml([_page(_message(1, '12.05.2023 10:00:00 GMT+02:00', text: text))]);
    expect(notes.single.text, '**Борщ**\nрецепт тут (https://eda.ru/borsch), _вкусно_ & "просто" https://t.me/x\n\n#суп 🔥');
  });

  test('фото и выгруженный файл — вложения; невыгруженный считается, текст остаётся', () {
    final notes = parseTelegramHtml([
      _page(
        _message(1, '12.05.2023 10:00:00 GMT+02:00', media: '<a class="photo_wrap clearfix pull_left" href="photos/photo_1@12-05-2023_10-00-00.jpg"><img class="photo" src="photos/photo_1@12-05-2023_10-00-00_thumb.jpg"/></a>') +
            _message(2, '12.05.2023 11:00:00 GMT+02:00', text: 'договор', media: '<a class="media clearfix pull_left block_link media_file" href="files/Договор.pdf"><div class="body"><div class="title bold">Договор.pdf</div><div class="status details">1.3 MB</div></div></a>') +
            _message(3, '12.05.2023 12:00:00 GMT+02:00', media: '<a class="media clearfix pull_left block_link media_voice_message" href="voice_messages/audio_1@12-05-2023.ogg"><div class="body"><div class="title bold">Voice message</div><div class="status details">00:12, 40.0 KB</div></div></a>') +
            _message(4, '12.05.2023 13:00:00 GMT+02:00', text: 'видео с концерта', media: '<div class="media clearfix pull_left media_video"><div class="body"><div class="title bold">Video</div><div class="description">\nNot included, change data exporting settings to download.\n</div></div></div>'),
      ),
    ]);
    expect([for (final note in notes) for (final file in note.files) (file.path, file.mime, file.seconds)], [
      ('photos/photo_1@12-05-2023_10-00-00.jpg', 'image/jpeg', null),
      ('files/Договор.pdf', 'application/pdf', null),
      ('voice_messages/audio_1@12-05-2023.ogg', 'audio/ogg', 12),
    ]);
    expect(notes[1].text, 'договор');
    expect((notes[3].text, notes[3].files.length, notes[3].filesMissing), ('видео с концерта', 0, 1));
  });

  test('альбом — одна заметка: подряд в одну секунду, подпись у одного', () {
    String photo(String name) => '<a class="photo_wrap clearfix pull_left" href="photos/$name.jpg"></a>';
    final notes = parseTelegramHtml([
      _page(
        _message(1, '12.05.2023 10:00:00 GMT+02:00', text: 'Море', media: photo('a')) +
            _message(2, '12.05.2023 10:00:00 GMT+02:00', media: photo('b'), joined: true) +
            _message(3, '12.05.2023 10:05:00 GMT+02:00', media: photo('c'), joined: true),
      ),
    ]);
    expect([for (final note in notes) note.files.map((file) => file.path).join(',')], ['photos/a.jpg,photos/b.jpg', 'photos/c.jpg']);
    expect(notes.first.text, 'Море');
  });

  test('пересланное: текст из пересланного, ответ и кнопки бота мимо', () {
    const forwarded = '''
       <div class="reply_to details">In reply to <a href="#go_to_message1" onclick="return GoToMessage(1)">this message</a></div>
       <div class="pull_left forwarded userpic_wrap"></div>
       <div class="forwarded body">
        <div class="from_name">Канал рецептов <span class="date details" title="10.05.2023 09:00:00 GMT+02:00"> 10.05.2023 09:00:00</span></div>
        <div class="text">Плов за 40 минут</div>
       </div>
       <table class="bot_buttons_table"><tbody><tr><td class="bot_button_row"><div class="bot_button"><a href="https://t.me/bot"><div>Открыть</div></a></div></td></tr></tbody></table>''';
    final notes = parseTelegramHtml([_page(_message(1, '12.05.2023 10:00:00 GMT+02:00', extra: forwarded))]);
    expect(notes.single.text, 'Плов за 40 минут');
    expect(notes.single.at, DateTime.utc(2023, 5, 12, 8).toLocal());
  });

  test('контакт, место и опрос — заметки своим текстом', () {
    final notes = parseTelegramHtml([
      _page(
        _message(1, '12.05.2023 10:00:00 GMT+02:00', media: '<div class="media clearfix pull_left media_contact"><div class="body"><div class="title bold">\nИван Петров\n</div><div class="status details">\n+373 69 123 456\n</div></div></div>') +
            _message(2, '12.05.2023 11:00:00 GMT+02:00', media: '<a class="media clearfix pull_left block_link media_location" href="https://maps.google.com/maps?q=47.0245,28.8323&amp;ll=47.0245,28.8323&amp;z=16"><div class="body"><div class="title bold">Location</div><div class="status details">47.0245, 28.8323</div></div></a>') +
            _message(3, '12.05.2023 12:00:00 GMT+02:00', media: '<div class="media_poll"><div class="question bold">Куда едем?</div><div class="details">Anonymous poll</div><div class="answer">- Море</div><div class="answer">- Горы</div></div>'),
      ),
    ]);
    expect(notes.map((note) => note.text), ['Иван Петров\n+373 69 123 456', '47.0245, 28.8323 https://maps.google.com/maps?q=47.0245,28.8323', 'Куда едем?\n- [ ] Море\n- [ ] Горы']);
    expect(notes.every((note) => note.files.isEmpty && note.filesMissing == 0), isTrue);
  });

  test('страницы идут по порядку, пустые и служебные пропускаются', () {
    final notes = parseTelegramHtml([
      _page(_service + _message(1, '12.05.2023 10:00:00 GMT+02:00', text: 'первая')),
      _page(_message(2, '13.05.2023 10:00:00 GMT+02:00') + _message(3, '14.05.2023 10:00:00 GMT+02:00', text: 'вторая')),
    ]);
    expect(notes.map((note) => note.text), ['первая', 'вторая']);
  });

  test('не страница выгрузки — ошибка', () {
    expect(() => parseTelegramHtml(['<html><body>привет</body></html>']), throwsFormatException);
  });
}
