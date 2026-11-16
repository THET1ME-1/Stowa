import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/obsidian_base.dart';

final _now = DateTime(2026, 11, 15, 12);

BaseNote _note(String path, Map<String, Object?> props, {DateTime? created}) =>
    BaseNote(id: path, path: path, tags: const ['книга'], links: const [], properties: props, created: created ?? DateTime(2026, 1, 1), modified: DateTime(2026, 11, 1));

/// Формулы из настоящей «Библиотеки»: скобки у свойства, список, лямбды filter и reduce.
const _library = '''
formulas:
  scores: '[note["Качество озвучки"], note["Качество сюжета"], note["Проработка персонажей"]].filter(!value.isEmpty())'
  avg: if(formula.scores.isEmpty(), 0, formula.scores.reduce(acc + value, 0) / formula.scores.length)
  rating: if(formula.scores.isEmpty(), "", "⛊".repeat(formula.avg.floor()) + "⛉".repeat(10 - formula.avg.floor()))
  readings: if(note["Прочтения"].isEmpty(), 0, note["Прочтения"].length)
views:
  - type: cards
    name: Перечитанное
    filters:
      and:
        - file.folder == "03 Библиотека/Книги"
        - formula.readings > 1
    order: []
    sort:
      - property: formula.readings
        direction: DESC
    image: note.Обложка
    cardSize: 210
    imageAspectRatio: 1.6
''';

