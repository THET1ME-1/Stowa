import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/image_fingerprint.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  late ItemsRepository items;
  setUp(() async {
    db = AppDatabase.memory();
    items = ItemsRepository(db);
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Рецепты', icon: 'folder', shape: 'pill'));
  });
  tearDown(() => db.close());

  Future<void> note(String id, DateTime at, {String? url, String? folder, bool deleted = false}) => db.into(db.items).insert(ItemsCompanion.insert(
        id: id,
        kind: url == null ? ItemKind.image : ItemKind.link,
        title: id,
        url: Value(url),
        folderId: Value(folder),
        deletedAt: Value(deleted ? at : null),
        createdAt: at,
        updatedAt: at,
      ));

  Future<void> print(String id, int value) =>
      db.into(db.facts).insert(FactsCompanion.insert(id: '$id-print', itemId: id, extractor: 'fingerprint', kind: FactKind.fingerprint, value: fingerprintText(value)));

  test('та же ссылка с метками рекламы — повтор, показывается самая ранняя другая заметка', () async {
    await note('may', DateTime(2026, 5, 12), url: 'https://eda.ru/borsch', folder: 'food');
    await note('june', DateTime(2026, 6, 1), url: 'https://www.eda.ru/borsch/');
    await note('now', DateTime(2026, 11, 6), url: 'https://eda.ru/borsch?utm_source=tg');

    final repeat = await items.repeatOf('now');
    expect((repeat!.id, repeat.folderName, repeat.createdAt), ('may', 'Рецепты', DateTime(2026, 5, 12)));
    // и у первой видно, что она не одна
    expect((await items.repeatOf('may'))!.id, 'june');
  });

  test('картинка по отпечатку: разница в пару бит — повтор, далёкая — нет', () async {
    await note('a', DateTime(2026, 5, 12));
    await note('b', DateTime(2026, 11, 6));
    await note('c', DateTime(2026, 11, 7));
    await print('a', 0x0f0f0f0f0f0f0f0f);
    await print('b', 0x0f0f0f0f0f0f0f0c);
    await print('c', 0x7070707070707070);
    expect((await items.repeatOf('b'))!.id, 'a');
    expect(await items.repeatOf('c'), isNull);
  });

  test('удалённая заметка повтором не считается, без повтора — null', () async {
    await note('gone', DateTime(2026, 5, 12), url: 'https://eda.ru/borsch', deleted: true);
    await note('now', DateTime(2026, 11, 6), url: 'https://eda.ru/borsch');
    await note('alone', DateTime(2026, 11, 6), url: 'https://eda.ru/plov');
    expect(await items.repeatOf('now'), isNull);
    expect(await items.repeatOf('alone'), isNull);
  });
}
