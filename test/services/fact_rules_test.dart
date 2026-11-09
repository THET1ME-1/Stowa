import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/rules_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/fact_rules.dart';

void main() {
  late AppDatabase db;
  late FactRules rules;
  final now = DateTime(2026, 11, 9, 12);

  setUp(() async {
    db = AppDatabase.memory();
    rules = FactRules(db, clock: () => now);
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'recipes', name: 'Рецепты', icon: 'restaurant', shape: 'squircle'));
    final repository = RulesRepository(db);
    await repository.save(condition: RuleConditionKind.pageType, conditionValue: 'recipe', action: RuleActionKind.toFolder, actionValue: 'recipes');
    await repository.save(condition: RuleConditionKind.priceAbove, conditionValue: '1000', action: RuleActionKind.addTag, actionValue: 'дорого');
    await repository.save(condition: RuleConditionKind.pageType, conditionValue: 'event', action: RuleActionKind.remindBefore, actionValue: '1440');
  });
  tearDown(() => db.close());

  Future<void> item(String id, {SortedBy sortedBy = SortedBy.none, String? folder, DateTime? reminder}) => db.into(db.items).insert(ItemsCompanion.insert(
        id: id,
        kind: ItemKind.link,
        title: id,
        folderId: Value(folder),
        sortedBy: Value(sortedBy),
        reminderAt: Value(reminder),
        createdAt: now,
        updatedAt: now,
      ));

  Future<void> fact(String itemId, FactKind kind, String value, {String? detail, double? number, DateTime? at}) => db.into(db.facts).insert(
        FactsCompanion.insert(id: '$itemId-${kind.name}', itemId: itemId, extractor: 'page', kind: kind, value: value, detail: Value(detail), number: Value(number), at: Value(at)),
      );

  Future<Item> saved(String id) => (db.select(db.items)..where((t) => t.id.equals(id))).getSingle();
  Future<Set<String>> tags(String id) async => {
    for (final row in await db.customSelect("SELECT tags.name AS name FROM item_tags JOIN tags ON tags.id = item_tags.tag_id WHERE item_tags.item_id = '$id'").get()) row.read<String>('name'),
  };

  test('рецепт уезжает в «Рецепты»; человек вынул — правило не возвращает', () async {
    await item('borsch');
    await fact('borsch', FactKind.pageType, 'рецепт', detail: 'recipe');
    await rules.apply('borsch');
    expect(((await saved('borsch')).folderId, (await saved('borsch')).sortedBy), ('recipes', SortedBy.rule));

    await (db.update(db.items)..where((t) => t.id.equals('borsch'))).write(const ItemsCompanion(folderId: Value(null), sortedBy: Value(SortedBy.user)));
    await rules.apply('borsch');
    expect((await saved('borsch')).folderId, isNull);
  });

  test('разложенное человеком правило по фактам не перекладывает', () async {
    await item('plov', sortedBy: SortedBy.user);
    await fact('plov', FactKind.pageType, 'рецепт', detail: 'recipe');
    await rules.apply('plov');
    expect((await saved('plov')).folderId, isNull);
  });

  test('цена больше 1000 — тег правила; дешевле — нет', () async {
    await item('sofa');
    await fact('sofa', FactKind.price, '4 500 лей', detail: 'MDL', number: 4500);
    await item('cup');
    await fact('cup', FactKind.price, '90 лей', detail: 'MDL', number: 90);
    await rules.apply('sofa');
    await rules.apply('cup');
    expect(await tags('sofa'), {'дорого'});
    expect(await tags('cup'), isEmpty);
    final link = await (db.select(db.itemTags)..where((t) => t.itemId.equals('sofa'))).getSingle();
    expect(link.source, TagSource.rule);
  });

  test('событие — напоминание за день до начала; своё напоминание и прошедшее не трогаются', () async {
    final start = DateTime(2026, 11, 14, 19);
    await item('concert');
    await fact('concert', FactKind.pageType, 'событие', detail: 'event');
    await fact('concert', FactKind.eventStart, '2026-11-14T19:00', at: start);
    await rules.apply('concert');
    expect((await saved('concert')).reminderAt, DateTime(2026, 11, 13, 19));

    await item('mine', reminder: DateTime(2026, 11, 14, 9));
    await fact('mine', FactKind.pageType, 'событие', detail: 'event');
    await fact('mine', FactKind.eventStart, '2026-11-14T19:00', at: start);
    await rules.apply('mine');
    expect((await saved('mine')).reminderAt, DateTime(2026, 11, 14, 9));

    await item('past');
    await fact('past', FactKind.pageType, 'событие', detail: 'event');
    await fact('past', FactKind.eventStart, '2026-11-01T19:00', at: DateTime(2026, 11, 1, 19));
    await rules.apply('past');
    expect((await saved('past')).reminderAt, isNull);
  });

  test('выключенное правило молчит', () async {
    await (db.update(db.rules)).write(const RulesCompanion(enabled: Value(false)));
    await item('borsch');
    await fact('borsch', FactKind.pageType, 'рецепт', detail: 'recipe');
    await rules.apply('borsch');
    expect((await saved('borsch')).folderId, isNull);
  });
}
