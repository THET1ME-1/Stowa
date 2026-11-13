import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  late ItemsRepository items;
  final now = DateTime(2026, 11, 13, 12);
  setUp(() {
    db = AppDatabase.memory();
    items = ItemsRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<void> add(String id, String title, {String body = '', String? folder}) => db.into(db.items).insert(
    ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(body.isEmpty ? title : '$title\n$body'), folderId: Value(folder), createdAt: now, updatedAt: now),
  );

  Future<List<(String, LinkKind)>> linked(String id) async => [for (final one in await items.watchLinked(id).first) (one.card.id, one.kind)];

  // посторонние заметки, чтобы похожие по словам не находились случайно
  Future<void> noise() async {
    for (var index = 0; index < 6; index++) {
      await add('z$index', 'посторонняя запись $index');
    }
  }

  test('открытая страница видит связь руками сразу: поток связей просыпается', () async {
    await noise();
    await add('plan', 'План отпуска');
    await add('ideas', 'Идеи');
    final seen = <List<String>>[];
    final watching = items.watchLinked('plan').listen((list) => seen.add([for (final one in list) if (one.kind == LinkKind.manual) one.card.id]));
    await pumpEventQueue();
    await items.link('plan', 'ideas');
    await pumpEventQueue();
    await items.unlink('plan', 'ideas');
    await pumpEventQueue();
    await watching.cancel();
    expect(seen.map((ids) => ids.join()).toList(), containsAllInOrder(['', 'ideas', '']));
  });

  test('[[Заголовок]] в тексте связывает, у второй заметки — обратная связь', () async {
    await noise();
    await add('beer', 'Пиво', body: 'варить с [[хмель]] и [[Солод|солодом]]');
    await add('hops', 'Хмель');
    await add('malt', 'Солод');
    expect(await linked('beer'), [('hops', LinkKind.text), ('malt', LinkKind.text)]);
    expect(await linked('hops'), [('beer', LinkKind.backlink)]);
  });

  test('убрал [[…]] из текста — связи нет; ссылка на несуществующую заметку ничего не даёт', () async {
    await noise();
    await add('beer', 'Пиво', body: 'варить с [[Хмель]] и [[Дрожжи]]');
    await add('hops', 'Хмель');
    await items.setBody('beer', 'Пиво\nварить без добавок', now);
    expect(await linked('beer'), isEmpty);
    expect(await linked('hops'), isEmpty);
  });

  test('«+ Связь»: связь вручную видна с обеих сторон, «убрать» снимает, повторная ставит заново', () async {
    await noise();
    await add('a', 'Отпуск в горах');
    await add('b', 'Список вещей');
    await items.link('a', 'b');
    expect(await linked('a'), [('b', LinkKind.manual)]);
    expect(await linked('b'), [('a', LinkKind.manual)]);
    await items.unlink('b', 'a');
    expect(await linked('a'), isEmpty);
    // отклонил, потом связал руками — связь есть
    await items.rejectRelated('a', 'b');
    await items.link('b', 'a');
    expect(await linked('a'), [('b', LinkKind.manual)]);
  });

  test('связь от ИИ с причиной; отклонённая пропадает, с какой стороны ни отклоняй', () async {
    await noise();
    await add('a', 'Купить шины');
    await add('b', 'Записаться на шиномонтаж');
    await db.into(db.links).insert(LinksCompanion.insert(fromId: 'b', toId: 'a', source: LinkSource.ai, reason: const Value('машина')));
    final first = (await items.watchLinked('a').first).single;
    expect((first.card.id, first.kind, first.reason), ('b', LinkKind.ai, 'машина'));
    await items.rejectRelated('a', 'b');
    expect(await linked('a'), isEmpty);
  });

  test('сперва из текста и ручные, потом похожие; одна заметка — один раз', () async {
    await noise();
    await add('a', 'Борщ со свёклой', body: 'рецепт, см. [[Свёкла подешевела]]');
    await add('b', 'Свёкла подешевела', body: 'купить на борщ');
    await add('c', 'Борщ украинский', body: 'со свёклой и пампушками');
    final result = await linked('a');
    expect(result.first, ('b', LinkKind.text));
    expect(result.where((one) => one.$1 == 'b'), hasLength(1));
    expect(result, contains(('c', LinkKind.similar)));
  });

  test('граф папки рисует и связи из текста', () async {
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'f', name: 'Пиво', icon: 'folder', shape: 'pill'));
    await noise();
    await add('a', 'Рецепт эля', body: 'см. [[Закупка]]', folder: 'f');
    await add('b', 'Закупка', folder: 'f');
    final graph = await items.graph(folderId: 'f');
    expect([for (final (x, y) in graph.edges) ([x, y]..sort()).join('|')], contains('a|b'));
  });

  test('заметки для связи: все живые, свежие первыми, без удалённых', () async {
    await add('a', 'Пиво');
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'old', kind: ItemKind.note, title: 'Старое', createdAt: now.subtract(const Duration(days: 3)), updatedAt: now));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'gone', kind: ItemKind.note, title: 'Удалённое', createdAt: now, updatedAt: now, deletedAt: Value(now)));
    expect([for (final one in await items.linkTargets()) one.id], ['a', 'old']);
  });
}
