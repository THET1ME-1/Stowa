import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/vault_note.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  const block = ValueKey('item-properties');
  const nameField = ValueKey('property-name-field');
  const valueField = ValueKey('property-value-field');

  Future<void> open(WidgetTester tester, Map<String, Object?> properties) async {
    await world.db
        .into(world.db.items)
        .insert(
          ItemsCompanion.insert(
            id: 'a',
            kind: ItemKind.note,
            title: 'Дюна',
            body: const Value('Дюна\nчитаю вторую часть'),
            properties: Value(packVaultProperties(properties)),
            createdAt: world.now,
            updatedAt: world.now,
          ),
        );
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
  }

  Future<Map<String, Object?>> saved() async {
    final item = await (world.db.select(world.db.items)..where((t) => t.id.equals('a'))).getSingle();
    return unpackVaultProperties(item.properties);
  }

  Future<void> tapRow(WidgetTester tester, String name) async {
    final row = find.byKey(ValueKey('property-row-$name'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  const book = <String, Object?>{
    'aliases': ['Дюна', 'Dune'],
    'rating': 5,
    'read': true,
    'publish': null,
  };

  testWidgets('у заметки без свойств блока нет', (tester) async {
    await open(tester, const {});
    expect(find.byKey(block), findsNothing);
  });

  testWidgets('свойства из файла видны: список через запятую, число, галочка словом', (tester) async {
    await open(tester, book);
    Finder inBlock(String text) => find.descendant(of: find.byKey(block), matching: find.text(text));
    expect(inBlock('Свойства'), findsOneWidget);
    expect(inBlock('aliases'), findsOneWidget);
    expect(inBlock('Дюна, Dune'), findsOneWidget);
    expect(inBlock('5'), findsOneWidget);
    expect(inBlock('Да'), findsOneWidget);
    expect(inBlock('publish'), findsOneWidget);
  });

  testWidgets('касание по свойству открывает правку: новое число ложится на то же место', (tester) async {
    await open(tester, book);
    await tapRow(tester, 'rating');
    await tester.enterText(find.byKey(valueField), '4');
    await tester.pumpAndSettle();
    await tapText(tester, 'Сохранить');
    final properties = await saved();
    expect(properties.keys, ['aliases', 'rating', 'read', 'publish']);
    expect(properties['rating'], 4);
  });

  testWidgets('не число в числовом свойстве не сохраняется', (tester) async {
    await open(tester, book);
    await tapRow(tester, 'rating');
    await tester.enterText(find.byKey(valueField), 'пять');
    await tester.pumpAndSettle();
    expect(find.text('Здесь нужно число'), findsOneWidget);
    await tapText(tester, 'Сохранить');
    expect((await saved())['rating'], 5);
  });

  testWidgets('список правится столбиком, пункт на строку', (tester) async {
    await open(tester, book);
    await tapRow(tester, 'aliases');
    expect(tester.widget<TextField>(find.byKey(valueField)).controller!.text, 'Дюна\nDune');
    await tester.enterText(find.byKey(valueField), 'Дюна\nDune\nАрракис');
    await tester.pumpAndSettle();
    await tapText(tester, 'Сохранить');
    expect((await saved())['aliases'], ['Дюна', 'Dune', 'Арракис']);
  });

  testWidgets('галочка снимается переключателем', (tester) async {
    await open(tester, book);
    await tapRow(tester, 'read');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tapText(tester, 'Сохранить');
    expect((await saved())['read'], false);
  });

  testWidgets('«Добавить свойство» в блоке: новое встаёт в конец', (tester) async {
    await open(tester, book);
    await tapText(tester, 'Добавить свойство');
    await tester.enterText(find.byKey(nameField), 'status');
    await tester.enterText(find.byKey(valueField), 'читаю');
    await tester.pumpAndSettle();
    await tapText(tester, 'Сохранить');
    final properties = await saved();
    expect(properties.keys.last, 'status');
    expect(properties['status'], 'читаю');
    expect(find.descendant(of: find.byKey(block), matching: find.text('читаю')), findsOneWidget);
  });

  testWidgets('дата выбирается в календаре и пишется днём, как в Obsidian', (tester) async {
    await open(tester, book);
    await tapText(tester, 'Добавить свойство');
    await tester.enterText(find.byKey(nameField), 'started');
    await tester.pumpAndSettle();
    await tapText(tester, 'Дата');
    await tapText(tester, 'Выбрать день');
    await tester.tap(find.text('12'));
    await tester.tap(find.text('ОК'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Сохранить');
    expect((await saved())['started'], '2026-11-12');
  });

  testWidgets('день переезжает в текст и обратно: смена вида его не теряет', (tester) async {
    await open(tester, {'started': '2026-11-12'});
    await tapRow(tester, 'started');
    await tapText(tester, 'Текст');
    expect(tester.widget<TextField>(find.byKey(valueField)).controller!.text, '2026-11-12');
    await tester.enterText(find.byKey(valueField), '2026-11-15');
    await tester.pumpAndSettle();
    await tapText(tester, 'Дата');
    await tapText(tester, 'Сохранить');
    expect((await saved())['started'], '2026-11-15');
  });

  testWidgets('имя, которое Stowa ведёт сама, и занятое имя завести нельзя', (tester) async {
    await open(tester, book);
    await tapText(tester, 'Добавить свойство');
    await tester.enterText(find.byKey(nameField), 'tags');
    await tester.pumpAndSettle();
    expect(find.text('Такое свойство уже есть'), findsOneWidget);
    await tapText(tester, 'Сохранить');
    expect((await saved()).containsKey('tags'), false);
    await tester.enterText(find.byKey(nameField), 'rating');
    await tester.pumpAndSettle();
    expect(find.text('Такое свойство уже есть'), findsOneWidget);
  });

  testWidgets('«Удалить свойство» убирает его, «Отменить» возвращает на место', (tester) async {
    await open(tester, book);
    await tapRow(tester, 'rating');
    await tapText(tester, 'Удалить свойство');
    expect((await saved()).keys, ['aliases', 'read', 'publish']);
    expect(find.text('Свойство удалено'), findsOneWidget);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(await saved(), book);
    expect((await saved()).keys, ['aliases', 'rating', 'read', 'publish']);
  });

  testWidgets('«⋮» → «Добавить свойство» заводит первое свойство заметки', (tester) async {
    await open(tester, const {});
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Добавить свойство');
    await tester.enterText(find.byKey(nameField), 'rating');
    await tester.pumpAndSettle();
    await tapText(tester, 'Число');
    await tester.enterText(find.byKey(valueField), '4,5');
    await tester.pumpAndSettle();
    await tapText(tester, 'Сохранить');
    expect(await saved(), {'rating': 4.5});
    expect(find.byKey(block), findsOneWidget);
  });

  testWidgets('длинный набор свёрнут до четырёх строк, «Ещё 3» показывает остальные', (tester) async {
    await open(tester, {for (var index = 1; index <= 7; index++) 'свойство $index': index});
    expect(find.byKey(const ValueKey('property-row-свойство 4')), findsOneWidget);
    expect(find.byKey(const ValueKey('property-row-свойство 5')), findsNothing);
    await tapText(tester, 'Ещё 3');
    expect(find.byKey(const ValueKey('property-row-свойство 7')), findsOneWidget);
    await tapText(tester, 'Свернуть');
    expect(find.byKey(const ValueKey('property-row-свойство 5')), findsNothing);
  });

  testWidgets('вложенное значение только показано: поменять можно имя, значение цело', (tester) async {
    await open(tester, {
      'source': {'site': 'habr', 'year': 2026},
    });
    await tapRow(tester, 'source');
    expect(find.byKey(valueField), findsNothing);
    expect(find.text('Такое значение меняется в файле заметки.'), findsOneWidget);
    await tester.enterText(find.byKey(nameField), 'откуда');
    await tester.pumpAndSettle();
    await tapText(tester, 'Сохранить');
    expect(await saved(), {
      'откуда': {'site': 'habr', 'year': 2026},
    });
  });

  testWidgets('320 точек и шрифт 1,3: блок и лист свойства не вылезают', (tester) async {
    tester.view.physicalSize = const Size(640, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, {
      'очень длинное название свойства заметки': 'и такое же длинное значение, которое не влезает в строку',
      'aliases': ['Дюна', 'Dune', 'Арракис', 'Пряность должна течь'],
      for (var index = 1; index <= 5; index++) 'свойство $index': index,
    });
    expect(tester.takeException(), isNull);
    await tapRow(tester, 'aliases');
    expect(tester.takeException(), isNull);
    for (final kind in ['Текст', 'Число', 'Галочка', 'Дата', 'Список']) {
      await tapText(tester, kind);
      expect(tester.takeException(), isNull, reason: kind);
    }
  });
}
