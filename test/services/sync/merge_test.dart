import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/sync/merge.dart';

void main() {
  group('mergeText', () {
    test('правки в разных строках встают обе', () {
      const base = 'один\nдва\nтри\nчетыре\n';
      const ours = 'один!\nдва\nтри\nчетыре\n';
      const theirs = 'один\nдва\nтри\nчетыре?\n';
      final result = mergeText(base, ours, theirs, oursNewer: true);
      expect(result.text, 'один!\nдва\nтри\nчетыре?\n');
      expect(result.loser, isNull);
    });

    test('одну строку правили обе стороны: остаётся свежая, вторая целиком в проигравших', () {
      const base = 'а\nб\nв\n';
      const ours = 'а\nБ наша\nв\n';
      const theirs = 'а\nБ их\nв\n';
      final newerOurs = mergeText(base, ours, theirs, oursNewer: true);
      expect(newerOurs.text, ours);
      expect(newerOurs.loser, theirs);
      final newerTheirs = mergeText(base, ours, theirs, oursNewer: false);
      expect(newerTheirs.text, theirs);
      expect(newerTheirs.loser, ours);
    });

    test('одинаковая правка с обеих сторон — не расхождение', () {
      final result = mergeText('x\ny\n', 'x\nz\n', 'x\nz\n', oursNewer: false);
      expect(result.text, 'x\nz\n');
      expect(result.loser, isNull);
    });

    test('вставка и удаление в разных местах', () {
      const base = 'a\nb\nc\nd\ne\n';
      const ours = 'a\nновая\nb\nc\nd\ne\n';
      const theirs = 'a\nb\nc\ne\n';
      final result = mergeText(base, ours, theirs, oursNewer: true);
      expect(result.text, 'a\nновая\nb\nc\ne\n');
      expect(result.loser, isNull);
    });

    test('пустая общая: строки обеих без потерь и без повторов', () {
      const ours = 'общая\nтолько наша\nконец\n';
      const theirs = 'общая\nтолько их\nконец\n';
      final result = mergeText('', ours, theirs, oursNewer: true);
      final lines = result.text.split('\n');
      expect(lines.where((l) => l == 'общая').length, 1);
      expect(lines, containsAll(['только наша', 'только их', 'конец']));
      expect(result.loser, isNull);
    });

    test('одна сторона не менялась — берётся другая', () {
      expect(mergeText('a\n', 'a\n', 'b\n', oursNewer: true).text, 'b\n');
      expect(mergeText('a\n', 'c\n', 'a\n', oursNewer: false).text, 'c\n');
    });

    test('длинная заметка склеивается быстро', () {
      final base = [for (var i = 0; i < 200000; i++) 'строка $i'].join('\n');
      final ours = base.replaceFirst('строка 10\n', 'строка десять\n');
      final theirs = base.replaceFirst('строка 199990', 'строка в конце');
      final watch = Stopwatch()..start();
      final result = mergeText(base, ours, theirs, oursNewer: true);
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
      expect(result.text, contains('строка десять'));
      expect(result.text, contains('строка в конце'));
      expect(result.loser, isNull);
    });
  });

  group('mergeJsonTables', () {
    String tables(List<Map<String, Object?>> rows) => jsonEncode({'tags': rows});
    List<Object?> rowsOf(String text) => (jsonDecode(text) as Map)['tags'] as List;

    test('добавили на одной, удалили на другой, правили разное', () {
      final base = tables([
        {'id': '1', 'name': 'дом'},
        {'id': '2', 'name': 'работа'},
        {'id': '3', 'name': 'учёба'},
      ]);
      final ours = tables([
        {'id': '1', 'name': 'дом'},
        {'id': '3', 'name': 'учёба'},
        {'id': '4', 'name': 'новая наша'},
      ]);
      final theirs = tables([
        {'id': '1', 'name': 'Дом'},
        {'id': '2', 'name': 'работа'},
        {'id': '3', 'name': 'учёба'},
        {'id': '5', 'name': 'новая их'},
      ]);
      final rows = rowsOf(mergeJsonTables(base, ours, theirs, oursNewer: true));
      expect(rows.map((r) => (r as Map)['id']).toSet(), {'1', '3', '4', '5'});
      expect(rows.firstWhere((r) => (r as Map)['id'] == '1'), {'id': '1', 'name': 'Дом'});
    });

    test('одну строку правили обе стороны — свежая', () {
      final base = tables([
        {'id': '1', 'name': 'a'},
      ]);
      final ours = tables([
        {'id': '1', 'name': 'b'},
      ]);
      final theirs = tables([
        {'id': '1', 'name': 'c'},
      ]);
      expect(rowsOf(mergeJsonTables(base, ours, theirs, oursNewer: false)), [
        {'id': '1', 'name': 'c'},
      ]);
    });

    test('пустая общая объединяет строки', () {
      final ours = tables([
        {'id': '1', 'name': 'a'},
      ]);
      final theirs = tables([
        {'id': '2', 'name': 'b'},
      ]);
      expect(rowsOf(mergeJsonTables('', ours, theirs, oursNewer: true)).length, 2);
    });

    test('не таблицы — целиком: менялась одна сторона или свежая', () {
      expect(mergeJsonTables('{"a":1}', '{"a":1}', '{"a":2}', oursNewer: true), contains('2'));
      expect(mergeJsonTables('{"a":1}', '{"a":3}', '{"a":2}', oursNewer: true), contains('3'));
    });
  });
}
