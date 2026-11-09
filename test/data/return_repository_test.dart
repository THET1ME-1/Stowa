import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/return_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/return_plan.dart';

void main() {
  late AppDatabase db;
  late ReturnRepository returns;
  final now = DateTime(2026, 11, 6, 20, 30);

  setUp(() async {
    db = AppDatabase.memory();
    returns = ReturnRepository(db);
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Рецепты', icon: 'folder', shape: 'pill'));
  });
  tearDown(() => db.close());

  Future<void> note(
    String id,
    DateTime created, {
    ItemKind kind = ItemKind.note,
    String? body,
    int? seconds,
    DateTime? opened,
    String? folder,
    bool deleted = false,
  }) =>
      db.into(db.items).insert(ItemsCompanion.insert(
            id: id,
            kind: kind,
            title: id,
            body: Value(body ?? id),
            durationSeconds: Value(seconds),
            openedAt: Value(opened),
            folderId: Value(folder),
            deletedAt: Value(deleted ? created : null),
            createdAt: created,
            updatedAt: created,
          ));

  Future<void> reading(String id, int minutes) => db.into(db.facts).insert(
        FactsCompanion.insert(id: '$id-read', itemId: id, extractor: 'page', kind: FactKind.readingTime, value: '$minutes', number: Value(minutes.toDouble())),
      );

  group('посмотреть потом', () {
    test('непросмотренные ролики и статьи за 30 дней с известной длиной, свежие первыми', () async {
      await note('ролик', now.subtract(const Duration(days: 2)), kind: ItemKind.video, seconds: 754);
      await note('статья', now.subtract(const Duration(days: 1)), kind: ItemKind.link);
      await reading('статья', 7);
      // открыт, старше месяца, без длины, удалён, заметка — мимо
      await note('открыт', now.subtract(const Duration(days: 1)), kind: ItemKind.video, seconds: 60, opened: now);
      await note('старый', now.subtract(const Duration(days: 31)), kind: ItemKind.video, seconds: 60);
      await note('без длины', now.subtract(const Duration(days: 1)), kind: ItemKind.link);
      await note('удалён', now.subtract(const Duration(days: 1)), kind: ItemKind.video, seconds: 60, deleted: true);
      await note('мысль', now.subtract(const Duration(days: 1)), seconds: 60);

      final queue = await returns.watchLater(now);
      expect(queue.map((one) => one.id), ['статья', 'ролик']);
      expect(queue.map((one) => one.minutes), [7, 13]);
      expect(summarizeWatchLater(queue), const WatchLaterFound(videos: 1, articles: 1, minutes: 20));
    });
  });

  group('в этот день', () {
    test('ровно год назад — главнее месяца и недели', () async {
      await note('год', DateTime(2025, 11, 6, 9));
      await note('месяц', DateTime(2026, 10, 6, 9));
      await note('неделя', DateTime(2026, 10, 30, 9));
      final day = await returns.onThisDay(now);
      expect((day!.found.period, day.found.yearsAgo, day.found.firstTitle), (ReturnPeriod.year, 1, 'год'));
      expect(day.ids, ['год']);
    });

    test('без года — месяц, без месяца — неделя; несколько лет назад тоже год', () async {
      await note('неделя', DateTime(2026, 10, 30, 9));
      expect((await returns.onThisDay(now))!.found.period, ReturnPeriod.week);
      await note('месяц', DateTime(2026, 10, 6, 23, 59));
      expect((await returns.onThisDay(now))!.found.period, ReturnPeriod.month);
      await note('три года', DateTime(2023, 11, 6, 0, 5));
      final day = (await returns.onThisDay(now))!;
      expect((day.found.period, day.found.yearsAgo), (ReturnPeriod.year, 3));
    });

    test('другой день и удалённое не считаются, нечего вспомнить — null', () async {
      await note('вчера год назад', DateTime(2025, 11, 5, 9));
      await note('удалён', DateTime(2025, 11, 6, 9), deleted: true);
      expect(await returns.onThisDay(now), isNull);
    });

    test('31-е: месяца назад такого дня не было — месяц пропускается', () async {
      await note('30 ноября', DateTime(2026, 11, 30, 9));
      expect(await returns.onThisDay(DateTime(2026, 12, 31, 20)), isNull);
    });
  });

  group('неделя', () {
    test('сколько сохранено за 7 дней, сколько не открыто и без папки', () async {
      await note('a', now.subtract(const Duration(days: 1)));
      await note('b', now.subtract(const Duration(days: 2)), opened: now);
      await note('c', now.subtract(const Duration(days: 3)), folder: 'food');
      await note('старое', now.subtract(const Duration(days: 8)));
      final week = await returns.week(now);
      expect(week.found, const WeekFound(saved: 3, unopened: 2, unsorted: 2));
      expect(week.unopened, ['a', 'c']);
      expect(week.unsorted, ['a', 'b']);
    });
  });

  group('покупки', () {
    test('заметки с тегом #купить и списки «Купить:» с неотмеченными пунктами', () async {
      await note('молоко', now, body: 'Молоко и хлеб #купить');
      await db.into(db.tags).insert(TagsCompanion.insert(id: 't', name: 'купить', createdAt: now));
      await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: 'молоко', tagId: 't', source: TagSource.inline));
      await note('Купить: Борщ', now, body: 'Купить: Борщ\n- [ ] свёкла\n- [x] капуста\n- [ ] морковь');
      // всё отмечено — покупать нечего; просто чек-лист без «купить» — не покупки
      await note('Купить: Плов', now, body: 'Купить: Плов\n- [x] рис');
      await note('Поездка', now, body: 'Поездка\n- [ ] паспорт');
      final lists = await returns.shopping();
      expect({for (final one in lists) one.id: one.items}, {
        'молоко': <String>[],
        'Купить: Борщ': ['свёкла', 'морковь'],
      });
    });

    test('«купить молоко, хлеб и яйца» без двоеточия — тоже список, пункты из строки', () async {
      await note('купить молоко, хлеб и яйца', now, body: 'купить молоко, хлеб и яйца');
      await note('Купил молоко', now, body: 'Купил молоко');
      final lists = await returns.shopping();
      expect({for (final one in lists) one.id: one.items}, {
        'купить молоко, хлеб и яйца': ['молоко', 'хлеб', 'яйца'],
      });
    });
  });

  test('после полуночи пересчитывает без правок в базе: приложение открыто сутками', () async {
    await note('Борщ', DateTime(2025, 11, 7, 9));
    var clock = DateTime(2026, 11, 6, 23, 59);
    final seen = <bool>[];
    final watching = returns.watch(() => returns.onThisDay(clock), clock: () => clock, dayCheck: const Duration(milliseconds: 20)).listen((day) => seen.add(day != null));
    addTearDown(watching.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(seen, [false]);
    clock = DateTime(2026, 11, 7, 0, 1);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(seen, [false, true]);
  });
}
