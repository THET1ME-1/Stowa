import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/note_properties.dart';

void main() {
  group('вид свойства по значению, как его выводит Obsidian', () {
    test('галочка, число, день, текст, список', () {
      expect(propertyKind(true), PropertyKind.checkbox);
      expect(propertyKind(5), PropertyKind.number);
      expect(propertyKind(4.5), PropertyKind.number);
      expect(propertyKind('2026-11-12'), PropertyKind.date);
      expect(propertyKind('Дюна'), PropertyKind.text);
      expect(propertyKind(['a', 'b']), PropertyKind.list);
    });

    test('пустое свойство и пустой список правятся как текст и список', () {
      expect(propertyKind(null), PropertyKind.text);
      expect(propertyKind(const <Object?>[]), PropertyKind.list);
    });

    test('день со временем и не день остаются текстом', () {
      expect(propertyKind('2026-11-12T10:30'), PropertyKind.text);
      expect(propertyKind('2026-11-40'), PropertyKind.text);
      expect(propertyKind('12.11.2026'), PropertyKind.text);
    });

    test('вложенное приложение только показывает', () {
      expect(propertyKind({'a': 1}), PropertyKind.other);
      expect(propertyKind([
        ['a'],
      ]), PropertyKind.other);
      expect(propertyKind([
        {'a': 1},
      ]), PropertyKind.other);
    });
  });

  group('значение свойства текстом', () {
    test('пустое, текст, число, галочка', () {
      expect(propertyText(null), '');
      expect(propertyText('Дюна'), 'Дюна');
      expect(propertyText(5), '5');
      expect(propertyText(4.5), '4.5');
      expect(propertyText(true), 'true');
    });

    test('список: в правке столбиком, в строке блока через запятую', () {
      expect(propertyText(['a', 5, null]), 'a\n5\n');
      expect(propertyText(['a', 5], separator: ', '), 'a, 5');
    });

    test('вложенное — одной строкой JSON', () {
      expect(propertyText({'a': 1, 'b': ['c']}), '{"a":1,"b":["c"]}');
    });
  });

  group('значение свойства из набранного', () {
    test('текст как есть, пустой — пустое свойство', () {
      expect(propertyValue(PropertyKind.text, ' Дюна '), 'Дюна');
      expect(propertyValue(PropertyKind.text, '5'), '5');
      expect(propertyValue(PropertyKind.text, '  '), null);
    });

    test('число: целое, дробное с точкой и с запятой, пустое', () {
      expect(propertyValue(PropertyKind.number, '5'), 5);
      expect(propertyValue(PropertyKind.number, '-4.5'), -4.5);
      expect(propertyValue(PropertyKind.number, '4,5'), 4.5);
      expect(propertyValue(PropertyKind.number, ''), null);
    });

    test('не число — ошибка, а не ноль и не текст', () {
      expect(() => propertyValue(PropertyKind.number, 'пять'), throwsFormatException);
      expect(() => propertyValue(PropertyKind.number, 'NaN'), throwsFormatException);
    });

    test('список: пункт на строку, пустые строки не пункты', () {
      expect(propertyValue(PropertyKind.list, 'a\n\n b \n'), ['a', 'b']);
      expect(propertyValue(PropertyKind.list, ''), const <Object?>[]);
    });

    test('нетронутый пункт списка остаётся числом, новый — текст', () {
      expect(propertyValue(PropertyKind.list, '5\n7\nтри', previous: [5, 'три']), [5, '7', 'три']);
    });

    test('день: строка дня, пустой — пустое свойство', () {
      expect(propertyValue(PropertyKind.date, '2026-11-12'), '2026-11-12');
      expect(propertyValue(PropertyKind.date, ''), null);
    });

    test('галочка: стоит или нет', () {
      expect(propertyValue(PropertyKind.checkbox, 'true'), true);
      expect(propertyValue(PropertyKind.checkbox, ''), false);
    });
  });

  group('день свойства', () {
    test('строка дня читается днём и пишется обратно той же строкой', () {
      expect(propertyDay('2026-11-12'), DateTime(2026, 11, 12));
      expect(propertyDayText(DateTime(2026, 3, 5, 14, 30)), '2026-03-05');
    });

    test('дня, которого нет в календаре, нет и у нас', () {
      expect(propertyDay('2026-02-31'), null);
      expect(propertyDay('Дюна'), null);
      expect(propertyDay(5), null);
    });
  });

  group('набор свойств после правки', () {
    const properties = <String, Object?>{'aliases': ['Дюна'], 'rating': 5, 'publish': null};

    test('новое свойство встаёт в конец', () {
      final next = withProperty(properties, name: 'status', value: 'читаю');
      expect(next.keys, ['aliases', 'rating', 'publish', 'status']);
      expect(next['status'], 'читаю');
    });

    test('новое значение остаётся на своём месте', () {
      final next = withProperty(properties, was: 'rating', name: 'rating', value: 4);
      expect(next.keys, ['aliases', 'rating', 'publish']);
      expect(next['rating'], 4);
    });

    test('переименованное остаётся на своём месте', () {
      final next = withProperty(properties, was: 'rating', name: 'оценка', value: 5);
      expect(next.keys, ['aliases', 'оценка', 'publish']);
    });

    test('удалённое уходит, остальные на месте', () {
      expect(withoutProperty(properties, 'rating').keys, ['aliases', 'publish']);
    });

    test('исходный набор не меняется', () {
      withProperty(properties, name: 'status', value: 1);
      withoutProperty(properties, 'rating');
      expect(properties.keys, ['aliases', 'rating', 'publish']);
    });
  });

  group('имя свойства', () {
    test('своё свойство Stowa и уже занятое завести нельзя', () {
      expect(propertyNameFree('tags', taken: const {}), false);
      expect(propertyNameFree('created', taken: const {}), false);
      expect(propertyNameFree('rating', taken: const {'rating'}), false);
      expect(propertyNameFree('rating', taken: const {'aliases'}), true);
    });

    test('пустое имя не имя', () {
      expect(propertyNameFree('  ', taken: const {}), false);
    });
  });
}