void main() {
  final dune = _note('03 Библиотека/Книги/Дюна.md', {
    'Качество озвучки': 8,
    'Качество сюжета': 9,
    'Проработка персонажей': null,
    'Прочтения': ['2024-01-01', '2026-03-01'],
    'Обложка': '[[Обложки/Дюна.jpg]]',
  });
  final idiot = _note('03 Библиотека/Книги/Идиот.md', {'Прочтения': ['2025-05-05']});

  test('формулы «Библиотеки»: оценки без пустых, среднее, полоска звёзд, число прочтений', () {
    final base = ObsidianBase.parse(_library);
    expect(base.value(dune, 'formula.scores', now: _now), [8, 9]);
    expect(base.value(dune, 'formula.avg', now: _now), 8.5);
    expect(base.value(dune, 'formula.rating', now: _now), '⛊' * 8 + '⛉' * 2);
    expect(base.value(dune, 'formula.readings', now: _now), 2);
    expect(base.value(idiot, 'formula.rating', now: _now), '');

    final result = base.run(0, [idiot, dune], now: _now);
    expect(result.unsupported, isFalse);
    expect(result.rows.single, dune);
  });

  test('настройки карточек: картинка из свойства, размер, пропорция', () {
    final view = ObsidianBase.parse(_library).views.single;
    expect(view.image, 'note.Обложка');
    expect(view.cardSize, 210);
    expect(view.imageAspectRatio, 1.6);
    expect(view.imageFit, BaseImageFit.cover);
  });

  Object? eval(String formula, {Map<String, Object?> props = const {}}) =>
      ObsidianBase.parse('formulas:\n  x: \'${formula.replaceAll("'", "''")}\'\n').value(_note('Папка/Заметка.md', props, created: DateTime(2026, 3, 8, 9, 5)), 'formula.x', now: _now);

  test('числа: остаток, округление, знаки после запятой, модуль, min и max', () {
    expect(eval('7 % 3'), 1);
    expect(eval('(2.567).round(1)'), 2.6);
    expect(eval('(2.5).toFixed(2)'), '2.50');
    expect(eval('(-3).abs()'), 3);
    expect(eval('(4.2).ceil()'), 5);
    expect(eval('max(3, 9, 4)'), 9);
    expect(eval('min(3, 9, 4)'), 3);
    expect(eval('number("12") + 1'), 13);
  });

  test('строки: замена, разбиение, срез, длина, заглавная буква', () {
    // строкой заменяются все вхождения, выражением без g — первое
    expect(eval('"a-b-c".replace("-", "+")'), 'a+b+c');
    expect(eval('"a-b-c".replace(/-/, "+")'), 'a+b-c');
    expect(eval('"a1b22".replace(/[0-9]+/g, "#")'), 'a#b#');
    expect(eval('/^Вой/.matches("Война")'), true);
    expect(eval('"a,b".split(",")'), ['a', 'b']);
    expect(eval('"Москва".slice(0, 3)'), 'Мос');
    expect(eval('"кот".length'), 3);
    expect(eval('"война и мир".title()'), 'Война И Мир');
    expect(eval('"абв".reverse()'), 'вба');
    expect(eval('"ab".isEmpty()'), false);
  });

  test('списки: map, sort, unique, flat, slice, reverse, длина и индекс', () {
    expect(eval('[3, 1, 2].map(value * 10)'), [30, 10, 20]);
    expect(eval('[3, 1, 2].sort()'), [1, 2, 3]);
    expect(eval('[1, 1, 2].unique()'), [1, 2]);
    expect(eval('[[1], [2, 3]].flat()'), [1, 2, 3]);
    expect(eval('[1, 2, 3].slice(1)'), [2, 3]);
    expect(eval('[1, 2, 3].reverse()'), [3, 2, 1]);
    expect(eval('["a", "b"].map(index)'), [0, 1]);
    expect(eval('[5, 6][1]'), 6);
    expect(eval('tags.length', props: {'tags': ['x', 'y']}), 2);
  });

  test('даты: части, формат, сравнение с длительностью, файл и его время', () {
    expect(eval('file.ctime.year'), 2026);
    expect(eval('file.ctime.month'), 3);
    expect(eval('file.ctime.day'), 8);
    expect(eval('file.ctime.format("YYYY-MM-DD HH:mm")'), '2026-03-08 09:05');
    expect(eval('date("2026-11-01").format("DD.MM.YYYY")'), '01.11.2026');
    expect(eval('now() - "30d" > date("2026-10-01")'), true);
    expect(eval('file.ctime.date() == date("2026-03-08")'), true);
    expect(eval('(date("2026-11-15") - date("2026-11-10")).days'), 5);
    expect(eval('file.ctime < now() - duration("1 week")'), true);
    expect(eval('file.hasProperty("автор")', props: {'автор': 'Толстой'}), true);
    expect(eval('file.name + "!"'), 'Заметка!');
  });

  test('итоги колонки: готовые и свой из summaries файла', () {
    final base = ObsidianBase.parse('summaries:\n  half: values.mean() / 2\nviews:\n  - type: table\n    summaries:\n      note.rating: Average\n');
    expect(base.views.single.summaryOf('rating'), 'Average');
    expect(base.summary('Average', [4, 5, null, 'x'], now: _now), 4.5);
    expect(base.summary('Median', [1, 9, 3], now: _now), 3);
    expect(base.summary('Sum', [1, 2], now: _now), 3);
    expect(base.summary('Filled', [1, null, '', []], now: _now), 1);
    expect(base.summary('Empty', [1, null, '', []], now: _now), 3);
    expect(base.summary('Unique', ['a', 'a', 'b'], now: _now), 2);
    expect(base.summary('Checked', [true, false, null], now: _now), 1);
    expect(base.summary('Earliest', ['2026-03-01', '2025-01-01'], now: _now), DateTime(2025));
    expect(base.summary('half', [2, 4], now: _now), 1.5);
  });

  test('поиск по показанным свойствам без регистра и надстрочных знаков; всего до предела', () {
    final base = ObsidianBase.parse('views:\n  - type: table\n    limit: 1\n    order: [file.name, author]\n');
    final notes = [_note('Кафе.md', {'author': 'Café Noir'}), _note('Дом.md', {'author': 'Пушкин'}), _note('Сад.md', {'author': 'cafe'})];
    final found = base.run(0, notes, now: _now, search: 'CAFE');
    expect(found.rows.single.basename, 'Кафе');
    expect(found.total, 2);
    expect(base.run(0, notes, now: _now, search: 'дом').rows.single.basename, 'Дом');
  });

  test('проверка выражения: понятное — null, сломанное — что не так', () {
    expect(ObsidianBase.check('rating > 3 && file.hasTag("книга")'), isNull);
    expect(ObsidianBase.check('rating > (3'), isNotNull);
  });

  test('свойство по имени с пробелом через note[…] и note.x', () {
    expect(eval('note["Дата прочтения"]', props: {'Дата прочтения': '2026-01-02'}), '2026-01-02');
    expect(eval('note.автор', props: {'автор': 'Пушкин'}), 'Пушкин');
  });

  test('доска: колонка-список «Прочитал, Любимое» отдаёт сам список, а не одну склеенную строку', () {
    final rows = [
      _note('А.md', {'Метки': ['Прочитал', 'Любимое']}),
      _note('Б.md', {'Метки': ['В работе']}),
    ];
    expect(boardColumnValue(rows, 'Метки', 'Прочитал, Любимое'), ['Прочитал', 'Любимое']);
    expect(boardColumnValue(rows, 'Метки', 'Новое'), ['Новое']);
    expect(boardColumnValue([_note('В.md', {'Статус': 'Готово'})], 'Статус', 'Готово'), 'Готово');
  });
}
