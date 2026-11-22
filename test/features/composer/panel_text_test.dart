import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stowa/domain/line_query.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/search_rank.dart';
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

  test('команды строки: язык интерфейса первым, слова всех семи языков, своё слово у каждого языка', () {
    final keys = commandKeys(lookupL(const Locale('de')));
    expect(keys[LineCommand.task]!.first, 'aufgabe');
    expect(keys[LineCommand.task], containsAll(['задача', 'task', 'завдання', 'sarcină', 'zadanie', 'tarea']));
    expect(keys[LineCommand.canvas], containsAll(['холст', 'canvas', 'leinwand', 'lienzo']));
    expect(keys[LineCommand.base], containsAll(['база', 'base', 'basis']));
    // одно и то же слово не может значить две разные команды
    final owners = <String, LineCommand>{};
    for (final MapEntry(key: command, value: words) in keys.entries) {
      for (final word in words) {
        expect(owners.putIfAbsent(word, () => command), command, reason: word);
      }
    }
    // строка под замком холст и базу не заводит
    expect(commandKeys(lookupL(const Locale('ru')), documents: false).keys, isNot(contains(LineCommand.canvas)));
  });

  // хозяин 22.11: «Холст — это не название, а тип заметки» — без своего имени, как в Obsidian
  test('имя холста или базы из строки: первая строка, без неё — «Без названия»', () {
    final l = lookupL(const Locale('ru'));
    expect(documentName(l, LineCommand.canvas, '  План ремонта\nвторая строка'), 'План ремонта');
    expect(documentName(l, LineCommand.base, ' '), 'Без названия');
    expect(documentName(l, LineCommand.canvas, ''), 'Без названия');
  });

  test('где нашлось в статье: в её тексте или в цитате', () {
    final l = lookupL(const Locale('ru'));
    expect(factLabel(l, const FactPart(FactKind.articleText, 'текст')), 'в статье');
    expect(factLabel(l, const FactPart(FactKind.highlight, 'цитата')), 'в цитате');
  });
}
