import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/smart_folders_repository.dart';

void main() {
  late AppDatabase db;
  late SmartFoldersRepository smart;
  final now = DateTime(2026, 11, 9, 12);

  setUp(() {
    db = AppDatabase.memory();
    smart = SmartFoldersRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  test('умная папка — запрос и имя, новые встают в конец', () async {
    final week = await smart.create(name: 'Скрины за неделю', query: 'скрины за неделю');
    await smart.create(name: 'Ролики YouTube до 5 минут', query: 'ролики youtube до 5 минут');
    final all = await smart.watchAll().first;
    expect([for (final one in all) (one.name, one.query)], [('Скрины за неделю', 'скрины за неделю'), ('Ролики YouTube до 5 минут', 'ролики youtube до 5 минут')]);
    expect(all.first.id, week);
    expect(all.first.icon, 'manage_search');
  });

  test('переименовать, удалить и вернуть по «Отменить»', () async {
    final id = await smart.create(name: 'Скрины', query: 'скрины');
    await smart.rename(id, 'Скриншоты');
    expect((await smart.watchAll().first).single.name, 'Скриншоты');
    final removed = await smart.remove(id);
    expect(await smart.watchAll().first, isEmpty);
    await smart.restore(removed!);
    expect((await smart.watchAll().first).single.name, 'Скриншоты');
  });

  test('пустое имя берётся из запроса с заглавной', () async {
    await smart.create(name: '  ', query: 'всё, что сохранено в Кишинёве');
    expect((await smart.watchAll().first).single.name, 'Всё, что сохранено в Кишинёве');
  });
}
