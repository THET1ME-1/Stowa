import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';

void main() {
  test('отклонённая связь пропадает из потока', () async {
    final db = AppDatabase.memory();
    final now = DateTime(2026);
    for (final (id, t) in [('a', 'Борщ со свёклой, рецепт'), ('b', 'Свёкла подешевела, купить на борщ'), ('c', 'Купить хлеб'), ('d', 'Позвонить в банк'), ('e', 'Идея для подарка'), ('f', 'Счёт за свет')]) {
      await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: t, body: Value(t), createdAt: now, updatedAt: now));
    }
    final repo = ItemsRepository(db);
    final events = <int>[];
    final sub = repo.watchLinked('a').listen((list) => events.add(list.length), onError: (Object e) => events.add(-1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.rejectRelated('a', 'b');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    await db.close();
    expect(events, [1, 0]);
  });
}
