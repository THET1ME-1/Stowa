import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/shot_date.dart';

void main() {
  test('камера, скриншот и ролик Android: дата и время из имени', () {
    expect(shotDateFromName('IMG_20260715_183012.jpg'), DateTime(2026, 7, 15, 18, 30, 12));
    expect(shotDateFromName('VID_20261012_154510.mp4'), DateTime(2026, 10, 12, 15, 45, 10));
    expect(shotDateFromName('Screenshot_20261106-141205.png'), DateTime(2026, 11, 6, 14, 12, 5));
    // у Pixel после секунд идут миллисекунды
    expect(shotDateFromName('PXL_20240503_184210123.jpg'), DateTime(2024, 5, 3, 18, 42, 10));
  });

  test('Telegram, Samsung и WhatsApp пишут дату по-своему', () {
    expect(shotDateFromName('photo_2024-05-03_18-42-10.jpg'), DateTime(2024, 5, 3, 18, 42, 10));
    expect(shotDateFromName('Screenshot_2024-05-03-18-42-10-123_com.android.chrome.jpg'), DateTime(2024, 5, 3, 18, 42, 10));
    expect(shotDateFromName('IMG-20240503-WA0001.jpg'), DateTime(2024, 5, 3));
  });

  test('без даты или с невозможной датой — null', () {
    expect(shotDateFromName('Договор.pdf'), isNull);
    expect(shotDateFromName('1730645112.ogg'), isNull);
    expect(shotDateFromName('IMG_20261345_183012.jpg'), isNull);
    expect(shotDateFromName('scan_1234567_890123.jpg'), isNull);
  });
}
