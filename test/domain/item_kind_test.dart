import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/item_kind.dart';
import 'package:stowa/domain/models.dart';

void main() {
  test('плашка ролика называет сервис, как в макете, а не адрес', () {
    expect(sourceName('vt.tiktok.com'), 'TikTok');
    expect(sourceName('www.youtube.com'), 'YouTube');
    expect(sourceName('youtu.be'), 'YouTube');
    expect(sourceName('instagram.com'), 'Instagram');
    expect(sourceName('rutube.ru'), 'Rutube');
    expect(sourceName('vkvideo.ru'), 'VK Видео');
    expect(sourceName('www.coffee-guide.ru'), 'coffee-guide.ru');
  });

  test('ролики узнаются по адресу, даже без схемы', () {
    expect(detectKind(text: 'vm.tiktok.com/ZM8x'), ItemKind.video);
    expect(detectKind(text: 'смотри https://youtu.be/abc'), ItemKind.video);
    expect(detectKind(text: 'https://www.instagram.com/reel/C1x/'), ItemKind.video);
    expect(detectKind(text: 'https://rutube.ru/video/abc/'), ItemKind.video);
  });

  test('прочая ссылка — ссылка, текст — заметка', () {
    expect(detectKind(text: 'https://coffee-guide.ru/turka'), ItemKind.link);
    expect(detectKind(text: 'код домофона 4512'), ItemKind.note);
    expect(detectKind(text: 'версия 1.5 вышла'), ItemKind.note);
  });

  test('длинная заметка со ссылкой внутри остаётся заметкой', () {
    const note = 'Разработка архитектуры приложения\nДипломная работа\n\n- расширить до 40 страниц\n- 20–40 источников\n\nДокументация: flutter.dev/docs';
    expect(detectKind(text: note), ItemKind.note);
    // а короткая подпись к ссылке её не делает заметкой
    expect(detectKind(text: 'Паста с креветками https://vt.tiktok.com/ZSpasta15/'), ItemKind.video);
    expect(detectKind(text: 'Как варить кофе в турке, коротко и по делу https://coffee-guide.ru/turka'), ItemKind.link);
  });

  test('файл узнаётся по типу', () {
    expect(detectKind(mime: 'image/jpeg'), ItemKind.image);
    expect(detectKind(mime: 'audio/mp4'), ItemKind.voice);
    expect(detectKind(mime: 'video/mp4'), ItemKind.video);
    expect(detectKind(mime: 'application/pdf'), ItemKind.file);
  });

  test('первая ссылка в тексте', () {
    expect(firstUrl('смотри coffee-guide.ru/turka и ещё')!.host, 'coffee-guide.ru');
    expect(firstUrl('https://youtu.be/abc?t=5')!.toString(), 'https://youtu.be/abc?t=5');
    expect(firstUrl('просто текст'), isNull);
    expect(firstUrl('почта me@site.ru'), isNull);
  });

  test('часть почты до «@» доменом не считается', () {
    expect(urlMatches('ivan.master@mail.md'), isEmpty);
    expect(firstUrl('пиши ivan.master@mail.md'), isNull);
    expect(urlMatches('сайт mobila.md, почта a.b@c.md').map((match) => match.group(0)), ['mobila.md']);
  });
}
