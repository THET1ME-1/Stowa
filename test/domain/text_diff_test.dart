import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/text_diff.dart';

void main() {
  String show(List<DiffLine> lines) => [
    for (final line in lines) '${switch (line.kind) { DiffKind.same => ' ', DiffKind.added => '+', DiffKind.removed => '-' }}${line.text}',
  ].join('\n');

  test('одинаковые строки остаются, убранные и добавленные помечены', () {
    final diff = diffLines('Ремонт\nкупить клей\nплитка', 'Ремонт\nплитка\nзатирка');
    expect(show(diff), ' Ремонт\n-купить клей\n плитка\n+затирка');
  });

  test('изменённая строка — убранная и добавленная рядом', () {
    expect(show(diffLines('а\nб\nв', 'а\nБ\nв')), ' а\n-б\n+Б\n в');
  });

  test('пусто с одной стороны', () {
    expect(show(diffLines('', 'новое')), '+новое');
    expect(show(diffLines('старое', '')), '-старое');
    expect(diffLines('', ''), isEmpty);
  });

  test('огромный текст не вешает: без поиска общих строк', () {
    final a = List.generate(5000, (index) => 'строка $index').join('\n');
    final b = List.generate(5000, (index) => 'строка ${index + 1}').join('\n');
    final started = DateTime.now();
    final diff = diffLines(a, b);
    expect(DateTime.now().difference(started).inSeconds, lessThan(3));
    expect(diff.where((line) => line.kind == DiffKind.added), isNotEmpty);
  });

  test('сводка: сколько строк добавлено и убрано', () {
    final diff = diffLines('а\nб', 'а\nв\nг');
    expect(diffCounts(diff), (added: 2, removed: 1));
  });
}
