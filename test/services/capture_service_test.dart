import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
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
    expect(saved.item.title, 'source.jpg');
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

  test('«Дописать» добавляет мысль в конец старой заметки', () async {
    final id = await capture.capture(const CaptureInput(text: 'Погода для пары'));
    await items.append(id, 'видеть небо у второго', DateTime(2026, 11, 3));
    final saved = (await items.get(id))!;
    expect(saved.item.body, 'Погода для пары\n\nвидеть небо у второго');
    expect(saved.item.updatedAt, DateTime(2026, 11, 3));
    expect(await db.searchIds('небо'), [id]);
  });
}
