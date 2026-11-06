import 'dart:io';

import 'package:drift/drift.dart' show Value;

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/domain/item_kind.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/capture_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase db;
  late Directory home;
  late CaptureService capture;
  late ItemsRepository items;

  setUp(() async {
    db = AppDatabase.memory();
    home = await Directory.systemTemp.createTemp('stowa_test');
    items = ItemsRepository(db);
    capture = CaptureService(db, tags: TagsRepository(db), filesRoot: home, clock: () => DateTime(2026, 11, 2, 12));
  });

  tearDown(() async {
    await capture.settled();
    await db.close();
    await home.delete(recursive: true);
  });

  Future<File> bigFile() async {
    final source = File(p.join(home.path, 'source.jpg'));
    await source.writeAsBytes(List.filled(12 * 1024 * 1024, 7));
    return source;
  }

  test('сохранение отдаёт id до копирования файлов и укладывается в 100 мс', () async {
    final source = await bigFile();
    // первый вызов прогревает базу и компилятор, меряем второй — как у живого телефона
    await capture.capture(const CaptureInput(text: 'прогрев'));
    final file = PickedFile(path: source.path, mime: 'image/jpeg', size: await source.length());
    final stopwatch = Stopwatch()..start();
    final id = await capture.capture(CaptureInput(text: 'x' * 50000, files: [file]));
    expect(stopwatch.elapsedMilliseconds, lessThan(100));
    final saved = await items.get(id);
    expect(saved!.item.body.length, 50000);
    expect(saved.item.kind, ItemKind.image);
  });

  test('файл ложится в папку приложения, путь хранится относительный', () async {
    final source = await bigFile();
    final id = await capture.capture(CaptureInput(
      files: [PickedFile(path: source.path, mime: 'image/jpeg', size: await source.length())],
    ));
    await capture.settled();
    final saved = await items.get(id);
    expect(saved!.attachments, hasLength(1));
    final stored = saved.attachments.single.path;
    expect(p.isRelative(stored), isTrue);
    expect(await File(p.join(home.path, stored)).length(), await source.length());
    expect(saved.item.title, 'Source');
  });

  test('у картинки запоминается размер как на экране', () async {
    final photo = File('test/fixtures/images/rotated.jpg');
    final id = await capture.capture(CaptureInput(files: [PickedFile(path: photo.path, mime: 'image/jpeg', size: await photo.length())]));
    await capture.settled();
    final file = (await items.get(id))!.attachments.single;
    expect((file.width, file.height), (20, 30));
  });

  test('картинкам, сохранённым до учёта размеров, размер дописывается', () async {
    final photo = File('test/fixtures/images/wide.png');
    await Directory(p.join(home.path, 'attachments', 'old')).create(recursive: true);
    await photo.copy(p.join(home.path, 'attachments', 'old', 'wide.png'));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'old', kind: ItemKind.image, title: 'Старое', createdAt: DateTime(2026), updatedAt: DateTime(2026)));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'fa', itemId: 'old', path: p.join('attachments', 'old', 'wide.png'), mime: 'image/png', size: 92));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'gone', itemId: 'old', path: 'attachments/old/missing.png', mime: 'image/png', size: 1));

    await capture.fillImageSizes();
    final file = (await items.get('old'))!.attachments.firstWhere((one) => one.id == 'fa');
    expect((file.width, file.height), (30, 20));
  });

  test('старые заголовки-имена файлов переписываются, свои заголовки не трогаются', () async {
    Future<void> old(String id, String title, String file, {String body = ''}) async {
      await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.image, title: title, body: Value(body), createdAt: DateTime(2026, 11, 1), updatedAt: DateTime(2026, 11, 1)));
      await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'f$id', itemId: id, path: 'attachments/$id/0_$file', mime: 'image/jpeg', size: 1));
    }

    await old('cam', 'IMG_20261101_101010.jpg', 'IMG_20261101_101010.jpg');
    await old('human', 'dver2.jpg', 'dver2.jpg');
    await old('mine', 'Дверь в Тбилиси', 'IMG_1.jpg');
    await old('text', 'IMG_2.jpg', 'IMG_2.jpg', body: 'подпись');

    await capture.retitleFileNames(({required mime, required fileName, required at}) => 'Фото от 1 ноября');
    Future<String> title(String id) async => (await items.get(id))!.item.title;
    expect(await title('cam'), 'Фото от 1 ноября');
    expect(await title('human'), 'Dver2');
    expect(await title('mine'), 'Дверь в Тбилиси');
    expect(await title('text'), 'IMG_2.jpg');
  });

  test('название места со всей строкой адреса сокращается до улицы и города', () async {
    Future<void> old(String id, String? place, {String? remind}) => db
        .into(db.items)
        .insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: id, placeName: Value(place), remindPlaceName: Value(remind), createdAt: DateTime(2026, 11, 1), updatedAt: DateTime(2026, 11, 1)));

    await old('long', 'Bulevardul Iuri Gagarin 7, Chișinău, Молдова, Chișinău', remind: 'улица Пушкина 12, Кишинёв, Молдова, Кишинёв');
    await old('short', 'Ботаника, Кишинёв');
    await old('none', null);

    await capture.shortenPlaceNames();
    final long = (await items.get('long'))!.item;
    expect(long.placeName, 'Bulevardul Iuri Gagarin 7, Chișinău');
    expect(long.remindPlaceName, 'улица Пушкина 12, Кишинёв');
    expect((await items.get('short'))!.item.placeName, 'Ботаника, Кишинёв');
    expect((await items.get('none'))!.item.placeName, isNull);
  });

  test('пачка заметок одной транзакцией: файлы ложатся после неё, afterCapture видит каждую записанной', () async {
    final source = await bigFile();
    final seen = <String, bool>{};
    capture.afterCapture = (id) => seen[id] = false;
    final ids = await capture.captureAll([
      const CaptureInput(text: 'Купить кофе'),
      CaptureInput(text: 'Море', files: [PickedFile(path: source.path, mime: 'image/jpeg', size: await source.length())]),
      CaptureInput(text: 'Старое', at: DateTime(2023, 5, 12)),
    ]);
    for (final id in seen.keys) {
      seen[id] = await items.get(id) != null;
    }
    expect(seen, {for (final id in ids) id: true});
    await capture.settled();
    expect((await items.get(ids[1]))!.attachments, hasLength(1));
    expect((await items.get(ids[2]))!.item.createdAt, DateTime(2023, 5, 12));
  });

  test('пачка зовёт afterBatch один раз со всеми заметками, а не afterCapture на каждую', () async {
    final single = <String>[];
    final batches = <List<String>>[];
    capture
      ..afterCapture = single.add
      ..afterBatch = batches.add;
    final ids = await capture.captureAll([const CaptureInput(text: 'раз'), const CaptureInput(text: 'два'), const CaptureInput(text: 'три')]);
    expect(batches, [ids]);
    expect(single, isEmpty);
    // одна заметка — обычный путь
    final one = await capture.capture(const CaptureInput(text: 'одна'));
    expect(single, [one]);
  });

  test('«напомни дома купить хлеб» — напоминание по месту, место уходит из заголовка', () async {
    final id = await capture.capture(const CaptureInput(text: 'напомни дома купить хлеб'));
    final item = (await items.get(id))!.item;
    expect((item.remindPlace, item.title, item.reminderAt), (PlaceReminderKind.home, 'Купить хлеб', null));
  });

  test('«напомни тут» просит место даже без «здесь и сейчас»; чип сняли — места нет', () async {
    final stamped = <String>[];
    capture.stampPlace = stamped.add;
    final here = await capture.capture(const CaptureInput(text: 'напомни тут купить кофе', here: false));
    expect((await items.get(here))!.item.remindPlace, PlaceReminderKind.point);
    expect(stamped, [here]);
    final plain = await capture.capture(const CaptureInput(text: 'напомни дома купить хлеб', detectPlace: false));
    expect((await items.get(plain))!.item.remindPlace, isNull);
    final forced = await capture.capture(const CaptureInput(text: 'купить молоко', forcedPlace: PlaceReminder(PlaceReminderKind.shop)));
    expect((await items.get(forced))!.item.remindPlace, PlaceReminderKind.shop);
  });

  test('пустая заметка в пачке — не сохраняется ничего', () async {
    await expectLater(capture.captureAll([const CaptureInput(text: 'есть'), const CaptureInput(text: '  ')]), throwsArgumentError);
    expect(await db.select(db.items).get(), isEmpty);
  });

  test('старые заметки, записанные ссылкой из-за адреса внутри, снова заметки', () async {
    Future<void> old(String id, ItemKind kind, String body) =>
        db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: kind, title: id, body: Value(body), createdAt: DateTime(2026), updatedAt: DateTime(2026)));
    await old('long', ItemKind.link, 'Дипломная\n- 40 страниц\n- 20 источников\nflutter.dev/docs');
    await old('short', ItemKind.video, 'Паста https://vt.tiktok.com/x');
    // адрес лежит в своём поле, а в тексте только заголовок: это ссылка, не трогать
    await old('apart', ItemKind.link, 'Как варить кофе в турке');

    await capture.reclassifyNotes();
    expect((await items.get('long'))!.item.kind, ItemKind.note);
    expect((await items.get('short'))!.item.kind, ItemKind.video);
    expect((await items.get('apart'))!.item.kind, ItemKind.link);
  });

  test('ссылка с превью, которую правка сделала заметкой, снова ссылка', () async {
    Future<void> old(String id, String body, {DateTime? previewAt}) => db.into(db.items).insert(ItemsCompanion.insert(
          id: id,
          kind: ItemKind.note,
          title: id,
          body: Value(body),
          url: Value(firstUrl(body)?.toString()),
          previewAt: Value(previewAt),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ));
    await old('broken', 'https://rt.pornhub.com/view_video.php?viewkey=6440\n\nЛучшее видео, на которое у меня 100%.', previewAt: DateTime(2026));
    // превью не было: это и раньше была заметка
    await old('plain', 'Кофе https://coffee.ru/turka');

    await capture.reclassifyNotes();
    expect((await items.get('broken'))!.item.kind, ItemKind.link);
    expect((await items.get('plain'))!.item.kind, ItemKind.note);
  });

  test('фото с камеры без текста: вместо IMG_… подпись от экрана', () async {
    final source = await bigFile();
    final camera = await source.copy(p.join(source.parent.path, 'IMG_20261103_154512.jpg'));
    final id = await capture.capture(CaptureInput(
      files: [PickedFile(path: camera.path, mime: 'image/jpeg', size: await camera.length())],
      untitled: 'Фото от 3 ноября',
    ));
    expect((await items.get(id))!.item.title, 'Фото от 3 ноября');
  });

  test('теги из текста ставятся с источником inline, выбранные руками — user', () async {
    final id = await capture.capture(const CaptureInput(text: 'поменять масло #Машина', forcedTagNames: ['Срочно']));
    final saved = await items.get(id);
    expect(saved!.tags, {'машина': TagSource.inline, 'срочно': TagSource.user});
  });

  test('«#Машина» и «машина» дают один тег', () async {
    await capture.capture(const CaptureInput(text: 'шины #Машина'));
    await capture.capture(const CaptureInput(text: 'страховка', forcedTagNames: ['машина']));
    final count = await db.customSelect('SELECT COUNT(*) AS c FROM tags').getSingle();
    expect(count.read<int>('c'), 1);
  });

  test('вид и адрес берутся из текста', () async {
    final id = await capture.capture(const CaptureInput(text: 'рецепт пасты vm.tiktok.com/ZM8x'));
    final saved = await items.get(id);
    expect(saved!.item.kind, ItemKind.video);
    expect(saved.item.url, 'https://vm.tiktok.com/ZM8x');
  });

  test('заголовок — первая строка без разметки, не длиннее 80 знаков', () async {
    final id = await capture.capture(const CaptureInput(text: '# Ремонт кухни\n- [ ] плитка'));
    expect((await items.get(id))!.item.title, 'Ремонт кухни');
    final long = await capture.capture(CaptureInput(text: 'слово ' * 40));
    expect((await items.get(long))!.item.title.length, lessThanOrEqualTo(80));
  });

  test('папка, выбранная руками, ставится сразу и помечается решением человека', () async {
    final id = await capture.capture(const CaptureInput(text: 'идея', forcedFolderId: 'ideas'));
    final saved = await items.get(id);
    expect(saved!.item.folderId, 'ideas');
    expect(saved.item.sortedBy, SortedBy.user);
    expect(saved.item.sortState, SortState.sorted);
  });

  test('после сохранения без папки вещь в очереди ИИ, разложенная руками — нет', () async {
    final loose = await capture.capture(const CaptureInput(text: 'непонятная мысль'));
    await capture.capture(const CaptureInput(text: 'идея', forcedFolderId: 'ideas'));
    final jobs = await db.select(db.aiJobs).get();
    expect(jobs.single.itemId, loose);
    expect(jobs.single.kind, 'sort');
  });

  test('файл не скопировался, а текста нет — пустая вещь не остаётся, сбой сообщается', () async {
    final failures = <CopyFailure>[];
    final subscription = capture.copyFailures.listen(failures.add);
    final id = await capture.capture(CaptureInput(files: [PickedFile(path: '${home.path}/нет_такого.pdf', mime: 'application/pdf', size: 10)]));
    await capture.settled();
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(await items.get(id), isNull);
    expect(failures.single.itemId, id);
    expect(failures.single.removed, isTrue);
  });

  test('файл не скопировался, но текст есть — вещь остаётся с текстом', () async {
    final failures = <CopyFailure>[];
    final subscription = capture.copyFailures.listen(failures.add);
    final id = await capture.capture(CaptureInput(text: 'договор аренды', files: [PickedFile(path: '${home.path}/нет_такого.pdf', mime: 'application/pdf', size: 10)]));
    await capture.settled();
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect((await items.get(id))!.item.body, 'договор аренды');
    expect(failures.single.removed, isFalse);
  });

  test('голосовое встаёт в очередь даже разложенным: его ждёт расшифровка', () async {
    final voice = File('${home.path}/in.m4a')..writeAsBytesSync([1, 2, 3]);
    final id = await capture.capture(CaptureInput(text: '', forcedFolderId: 'ideas', files: [PickedFile(path: voice.path, mime: 'audio/mp4', size: 3)]));
    expect((await db.select(db.aiJobs).getSingle()).itemId, id);
  });

  test('дата в тексте ставит напоминание и уходит из заголовка', () async {
    final id = await capture.capture(const CaptureInput(text: '23 декабря 13:00 зубной'));
    final saved = await items.get(id);
    expect(saved!.item.reminderAt, DateTime(2026, 12, 23, 13));
    expect(saved.item.title, 'Зубной');
    expect(saved.item.body, '23 декабря 13:00 зубной');
  });

  test('напоминание, снятое человеком, из текста не ставится', () async {
    final id = await capture.capture(const CaptureInput(text: 'завтра в 10 сервис', detectReminder: false));
    final saved = await items.get(id);
    expect(saved!.item.reminderAt, isNull);
    expect(saved.item.title, 'Завтра в 10 сервис');
  });

  test('время, выбранное руками, главнее найденного в тексте', () async {
    final picked = DateTime(2026, 11, 20, 18);
    final id = await capture.capture(CaptureInput(text: 'завтра в 10 сервис', forcedReminder: picked));
    expect((await items.get(id))!.item.reminderAt, picked);
  });

  test('ближайшие напоминания приходят потоком по порядку', () async {
    await capture.capture(const CaptureInput(text: '23 декабря 13:00 зубной'));
    await capture.capture(const CaptureInput(text: 'завтра в 10 сервис'));
    await capture.capture(const CaptureInput(text: 'просто заметка'));
    final upcoming = await items.watchUpcoming(DateTime(2026, 11, 2, 12)).first;
    expect(upcoming.map((card) => card.title), ['Сервис', 'Зубной']);
    expect(upcoming.first.reminderAt, DateTime(2026, 11, 3, 10));
  });

  test('пустую вещь не сохраняет', () async {
    expect(() => capture.capture(const CaptureInput(text: '   ')), throwsArgumentError);
  });

  test('после сохранения зовётся хук с id', () async {
    final seen = <String>[];
    capture.afterCapture = seen.add;
    final id = await capture.capture(const CaptureInput(text: 'код домофона 4512'));
    expect(seen, [id]);
  });

  test('последние вещи приходят потоком, новые первыми', () async {
    await capture.capture(const CaptureInput(text: 'первая'));
    capture = CaptureService(db, tags: TagsRepository(db), filesRoot: home, clock: () => DateTime(2026, 11, 2, 13));
    await capture.capture(const CaptureInput(text: 'вторая'));
    final recent = await items.watchRecent().first;
    expect(recent.map((card) => card.title), ['Вторая', 'Первая']);
  });

  group('правила', () {
    setUp(() async {
      await db.into(db.folders).insert(FoldersCompanion.insert(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill'));
      await db.into(db.rules).insert(RulesCompanion.insert(
            id: 'r1',
            conditionKind: RuleConditionKind.keyword,
            conditionValue: 'шиномонтаж',
            actionKind: RuleActionKind.addTag,
            actionValue: 'машина',
          ));
      await db.into(db.rules).insert(RulesCompanion.insert(
            id: 'r2',
            conditionKind: RuleConditionKind.hasTag,
            conditionValue: 'машина',
            actionKind: RuleActionKind.toFolder,
            actionValue: 'car',
          ));
    });

    test('слово ставит тег, тег кладёт в папку, разобрано правилом', () async {
      final id = await capture.capture(const CaptureInput(text: 'записаться на шиномонтаж'));
      final saved = (await items.get(id))!;
      expect(saved.item.folderId, 'car');
      expect(saved.item.sortedBy, SortedBy.rule);
      expect(saved.item.sortState, SortState.sorted);
      expect(saved.tags, {'машина': TagSource.rule});
    });

    test('«во Входящие как есть» правила не трогают и ИИ не разбирает', () async {
      final id = await capture.capture(const CaptureInput(text: 'записаться на шиномонтаж', asIs: true));
      final saved = (await items.get(id))!;
      expect(saved.item.folderId, isNull);
      expect(saved.item.sortedBy, SortedBy.user);
      expect(saved.item.sortState, SortState.sorted);
      expect(saved.tags, isEmpty);
    });

    test('папка, выбранная руками, главнее правила', () async {
      await db.into(db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'squircle'));
      final id = await capture.capture(const CaptureInput(text: 'шиномонтаж', forcedFolderId: 'home'));
      final saved = (await items.get(id))!;
      expect(saved.item.folderId, 'home');
      expect(saved.item.sortedBy, SortedBy.user);
    });
  });

  test('без правила заметка ложится туда, где уже был её герой', () async {
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'novel', name: 'Роман', icon: 'menu_book', shape: 'squircle'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill'));
    await capture.capture(const CaptureInput(text: 'Милтон работает курьером', forcedFolderId: 'novel'));
    await capture.capture(const CaptureInput(text: 'Сцена: Милтон спорит с сестрой', forcedFolderId: 'novel'));
    await capture.capture(const CaptureInput(text: 'Замена масла', forcedFolderId: 'car'));

    final id = await capture.capture(const CaptureInput(text: 'Пусть у Милтона будет личная проблема'));
    final saved = (await items.get(id))!;
    expect(saved.item.folderId, 'novel');
    expect(saved.item.sortedBy, SortedBy.similar);
    expect(saved.item.sortState, SortState.sorted);
  });

  test('голосовое получает свой заголовок, а не имя файла', () async {
    final source = File(p.join(home.path, 'voice_1.m4a'))..writeAsBytesSync([1, 2, 3]);
    final id = await capture.capture(CaptureInput(files: [PickedFile(path: source.path, mime: 'audio/mp4', size: 3)], title: 'Голосовое'));
    final saved = (await items.get(id))!;
    expect(saved.item.title, 'Голосовое');
    expect(saved.item.kind, ItemKind.voice);
  });

  test('«Дописать» добавляет мысль в конец старой заметки', () async {
    final id = await capture.capture(const CaptureInput(text: 'Погода для пары'));
    await items.append(id, 'видеть небо у второго', DateTime(2026, 11, 3));
    final saved = (await items.get(id))!;
    expect(saved.item.body, 'Погода для пары\n\nвидеть небо у второго');
    expect(saved.item.updatedAt, DateTime(2026, 11, 3));
    expect(await db.searchIds('небо'), [id]);
  });
}
