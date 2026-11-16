import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/icons/icon_registry.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart' show ItemCard;
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/services/capture_service.dart' show PickedFile;
import 'package:stowa/features/folder/folder_cards.dart';
import 'package:stowa/features/home/folder_shelf.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> seed() async {
    final db = world.db;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Рецепты', icon: 'restaurant', shape: 'cookie9'));
    final kinds = [
      ('n', ItemKind.note, 'Борщ как у бабушки', null),
      ('l', ItemKind.link, 'Как варить кофе в турке', 'https://coffee-guide.ru/turka'),
      ('v', ItemKind.video, 'Тарт с малиной', 'https://www.tiktok.com/@chef/1'),
    ];
    for (final (index, (id, kind, title, url)) in kinds.indexed) {
      final at = world.now.subtract(Duration(minutes: 10 - index));
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: id,
            kind: kind,
            title: title,
            body: Value(title),
            url: Value(url),
            folderId: const Value('food'),
            sortState: const Value(SortState.sorted),
            createdAt: at,
            updatedAt: at,
          ));
    }
  }

  Future<void> openFolder(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    // имя папки есть и в подписях карточек «Только что», жмём по плитке
    await tester.tap(find.descendant(of: find.byType(FolderPill), matching: find.text('Рецепты')));
    await tester.pumpAndSettle();
  }

  testWidgets('тап по папке на главной открывает её: имя, число, все вещи', (tester) async {
    await seed();
    await openFolder(tester);
    expect(find.text('Рецепты'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Борщ как у бабушки'), findsOneWidget);
    expect(find.text('Как варить кофе в турке'), findsOneWidget);
    expect(find.text('TikTok'), findsOneWidget);
  });

  testWidgets('деньги в заметках папки — строкой «Всего …» под заголовком; без цен строки нет', (tester) async {
    await seed();
    await openFolder(tester);
    expect(find.byKey(const ValueKey('folder-total')), findsNothing);
    await world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'p1', itemId: 'n', extractor: 'text', kind: FactKind.price, value: '250 лей', number: const Value(250), detail: const Value('MDL')));
    await world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'p2', itemId: 'l', extractor: 'text', kind: FactKind.price, value: '1 000 лей', number: const Value(1000), detail: const Value('MDL')));
    await tester.pumpAndSettle();
    final shown = find.byKey(const ValueKey('folder-total'));
    expect(shown, findsOneWidget);
    expect(tester.widget<Text>(find.descendant(of: shown, matching: find.byType(Text))).data!.replaceAll(' ', ' '), 'Всего 1 250 лей');
  });

  testWidgets('ролик без обложки — строкой, как ссылка, а не пустой плиткой', (tester) async {
    await seed();
    await openFolder(tester);
    final card = find.ancestor(of: find.text('Тарт с малиной'), matching: find.byType(FolderItemCard));
    expect(tester.getSize(card).height, lessThan(120));
    expect(find.text('TikTok'), findsOneWidget);
  });

  testWidgets('в карточке заметки оформление, а не значки разметки', (tester) async {
    await seed();
    await (world.db.update(world.db.items)..where((t) => t.id.equals('n'))).write(const ItemsCompanion(body: Value('Борщ как у бабушки\nСвёкла **обязательно**\n- [ ] купить сметану')));
    await openFolder(tester);
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.textContaining('[ ]', findRichText: true), findsNothing);
    expect(find.textContaining('☐ купить сметану', findRichText: true), findsOneWidget);
  });

  testWidgets('чип вида оставляет только ссылки', (tester) async {
    await seed();
    await openFolder(tester);
    await tester.tap(find.text('Ссылки'));
    await tester.pumpAndSettle();
    expect(find.text('Как варить кофе в турке'), findsOneWidget);
    expect(find.text('Борщ как у бабушки'), findsNothing);
  });

  testWidgets('«Закинуть сюда» кладёт прямо в эту папку', (tester) async {
    await seed();
    await openFolder(tester);
    expect(find.text('Закинуть сюда'), findsOneWidget);
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Сырники на рисовой муке');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Закинуть в «Рецепты»'), findsOneWidget);
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();

    final saved = await (world.db.select(world.db.items)..where((t) => t.title.equals('Сырники на рисовой муке'))).getSingle();
    expect(saved.folderId, 'food');
    expect(find.text('4'), findsOneWidget);
  });

  Future<void> openLook(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Название и вид'));
    await tester.pumpAndSettle();
  }

  testWidgets('переименовать через меню: имя на том же экране, что цвет и значок', (tester) async {
    await seed();
    await openFolder(tester);
    await openLook(tester);
    await tester.enterText(find.byKey(const ValueKey('folder-name-field')), 'еда дома');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Еда дома'), findsOneWidget);
  });

  testWidgets('«Цвет и значок» — свой экран: цвет, иконка, «Сохранить» меняет папку', (tester) async {
    await seed();
    await openFolder(tester);
    await openLook(tester);
    expect(find.byKey(const ValueKey('folder-look')), findsOneWidget);
    // иконки под имя «Рецепты» идут первыми
    expect(find.text('Подходят к имени'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('color-mint')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'кофе');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('icon-local_cafe')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final folder = await world.db.select(world.db.folders).getSingle();
    expect(folder.color, 'mint');
    expect(folder.icon, 'local_cafe');
    expect(find.byKey(const ValueKey('folder-look')), findsNothing);
  });

  testWidgets('цвет одной строкой: круг оттенков даёт любой цвет, он встаёт первым в строке', (tester) async {
    await seed();
    await openFolder(tester);
    await openLook(tester);
    // круг и пять кружков, а не двенадцать готовых
    expect(find.byKey(const ValueKey('color-wheel')), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('color-') && widget.key != const ValueKey('color-wheel')), findsNWidgets(5));

    await tester.tap(find.byKey(const ValueKey('color-wheel')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('color-hex')), '3A7BD5');
    await tester.pumpAndSettle();
    // каналы R, G, B подхватывают HEX, а правка канала двигает цвет
    expect(find.widgetWithText(TextField, '58'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('color-B')), '213');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('color-#3A7BD5')), findsOneWidget);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.folders).getSingle()).color, '#3A7BD5');
  });

  testWidgets('иконки листаются до конца всего набора', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    await seed();
    await openFolder(tester);
    await openLook(tester);
    final scroll = find.descendant(of: find.byKey(const ValueKey('look-scroll')), matching: find.byType(Scrollable)).first;
    expect(find.text('Все иконки'), findsNothing);
    await tester.scrollUntilVisible(find.text('Все иконки'), 400, scrollable: scroll);
    expect(find.text('Все иконки'), findsOneWidget);
    // последняя иконка набора достаётся прокруткой и выбирается
    final last = find.byKey(ValueKey('icon-${symbolNames.last}'));
    await tester.scrollUntilVisible(last, 4000, scrollable: scroll, maxScrolls: 40);
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    await tester.tap(last);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.folders).getSingle()).icon, symbolNames.last);
  });

  testWidgets('«Цвет и значок» влезает в 320 точек при крупном шрифте и раскладывается вширь на планшете', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await seed();
    await openFolder(tester);
    await openLook(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('look-wide')), findsNothing);

    tester.view.physicalSize = const Size(1000, 700);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('look-wide')), findsOneWidget);
  });

  testWidgets('меню папки → плитка «Создать внутри: Холст»: холст в этой папке, сразу открыт', (tester) async {
    await seed();
    await openFolder(tester);
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('folder-new-canvas')));
    await tester.pumpAndSettle();
    // поле названия, а не «Имя папки», и кнопка «Создать»
    expect(find.text('Название'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Меню на неделю');
    await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
    await tester.pumpAndSettle();
    final canvas = (await world.db.select(world.db.items).get()).singleWhere((item) => item.kind == ItemKind.canvas);
    expect((canvas.title, canvas.folderId), ('Меню на неделю', 'food'));
    expect(find.text('Меню на неделю'), findsOneWidget);
    expect(find.byKey(const ValueKey('canvas-add')), findsOneWidget);
  });

  // жалоба 15.11: «в папке не кидается более одной фотки, хотя выбрал больше трёх» — три фото
  // ложились одной заметкой, а плитка показывает только первое
  testWidgets('в папке три фото без текста — три плитки, каждая со своим фото', (tester) async {
    await seed();
    await openFolder(tester);
    final dir = Directory.systemTemp.createTempSync('stowa_pick');
    addTearDown(() => dir.deleteSync(recursive: true));
    final picked = [
      for (final name in ['a.jpg', 'b.jpg', 'c.jpg'])
        PickedFile(path: (File('${dir.path}/$name')..writeAsBytesSync(List.filled(64, 1))).path, mime: 'image/jpeg', size: 64),
    ];
    final before = (await world.db.select(world.db.items).get()).length;
    tester.state<LineDockState>(find.byType(LineDock)).attach(picked);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закинуть').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final added = (await world.db.select(world.db.items).get()).skip(before).toList();
    expect(added, hasLength(3));
    expect(added.every((item) => item.folderId == 'food'), isTrue);
  });

  testWidgets('заметка с тремя фото: на плитке ленты и доски «+2», у одного фото метки нет', (tester) async {
    final dir = Directory.systemTemp.createTempSync('stowa_tiles');
    addTearDown(() => dir.deleteSync(recursive: true));
    ItemCard card(int files) => ItemCard(
      id: 'album$files', title: 'Поездка', kind: ItemKind.image, folderId: 'food', sortState: SortState.sorted,
      createdAt: world.now, thumbPath: 'missing.jpg', thumbRatio: 0.75, fileCount: files,
    );
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(ListView(children: [
      FolderItemCard(card: card(3), filesRoot: dir, now: world.now, onTap: () {}),
      BoardTile(card: card(3), filesRoot: dir, width: 160, darkPill: false, onTap: () {}, onLongPress: () {}),
      FolderItemCard(card: card(1), filesRoot: dir, now: world.now, onTap: () {}),
    ])));
    await tester.pumpAndSettle();
    // картинка в поддельном времени не декодируется и стоит нулевой высоты: метка над ней
    // считается невидимой, поэтому ищется и в скрытом
    expect(find.descendant(of: find.byType(BoardTile), matching: find.text('+2')), findsOneWidget);
    expect(find.descendant(of: find.byType(FolderItemCard, skipOffstage: false), matching: find.text('+2', skipOffstage: false), skipOffstage: false), findsOneWidget);
  });

  testWidgets('удалить папку: вещи без папки, «Вернуть» возвращает', (tester) async {
    await seed();
    await openFolder(tester);
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    // меню длинное: «Удалить папку» внизу листа, лист листается
    await tester.ensureVisible(find.text('Удалить папку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить папку'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить папку'));
    await tester.pumpAndSettle();

    expect(find.text('Папка удалена'), findsOneWidget);
    expect((await world.db.select(world.db.items).get()).every((item) => item.folderId == null), isTrue);
    await tester.tap(find.text('Вернуть'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.items).get()).every((item) => item.folderId == 'food'), isTrue);
  });

  testWidgets('долгое нажатие: удалить вещь, «Отменить» возвращает', (tester) async {
    await seed();
    await openFolder(tester);
    await tester.longPress(find.text('Тарт с малиной'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Тарт с малиной'), findsNothing);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Тарт с малиной'), findsOneWidget);
  });

  testWidgets('плашка с «Отменить» уходит сама и не висит над строкой', (tester) async {
    await seed();
    await openFolder(tester);
    await tester.longPress(find.text('Тарт с малиной'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Отменить'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Отменить'), findsNothing);
  });

  testWidgets('долгое нажатие выбирает, «В папку» перекладывает', (tester) async {
    await seed();
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'cookie9'));
    await openFolder(tester);
    await tester.longPress(find.text('Тарт с малиной'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В папку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дом').last);
    await tester.pumpAndSettle();

    expect(find.text('Переложил 1 заметку в «Дом»'), findsOneWidget);
    final moved = await (world.db.select(world.db.items)..where((t) => t.id.equals('v'))).getSingle();
    expect(moved.folderId, 'home');

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    final back = await (world.db.select(world.db.items)..where((t) => t.id.equals('v'))).getSingle();
    expect(back.folderId, 'food');
  });

  testWidgets('переложить в новую папку прямо из листа', (tester) async {
    await seed();
    await openFolder(tester);
    await tester.longPress(find.text('Тарт с малиной'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В папку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Новая папка'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'выпечка');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final folder = await (world.db.select(world.db.folders)..where((t) => t.name.equals('Выпечка'))).getSingle();
    final moved = await (world.db.select(world.db.items)..where((t) => t.id.equals('v'))).getSingle();
    expect(moved.folderId, folder.id);
  });

  testWidgets('кнопка порядка ставит вещи по имени', (tester) async {
    await seed();
    await openFolder(tester);
    double top(String title) => tester.getTopLeft(find.text(title)).dy;
    expect(top('Тарт с малиной'), lessThan(top('Борщ как у бабушки')));

    await tester.tap(find.byTooltip('Порядок'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('По имени'));
    await tester.pumpAndSettle();
    expect(top('Борщ как у бабушки'), lessThan(top('Как варить кофе в турке')));
    expect(top('Как варить кофе в турке'), lessThan(top('Тарт с малиной')));
  });

  Future<void> nest() async {
    final db = world.db;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'soup', name: 'Супы', icon: 'soup_kitchen', shape: 'pill', parentId: const Value('food')));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'cold', name: 'Холодные', icon: 'ac_unit', shape: 'pill', parentId: const Value('soup')));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'ok', kind: ItemKind.note, title: 'Окрошка на квасе', folderId: const Value('cold'), createdAt: world.now, updatedAt: world.now));
  }

  Finder pill(String name) => find.descendant(of: find.byType(FolderPill), matching: find.text(name));

  testWidgets('вложенная папка: пилюлей в родителе, не на главной; внутри путь родителей', (tester) async {
    await seed();
    await nest();
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    expect(pill('Супы'), findsNothing);
    // на главной число с вложенными: три своих и одна в «Холодных»
    expect(find.descendant(of: find.byType(FolderPill), matching: find.text('4')), findsOneWidget);

    await tester.tap(pill('Рецепты'));
    await tester.pumpAndSettle();
    expect(pill('Супы'), findsOneWidget);
    expect(pill('Холодные'), findsNothing);
    await tester.tap(pill('Супы'));
    await tester.pumpAndSettle();
    await tester.tap(pill('Холодные'));
    await tester.pumpAndSettle();
    expect(find.text('Окрошка на квасе'), findsOneWidget);
    expect(find.text('Рецепты / Супы'), findsOneWidget);

    // путь ведёт к родителю, а не копит экраны
    await tester.tap(find.text('Рецепты / Супы'));
    await tester.pumpAndSettle();
    expect(pill('Холодные'), findsOneWidget);
  });

  testWidgets('«Новая папка внутри» заводит вложенную; на третьем уровне пункта нет', (tester) async {
    await seed();
    await nest();
    await openFolder(tester);
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('folder-new-folder')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'выпечка');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    final created = await (world.db.select(world.db.folders)..where((t) => t.name.equals('Выпечка'))).getSingle();
    expect(created.parentId, 'food');
    expect(pill('Выпечка'), findsOneWidget);

    await tester.tap(pill('Супы'));
    await tester.pumpAndSettle();
    await tester.tap(pill('Холодные'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('folder-new-folder')), findsNothing);
    expect(find.byKey(const ValueKey('folder-new-canvas')), findsOneWidget);
  });

  testWidgets('«Переложить в…»: без себя и своих вложенных, «Наверх» делает верхней', (tester) async {
    await seed();
    await nest();
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'pill', sortOrder: const Value(1)));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(pill('Рецепты'));
    await tester.pumpAndSettle();
    await tester.tap(pill('Супы'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переложить в…'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text('Холодные')), findsNothing);
    expect(find.descendant(of: sheet, matching: find.text('Супы')), findsNothing);
    await tester.tap(find.descendant(of: sheet, matching: find.text('Дом')));
    await tester.pumpAndSettle();
    expect((await (world.db.select(world.db.folders)..where((t) => t.id.equals('soup'))).getSingle()).parentId, 'home');
    expect(find.text('Дом'), findsOneWidget);

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переложить в…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Наверх'));
    await tester.pumpAndSettle();
    expect((await (world.db.select(world.db.folders)..where((t) => t.id.equals('soup'))).getSingle()).parentId, isNull);
  });

  testWidgets('папка влезает в 320 точек при крупном шрифте', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seed();
    await nest();
    await openFolder(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(pill('Супы'));
    await tester.pumpAndSettle();
    await tester.tap(pill('Холодные'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
