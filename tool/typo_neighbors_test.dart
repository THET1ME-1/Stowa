// Собирает lib/domain/typo_neighbors.dart: основы настоящих слов, которые угадыватель
// без списка принял бы за опечатку слова темы («весьма» — «ведьма», «summer» — «simmer»).
//
// Словари — LibreOffice (github.com/LibreOffice/dictionaries), 13 файлов на 11 языков.
// Запуск после правки словарей тем:
//   tool/typo_dicts.sh <папка>
//   STOWA_DICTS=<папка> flutter test tool/typo_neighbors_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/line_query.dart';
import 'package:stowa/domain/topics.dart';

void main() {
  test('список соседей опечаток', () {
    final folder = Platform.environment['STOWA_DICTS'];
    if (folder == null) {
      markTestSkipped('нет STOWA_DICTS');
      return;
    }
    final stems = <String>{};
    for (final file in Directory(folder).listSync().whereType<File>().where((file) => file.path.endsWith('.txt'))) {
      var found = 0;
      for (final word in file.readAsLinesSync()) {
        if (topicsByTypo(word, neighbors: false).isEmpty) continue;
        stems.add(stem(normalizeQuery(word)));
        found++;
      }
      // ignore: avoid_print
      print('${file.uri.pathSegments.last}: $found');
    }
    final sorted = stems.toList()..sort();
    final lines = StringBuffer()
      ..writeln('// Собрано tool/typo_neighbors_test.dart из словарей LibreOffice, руками не править.')
      ..writeln()
      ..writeln('/// Основы настоящих слов, которые стоят в одной букве от слов тем: их не считать опечаткой.')
      ..writeln('const typoNeighbors = <String>{');
    for (var start = 0; start < sorted.length; start += 8) {
      lines.writeln("  ${sorted.skip(start).take(8).map((one) => "'${one.replaceAll("'", r"\'")}'").join(', ')},");
    }
    lines.writeln('};');
    File('lib/domain/typo_neighbors.dart').writeAsStringSync(lines.toString());
    // ignore: avoid_print
    print('основ: ${stems.length}');
  }, timeout: const Timeout(Duration(minutes: 30)));
}
