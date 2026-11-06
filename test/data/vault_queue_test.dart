import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 6, 10);

  setUp(() async {
    db = AppDatabase.memory();
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'f', name: 'Рецепты', icon: 'folder', shape: 'pill'));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Карбонара', body: const Value('Карбонара'), createdAt: now, updatedAt: now));
    await db.delete(db.vaultQueue).go();
  });
  tearDown(() => db.close());

  Future<Set<String>> queued() async => {for (final row in await db.select(db.vaultQueue).get()) row.target};
  Future<void> edit(ItemsCompanion change) => (db.update(db.items)..where((t) => t.id.equals('a'))).write(change);

  test('новая вещь встаёт в очередь', () async {
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'b', kind: ItemKind.note, title: 'Борщ', createdAt: now, updatedAt: now));
    expect(await queued(), {'item:b'});
  });

  test('правка заголовка ставит вещь в очередь, правка facts_text и sort_state — нет', () async {
    await edit(const ItemsCompanion(factsText: Value('гуанчиале'), sortState: Value(SortState.sorted)));
    expect(await queued(), isEmpty);
    await edit(const ItemsCompanion(title: Value('Паста')));
    expect(await queued(), {'item:a'});
  });

  test('тег на вещи, вложение и перенос в папку ставят вещь в очередь', () async {
    await edit(const ItemsCompanion(folderId: Value('f')));
    expect(await queued(), {'item:a'});
    await db.delete(db.vaultQueue).go();
    await db.into(db.tags).insert(TagsCompanion.insert(id: 't', name: 'паста', createdAt: now));
    await db.delete(db.vaultQueue).go();
    await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: 'a', tagId: 't', source: TagSource.user));
    expect(await queued(), {'item:a'});
    await db.delete(db.vaultQueue).go();
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'p', itemId: 'a', path: 'Карбонара/фото.jpg', mime: 'image/jpeg', size: 10));
    expect(await queued(), {'item:a'});
  });

  test('новая просьба поверх старой поднимает версию и снимает аренду', () async {
    await edit(const ItemsCompanion(title: Value('Паста')));
    final first = await db.select(db.vaultQueue).getSingle();
    await (db.update(db.vaultQueue)..where((t) => t.target.equals('item:a'))).write(const VaultQueueCompanion(claimedUntil: Value(99999999999999)));
    await edit(const ItemsCompanion(title: Value('Паста 2')));
    final second = await db.select(db.vaultQueue).getSingle();
    expect(second.version, first.version + 1);
    expect(second.claimedUntil, isNull);
  });

  test('сторож очереди замечает новую правку поверх старой: задач столько же, версия выросла', () async {
    await edit(const ItemsCompanion(title: Value('Паста')));
    final stamps = <(int, int)>[];
    final watching = db.watchVaultQueue().listen(stamps.add);
    addTearDown(watching.cancel);
    await pumpEventQueue();
    await edit(const ItemsCompanion(title: Value('Паста 2')));
    await pumpEventQueue();
    // задача одна и та же, но писатель должен проснуться ещё раз
    expect(stamps.length, greaterThanOrEqualTo(2));
    expect(stamps.first.$1, stamps.last.$1);
    expect(stamps.last, isNot(stamps.first));
  });

  test('переименование папки ставит meta:folders, тег — meta:tags, правило — meta:rules', () async {
    await (db.update(db.folders)..where((t) => t.id.equals('f'))).write(const FoldersCompanion(name: Value('Еда')));
    await db.into(db.tags).insert(TagsCompanion.insert(id: 't', name: 'паста', createdAt: now));
    await db.into(db.rules).insert(RulesCompanion.insert(id: 'r', conditionKind: RuleConditionKind.hasTag, conditionValue: 'паста', actionKind: RuleActionKind.toFolder, actionValue: 'f'));
    expect(await queued(), containsAll(['meta:folders', 'meta:tags', 'meta:rules']));
  });

  test('новый факт ставит facts:<id>', () async {
    await db.into(db.facts).insert(FactsCompanion.insert(id: 'x', itemId: 'a', extractor: 'text', kind: FactKind.price, value: '5 лей'));
    expect(await queued(), {'facts:a'});
  });

  test('при флаге importing очередь пустая', () async {
    await db.into(db.vaultFlags).insert(VaultFlagsCompanion.insert(name: 'importing'));
    await edit(const ItemsCompanion(title: Value('Паста')));
    await db.into(db.facts).insert(FactsCompanion.insert(id: 'x', itemId: 'a', extractor: 'text', kind: FactKind.price, value: '5 лей'));
    expect(await queued(), isEmpty);
  });
}
