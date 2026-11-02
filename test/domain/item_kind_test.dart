import 'package:flutter_test/flutter_test.dart';
import 'package:kladovka/domain/item_kind.dart';
import 'package:kladovka/domain/models.dart';

void main() {
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
}
