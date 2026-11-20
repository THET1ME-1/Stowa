import 'dart:io';

import 'package:drift/drift.dart' show ApplyInterceptor, QueryExecutor, QueryInterceptor, TransactionExecutor, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/core/user_first.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/auto_sorter.dart';
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_writer.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  final now = DateTime(2026, 11, 6, 10);

  setUp(() async {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_vault');
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  VaultWriter writer([AppDatabase? base]) => VaultWriter(base ?? db, root: root, clock: () => now);
  VaultReader reader([AppDatabase? base]) => VaultReader(base ?? db, root: root, clock: () => now);
  File file(String relative) => File(p.join(root.path, relative));
  void put(String relative, String text) => file(relative)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);
  Future<Item?> item(String id) => (db.select(db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<List<Item>> items() => db.select(db.items).get();
  Future<List<String>> queue() async => [for (final row in await db.select(db.vaultQueue).get()) row.target];
  Future<void> note(String id, String title, {String? body, String? folder}) => db
      .into(db.items)
      .insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(body ?? title), folderId: Value(folder), createdAt: now, updatedAt: now));
  // правка снаружи: другое время файла, как у настоящего редактора
  void touch(String relative, String text) {
    file(relative).writeAsStringSync(text);
    file(relative).setLastModifiedSync(DateTime.now().add(const Duration(minutes: 5)));
  }

  test('в браузере: сверка в фоне уступает человеку, а пересборка, которую он ждёт у счётчика, — нет', () async {
    var clock = now;
    final gate = UserFirst(enabled: true, clock: () => clock, hold: const Duration(seconds: 2), poll: const Duration(milliseconds: 10));
    final busy = VaultReader(db, root: root, clock: () => now, gate: gate);
    put('Идеи.md', 'Сделать полку\n');
    put('Схема.bin', 'не заметка и не вложение');
    gate.touch();
    final rebuilt = await busy.rebuild().timeout(const Duration(seconds: 5));
    expect(rebuilt.added, greaterThan(0));

    // новый файл, о котором база не знает: сверка спросит у базы, упомянут ли он в заметках
    put('Чертёж.bin', 'ещё один файл');
    gate.touch();
    var done = false;
    final running = busy.reconcile().then((_) => done = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(done, isFalse, reason: 'человек занят — сверка ждёт');
    clock = clock.add(const Duration(seconds: 3));
    await running.timeout(const Duration(seconds: 5));
    expect(done, isTrue);
  });

  test('обложка из шапки заметки — не отдельная заметка', () async {
    // так пишет обложки плагин книг Obsidian: в свойстве, а не в тексте
    put('Книги/Обложки/1984.jpg', 'jpg');
    put('Книги/Обложки/Дюна.webp', 'webp');
    put('Книги/1984.md', '---\nОбложка: "[[Книги/Обложки/1984.jpg|1984.jpg]]"\nАвтор: Оруэлл\n---\nПрочитать к пятнице\n');
    put('Книги/Дюна.md', '---\nОбложка: "[[Дюна.webp]]"\n---\nВзять у Сани\n');
    await reader().reconcile();
    expect((await items()).map((one) => one.title), unorderedEquals(['1984', 'Дюна']));
  });

  test('пока файлы копии пишутся, сверка стоит и начинается только после них', () async {
    // восстановление из копии пишет тысячи файлов: сверке незачем разбирать хранилище,
    // собранное наполовину
    final vault = reader();
    late Future<void> woken;
    var scanned = false;
    await vault.withoutScans((keep) async {
      put('Вложения/схема.png', 'png');
      woken = vault.reconcile().then((_) => scanned = true);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await keep();
      expect(scanned, isFalse, reason: 'сверка ждёт конца записи');
      put('Курсовая.md', 'Текст курсовой\n\n![[схема.png]]\n');
    });
    await woken;
    expect(scanned, isTrue);
    final all = await items();
    expect(all.map((item) => item.title), ['Курсовая']);
    final files = await db.select(db.attachments).get();
    expect(files.map((file) => file.path), ['Вложения/схема.png']);
  });

  test('правка текста снаружи видна в базе и в поиске, назад в очередь не встаёт', () async {
    await note('a', 'Плитка', body: 'Плитка\nкупить клей');
    await writer().drain();
    touch('Плитка.md', file('Плитка.md').readAsStringSync().replaceFirst('купить клей', 'купить затирку'));
    final scan = await reader().reconcile();
    expect(scan.changed, 1);
    expect((await item('a'))!.body, 'Плитка\nкупить затирку');
    expect(await db.searchIds('затирку'), ['a']);
    // сама заметка назад не пишется; прежний текст ушёл в историю
    expect(await queue(), ['history:a']);
  });

  test('новый файл из Obsidian становится вещью, id дописан в файл, остальное как было', () async {
    put('Идеи.md', 'Сделать полку #дом\n');
    final scan = await reader().reconcile();
    expect(scan.added, 1);
    final created = (await items()).single;
    expect(created.title, 'Идеи');
    expect(created.body, 'Сделать полку #дом');
    expect(file('Идеи.md').readAsStringSync(), '---\nid: ${created.id}\n---\nСделать полку #дом\n');
    final tags = await db.select(db.tags).get();
    expect(tags.map((tag) => tag.name), ['дом']);
    // новый тег уходит в tags.json, а сама заметка назад не пишется
    expect(await queue(), ['meta:tags']);
    // второй проход ничего не меняет
    expect((await reader().reconcile()).changed + (await reader().reconcile()).added, 0);
  });

  test('сверку оборвали посреди первого прохода — следующая не плодит копий', () async {
    for (var index = 0; index < 250; index++) {
      put('Конспекты/Лекция $index.md', 'Текст лекции $index');
    }
    // приложение закрыли, пока шла вторая сотня: часы бросают посреди её записи
    var ticks = 0;
    final broken = VaultReader(db, root: root, clock: () {
      if (++ticks > 150) throw StateError('закрыли');
      return now;
    });
    await expectLater(broken.reconcile(), throwsStateError);
    await reader().reconcile();
    final all = await (db.select(db.items)..where((t) => t.deletedAt.isNull())).get();
    expect(all, hasLength(250));
    expect(await db.select(db.vaultFiles).get(), hasLength(250));
  });

  test('удалённый снаружи файл — вещь в корзине', () async {
    await note('a', 'Плитка');
    await writer().drain();
    file('Плитка.md').deleteSync();
    final scan = await reader().reconcile();
    expect(scan.removed, 1);
    expect((await item('a'))!.deletedAt, isNotNull);
  });

  test('папка, созданная в файловом менеджере, — папка Stowa; подпапка — вложенная папка любой глубины', () async {
    put('Сад/Грядки.md', 'Посадить чеснок');
    put('Сад/Весна/Рассада.md', 'Томаты');
    put('Сад/Весна/Март/Апрель/Полив.md', 'Через день');
    put('Дача/Весна/Окна.md', 'Помыть');
    put('.obsidian/workspace.md', 'служебное Obsidian');
    await reader().reconcile();
    final folders = {for (final folder in await db.select(db.folders).get()) folder.id: folder};
    String pathOf(String? id) {
      final names = <String>[];
      for (var current = id; current != null; current = folders[current]!.parentId) {
        names.insert(0, folders[current]!.name);
      }
      return names.join('/');
    }

    expect(folders.values.map((folder) => pathOf(folder.id)), unorderedEquals(['Сад', 'Сад/Весна', 'Сад/Весна/Март', 'Сад/Весна/Март/Апрель', 'Дача', 'Дача/Весна']));
    final byTitle = {for (final one in await items()) one.title: pathOf(one.folderId)};
    expect(byTitle, {'Грядки': 'Сад', 'Рассада': 'Сад/Весна', 'Полив': 'Сад/Весна/Март/Апрель', 'Окна': 'Дача/Весна'});

    // повторная сверка и запись не плодят папок и не двигают файлы
    await writer().drain();
    await reader().reconcile();
    expect(await db.select(db.folders).get(), hasLength(6));
    expect(file('Сад/Весна/Март/Апрель/Полив.md').existsSync(), isTrue);
  });

  test('[[Заметка]] — связь из текста (в таблицу не пишется), ![[фото.jpg]] рядом с заметкой — вложение', () async {
    put('Чеснок.md', 'Сорт Любаша');
    put('Сад/Грядки.md', 'Посадить, см. [[Чеснок]]\n\n![[фото.jpg]]\n');
    put('Сад/фото.jpg', 'jpeg');
    await reader().reconcile();
    final all = await items();
    final beds = all.firstWhere((one) => one.title == 'Грядки');
    final garlic = all.firstWhere((one) => one.title == 'Чеснок');
    // связь считается из текста: убрали [[…]] в Obsidian — пропала и в Stowa
    expect(await db.select(db.links).get(), isEmpty);
    final linked = await ItemsRepository(db).watchLinked(beds.id).first;
    expect([for (final one in linked) (one.card.id, one.kind)], [(garlic.id, LinkKind.text)]);
    final attachment = (await db.select(db.attachments).get()).single;
    expect(attachment.path, 'Сад/фото.jpg');
    expect(attachment.mime, 'image/jpeg');
  });

  test('правка с двух сторон: файл берётся, версия из базы — рядом отдельной вещью с тегом «конфликт»', () async {
    await note('a', 'Плитка', body: 'Плитка\nверсия Stowa 1');
    await writer().drain();
    // в приложении поправили, но записать не успели — и тут же пришёл файл от Syncthing
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(const ItemsCompanion(body: Value('Плитка\nверсия Stowa 2')));
    touch('Плитка.md', file('Плитка.md').readAsStringSync().replaceFirst('версия Stowa 1', 'версия с компьютера'));
    final scan = await reader().reconcile();
    expect(scan.conflicts, 1);
    expect((await item('a'))!.body, 'Плитка\nверсия с компьютера');
    final copy = (await items()).firstWhere((one) => one.id != 'a');
    expect(copy.title, 'Плитка (Stowa)');
    expect(copy.body, contains('версия Stowa 2'));
    final tagged = await db.customSelect("SELECT tags.name FROM item_tags JOIN tags ON tags.id = item_tags.tag_id WHERE item_tags.item_id = '${copy.id}'").get();
    expect(tagged.map((row) => row.read<String>('name')), ['конфликт']);
  });

  test('конфликт Syncthing — отдельная вещь с тегом «конфликт», у оригинала свой id', () async {
    await note('a', 'Плитка', body: 'Плитка\nодин');
    await writer().drain();
    put('Плитка.sync-conflict-20261106-101500-ABCDEFG.md', file('Плитка.md').readAsStringSync().replaceFirst('один', 'два'));
    await reader().reconcile();
    final all = await items();
    expect(all, hasLength(2));
    final copy = all.firstWhere((one) => one.id != 'a');
    expect(copy.body, contains('два'));
    expect((await item('a'))!.body, contains('один'));
  });

  test('пересборка из папки: вещи, папки, теги, правила, факты и прогоны — без сети и без повторного разбора', () async {
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'f', name: 'Ремонт', icon: 'build', shape: 'gem'));
    await note('a', 'Плитка', body: 'Плитка\nклей', folder: 'f');
    await db.into(db.tags).insert(TagsCompanion.insert(id: 't', name: 'дом', createdAt: now, pinned: const Value(true)));
    await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: 'a', tagId: 't', source: TagSource.user));
    await db.into(db.rules).insert(RulesCompanion.insert(id: 'r', conditionKind: RuleConditionKind.keyword, conditionValue: 'плитка', actionKind: RuleActionKind.addTag, actionValue: 't'));
    await db.into(db.facts).insert(FactsCompanion.insert(id: 'x', itemId: 'a', extractor: 'file_text', kind: FactKind.fileText, value: 'Затирка серая'));
    await db.into(db.extractorRuns).insert(ExtractorRunsCompanion.insert(itemId: 'a', extractor: 'file_text', version: 3, itemStamp: const Value('s1')));
    await writer().drain();

    // переустановка: база пустая, папка та же
    final fresh = AppDatabase.memory();
    addTearDown(fresh.close);
    var steps = 0;
    await reader(fresh).rebuild(progress: (step, done, total) => steps++);
    expect(steps, greaterThan(0));
    final restored = await (fresh.select(fresh.items)..where((t) => t.id.equals('a'))).getSingle();
    expect(restored.folderId, 'f');
    expect((await fresh.select(fresh.folders).getSingle()).icon, 'build');
    expect((await fresh.select(fresh.tags).getSingle()).pinned, isTrue);
    expect((await fresh.select(fresh.rules).getSingle()).conditionValue, 'плитка');
    expect((await fresh.select(fresh.facts).getSingle()).value, 'Затирка серая');
    expect((await fresh.select(fresh.extractorRuns).getSingle()).version, 3);
    expect(await fresh.searchIds('затирка'), ['a'], reason: 'текст фактов в поиске сразу');
    expect(await fresh.select(fresh.vaultQueue).get(), isEmpty, reason: 'собранное не пишется обратно');
  });

  test('цитаты статьи переживают переустановку и сразу ищутся по пометке', () async {
    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'a', kind: ItemKind.link, title: 'Кофе без турки', url: const Value('https://blog.example.com/kofe'), createdAt: now, updatedAt: now),
    );
    await db.into(db.highlights).insert(HighlightsCompanion.insert(id: 'h1', itemId: 'a', quote: 'вода важнее зёрен', note: const Value('купить фильтр'), position: const Value(120), createdAt: now));
    await writer().drain();

    final fresh = AppDatabase.memory();
    addTearDown(fresh.close);
    await reader(fresh).rebuild();
    final quotes = await fresh.select(fresh.highlights).get();
    expect([for (final one in quotes) (one.itemId, one.quote, one.note, one.position)], [('a', 'вода важнее зёрен', 'купить фильтр', 120)]);
    expect(await fresh.searchIds('фильтр'), ['a']);
    expect(await fresh.select(fresh.vaultQueue).get(), isEmpty, reason: 'собранное не пишется обратно');
  });

  test('история правок переживает переустановку и назад не пишется', () async {
    await note('a', 'Плитка', body: 'Плитка\n20×20');
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(ItemsCompanion(body: const Value('Плитка\n30×30'), updatedAt: Value(now.add(const Duration(hours: 1)))));
    await writer().drain();

    final fresh = AppDatabase.memory();
    addTearDown(fresh.close);
    await reader(fresh).rebuild();
    final versions = await fresh.select(fresh.noteVersions).get();
    expect([for (final one in versions) (one.itemId, one.body, one.savedAt)], [('a', 'Плитка\n20×20', now)]);
    expect(await fresh.select(fresh.vaultQueue).get(), isEmpty);
  });

  test('правка в Obsidian получает время файла и оставляет прежний текст в истории', () async {
    await note('a', 'Плитка', body: 'Плитка\nкупить клей');
    await writer().drain();
    // Obsidian меняет текст, а свойство updated в файле остаётся прежним
    touch('Плитка.md', file('Плитка.md').readAsStringSync().replaceFirst('купить клей', 'купить затирку'));
    await reader().reconcile();
    final edited = (await item('a'))!;
    expect(edited.updatedAt.isAfter(now), isTrue);
    expect((await db.select(db.noteVersions).getSingle()).body, 'Плитка\nкупить клей');
  });

  test('две сверки разом (окно и фоновая задача) не заводят заметку и папку дважды', () async {
    put('Сад/Грядки.md', 'Посадить чеснок');
    put('Сад/Рассада.md', 'Томаты');
    // у фона своя очередь сверки, общая у них только база
    await Future.wait([reader().reconcile(), reader().reconcile()]);
    expect((await items()).map((one) => one.title), unorderedEquals(['Грядки', 'Рассада']));
    expect(await db.select(db.folders).get(), hasLength(1));
  });

  test('чужая сверка оборвалась посреди прохода — её метка не держит вечно', () async {
    await db.into(db.vaultFlags).insert(VaultFlagsCompanion.insert(name: 'reading:${root.path}', value: Value('${now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch}|оборвался')));
    put('Идеи.md', 'Полка');
    await reader().reconcile().timeout(const Duration(seconds: 5));
    expect((await items()).single.title, 'Идеи');
  });

  test('счётчик сборки считает заметки, а не проходы: «… из 3», от нуля до трёх', () async {
    for (final name in ['a', 'b', 'c']) {
      put('$name.md', 'заметка $name');
    }
    final seen = <(int, int)>[];
    await reader().rebuild(progress: (step, done, total) => step == RebuildStep.notes ? seen.add((done, total)) : null);
    expect(seen.map((step) => step.$2).toSet(), {3});
    expect(seen.first.$1, 0);
    expect(seen.last, (3, 3));
    expect([for (final step in seen) step.$1], orderedEquals([...seen.map((step) => step.$1)]..sort()), reason: 'счётчик не откатывается назад');
  });

  test('после заметок ход идёт дальше по шагам: файлы, потом добытое о заметках, до «N из N»', () async {
    for (final id in ['a', 'b', 'c']) {
      await note(id, 'Заметка $id');
      await db.into(db.facts).insert(FactsCompanion.insert(id: 'x$id', itemId: id, extractor: 'file_text', kind: FactKind.fileText, value: 'текст $id'));
    }
    put('Хлам/схема.png', 'png');
    await writer().drain();

    final fresh = AppDatabase.memory();
    addTearDown(fresh.close);
    final seen = <(RebuildStep, int, int)>[];
    await reader(fresh).rebuild(progress: (step, done, total) => seen.add((step, done, total)));
    expect(seen.map((one) => one.$1).toSet().toList(), [RebuildStep.notes, RebuildStep.files, RebuildStep.extras], reason: 'шаги по порядку, назад не возвращаются');
    expect(seen.last, (RebuildStep.extras, 3, 3));
    final files = [for (final one in seen) if (one.$1 == RebuildStep.files) one];
    expect(files.last.$2, files.last.$3, reason: 'файлы дошли до конца');
  });

  test('файлы без своей заметки сверяются с текстом заметок один раз, а не запросом на каждый файл', () async {
    // запрос на файл просматривал текст всех заметок: 222 файла College — 20 с вне браузера
    for (var i = 0; i < 60; i++) {
      put('Хлам/скан $i.png', 'png');
    }
    put('Хлам/упомянутый.png', 'png');
    put('Заметка.md', 'Скан лежит в упомянутый.png, переложить');
    final counter = _Selects();
    final counted = AppDatabase(NativeDatabase.memory().interceptWith(counter));
    addTearDown(counted.close);
    await reader(counted).reconcile();
    final titles = [for (final one in await counted.select(counted.items).get()) one.title];
    expect(titles, hasLength(61), reason: 'шестьдесят сканов и заметка');
    expect(titles, isNot(contains('упомянутый')), reason: 'упомянутый в тексте файл — не заметка');
    expect(counter.count, lessThan(40));
  });

  test('добытое о заметках возвращается пачками, а не транзакцией на каждую заметку', () async {
    // в браузере каждая транзакция — запись на диск: 1062 файла College шли по одной 11 минут
    for (var i = 0; i < 120; i++) {
      await note('n$i', 'Заметка $i');
      await db.into(db.facts).insert(FactsCompanion.insert(id: 'x$i', itemId: 'n$i', extractor: 'file_text', kind: FactKind.fileText, value: 'текст $i'));
    }
    await writer().drain();

    final counter = _Transactions();
    final fresh = AppDatabase(NativeDatabase.memory().interceptWith(counter));
    addTearDown(fresh.close);
    await reader(fresh).rebuild();
    expect(await fresh.select(fresh.facts).get(), hasLength(120));
    expect(await fresh.searchIds('текст'), hasLength(120), reason: 'текст добытого сразу в поиске');
    expect(counter.count, lessThan(30));
  });

  test('счётчик сверки — только изменённые заметки, не вся папка', () async {
    for (final name in ['a', 'b', 'c']) {
      put('$name.md', 'заметка $name');
    }
    await reader().reconcile();
    touch('b.md', '${file('b.md').readAsStringSync()}правка\n');
    final seen = <(int, int)>[];
    await reader().reconcile(progress: (done, total) => seen.add((done, total)));
    expect(seen.map((step) => step.$2).toSet(), {1});
    expect(seen.last, (1, 1));
  });

  test('заметка, написанная вне Stowa, лежит где положили: раскладка её не трогает и «разбираю» нет', () async {
    put('Работа/Дела.md', 'Список дел\n\n- позвонить в банк');
    put('План отпуска.md', 'Море в июле, билеты до 1 июня, работа подождёт');
    await reader().rebuild();
    final plan = (await items()).singleWhere((one) => one.title == 'План отпуска');
    expect(plan.folderId, isNull);
    expect(plan.sortedBy, SortedBy.user);
    expect(plan.sortState, SortState.sorted);
    expect(await AutoSorter(db, clock: () => now).sortInbox(), isEmpty);
    expect(file('План отпуска.md').existsSync(), isTrue);
  });

  test('pinned в файле — заметка закреплена, без свойства — нет', () async {
    put('Пароли.md', '---\npinned: 2026-11-14T09:15:00.000+02:00\n---\nWi-Fi дома');
    put('Кофе.md', 'Купить кофе');
    await reader().rebuild();
    final all = await items();
    expect(all.singleWhere((one) => one.title == 'Пароли').pinnedAt, DateTime.parse('2026-11-14T09:15:00.000+02:00').toLocal());
    expect(all.singleWhere((one) => one.title == 'Кофе').pinnedAt, isNull);
  });

  test('раскладка Obsidian — образец для новых заметок: угадыватель кладёт новую туда же', () async {
    put('Встречи/Созвон с Олегом.md', 'Созвон по бюджету, договорились о сроках');
    put('Встречи/Созвон с заказчиком.md', 'Созвон: макет, правки, сроки сдачи');
    put('Встречи/Планёрка.md', 'Планёрка в понедельник, созвон с командой');
    put('Кухня/Сырники.md', 'Творог, яйцо, мука, сковорода');
    put('Кухня/Блины.md', 'Мука, молоко, яйца, тесто на сковороде');
    await reader().rebuild();
    final index = await ItemsRepository(db, clock: () => now).folderIndex();
    final meetings = (await db.select(db.folders).get()).singleWhere((folder) => folder.name == 'Встречи');
    expect(index.guess('Созвон с Петей про сроки и бюджет')?.folderId, meetings.id);
  });

  test('своя заметка Stowa без папки остаётся неразобранной: её разложат', () async {
    put('Мысль.md', '---\nid: own-1\nkind: note\ncreated: 2026-11-06T10:00:00.000\nupdated: 2026-11-06T10:00:00.000\n---\nМысль');
    await reader().rebuild();
    final own = await item('own-1');
    expect(own!.sortedBy, SortedBy.none);
    expect(own.sortState, SortState.pending);
  });

  test('хранилище не выбрано — читатель ничего не делает', () async {
    put('Идеи.md', 'текст');
    final scan = await VaultReader(db, root: null, clock: () => now).reconcile();
    expect(scan.added, 0);
    expect(await items(), isEmpty);
  });
}

// сколько запросов на чтение ушло в базу
class _Selects extends QueryInterceptor {
  var count = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor, String statement, List<Object?> args) {
    count++;
    return super.runSelect(executor, statement, args);
  }
}

// сколько транзакций открыла база
class _Transactions extends QueryInterceptor {
  var count = 0;

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    count++;
    return super.beginTransaction(parent);
  }
}
