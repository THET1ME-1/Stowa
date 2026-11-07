import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/link_checker.dart';

void main() {
  late AppDatabase db;
  var now = DateTime(2026, 11, 7, 12);
  late Map<String, LinkReply> replies;
  late List<String> asked;

  setUp(() {
    db = AppDatabase.memory();
    now = DateTime(2026, 11, 7, 12);
    replies = {};
    asked = [];
  });
  tearDown(() => db.close());

  LinkChecker checker() => LinkChecker(db, clock: () => now, check: (uri) async {
    asked.add('$uri');
    return replies['$uri'] ?? LinkReply.alive;
  });

  Future<void> link(String id, String url, {DateTime? goneAt, bool kept = false, DateTime? checked}) => db.into(db.items).insert(
    ItemsCompanion.insert(
      id: id,
      kind: ItemKind.link,
      title: id,
      url: Value(url),
      goneAt: Value(goneAt),
      goneKept: Value(kept),
      linkCheckedAt: Value(checked),
      createdAt: now,
      updatedAt: now,
    ),
  );
  Future<Item> item(String id) => (db.select(db.items)..where((t) => t.id.equals(id))).getSingle();

  test('404 и 410 — ссылка мёртвая; живая остаётся живой; время проверки записано', () async {
    await link('a', 'https://a.md/x');
    await link('b', 'https://b.md/y');
    await link('c', 'https://c.md/z');
    replies['https://a.md/x'] = LinkReply.missing;
    replies['https://b.md/y'] = LinkReply.missing;
    await checker().run();
    expect((await item('a')).goneAt, now);
    expect((await item('b')).goneAt, now);
    expect((await item('c')).goneAt, isNull);
    expect((await item('c')).linkCheckedAt, now);
  });

  test('адреса нет, а другие сайты ответили — мёртвая; не ответил никто — это нет сети, не решение', () async {
    await link('a', 'https://closed.md/x');
    await link('b', 'https://alive.md/y');
    replies['https://closed.md/x'] = LinkReply.noHost;
    await checker().run();
    expect((await item('a')).goneAt, now);

    await db.delete(db.items).go();
    await link('a', 'https://closed.md/x');
    await link('b', 'https://alive.md/y');
    replies['https://alive.md/y'] = LinkReply.noHost;
    await checker().run();
    expect((await item('a')).goneAt, isNull);
    expect((await item('a')).linkCheckedAt, isNull, reason: 'без сети проверка не считается');
  });

  test('403, 5xx и срок — не решение: ссылка не мёртвая', () async {
    await link('a', 'https://a.md/x');
    await link('b', 'https://b.md/y');
    replies['https://a.md/x'] = LinkReply.unsure;
    await checker().run();
    expect((await item('a')).goneAt, isNull);
  });

  test('ожившая ссылка снимает пометку и решение «оставить копию»', () async {
    await link('a', 'https://a.md/x', goneAt: now.subtract(const Duration(days: 30)), kept: true);
    await checker().run();
    final back = await item('a');
    expect(back.goneAt, isNull);
    expect(back.goneKept, isFalse);
  });

  test('проверенную за неделю не трогает; «Проверить сейчас» — проверяет', () async {
    await link('a', 'https://a.md/x', checked: now.subtract(const Duration(days: 3)));
    await link('b', 'https://b.md/y', checked: now.subtract(const Duration(days: 8)));
    await checker().run();
    expect(asked, ['https://b.md/y']);
    asked.clear();
    await checker().run(force: true);
    expect(asked.toSet(), {'https://a.md/x', 'https://b.md/y'});
  });

  test('уже мёртвая ссылка помнит, когда умерла, а не когда проверили снова', () async {
    final died = now.subtract(const Duration(days: 20));
    await link('a', 'https://a.md/x', goneAt: died);
    await link('b', 'https://b.md/y');
    replies['https://a.md/x'] = LinkReply.missing;
    await checker().run(force: true);
    expect((await item('a')).goneAt, died);
  });
}
