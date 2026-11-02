import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:drift/native.dart' show SqliteException;

ItemsCompanion _item(String id, String title, {String body = ''}) {
  final now = DateTime(2026, 11, 2, 12);
  return ItemsCompanion.insert(
    id: id,
    kind: ItemKind.note,
    title: title,
    body: Value(body),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  test('вещь пишется и находится полнотекстом', () async {
    await db.into(db.items).insert(_item('a', 'Тарт с малиной', body: 'испечь в субботу'));
    await db.into(db.items).insert(_item('b', 'Код домофона', body: '4512'));
    expect(await db.searchIds('малин*'), ['a']);
    expect(await db.searchIds('субботу'), ['a']);
  });

  test('поиск не различает регистр и ё', () async {
    await db.into(db.items).insert(_item('a', 'Ёлка на Новый год'));
    expect(await db.searchIds('елка'), ['a']);
    expect(await db.searchIds('НОВЫЙ'), ['a']);
  });

  test('правка вещи обновляет поиск', () async {
    await db.into(db.items).insert(_item('a', 'Старое'));
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(const ItemsCompanion(title: Value('Новое имя')));
    expect(await db.searchIds('старое'), isEmpty);
    expect(await db.searchIds('новое'), ['a']);
  });

  test('мягко удалённая вещь не ищется', () async {
    await db.into(db.items).insert(_item('a', 'Тарт с малиной'));
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(ItemsCompanion(deletedAt: Value(DateTime(2026, 11, 3))));
    expect(await db.searchIds('малин*'), isEmpty);
  });

  test('тег с тем же именем не заводится второй раз', () async {
    final now = DateTime(2026, 11, 2);
    await db.into(db.tags).insert(TagsCompanion.insert(id: '1', name: 'машина', createdAt: now));
    expect(
      () => db.into(db.tags).insert(TagsCompanion.insert(id: '2', name: 'машина', createdAt: now)),
      throwsA(isA<SqliteException>()),
    );
  });

  test('вид вещи хранится по имени', () async {
    await db.into(db.items).insert(_item('a', 'Ссылка').copyWith(kind: const Value(ItemKind.video)));
    final raw = await db.customSelect("SELECT kind FROM items WHERE id = 'a'").getSingle();
    expect(raw.read<String>('kind'), 'video');
  });
}
