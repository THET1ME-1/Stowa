import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 3, 12);
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<void> add(String id, String text, {String? folder}) => db
      .into(db.items)
      .insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: text, body: Value(text), folderId: Value(folder), createdAt: now, updatedAt: now));

  test('граф папки: связи от ИИ и похожие по редким словам, только внутри папки', () async {
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'garden', name: 'Огород', icon: 'yard', shape: 'pill'));
    await add('a', 'рассада томатов черри', folder: 'garden');
    await add('b', 'подкормка рассады томатов', folder: 'garden');
    await add('c', 'полив огурцов', folder: 'garden');
    await add('d', 'парник для огурцов', folder: 'garden');
    await add('x', 'томаты на ужин');
    for (var index = 0; index < 6; index++) {
      await add('z$index', 'посторонняя заметка $index');
    }
    await db.into(db.links).insert(LinksCompanion.insert(fromId: 'a', toId: 'c', source: LinkSource.ai, reason: const Value('огород')));

    final graph = await ItemsRepository(db).graph(folderId: 'garden');
    expect(graph.nodes.map((card) => card.id), unorderedEquals(['a', 'b', 'c', 'd']));
    final pairs = {for (final (a, b) in graph.edges) ([a, b]..sort()).join('|')};
    expect(pairs, contains('a|c'));
    expect(pairs, contains('a|b'));
    expect(pairs.any((pair) => pair.contains('x')), isFalse);
  });

  test('отклонённая человеком связь в граф не попадает', () async {
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'garden', name: 'Огород', icon: 'yard', shape: 'pill'));
    await add('a', 'рассада томатов черри', folder: 'garden');
    await add('b', 'подкормка рассады томатов', folder: 'garden');
    for (var index = 0; index < 6; index++) {
      await add('z$index', 'посторонняя заметка $index');
    }
    await ItemsRepository(db).rejectRelated('a', 'b');
    final graph = await ItemsRepository(db).graph(folderId: 'garden');
    expect(graph.edges, isEmpty);
  });
}
