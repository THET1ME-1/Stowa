import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/obsidian_base.dart';

final _now = DateTime(2026, 11, 15, 12);

BaseNote _note(String path, {List<String> tags = const [], List<String> links = const [], Map<String, Object?> props = const {}, DateTime? mtime}) =>
    BaseNote(id: path, path: path, tags: tags, links: links, properties: props, created: DateTime(2026, 1, 1), modified: mtime ?? DateTime(2026, 11, 1));

final _notes = [
  _note('Книги/Сто лет одиночества.md', tags: ['книга', 'читать/потом'], props: {'author': 'Маркес', 'rating': 5, 'status': 'прочитано', 'year': 1967}),
  _note('Книги/Мастер и Маргарита.md', tags: ['книга'], props: {'author': 'Булгаков', 'rating': 4, 'status': 'читаю'}, mtime: DateTime(2026, 11, 14)),
  _note('Книги/Старое/Идиот.md', tags: ['книга'], props: {'author': 'Достоевский', 'rating': 3, 'status': 'прочитано'}),
  _note('Дом/Ремонт кухни.md', tags: ['ремонт'], links: ['Идеи для кухни'], props: {'price': 9840}, mtime: DateTime(2026, 11, 15, 10)),
];

void main() {
  test('разбор файла: фильтры, формулы, подписи и виды', () {
    final base = ObsidianBase.parse('''
filters:
  and:
    - file.inFolder("Книги")
    - 'file.ext == "md"'
formulas:
  stars: 'rating * 2'
properties:
  note.author:
    displayName: Автор
views:
  - type: table
    name: Все книги
    order: [file.name, note.author, rating, formula.stars]
    sort:
      - property: rating
        direction: DESC
  - type: cards
    name: Читаю
    filters:
      and:
        - status == "читаю"
''');
    expect(base.broken, isFalse);
    expect(base.views.map((view) => (view.type, view.name)), [(BaseViewType.table, 'Все книги'), (BaseViewType.cards, 'Читаю')]);
    expect(base.views.first.order, ['file.name', 'note.author', 'rating', 'formula.stars']);
    expect(base.displayName('note.author'), 'Автор');
    expect(base.displayName('author'), 'Автор');
    // своих подписей у file.* нет: их даёт экран на языке приложения
    expect(base.displayName('file.name'), isNull);

    final all = base.run(0, _notes, now: _now);
    expect(all.rows.map((note) => note.basename), ['Сто лет одиночества', 'Мастер и Маргарита', 'Идиот']);
    expect(all.unsupported, isFalse);
    expect(base.value(all.rows.first, 'formula.stars', now: _now), 10);
    expect(base.value(all.rows.first, 'note.author', now: _now), 'Маркес');

    final reading = base.run(1, _notes, now: _now);
    expect(reading.rows.single.basename, 'Мастер и Маргарита');
  });

  test('теги с вложенными, ссылки, not и or', () {
    BaseResult run(String filters) => ObsidianBase.parse('filters:\n$filters\nviews:\n  - type: list\n    name: Список\n').run(0, _notes, now: _now);
    expect(run('  and:\n    - file.hasTag("читать")').rows.single.basename, 'Сто лет одиночества');
    expect(run('  and:\n    - file.hasLink("Идеи для кухни")').rows.single.basename, 'Ремонт кухни');
    expect(run('  not:\n    - file.inFolder("Книги")').rows.single.basename, 'Ремонт кухни');
    expect(run('  or:\n    - rating >= 5\n    - price > 9000').rows.map((n) => n.basename), ['Сто лет одиночества', 'Ремонт кухни']);
    expect(run("  and:\n    - '!file.inFolder(\"Книги\") || author == \"Маркес\"'").rows.length, 2);
  });

  test('даты: правленные за последние три дня', () {
    final result = ObsidianBase.parse('filters: \'file.mtime > now() - "3 days"\'\nviews:\n  - type: table\n    name: Свежие\n').run(0, _notes, now: _now);
    expect(result.rows.map((n) => n.basename), ['Мастер и Маргарита', 'Ремонт кухни']);
  });

  test('строки: contains, startsWith, lower; длина списка', () {
    BaseResult run(String expr) => ObsidianBase.parse("filters: '$expr'\nviews:\n  - type: table\n    name: x\n").run(0, _notes, now: _now);
    expect(run('author.lower().contains("бул")').rows.single.basename, 'Мастер и Маргарита');
    expect(run('file.name.startsWith("Ид")').rows.single.basename, 'Идиот');
    expect(run('file.tags.length > 1').rows.single.basename, 'Сто лет одиночества');
  });

  test('сортировка, предел и группы', () {
    final base = ObsidianBase.parse('''
filters: file.inFolder("Книги")
views:
  - type: table
    name: По статусу
    groupBy:
      property: status
      direction: ASC
    sort:
      - property: rating
        direction: ASC
    limit: 2
''');
    final result = base.run(0, _notes, now: _now);
    expect(result.rows.map((n) => n.basename), ['Идиот', 'Мастер и Маргарита']);
    expect(result.groups!.map((group) => group.key), ['прочитано', 'читаю']);
  });

  test('непонятное условие не прячет заметки молча: оно пропускается с пометкой', () {
    final result = ObsidianBase.parse('filters:\n  and:\n    - file.inFolder("Книги")\n    - file.hasProperty("x").map(v => v)\nviews:\n  - type: table\n    name: x\n').run(0, _notes, now: _now);
    expect(result.unsupported, isTrue);
    expect(result.rows, hasLength(3));
  });

  test('битый YAML и вид «Карта» — без падения', () {
    expect(ObsidianBase.parse('views: [').broken, isTrue);
    final map = ObsidianBase.parse('views:\n  - type: map\n    name: Карта\n');
    expect(map.views.single.type, BaseViewType.map);
    expect(ObsidianBase.parse('').views.single.type, BaseViewType.table);
  });

  test('новая база папки: условие на папку и таблица с названием и датой', () {
    final text = newBaseFor('Дом/Ремонт');
    final base = ObsidianBase.parse(text);
    expect(base.run(0, [..._notes, _note('Дом/Ремонт/Плитка.md')], now: _now).rows.single.basename, 'Плитка');
    expect(base.views.single.order, ['file.name', 'file.mtime']);
  });
}
