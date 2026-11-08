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
    expect(find.text('Дом ещё не отмечен: Stowa напомнит, когда отметишь его в «Местах»'), findsOneWidget);
    expect(find.byKey(const ValueKey('item-place-reminder')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('item-place-reminder')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Убрать напоминание'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.items).getSingle()).remindPlace, isNull);
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
}
