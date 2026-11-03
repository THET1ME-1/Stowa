import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stowa/features/composer/panel_text.dart';
import 'package:stowa/l10n/app_localizations.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  test('подпись вещи без заголовка: по виду файла и дню', () {
    final l = lookupL(const Locale('ru'));
    final day = DateTime(2026, 11, 3, 15, 45);
    expect(untitledFor(l, mime: 'image/jpeg', fileName: 'IMG_20261103_154512.jpg', at: day), 'Фото от 3 ноября');
    expect(untitledFor(l, mime: 'image/png', fileName: 'Screenshot_20261103-154512.png', at: day), 'Скриншот от 3 ноября');
    expect(untitledFor(l, mime: 'video/mp4', fileName: 'VID_20261103.mp4', at: day), 'Видео от 3 ноября');
    expect(untitledFor(l, mime: 'audio/ogg', fileName: '1730645112.ogg', at: day), 'Запись от 3 ноября');
    expect(untitledFor(l, mime: 'application/pdf', fileName: '20261103.pdf', at: day), 'Файл от 3 ноября');
  });
}
