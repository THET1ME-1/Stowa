import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/url_key.dart';

void main() {
  test('схема, www, хвостовой слеш, якорь и метки рекламы не делают адрес другим', () {
    final key = urlKey('https://eda.ru/recepty/borsch');
    expect(urlKey('http://www.eda.ru/recepty/borsch/'), key);
    expect(urlKey('https://EDA.ru/recepty/borsch#comments'), key);
    expect(urlKey('https://eda.ru/recepty/borsch?utm_source=tg&utm_medium=post&fbclid=x'), key);
  });

  test('ролик YouTube — один, каким бы адресом его ни прислали', () {
    final key = urlKey('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    expect(urlKey('https://youtu.be/dQw4w9WgXcQ?si=abc'), key);
    expect(urlKey('https://m.youtube.com/watch?v=dQw4w9WgXcQ&feature=share'), key);
    expect(urlKey('https://youtube.com/shorts/dQw4w9WgXcQ'), key);
  });

  test('смысловые параметры остаются: другая страница — другой адрес', () {
    expect(urlKey('https://rt.pornhub.com/view_video.php?viewkey=1'), isNot(urlKey('https://rt.pornhub.com/view_video.php?viewkey=2')));
    expect(urlKey('https://shop.md/item?id=5&color=red'), urlKey('https://shop.md/item?color=red&id=5'));
    expect(urlKey('https://eda.ru/a'), isNot(urlKey('https://eda.ru/b')));
  });
}
