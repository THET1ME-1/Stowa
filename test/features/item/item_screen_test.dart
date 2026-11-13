import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/core/widgets/voice_player.dart';
import 'package:stowa/features/item/item_media.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/features/item/photo_viewer.dart';
import 'package:stowa/services/place_service.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester, {required String body, required String title}) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.note,
          title: title,
          body: Value(body),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
  }

  testWidgets('открытая заметка запоминает, когда её открыли, а время правки не трогает', (tester) async {
    await open(tester, body: 'Мысль', title: 'Мысль');
    final item = await world.db.select(world.db.items).getSingle();
    expect(item.openedAt, world.now);
    expect(item.updatedAt, world.now);
    expect(await world.db.select(world.db.vaultQueue).get(), everyElement(predicate<VaultQueueData>((row) => row.target != 'item:a' || row.version == 1)));
  });

  testWidgets('напоминание по месту без места «всегда»: спрашивает уведомления и предлагает разрешить место', (tester) async {
    world.currentPlace = const PlaceFix(latitude: 47.0245, longitude: 28.8323, name: 'Ботаника, Кишинёв');
    await open(tester, body: 'Купить кофе', title: 'Купить кофе');
    expect(world.notifications.asked, 0);
    await tester.tap(find.byTooltip('Напомнить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Напомнить здесь'));
    await tester.pumpAndSettle();
    expect(world.notifications.asked, 1);
    expect(find.text('Напомню у места, если разрешишь место «всегда»'), findsOneWidget);
    await tester.tap(find.text('Разрешить'));
    await tester.pumpAndSettle();
    expect(world.placeChannel.asked, 1);
  });

  testWidgets('«Напомнить» → «Напомнить дома»: плашка места; дом не отмечен — так и сказано; убрать', (tester) async {
    world.placeChannel.background = true;
    await open(tester, body: 'Купить хлеб', title: 'Купить хлеб');
    await tester.tap(find.byTooltip('Напомнить'));
    await tester.pumpAndSettle();
    expect(find.text('По времени'), findsOneWidget);
    await tester.tap(find.text('Напомнить дома'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.items).getSingle()).remindPlace, PlaceReminderKind.home);
    expect(find.text('Такого места ещё нет: напомню, когда отметишь его в «Местах»'), findsOneWidget);
    expect(find.byKey(const ValueKey('item-place-reminder')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('item-place-reminder')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Убрать напоминание'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.items).getSingle()).remindPlace, isNull);
  });

  testWidgets('«Напомнить» показывает свои места и «у любого» для вида, где мест несколько', (tester) async {
    world.placeChannel.background = true;
    for (final (id, name, kind) in [('o', 'Офис', PlaceKind.work), ('s', 'Склад', PlaceKind.work), ('sasha', 'Саша', PlaceKind.guests)]) {
      await world.db.into(world.db.places).insert(PlacesCompanion.insert(id: id, kind: kind, name: name, latitude: 47.0, longitude: 28.8, createdAt: world.now));
    }
    await open(tester, body: 'Отдать книгу', title: 'Отдать книгу');
    await tester.tap(find.byTooltip('Напомнить'));
    await tester.pumpAndSettle();
    for (final label in ['Напомнить: Офис', 'Напомнить: Склад', 'Напомнить: Саша', 'Напомнить на работе']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // гостей одно место — «у любого» для них не нужно
    expect(find.text('Напомнить в гостях'), findsNothing);

    await tester.tap(find.text('Напомнить: Саша'));
    await tester.pumpAndSettle();
    final item = await world.db.select(world.db.items).getSingle();
    expect((item.remindPlace, item.remindPlaceRef, item.remindPlaceName), (PlaceReminderKind.place, 'sasha', 'Саша'));
    expect(find.text('Напомнить: Саша'), findsOneWidget);
  });

  testWidgets('«Напомнить здесь» берёт текущую точку с названием', (tester) async {
    world.currentPlace = const PlaceFix(latitude: 47.0245, longitude: 28.8323, name: 'Ботаника, Кишинёв');
    await open(tester, body: 'Купить кофе', title: 'Купить кофе');
    await tester.tap(find.byTooltip('Напомнить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Напомнить здесь'));
    await tester.pumpAndSettle();
    final item = await world.db.select(world.db.items).getSingle();
    expect((item.remindPlace, item.remindLatitude, item.remindPlaceName), (PlaceReminderKind.point, 47.0245, 'Ботаника, Кишинёв'));
    expect(find.text('Напомнить: Ботаника, Кишинёв'), findsOneWidget);
  });

  testWidgets('у задачи видна галочка, касание её ставит', (tester) async {
    await open(tester, body: '- [ ] купить молоко', title: 'Купить молоко');
    expect(find.text('купить молоко'), findsOneWidget);
    await tester.tap(find.text('купить молоко'));
    await tester.pumpAndSettle();
    final item = await world.db.select(world.db.items).getSingle();
    expect(item.body, '- [x] купить молоко');
  });

  Future<Item> saved() => world.db.select(world.db.items).getSingle();

  testWidgets('«Переложить» → «Без папки» вынимает заметку из папки, угадыватель получает урок', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'work', name: 'Работа', icon: 'work', shape: 'pill'));
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.note,
          title: 'Отчёт клиенту',
          body: const Value('Отчёт клиенту'),
          folderId: const Value('work'),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();

    // кнопка в нижней пилюле; вторая такая же — в шапке у имени папки
    await tester.tap(find.byTooltip('Переложить в папку').last);
    await tester.pumpAndSettle();
    // своей папки в списке нет, «Без папки» — есть
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Работа')), findsNothing);
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Без папки')));
    await tester.pumpAndSettle();

    expect((await saved()).folderId, isNull);
    final lesson = await world.db.select(world.db.corrections).getSingle();
    expect((lesson.fromFolderId, lesson.toFolderId), ('work', ''));
    expect(find.text('Переложил в «Без папки»'), findsOneWidget);
  });

  testWidgets('первая строка заметки остаётся текстом, заголовком над ним не встаёт', (tester) async {
    await open(tester, body: 'Борщ\nСвёкла 2 шт', title: 'Борщ');
    expect(find.text('Борщ\nСвёкла 2 шт'), findsOneWidget);
    expect(find.text('Борщ'), findsNothing);
  });

  testWidgets('правка не уносит первую строку из текста, заголовок идёт за ней', (tester) async {
    await open(tester, body: 'Борщ\nСвёкла 2 шт', title: 'Борщ');
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, isEmpty);
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, 'Борщ\nСвёкла 2 шт');

    await tester.enterText(find.byType(TextField).last, 'Борщ зелёный\nЩавель пучок');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    expect((await saved()).body, 'Борщ зелёный\nЩавель пучок');
    expect((await saved()).title, 'Борщ зелёный');
    expect(find.text('Борщ зелёный\nЩавель пучок'), findsOneWidget);
  });

  testWidgets('правка времени в тексте переставляет напоминание', (tester) async {
    await open(tester, body: 'в 7:00 закинуть футболку в пакет', title: 'Закинуть футболку в пакет');
    final morning = DateTime(world.now.year, world.now.month, world.now.day + 1, 7);
    await (world.db.update(world.db.items)..where((t) => t.id.equals('a'))).write(ItemsCompanion(reminderAt: Value(morning)));
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'в 8:30 закинуть футболку в пакет');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect((await saved()).reminderAt, morning.add(const Duration(hours: 1, minutes: 30)));
  });

  group('правка без «Готово»: время и место встают сами после паузы', () {
    Future<void> edit(WidgetTester tester, String text) async {
      await tester.tap(find.byTooltip('Править'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, text);
      // пауза автосохранения, «Готово» не нажимаем
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('время', (tester) async {
      await open(tester, body: 'Купить хлеб', title: 'Купить хлеб');
      await edit(tester, 'Купить хлеб в 6 вечера');
      expect((await saved()).reminderAt, DateTime(world.now.year, world.now.month, world.now.day, 18));
    });

    testWidgets('вписал место — напоминание у магазина', (tester) async {
      await open(tester, body: 'Купить хлеб', title: 'Купить хлеб');
      await edit(tester, 'Купить хлеб, буду проходить мимо магазина');
      expect((await saved()).remindPlace, PlaceReminderKind.shop);
    });

    testWidgets('поменял место — напоминание переезжает', (tester) async {
      await open(tester, body: 'Буду проходить мимо магазина, купить пластырь', title: 'Купить пластырь');
      await (world.db.update(world.db.items)..where((t) => t.id.equals('a'))).write(const ItemsCompanion(remindPlace: Value(PlaceReminderKind.shop)));
      await edit(tester, 'Буду проходить мимо аптеки, купить пластырь');
      expect((await saved()).remindPlace, PlaceReminderKind.pharmacy);
    });

    testWidgets('«завтра» рядом с местом — день места, а не звонок в 9 утра', (tester) async {
      await open(tester, body: 'Купить хлеб', title: 'Купить хлеб');
      await edit(tester, 'Завтра буду проходить мимо магазина, купить хлеб');
      final item = await saved();
      expect((item.remindPlace, item.remindPlaceDay, item.reminderAt), (PlaceReminderKind.shop, DateTime(world.now.year, world.now.month, world.now.day + 1), null));
    });

    testWidgets('своё место по имени', (tester) async {
      await world.db.into(world.db.places).insert(PlacesCompanion.insert(id: 'sasha', kind: PlaceKind.guests, name: 'Саша', latitude: 47.0, longitude: 28.8, createdAt: world.now));
      await open(tester, body: 'Отдать книгу', title: 'Отдать книгу');
      await edit(tester, 'Буду у Саши, отдать книгу');
      final item = await saved();
      expect((item.remindPlace, item.remindPlaceRef), (PlaceReminderKind.place, 'sasha'));
    });

    testWidgets('стёр место — напоминание остаётся', (tester) async {
      await open(tester, body: 'Буду проходить мимо магазина, купить хлеб', title: 'Купить хлеб');
      await (world.db.update(world.db.items)..where((t) => t.id.equals('a'))).write(const ItemsCompanion(remindPlace: Value(PlaceReminderKind.shop)));
      await edit(tester, 'Купить хлеб');
      expect((await saved()).remindPlace, PlaceReminderKind.shop);
    });
  });

  testWidgets('стёр время и набрал то же, пока правка не сохранилась, — напоминание встаёт по тексту', (tester) async {
    // напоминание разошлось с текстом: «8 часов вечера», а стоит 6 утра (старая сборка так ставила)
    await open(tester, body: 'В 8 часов вечера пить пиво', title: 'Пить пиво');
    final wrong = DateTime(world.now.year, world.now.month, world.now.day, 6);
    await (world.db.update(world.db.items)..where((t) => t.id.equals('a'))).write(ItemsCompanion(reminderAt: Value(wrong)));
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    // быстрее паузы автосохранения: стёр «8» и набрал заново
    await tester.enterText(find.byType(TextField).last, 'В  часов вечера пить пиво');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField).last, 'В 8 часов вечера пить пиво');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect((await saved()).reminderAt, DateTime(world.now.year, world.now.month, world.now.day, 20));
  });

  testWidgets('правка рядом со временем, само время не трогали — напоминание не сбивается', (tester) async {
    await open(tester, body: 'В 8 часов вечера пить пиво', title: 'Пить пиво');
    final mine = DateTime(world.now.year, world.now.month, world.now.day, 21, 30);
    await (world.db.update(world.db.items)..where((t) => t.id.equals('a'))).write(ItemsCompanion(reminderAt: Value(mine)));
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'В 8 часов вечера пить пиво с Сашей');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect((await saved()).reminderAt, mine);
  });

  testWidgets('время вписали в готовую заметку без напоминания — напоминание встаёт', (tester) async {
    await open(tester, body: 'Купить хлеб', title: 'Купить хлеб');
    expect((await saved()).reminderAt, isNull);
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Купить хлеб завтра в 9');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect((await saved()).reminderAt, DateTime(world.now.year, world.now.month, world.now.day + 1, 9));
  });

  testWidgets('стёрли время из текста — напоминание остаётся', (tester) async {
    await open(tester, body: 'в 7:00 закинуть футболку', title: 'Закинуть футболку');
    final morning = DateTime(world.now.year, world.now.month, world.now.day + 1, 7);
    await (world.db.update(world.db.items)..where((t) => t.id.equals('a'))).write(ItemsCompanion(reminderAt: Value(morning)));
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'закинуть футболку');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect((await saved()).reminderAt, morning);
  });

  testWidgets('свой заголовок стоит над текстом, текст при этом целый', (tester) async {
    await open(tester, body: 'Дипломная работа\nКлючевые слова оставить', title: 'Дипломная работа');
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Архитектура приложения');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect((await saved()).title, 'Архитектура приложения');
    expect((await saved()).body, 'Дипломная работа\nКлючевые слова оставить');
    expect(find.text('Архитектура приложения'), findsOneWidget);
    expect(find.text('Дипломная работа\nКлючевые слова оставить'), findsOneWidget);

    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'Архитектура приложения');
  });

  testWidgets('та же ссылка уже лежит — строка «Такая же лежит в папке «Рецепты» с 12 мая», касание открывает её', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Рецепты', icon: 'folder', shape: 'pill'));
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'old',
          kind: ItemKind.link,
          title: 'Борщ бабушки',
          body: const Value('https://eda.ru/borsch'),
          url: const Value('https://eda.ru/borsch'),
          folderId: const Value('food'),
          createdAt: DateTime(world.now.year, 5, 12),
          updatedAt: DateTime(world.now.year, 5, 12),
        ));
    await open(tester, body: 'https://www.eda.ru/borsch/?utm_source=tg', title: 'Борщ');
    await (world.db.update(world.db.items)..where((t) => t.id.equals('a'))).write(const ItemsCompanion(url: Value('https://www.eda.ru/borsch/?utm_source=tg')));
    await tester.pumpAndSettle();

    expect(find.text('Такая же лежит в папке «Рецепты» с 12 мая'), findsOneWidget);
    await tester.tap(find.text('Такая же лежит в папке «Рецепты» с 12 мая'));
    await tester.pumpAndSettle();
    expect(find.text('Борщ бабушки'), findsOneWidget);
  });

  testWidgets('повтора нет — строки нет', (tester) async {
    await open(tester, body: 'Мысль', title: 'Мысль');
    expect(find.textContaining('Такая же'), findsNothing);
  });

  testWidgets('касание по тексту тоже открывает правку', (tester) async {
    await open(tester, body: 'Мысль\nвторая строка мысли', title: 'Мысль');
    await tester.tap(find.textContaining('вторая строка'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('набранное сохраняется само, без «Готово»', (tester) async {
    await open(tester, body: 'Мысль', title: 'Мысль');
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Мысль\nдописал');
    await tester.pump(const Duration(seconds: 2));
    expect((await saved()).body, 'Мысль\nдописал');
  });

  testWidgets('панель правки: чек-лист ставит «- [ ] » в начало строки', (tester) async {
    await open(tester, body: 'купить хлеб', title: 'Покупки');
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    final body = find.byType(TextField).last;
    await tester.tap(body);
    tester.widget<TextField>(body).controller!.selection = const TextSelection.collapsed(offset: 3);
    await tester.tap(find.byTooltip('Чек-лист'));
    await tester.pump();
    expect(tester.widget<TextField>(body).controller!.text, '- [ ] купить хлеб');
  });

  testWidgets('в правке те же инструменты, что в строке: заголовок, курсив, зачёркнутый, цитата, код, отменить и вернуть', (tester) async {
    await open(tester, body: 'купить хлеб', title: 'Покупки');
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    for (final tool in ['Заголовок', 'Жирный', 'Курсив', 'Зачеркнуть', 'Список', 'Чек-лист', 'Цитата', 'Код', 'Отменить', 'Вернуть']) {
      expect(find.byTooltip(tool), findsOneWidget, reason: tool);
    }
    final body = find.byType(TextField).last;
    await tester.tap(body);
    tester.widget<TextField>(body).controller!.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
    await tester.tap(find.byTooltip('Курсив'));
    await tester.pump();
    expect(tester.widget<TextField>(body).controller!.text, '_купить_ хлеб');
    // отмена работает и для кнопок разметки
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Отменить'));
    await tester.pump();
    expect(tester.widget<TextField>(body).controller!.text, 'купить хлеб');
    await tester.tap(find.byTooltip('Заголовок'));
    await tester.pump();
    expect(tester.widget<TextField>(body).controller!.text, '# купить хлеб');
  });

  testWidgets('разметка видна: жирное жирным, пункт с точкой, без звёздочек', (tester) async {
    await open(tester, body: 'План\nЭто **важно**\n- первое', title: 'План');
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('важно', findRichText: true), findsOneWidget);
    expect(find.textContaining('первое', findRichText: true), findsOneWidget);
  });

  testWidgets('место сохранения видно под заголовком и открывает карту', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.note,
          title: 'Кофе',
          body: const Value('зерно из той лавки'),
          latitude: const Value(47.0245),
          longitude: const Value(28.8323),
          placeName: const Value('Ботаника, Кишинёв'),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    expect(find.text('Ботаника, Кишинёв'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('item-place')));
    // карта тянет плитки из сети: ждём только въезд экрана
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Карта'), findsOneWidget);
    expect(find.text('Ботаника, Кишинёв'), findsWidgets);
  });

  testWidgets('шапка: пилюля с папкой, днём и видом вещи', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'study', name: 'Учёба', icon: 'school', shape: 'cookie9'));
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.note,
          title: 'Военная кафедра',
          body: const Value('взять военный билет'),
          folderId: const Value('study'),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();

    expect(find.text('Учёба'), findsOneWidget);
    expect(find.text('Заметка'), findsOneWidget);
    // дата и время создания видны под заголовком целиком, с днём недели
    expect(find.text('Понедельник, 2 ноября, 10:00'), findsOneWidget);
    // значок вложен в полукруглый край пилюли: круг с тем же центром, углы не выпирают
    final badge = find.byKey(const ValueKey('item-folder-badge'));
    expect((tester.widget<Container>(badge).decoration! as BoxDecoration).shape, BoxShape.circle);
    final pill = tester.getRect(find.ancestor(of: badge, matching: find.byType(InkWell)).first);
    final rect = tester.getRect(badge);
    expect(rect.center.dx - pill.left, closeTo(pill.height / 2, 0.5));
    expect(rect.center.dy, closeTo(pill.center.dy, 0.5));
    final label = tester.renderObject<RenderParagraph>(find.text('Учёба'));
    expect(label.didExceedMaxLines, isFalse);
    // пустых кнопок без подложки в шапке нет: у каждой своя форма
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('без папки пилюля так и говорит', (tester) async {
    await open(tester, body: 'мысль', title: 'Мысль');
    expect(find.text('Без папки'), findsOneWidget);
  });

  testWidgets('текст лежит отдельной карточкой, не на фоне', (tester) async {
    await open(tester, body: 'Мысль\nвторая строка мысли', title: 'Мысль');
    final card = find.ancestor(of: find.textContaining('вторая строка', findRichText: true), matching: find.byKey(const ValueKey('item-body-card')));
    expect(card, findsOneWidget);
  });

  testWidgets('«Дописать» открывает правку с курсором с новой строки в конце', (tester) async {
    await open(tester, body: 'Мысль\nпервая', title: 'Мысль');
    await tester.tap(find.text('Дописать'));
    await tester.pumpAndSettle();
    final body = tester.widget<TextField>(find.byType(TextField).last).controller!;
    expect(body.text, 'Мысль\nпервая\n');
    expect(body.selection.baseOffset, body.text.length);

    await tester.enterText(find.byType(TextField).last, 'Мысль\nпервая\nвторая');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect((await saved()).body, 'Мысль\nпервая\nвторая');
  });

  testWidgets('«Дописать» и выход без набора ничего не меняют', (tester) async {
    await open(tester, body: 'Мысль\nпервая', title: 'Мысль');
    await tester.tap(find.text('Дописать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect((await saved()).body, 'Мысль\nпервая');
  });

  testWidgets('напоминание стоит отдельной плашкой', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.note,
          title: 'Кафедра',
          body: const Value('Кафедра'),
          reminderAt: Value(DateTime(2026, 11, 3, 14)),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('item-reminder')), findsOneWidget);
    expect(find.textContaining('14:00'), findsOneWidget);
  });

  testWidgets('«⋮» открывает лист: копировать и удалить', (tester) async {
    await open(tester, body: 'мысль', title: 'Мысль');
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    expect(find.text('Скопировать текст'), findsOneWidget);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect((await saved()).deletedAt, isNotNull);
  });

  group('дата заметки', () {
    final written = DateTime(2026, 10, 30, 8, 15);

    Future<void> openOld(WidgetTester tester) async {
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Мысль', body: const Value('Мысль'), createdAt: written, updatedAt: written));
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
      await tester.pumpAndSettle();
    }

    testWidgets('касание по дате → «Сейчас»: заметка записана сейчас, «Отменить» возвращает прежний день', (tester) async {
      await openOld(tester);
      await tester.tap(find.byKey(const ValueKey('item-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сейчас'));
      await tester.pumpAndSettle();
      expect((await saved()).createdAt, world.now);
      expect(find.text('Дата изменена'), findsOneWidget);
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect((await saved()).createdAt, written);
    });

    testWidgets('«⋮» → «Изменить дату» → день в календаре: время остаётся прежним', (tester) async {
      await openOld(tester);
      await tester.tap(find.byTooltip('Ещё'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Изменить дату'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выбрать день и время'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12'));
      await tester.tap(find.text('ОК'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ОК'));
      await tester.pumpAndSettle();
      expect((await saved()).createdAt, DateTime(2026, 10, 12, 8, 15));
    });

    testWidgets('сегодняшний день с временем из будущего обрезается до «сейчас»', (tester) async {
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Мысль', body: const Value('Мысль'), createdAt: DateTime(2026, 11, 1, 23, 40), updatedAt: DateTime(2026, 11, 1, 23, 40)));
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('item-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выбрать день и время'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.tap(find.text('ОК'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ОК'));
      await tester.pumpAndSettle();
      expect((await saved()).createdAt, world.now, reason: '2 ноября 23:40 ещё не наступило');
    });
  });

  testWidgets('320 точек и шрифт 1,3: ничего не вылезает', (tester) async {
    tester.view.physicalSize = const Size(640, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'r', name: 'Рецепты на каждый день', icon: 'restaurant', shape: 'pill'));
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.note,
          title: 'Очень длинный заголовок заметки про военную кафедру',
          body: const Value('- [ ] первое\n- второе'),
          folderId: const Value('r'),
          reminderAt: Value(DateTime(2026, 11, 3, 14)),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('вещи разных видов', () {
    Future<void> show(WidgetTester tester, ItemsCompanion item, {List<AttachmentsCompanion> files = const []}) async {
      await world.db.into(world.db.items).insert(item);
      for (final file in files) {
        await world.db.into(world.db.attachments).insert(file);
      }
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
      await tester.pumpAndSettle();
    }

    testWidgets('свой ролик: обложка с длиной и кадры по шкале со временем, касание кадра — смотреть', (tester) async {
      await world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'f0', itemId: 'a', extractor: 'video', kind: FactKind.frame, value: '.stowa/frames/a/0.jpg', number: const Value(10)));
      await world.db.into(world.db.facts).insert(
        FactsCompanion.insert(id: 'f1', itemId: 'a', extractor: 'video', kind: FactKind.frame, value: '.stowa/frames/a/1.jpg', number: const Value(95), position: const Value(1)),
      );
      await show(
        tester,
        ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.video,
          title: 'Отпуск',
          coverPath: const Value('.stowa/covers/a.jpg'),
          durationSeconds: const Value(120),
          createdAt: world.now,
          updatedAt: world.now,
        ),
        files: [AttachmentsCompanion.insert(id: 'v', itemId: 'a', path: 'Отпуск/clip.mp4', mime: 'video/mp4', size: 1)],
      );
      expect(find.text('2:00'), findsOneWidget);
      expect(find.text('0:10'), findsOneWidget);
      expect(find.text('1:35'), findsOneWidget);
      expect(find.byKey(const ValueKey('video-frames')), findsOneWidget);
    });

    testWidgets('фото между абзацами — в тексте на своём месте, над заголовком только остальные', (tester) async {
      await show(
        tester,
        ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.note,
          title: 'Плитка',
          body: const Value('Плитка\nвот так легла\n![[IMG-1.jpg]]\nклей серый\n![[нет.jpg]]'),
          createdAt: world.now,
          updatedAt: world.now,
        ),
        files: [
          AttachmentsCompanion.insert(id: 'p1', itemId: 'a', path: 'Плитка/IMG-1.jpg', mime: 'image/jpeg', size: 1, width: const Value(400), height: const Value(300)),
          AttachmentsCompanion.insert(id: 'p2', itemId: 'a', path: 'Плитка/скан.jpg', mime: 'image/jpeg', size: 1, position: const Value(1)),
        ],
      );
      // крупно над заголовком — только фото, которого нет в тексте
      expect(find.byType(Image), findsOneWidget);
      await tester.scrollUntilVisible(find.text('клей серый'), 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('item-body-card'));
      expect(find.descendant(of: card, matching: find.byType(Image)), findsOneWidget);
      expect(find.textContaining('![['), findsNothing);
      // картинка стоит между своими строками
      final photo = tester.getTopLeft(find.descendant(of: card, matching: find.byType(Image))).dy;
      expect(photo, greaterThan(tester.getTopLeft(find.textContaining('вот так легла')).dy));
      expect(photo, lessThan(tester.getTopLeft(find.text('клей серый')).dy));
      // файла нет — тихая плашка с именем
      expect(find.text('нет.jpg'), findsOneWidget);
    });

    testWidgets('ссылка: превью с сайтом и описанием, адрес не повторяется текстом, главная кнопка «Открыть»', (tester) async {
      await show(
        tester,
        ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.link,
          title: 'Сборщик мусора в Dart',
          body: const Value('https://habr.com/ru/articles/1/'),
          url: const Value('https://habr.com/ru/articles/1/'),
          previewSite: const Value('Хабр'),
          previewText: const Value('Разбираем поколения'),
          previewAt: Value(world.now),
          createdAt: world.now,
          updatedAt: world.now,
        ),
      );
      expect(find.byType(LinkPreviewCard), findsOneWidget);
      expect(find.text('Хабр'), findsOneWidget);
      expect(find.text('Разбираем поколения'), findsOneWidget);
      expect(find.text('Открыть'), findsOneWidget);
      expect(find.byKey(const ValueKey('item-body-card')), findsNothing);
    });

    ItemsCompanion adultLink() => ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.link,
          title: 'Тайтл',
          url: const Value('https://hentailib.me/ru/manga/x'),
          coverPath: const Value('covers/a.jpg'),
          previewSite: const Value('HentaiLib'),
          previewText: const Value('Откровенное описание'),
          previewAt: Value(world.now),
          createdAt: world.now,
          updatedAt: world.now,
        );
    Future<void> markAdult() => world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'a-adult', itemId: 'a', extractor: 'page', kind: FactKind.adult, value: '18+'));

    testWidgets('страница 18+ при выключенном показе: обложка размыта, описание спрятано', (tester) async {
      await markAdult();
      await show(tester, adultLink());
      expect(find.byKey(const ValueKey('adult-veil-a')), findsOneWidget);
      expect(find.text('18+'), findsOneWidget);
      expect(find.text('Откровенное описание'), findsNothing);
      expect(find.textContaining('Описание скрыто'), findsOneWidget);
    });

    testWidgets('показ 18+ включён — обложка и описание как есть', (tester) async {
      world.showAdult = true;
      await markAdult();
      await show(tester, adultLink());
      expect(find.byKey(const ValueKey('adult-veil-a')), findsNothing);
      expect(find.text('Откровенное описание'), findsOneWidget);
    });

    testWidgets('ролик по ссылке: обложка с сервисом и длиной, автор, «Смотреть»', (tester) async {
      await show(
        tester,
        ItemsCompanion.insert(
          id: 'a',
          kind: ItemKind.video,
          title: 'Never Gonna Give You Up',
          url: const Value('https://youtu.be/dQw4w9WgXcQ'),
          previewAuthor: const Value('Rick Astley'),
          durationSeconds: const Value(213),
          createdAt: world.now,
          updatedAt: world.now,
        ),
      );
      expect(find.byType(VideoCover), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);
      expect(find.text('3:33'), findsOneWidget);
      expect(find.text('Rick Astley'), findsOneWidget);
      expect(find.text('Смотреть'), findsOneWidget);
    });

    testWidgets('фото: касание открывает просмотр во весь экран', (tester) async {
      await show(
        tester,
        ItemsCompanion.insert(id: 'a', kind: ItemKind.image, title: 'Лампа', createdAt: world.now, updatedAt: world.now),
        files: [AttachmentsCompanion.insert(id: 'f1', itemId: 'a', path: 'attachments/a/0_lampa.jpg', mime: 'image/jpeg', size: 1000, width: const Value(1200), height: const Value(1600))],
      );
      // центр высокого фото в тестовом окне уходит под плавающую панель
      await tester.tapAt(tester.getTopLeft(find.byType(Hero).first) + const Offset(40, 40));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsOneWidget);
      expect(find.text('В галерею'), findsOneWidget);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsNothing);
    });

    testWidgets('файл строкой с именем и весом, голосовое — плеером', (tester) async {
      await show(
        tester,
        ItemsCompanion.insert(id: 'a', kind: ItemKind.voice, title: 'Договор с хозяйкой', createdAt: world.now, updatedAt: world.now),
        files: [
          AttachmentsCompanion.insert(id: 'v', itemId: 'a', path: 'attachments/a/0_voice.m4a', mime: 'audio/mp4', size: 40000),
          AttachmentsCompanion.insert(id: 'd', itemId: 'a', path: 'attachments/a/1_Договор.pdf', mime: 'application/pdf', size: 1258291, position: const Value(1)),
        ],
      );
      expect(find.byType(VoicePlayer), findsOneWidget);
      expect(find.text('Договор.pdf'), findsOneWidget);
      expect(find.text('PDF · 1.2 MB'), findsOneWidget);
    });

    testWidgets('«Связано»: похожая вещь с причиной, крестик записывает отказ', (tester) async {
      for (final (id, title) in [('b', 'Свёкла подешевела, купить на борщ'), ('c', 'Купить хлеб'), ('d', 'Позвонить в банк'), ('e', 'Идея для подарка'), ('f', 'Счёт за свет')]) {
        await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(title), createdAt: world.now, updatedAt: world.now));
      }
      await show(tester, ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Борщ', body: const Value('Борщ со свёклой, рецепт'), createdAt: world.now, updatedAt: world.now));
      // до конца: внизу у списка запас под плавающую панель, крестик выходит из-под неё
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('Свёкла подешевела, купить на борщ'), findsOneWidget);
      expect(find.textContaining('общее:'), findsOneWidget);
      await tester.tap(find.byTooltip('Не связывать'));
      await tester.pumpAndSettle();
      // что связь уходит с экрана, сторожит test/data/related_repository_test.dart: пересчёт
      // потока — цепочка запросов к базе, в поддельном времени виджет-теста она не доходит
      final refused = await world.db.select(world.db.links).getSingle();
      expect((refused.fromId, refused.toId, refused.rejected), ('a', 'b', true));
    });
  });

  group('связи руками', () {
    Future<void> other(String id, String title, {String body = ''}) => world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(body.isEmpty ? title : '$title\n$body'), createdAt: world.now.subtract(const Duration(days: 1)), updatedAt: world.now),
    );

    testWidgets('[[Заметка]] в тексте — ссылка без скобок, касание открывает ту заметку; в «Связано» — «в тексте заметки»', (tester) async {
      await other('hops', 'Хмель', body: 'каскад и цитра');
      await open(tester, body: 'Пиво\nварить с [[Хмель]]', title: 'Пиво');
      expect(find.textContaining('[[', findRichText: true), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('в тексте заметки'), findsOneWidget);
      // у связи из текста крестика нет: её держит текст
      expect(find.byTooltip('Не связывать'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      // касание ровно по слову «Хмель»: где оно в абзаце, говорит сам абзац
      final paragraph = tester.renderObject<RenderParagraph>(find.textContaining('варить с', findRichText: true).first);
      final shown = paragraph.text.toPlainText();
      final start = shown.indexOf('Хмель');
      final box = paragraph.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + 5)).first;
      await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
      await tester.pumpAndSettle();
      expect(find.textContaining('каскад и цитра', findRichText: true), findsWidgets);
    });

    testWidgets('«+ Связь»: поиск по словам из текста, касание связывает вручную', (tester) async {
      await other('list', 'Список вещей', body: 'палатка, спальник, горелка');
      await other('car', 'Замена масла');
      await open(tester, body: 'Отпуск в горах', title: 'Отпуск в горах');
      await tester.tap(find.byKey(const ValueKey('link-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('link-search')), 'спальн');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('link-car')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('link-list')));
      await tester.pumpAndSettle();
      expect(find.text('Связано с «Список вещей»'), findsOneWidget);
      // что связь появляется в «Связано», сторожит test/data/items_repository_links_test.dart:
      // пересчёт потока в поддельном времени виджет-теста не доходит
      final link = await world.db.select(world.db.links).getSingle();
      expect((link.fromId, link.toId, link.source, link.rejected), ('a', 'list', LinkSource.manual, false));
    });

    testWidgets('ручная связь в «Связано» — «связь вручную», крестик «Убрать связь» её снимает', (tester) async {
      await other('list', 'Список вещей');
      await world.db.into(world.db.links).insert(LinksCompanion.insert(fromId: 'a', toId: 'list', source: LinkSource.manual));
      await open(tester, body: 'Отпуск в горах', title: 'Отпуск в горах');
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('связь вручную'), findsOneWidget);
      await tester.tap(find.byTooltip('Убрать связь'));
      await tester.pumpAndSettle();
      expect(await world.db.select(world.db.links).get(), isEmpty);
    });

    testWidgets('правка: «[[» дописывает «]]», над клавиатурой заметки по словам, касание ставит заголовок', (tester) async {
      await other('beer', 'Пиво я очень люблю', body: 'и обожаю');
      await other('car', 'Замена масла');
      await open(tester, body: 'Пятница', title: 'Пятница');
      await tester.tap(find.byTooltip('Править'));
      await tester.pumpAndSettle();
      final body = find.byType(TextField).last;
      await tester.enterText(body, 'Пятница: [');
      await tester.enterText(body, 'Пятница: [[');
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(body).controller!;
      expect(controller.text, 'Пятница: [[]]');
      expect(find.byKey(const ValueKey('wiki-suggestions')), findsOneWidget);
      // набранное между скобками ищет по словам
      controller.value = const TextEditingValue(text: 'Пятница: [[обож]]', selection: TextSelection.collapsed(offset: 15));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wiki-car')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('wiki-beer')));
      await tester.pumpAndSettle();
      expect(controller.text, 'Пятница: [[Пиво я очень люблю]]');
      expect(find.byKey(const ValueKey('wiki-suggestions')), findsNothing);
    });
  });
}
