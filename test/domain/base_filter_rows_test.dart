import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/base_edit.dart';
import 'package:stowa/domain/base_filter_rows.dart';
import 'package:stowa/domain/obsidian_base.dart';

void main() {
  test('строки фильтра из выражений: свойство, условие, значение', () {
    FilterRow row(String source) => FilterRow.parse(source);
    expect(row('Метки.contains("Прочитал")'), const FilterRow('Метки', FilterOp.contains, 'Прочитал'));
    expect(row('!Метки.contains("Не зашло")'), const FilterRow('Метки', FilterOp.notContains, 'Не зашло'));
    expect(row('file.folder == "03 Библиотека/Книги"'), const FilterRow('file.folder', FilterOp.isEqual, '03 Библиотека/Книги'));
    expect(row('note["Курс обучения"] >= 2'), const FilterRow('Курс обучения', FilterOp.atLeast, '2', quoted: false));
    expect(row('formula.readings > 1'), const FilterRow('formula.readings', FilterOp.greater, '1', quoted: false));
    expect(row('file.folder.startsWith("01 Конспекты")'), const FilterRow('file.folder', FilterOp.startsWith, '01 Конспекты'));
    expect(row('status.isEmpty()'), const FilterRow('status', FilterOp.isEmpty, ''));
    expect(row('!status.isEmpty()'), const FilterRow('status', FilterOp.isNotEmpty, ''));
    expect(row('file.hasTag("книга")'), const FilterRow('file.tags', FilterOp.hasTag, 'книга'));
    expect(row('file.inFolder("Дом")'), const FilterRow('file.folder', FilterOp.inFolder, 'Дом'));
    expect(row('done == true'), const FilterRow('done', FilterOp.isEqual, 'true', quoted: false));
    // то, что строкой не разложить, остаётся выражением и не портится
    expect(row('file.mtime > now() - "30d"'), const FilterRow.expression('file.mtime > now() - "30d"'));
  });

  test('строка обратно в выражение: имя с пробелом через note[…], кавычки экранируются', () {
    expect(const FilterRow('Курс обучения', FilterOp.isNot, 'Он сказал "да"').source, r'note["Курс обучения"] != "Он сказал \"да\""');
    expect(const FilterRow('Метки', FilterOp.notContains, 'x').source, '!Метки.contains("x")');
    expect(const FilterRow('rating', FilterOp.atMost, '3', quoted: false).source, 'rating <= 3');
    expect(const FilterRow('file.tags', FilterOp.hasTag, '#книга').source, 'file.hasTag("книга")');
    expect(const FilterRow.expression('a > 1').source, 'a > 1');
    // значение набрали числом — без кавычек, словом — в кавычках
    expect(const FilterRow('rating', FilterOp.isEqual, '').withValue('5').source, 'rating == 5');
    expect(const FilterRow('status', FilterOp.isEqual, '').withValue('читаю').source, 'status == "читаю"');
  });

  test('новая заметка из вида: папка, свойства и теги из условий «все»', () {
    final base = ObsidianBase.parse('''
filters:
  and:
    - file.inFolder("03 Библиотека/Книги")
views:
  - type: cards
    name: Прочитано
    filters:
      and:
        - Метки.contains("Прочитал")
        - note["Курс обучения"] == 2
        - status == "готово"
        - file.hasTag("книга")
        - formula.readings > 1
        - or:
            - a == 1
            - b == 2
''');
    final made = newNoteDefaults(base, 0);
    expect(made.folder, '03 Библиотека/Книги');
    expect(made.properties, {
      'Метки': ['Прочитал'],
      'Курс обучения': 2,
      'status': 'готово',
    });
    expect(made.tags, ['книга']);
    // в колонке канбана значение группы тоже ложится в свойство
    expect(newNoteDefaults(base, 0, group: ('status', 'в работе')).properties['status'], 'в работе');
  });

  test('группы: and/or/not туда и обратно, пустое — без фильтра', () {
    const filter = BaseAnd([
      BaseExpr('file.folder == "Книги"'),
      BaseOr([BaseExpr('rating > 3'), BaseExpr('file.hasTag("топ")')]),
      BaseNot([BaseExpr('status.isEmpty()')]),
    ]);
    final group = FilterGroup.from(filter);
    expect(group.join, FilterJoin.all);
    expect(group.items, hasLength(3));
    expect((group.items[1] as FilterGroup).join, FilterJoin.any);
    expect((group.items[2] as FilterGroup).join, FilterJoin.none);
    expect(describeFilter(group.toFilter()), describeFilter(filter));
    // одно выражение строкой — группа «все» из одной строки
    expect(FilterGroup.from(const BaseExpr('a > 1')).items.single, const FilterRow('a', FilterOp.greater, '1', quoted: false));
    expect(const FilterGroup(FilterJoin.all, []).toFilter(), isNull);
    expect(FilterGroup.from(null).items, isEmpty);
  });

  test('недописанное условие (значения ещё нет) в файл не идёт и заметки не прячет', () {
    const group = FilterGroup(FilterJoin.all, [
      FilterRow('file.links', FilterOp.hasLink, ''),
      FilterRow('Автор', FilterOp.isEqual, '  '),
      FilterRow('Метки', FilterOp.isNotEmpty, ''),
    ]);
    expect(describeFilter(group.toFilter()), 'and(!Метки.isEmpty())');
    expect(const FilterGroup(FilterJoin.all, [FilterRow('Автор', FilterOp.contains, '')]).toFilter(), isNull);
  });
}
