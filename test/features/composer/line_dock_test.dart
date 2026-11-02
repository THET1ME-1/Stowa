import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), text);
    // поиск ждёт паузу в наборе
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  Future<void> note(String id, String title, {String body = '', String? folder, int daysAgo = 3}) async {
    final at = world.now.subtract(Duration(days: daysAgo));
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: id,
          kind: ItemKind.note,
          title: title,
          body: Value(body.isEmpty ? title : body),
          folderId: Value(folder),
          sortState: const Value(SortState.sorted),
          createdAt: at,
          updatedAt: at,
        ));
  }

  testWidgets('новая мысль: строка «Закинуть» с причиной и напоминанием, сохраняет и чистит', (tester) async {
    await open(tester);
    await type(tester, '23 декабря 13:00 зубной');
    expect(find.text('Закинуть, папку подберу'), findsOneWidget);
    expect(find.text('напомню 23 декабря в 13:00'), findsOneWidget);
    expect(find.text('папку подберёт твой ключ ИИ'), findsOneWidget);

    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    final item = await world.db.select(world.db.items).getSingle();
    expect(item.title, 'Зубной');
    expect(find.text('Закинул, напомню 23 декабря в 13:00'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('точное слово находит вещь, белая строка у неё, кнопка открывает', (tester) async {
    await note('wifi', 'Пароль от Wi-Fi', body: 'Пароль от Wi-Fi\nСеть Keenetic, пароль zelenyi-chai-77');
    await open(tester);
    await type(tester, 'пароль');
    expect(find.text('Нашлось 1'), findsOneWidget);
    expect(find.text('Открыть'), findsOneWidget);

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.text('Сеть Keenetic, пароль zelenyi-chai-77'), findsOneWidget);
  });

  testWidgets('# показывает теги, «Вставить» делает чип', (tester) async {
    await world.db.into(world.db.tags).insert(TagsCompanion.insert(id: 't', name: 'свет', createdAt: world.now, iconValue: const Value('emoji_objects')));
    await open(tester);
    await type(tester, 'лампа над столом #св');
    expect(find.text('Теги'), findsOneWidget);
    expect(find.text('#свет'), findsOneWidget);

    await tester.tap(find.text('Вставить'));
    await tester.pumpAndSettle();
    expect(find.text('свет'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'лампа над столом ');
  });

  testWidgets('@ выбирает папку, вещь ложится в неё и строка говорит почему', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill'));
    await open(tester);
    await type(tester, '@маш');
    await tester.tap(find.text('Вставить'));
    await tester.pumpAndSettle();
    await type(tester, 'летняя резина');
    expect(find.text('Закинуть в «Машина»'), findsOneWidget);
    expect(find.text('ты выбрал папку сам'), findsOneWidget);

    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    final item = await world.db.select(world.db.items).getSingle();
    expect(item.folderId, 'car');
    expect(find.text('Легло в «Машина»'), findsOneWidget);
  });

  testWidgets('/ показывает команды, «/задача» кладёт с галочкой', (tester) async {
    await open(tester);
    await type(tester, '/за');
    expect(find.text('/задача'), findsOneWidget);
    await tester.tap(find.text('Вставить'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).controller!.text, '/задача ');

    await type(tester, '/задача купить батарейки');
    expect(find.text('Задача, папку подберу'), findsOneWidget);
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    final item = await world.db.select(world.db.items).getSingle();
    expect(item.body, '- [ ] купить батарейки');
    expect(item.title, 'Купить батарейки');
  });

  testWidgets('похожая заметка: «Дописать» кладёт мысль в неё', (tester) async {
    await note('weather', 'Погода для пары', body: 'Погода для пары\nвиджет показывает погоду у второго');
    await open(tester);
    await type(tester, 'виджет погоды для пары чтобы видеть небо');
    expect(find.text('Дописать'), findsOneWidget);

    await tester.tap(find.text('Дописать'));
    await tester.pumpAndSettle();
    final item = await world.db.select(world.db.items).getSingle();
    expect(item.body, endsWith('Виджет погоды для пары чтобы видеть небо'));
    expect(find.text('Дописал в «Погода для пары»'), findsOneWidget);
  });

  testWidgets('«Отменить» убирает вещь и возвращает текст в строку', (tester) async {
    await open(tester);
    await type(tester, 'купить хлеб');
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'купить хлеб');
    final live = await (world.db.select(world.db.items)..where((t) => t.deletedAt.isNull())).get();
    expect(live, isEmpty);
  });

  testWidgets('на весь экран: панель разметки, заголовок встаёт в начало строки', (tester) async {
    await open(tester);
    await type(tester, 'Поездка в Грецию');
    await tester.tap(find.byTooltip('На весь экран'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Заголовок'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '# Поездка в Грецию');
    expect(find.text('Папку подберу'), findsOneWidget);
  });

  testWidgets('касание закреплённого тега показывает вещи с ним', (tester) async {
    await world.db.into(world.db.tags).insert(TagsCompanion.insert(id: 't', name: 'код', createdAt: world.now, pinned: const Value(true)));
    await note('wifi', 'Пароль от Wi-Fi');
    await note('door', 'Код домофона');
    for (final id in ['wifi', 'door']) {
      await world.db.into(world.db.itemTags).insert(ItemTagsCompanion.insert(itemId: id, tagId: 't', source: TagSource.user));
    }
    await open(tester);
    await tester.tap(find.byTooltip('#код'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Нашлось 2'), findsOneWidget);
  });

  testWidgets('панель с находками влезает в 320 точек при крупном шрифте', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await note('a', 'Погода для пары в Togetherly');
    await note('b', 'Погода на выходные в горах');
    await open(tester);
    await type(tester, 'погода завтра в 10 #дом');
    expect(tester.takeException(), isNull);
  });
}
