import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_panel.dart';

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
    expect(find.text('без папки, разложу, когда появится похожее'), findsOneWidget);

    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    final item = await world.db.select(world.db.items).getSingle();
    expect(item.title, 'Зубной');
    expect(find.text('Закинул, напомню 23 декабря в 13:00'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('«напомни дома» — чип «Напомнить дома», сохраняется с местом; снял чип — без места', (tester) async {
    await open(tester);
    await type(tester, 'напомни дома купить хлеб');
    expect(find.text('Напомнить дома'), findsOneWidget);
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    var item = await world.db.select(world.db.items).getSingle();
    expect((item.remindPlace, item.title), (PlaceReminderKind.home, 'Купить хлеб'));

    await world.db.delete(world.db.items).go();
    await type(tester, 'когда приду на работу отдать ключи');
    expect(find.text('Напомнить на работе'), findsOneWidget);
    await tester.tap(find.byTooltip('Без напоминания по месту'));
    await tester.pumpAndSettle();
    expect(find.text('Напомнить на работе'), findsNothing);
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    item = await world.db.select(world.db.items).getSingle();
    expect(item.remindPlace, isNull);
  });

  testWidgets('точное слово находит вещь, белая строка у неё, кнопка открывает', (tester) async {
    await note('wifi', 'Пароль от Wi-Fi', body: 'Пароль от Wi-Fi\nСеть Keenetic, пароль zelenyi-chai-77');
    await open(tester);
    await type(tester, 'пароль');
    expect(find.text('Нашлось 1'), findsOneWidget);
    expect(find.text('Открыть'), findsOneWidget);

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.text('Пароль от Wi-Fi\nСеть Keenetic, пароль zelenyi-chai-77'), findsOneWidget);
  });

  testWidgets('время в запросе отбирает найденное, над ним — что поиск понял', (tester) async {
    await note('old', 'Пароль от Wi-Fi', daysAgo: 3);
    await note('new', 'Пароль от почты', daysAgo: 1);
    await open(tester);
    Finder inPanel(String text) => find.descendant(of: find.byType(LinePanel), matching: find.text(text));
    await type(tester, 'пароль вчера');
    expect(inPanel('Ищу: вчера'), findsOneWidget);
    expect(inPanel('Пароль от почты'), findsOneWidget);
    expect(inPanel('Пароль от Wi-Fi'), findsNothing);

    // латиницей и в чужой раскладке находит то же
    await type(tester, 'parol');
    expect(inPanel('Пароль от почты'), findsOneWidget);
    expect(inPanel('Пароль от Wi-Fi'), findsOneWidget);
    expect(find.textContaining('Ищу:'), findsNothing);
    await type(tester, 'gfhjkm');
    expect(inPanel('Пароль от Wi-Fi'), findsOneWidget);
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

  testWidgets('папка с пробелом в имени создаётся из строки и встаёт чипом', (tester) async {
    await open(tester);
    await type(tester, '@Беспроводные возможности');
    expect(find.text('Создать папку «Беспроводные возможности»'), findsOneWidget);
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    final folder = await world.db.select(world.db.folders).getSingle();
    expect(folder.name, 'Беспроводные возможности');
    // чип над строкой и плитка новой папки в ленте
    expect(find.text('Беспроводные возможности'), findsNWidgets(2));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
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

  testWidgets('раскрыл на весь экран и свернул — фокус и клавиатура на месте, поле то же', (tester) async {
    await open(tester);
    await type(tester, 'мысль');
    final field = tester.state(find.byType(EditableText));
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byTooltip('На весь экран'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(EditableText)), same(field));
    expect(tester.testTextInput.isVisible, isTrue);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>(), same(field));

    await tester.tap(find.byTooltip('Свернуть'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(EditableText)), same(field));
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('строка сворачивается плавно, а не прыжком', (tester) async {
    await open(tester);
    await type(tester, 'мысль');
    final card = find.byKey(const ValueKey('composer'));
    final compact = tester.getSize(card).height;
    await tester.tap(find.byTooltip('На весь экран'));
    await tester.pumpAndSettle();
    final full = tester.getSize(card).height;

    await tester.tap(find.byTooltip('Свернуть'));
    await tester.pump();
    // сжимается сама карточка, кадр за кадром, пружинкой макета: на старте едет быстро,
    // но через 60 мс ещё в пути, а не уже внизу
    double progress() => (full - tester.getSize(card).height) / (full - compact);
    await tester.pump(const Duration(milliseconds: 60));
    expect(progress(), inExclusiveRange(0.1, 0.8));
    // панели подсказок нет, пока строка едет
    expect(find.text('Похожего нет, это новое'), findsNothing);
    await tester.pump(const Duration(milliseconds: 120));
    expect(progress(), inExclusiveRange(0.5, 1.1));
    await tester.pumpAndSettle();
    expect(tester.getSize(card).height, closeTo(compact, 1));
    expect(find.text('Похожего нет, это новое'), findsOneWidget);
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
