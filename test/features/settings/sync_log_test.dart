import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/history_screen.dart';
import 'package:stowa/features/settings/sync_log_screen.dart';
import 'package:stowa/services/sync/cloud_history.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_engine.dart';

import '../../helpers/test_app.dart';
import '../../services/sync/fakes.dart';

void main() {
  late TestWorld world;
  late FakeRemote remote;
  late VaultKey key;
  late MemoryVault phone;
  late SyncEngine engine;
  // часы телефона: 2 ноября 2026, утро; сервер идёт по ним же
  var clock = DateTime(2026, 11, 2, 7).millisecondsSinceEpoch;

  setUp(() {
    world = TestWorld();
    clock = DateTime(2026, 11, 2, 7).millisecondsSinceEpoch;
    remote = FakeRemote(now: () => DateTime.fromMillisecondsSinceEpoch(clock, isUtc: true));
    key = VaultKey.generate();
    world.cloudHistory = CloudHistory(remote: remote, key: key);
    phone = MemoryVault(() => clock);
    engine = SyncEngine(vault: phone, remote: remote, state: MemoryState(), key: key);
  });

  tearDown(() => world.dispose());

  Future<void> edit(String path, String text, {int minutes = 1, String device = 'Pixel 8'}) async {
    clock += minutes * 60 * 1000;
    remote.device = device;
    phone.putText(path, text);
    await engine.sync();
  }

  test('строки журнала: подряд с одного устройства — одна строка, удаление — своя', () {
    CloudVersion v(int minute, String path, {String device = 'Pixel', bool deleted = false}) => CloudVersion(
      file: path,
      path: path,
      rev: minute,
      at: DateTime(2026, 11, 2, 9, minute),
      sentAt: DateTime(2026, 11, 2, 9, minute),
      size: 1,
      hash: '$minute',
      blobs: const [],
      device: device,
      deleted: deleted,
    );
    final rows = groupLog([
      LogEntry(v(30, 'a.md')),
      LogEntry(v(28, 'a.md')),
      LogEntry(v(25, 'a.md', device: 'Сайт')),
      LogEntry(v(20, 'b.md', deleted: true)),
      LogEntry(v(19, 'b.md')),
    ]);
    expect([for (final row in rows) (row.last.path, row.edits)], [('a.md', 2), ('a.md', 1), ('b.md', 1), ('b.md', 1)]);
    expect(rows.first.from, DateTime(2026, 11, 2, 9, 28));
  });

  testWidgets('журнал по дням: имя, устройство, число правок; касание открывает историю заметки', (tester) async {
    await edit('Дом/План.md', '---\nid: p\n---\nплан\n');
    await edit('Дом/План.md', '---\nid: p\n---\nплан\nещё\n');
    await edit('Покупки.md', '---\nid: s\n---\nмолоко\n', minutes: 30, device: 'Сайт');
    await edit('.stowa/tags.json', '[]');
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'p', kind: ItemKind.note, title: 'План', body: const Value('план\nещё'), createdAt: world.now, updatedAt: world.now));
    await world.db.into(world.db.vaultFiles).insert(VaultFilesCompanion.insert(itemId: 'p', path: 'Дом/План.md', modified: 0, size: 0));

    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const SyncLogScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('Покупки'), findsOneWidget);
    expect(find.text('План'), findsOneWidget);
    expect(find.textContaining('Pixel 8 · 2 правки · Дом'), findsOneWidget);
    expect(find.textContaining('Сайт'), findsOneWidget);
    // служебное в журнал не попадает
    expect(find.text('tags'), findsNothing);

    await tester.tap(find.text('План'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
  });

  testWidgets('касание удалённой заметки — подсказка про корзину', (tester) async {
    await edit('Ушла.md', 'текст\n');
    phone.files.remove('Ушла.md');
    clock += 60 * 1000;
    await engine.sync();
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const SyncLogScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('удалено'), findsOneWidget);
    await tester.tap(find.text('Ушла').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('удалённое возвращается из корзины'), findsOneWidget);
  });

  testWidgets('нет связи — тихая строка', (tester) async {
    remote.failWhen = (call) => call == 'log';
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const SyncLogScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Нет связи с сервером'), findsOneWidget);
  });
}
