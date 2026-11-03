import 'package:drift/drift.dart' show innerJoin;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/rules_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  late TagsRepository tags;
  late RulesRepository rules;
  final at = DateTime(2026, 11, 3, 12);

  Future<void> item(String id, List<String> names) async {
    await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: id, createdAt: at, updatedAt: at));
    for (final name in names) {
      final tag = await tags.ensure(name);
      await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: id, tagId: tag.id, source: TagSource.user));
    }
  }

  Future<List<String>> tagsOf(String itemId) async {
    final rows = await (db.select(db.itemTags).join([innerJoin(db.tags, db.tags.id.equalsExp(db.itemTags.tagId))])..where(db.itemTags.itemId.equals(itemId))).get();
    return [for (final row in rows) row.readTable(db.tags).name]..sort();
  }

  setUp(() {
    db = AppDatabase.memory();
    tags = TagsRepository(db, clock: () => at);
    rules = RulesRepository(db);
  });
  tearDown(() => db.close());

  test('новый тег с иконкой и закреплением встаёт на главную последним', () async {
    await tags.create(name: 'Кино', iconKind: TagIconKind.symbol, iconValue: 'movie', pinned: true);
    await tags.create(name: 'код', iconKind: TagIconKind.emoji, iconValue: '🔑', pinned: true);
    final pinned = await tags.watchPinned().first;
    expect(pinned.map((tag) => tag.name), ['кино', 'код']);
    expect(pinned.last.iconValue, '🔑');
  });

  test('переименование в уже существующее имя сливает теги', () async {
    await item('a', ['авто']);
    await item('b', ['машина', 'авто']);
    final auto = await tags.ensure('авто');
    await tags.update(auto.id, name: 'Машина');
    expect(await tagsOf('a'), ['машина']);
    expect(await tagsOf('b'), ['машина']);
    expect((await tags.watchAll().first).map((tag) => tag.name), ['машина']);
  });

  test('удаление и «Вернуть» восстанавливают тег у всех вещей и его правила', () async {
    for (var index = 0; index < 9; index++) {
      await item('i$index', ['машина']);
    }
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill'));
    await rules.setTagFolder('машина', 'car');
    final car = await tags.ensure('машина');
    final snapshot = await tags.delete(car.id);
    expect(await tags.watchAll().first, isEmpty);
    expect(await rules.enabled(), isEmpty);

    await tags.restore(snapshot);
    expect((await tags.watchAll().first).single.count, 9);
    expect((await rules.enabled()).single.actionValue, 'car');
  });

  test('порядок закреплённых сохраняется', () async {
    for (final name in ['а', 'б', 'в']) {
      await tags.create(name: name, iconKind: TagIconKind.symbol, iconValue: 'label', pinned: true);
    }
    final ids = [for (final tag in await tags.watchPinned().first) tag.id];
    await tags.reorderPinned([ids[2], ids[0], ids[1]]);
    expect((await tags.watchPinned().first).map((tag) => tag.name), ['в', 'а', 'б']);
  });

  test('тег кладёт в папку: одно правило на тег, «Без папки» правило снимает', () async {
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'pill'));
    await rules.setTagFolder('машина', 'car');
    await rules.setTagFolder('машина', 'home');
    expect(await rules.tagFolder('машина'), 'home');
    expect(await rules.enabled(), hasLength(1));
    await rules.setTagFolder('машина', null);
    expect(await rules.tagFolder('машина'), isNull);
  });

  test('снять тег с одной вещи', () async {
    await item('a', ['машина', 'шины']);
    await item('b', ['машина']);
    await tags.unlink('a', 'машина');
    expect(await tagsOf('a'), ['шины']);
    expect(await tagsOf('b'), ['машина']);
  });

  test('правило целиком: создать, выключить, удалить', () async {
    final id = await rules.save(condition: RuleConditionKind.domain, conditionValue: 'tiktok.com', action: RuleActionKind.addTag, actionValue: 'видео');
    expect((await rules.watchAll().first).single.conditionValue, 'tiktok.com');
    await rules.setEnabled(id, false);
    expect(await rules.enabled(), isEmpty);
    await rules.remove(id);
    expect(await rules.watchAll().first, isEmpty);
  });
}
