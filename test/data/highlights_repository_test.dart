import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/highlights_repository.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  late HighlightsRepository highlights;
  final now = DateTime(2026, 11, 7, 12);

  setUp(() async {
    db = AppDatabase.memory();
    highlights = HighlightsRepository(db, clock: () => now);
    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'a', kind: ItemKind.link, title: 'Кофе без турки', url: const Value('https://blog.example.com/kofe'), createdAt: now, updatedAt: now),
    );
  });
  tearDown(() => db.close());

  test('цитаты по порядку в тексте статьи, а не по времени', () async {
    await highlights.add('a', 'второй абзац', position: 900);
    await highlights.add('a', 'первый абзац', position: 10);
    final list = await highlights.watch('a').first;
    expect([for (final one in list) one.quote], ['первый абзац', 'второй абзац']);
  });

  test('цитата и пометка ищутся сразу; убранная — уже нет, «Отменить» возвращает', () async {
    final id = await highlights.add('a', 'вода важнее зёрен', position: 0);
    expect(await db.searchIds('зёрен'), ['a']);
    await highlights.setNote(id, 'купить фильтр');
    expect(await db.searchIds('фильтр'), ['a']);

    final removed = await highlights.remove(id);
    expect(await db.searchIds('фильтр'), isEmpty);
    await highlights.restore(removed!);
    expect((await highlights.watch('a').first).single.note, 'купить фильтр');
    expect(await db.searchIds('фильтр'), ['a']);
  });

  test('пустая пометка снимается, а не хранится пробелами', () async {
    final id = await highlights.add('a', 'вода важнее зёрен', position: 0);
    await highlights.setNote(id, '  ');
    expect((await highlights.watch('a').first).single.note, isNull);
  });
}
