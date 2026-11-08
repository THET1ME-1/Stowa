import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/history_repository.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  late ItemsRepository items;
  late HistoryRepository history;
  final start = DateTime(2026, 11, 8, 10);

  setUp(() async {
    db = AppDatabase.memory();
    items = ItemsRepository(db);
    history = HistoryRepository(db, items);
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Ремонт', body: const Value('Ремонт\nкупить клей'), createdAt: start, updatedAt: start));
  });
  tearDown(() => db.close());

  Future<void> edit(String body, DateTime at) => items.setTitleBody('a', title: 'Ремонт', body: body, at: at);
  Future<List<NoteVersion>> versions() => history.watch('a').first;

  test('правка после перерыва сохраняет прежний текст снимком', () async {
    await edit('Ремонт\nкупить клей\nплитка 20×20', start.add(const Duration(minutes: 15)));
    final saved = await versions();
    expect(saved, hasLength(1));
    expect(saved.single.body, 'Ремонт\nкупить клей');
    expect(saved.single.savedAt, start);
  });

  test('одна сессия правки — одна версия, хоть автосохранение пишет каждую секунду', () async {
    final session = start.add(const Duration(hours: 1));
    for (var second = 1; second < 30; second++) {
      await edit('Ремонт\nкупить клей${'!' * second}', session.add(Duration(seconds: second)));
    }
    expect(await versions(), hasLength(1));
    // следующая сессия через час — ещё одна, с концом первой
    await edit('Ремонт\nготово', session.add(const Duration(hours: 1)));
    final saved = await versions();
    expect(saved, hasLength(2));
    expect(saved.first.body, 'Ремонт\nкупить клей${'!' * 29}');
  });

  test('без правки текста снимка нет', () async {
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(ItemsCompanion(reminderAt: Value(start), updatedAt: Value(start.add(const Duration(days: 1)))));
    expect(await versions(), isEmpty);
  });

  test('хранятся 50 последних или все за 30 дней', () async {
    final now = start.add(const Duration(days: 100));
    for (var day = 0; day < 55; day++) {
      await db.into(db.noteVersions).insert(NoteVersionsCompanion.insert(id: 'old$day', itemId: 'a', title: 'Ремонт', body: 'день $day', savedAt: now.subtract(Duration(days: 40 + day))));
    }
    for (var day = 0; day < 60; day++) {
      await db.into(db.noteVersions).insert(NoteVersionsCompanion.insert(id: 'new$day', itemId: 'a', title: 'Ремонт', body: 'свежий $day', savedAt: now.subtract(Duration(days: 1 + day % 20, minutes: day))));
    }
    // прошлая правка — час назад: её снимок свежий
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(ItemsCompanion(updatedAt: Value(now.subtract(const Duration(hours: 1)))));
    await edit('Ремонт\nпосле', now);
    final saved = await versions();
    // 60 свежих и снимок только что — все за 30 дней; старые сверх 50 ушли
    expect(saved.where((one) => one.body.startsWith('свежий')), hasLength(60));
    expect(saved.where((one) => one.body.startsWith('день')), isEmpty);
    expect(saved, hasLength(61));
  });

  test('старше 30 дней остаются, пока их не больше 50', () async {
    final now = start.add(const Duration(days: 200));
    for (var day = 0; day < 10; day++) {
      await db.into(db.noteVersions).insert(NoteVersionsCompanion.insert(id: 'old$day', itemId: 'a', title: 'Ремонт', body: 'день $day', savedAt: now.subtract(Duration(days: 40 + day))));
    }
    await edit('Ремонт\nпосле', now);
    expect(await versions(), hasLength(11));
  });

  test('вернуть версию: текст как тогда, нынешний уходит в историю, возврат можно отменить', () async {
    await edit('Ремонт\nплитка', start.add(const Duration(minutes: 15)));
    // возврат сразу после правки, без перерыва: нынешнее всё равно сохраняется
    final old = (await versions()).single;
    await history.restore(old, start.add(const Duration(minutes: 16)));
    final item = (await items.get('a'))!.item;
    expect(item.body, 'Ремонт\nкупить клей');
    final saved = await versions();
    expect(saved.map((one) => one.body), ['Ремонт\nплитка', 'Ремонт\nкупить клей']);
    await history.restore(saved.first, start.add(const Duration(minutes: 17)));
    expect((await items.get('a'))!.item.body, 'Ремонт\nплитка');
  });

  test('снимок ставит историю заметки в очередь хранилища', () async {
    await db.delete(db.vaultQueue).go();
    await edit('Ремонт\nплитка', start.add(const Duration(minutes: 15)));
    expect([for (final row in await db.select(db.vaultQueue).get()) row.target], containsAll(['item:a', 'history:a']));
  });

  test('стёртая насовсем заметка уносит историю', () async {
    await edit('Ремонт\nплитка', start.add(const Duration(minutes: 15)));
    await (db.delete(db.items)..where((t) => t.id.equals('a'))).go();
    expect(await db.select(db.noteVersions).get(), isEmpty);
  });
}
