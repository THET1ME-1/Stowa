import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  late ItemsRepository items;
  final at = DateTime(2026, 11, 2, 12);

  setUp(() async {
    db = AppDatabase.memory();
    items = ItemsRepository(db);
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill'));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Шины', createdAt: at, updatedAt: at));
  });
  tearDown(() => db.close());

  test('переложить руками: папка, «разложил человек», запись для обучения', () async {
    await items.moveToFolder('a', 'car', at);
    final item = (await items.get('a'))!.item;
    expect(item.folderId, 'car');
    expect(item.sortedBy, SortedBy.user);
    expect(item.sortState, SortState.sorted);
    final corrections = await db.select(db.corrections).get();
    expect(corrections.single.toFolderId, 'car');
    expect(corrections.single.fromFolderId, isNull);
  });

  test('страница вещи видит правку сразу', () async {
    final updates = items.watchItem('a').map((full) => full?.item.body);
    expectLater(updates, emitsInOrder(['', '- [x] купить']));
    await Future<void>.delayed(Duration.zero);
    await items.setBody('a', '- [x] купить', at);
  });
}
