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

  test('дата заметки меняется, и правка встаёт в очередь файла', () async {
    await db.delete(db.vaultQueue).go();
    final earlier = DateTime(2026, 10, 30, 8, 15);
    await items.setCreated('a', earlier);
    final item = (await items.get('a'))!.item;
    expect(item.createdAt, earlier);
    expect(item.updatedAt, at, reason: 'заметку не правили — время правки прежнее');
    expect((await db.select(db.vaultQueue).get()).map((row) => row.target), ['item:a']);
  });

  test('дата позже последней правки тянет время правки за собой', () async {
    final later = DateTime(2026, 11, 5, 9);
    await items.setCreated('a', later);
    final item = (await items.get('a'))!.item;
    expect(item.createdAt, later);
    expect(item.updatedAt, later, reason: 'заметка не может быть поправлена раньше, чем записана');
  });

  test('страница вещи видит правку сразу', () async {
    final updates = items.watchItem('a').map((full) => full?.item.body);
    expectLater(updates, emitsInOrder(['', '- [x] купить']));
    await Future<void>.delayed(Duration.zero);
    await items.setBody('a', '- [x] купить', at);
  });
}
