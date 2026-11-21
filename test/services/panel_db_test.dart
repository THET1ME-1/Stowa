import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/panel_bridge.dart';
import 'package:stowa/services/panel_db.dart';

// STOWA-9, хозяин 21.11: «почти ни одной функции не перенёс» — в панели строка телефона,
// а она читает базу. База остаётся во вкладке: панель получает её только на чтение
void main() {
  late AppDatabase tab;
  late PanelDbServer server;
  var serial = 0;

  setUp(() {
    tab = AppDatabase.memory();
    server = PanelDbServer(tab);
  });
  tearDown(() async {
    server.stop();
    await tab.close();
  });

  Future<void> note(AppDatabase db, String id, String title) => db.into(db.items).insert(
    ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(title), createdAt: DateTime(2026, 11, 21), updatedAt: DateTime(2026, 11, 21)),
  );

  Future<AppDatabase> panel() async {
    final name = 'stowa-db-test-${serial++}';
    // конец панели открыт до того, как вкладка начала отдавать базу: как в connectTabDatabase
    final channel = panelDbChannel(name);
    server.serve(name);
    final db = await openPanelDb(channel);
    addTearDown(db.close);
    return db;
  }

  test('панель читает базу вкладки', () async {
    await note(tab, 'a', 'Шины на зиму');
    final db = await panel();
    final rows = await db.select(db.items).get();
    expect(rows.single.title, 'Шины на зиму');
  });

  test('панель не пишет в базу вкладки: ни вставкой, ни транзакцией', () async {
    final db = await panel();
    await expectLater(note(db, 'b', 'Из панели'), throwsA(anything));
    await expectLater(db.transaction(() => note(db, 'c', 'Из панели')), throwsA(anything));
    expect(await tab.select(tab.items).get(), isEmpty);
  });

  test('правка во вкладке будит слежку панели', () async {
    final db = await panel();
    final link = PanelLink();
    addTearDown(link.close);
    server.relayChanges(PanelLink());
    followPanelDb(db, link.messages);
    final seen = <int>[];
    final watching = db.select(db.items).watch().listen((rows) => seen.add(rows.length));
    addTearDown(watching.cancel);
    await pumpEventQueue();
    await note(tab, 'a', 'Шины на зиму');
    await pumpEventQueue(times: 50);
    expect(seen.last, 1);
  });
}
