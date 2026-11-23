import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/vault_note.dart';
import 'package:stowa/features/item/history_screen.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/services/sync/cloud_history.dart';
import 'package:stowa/services/sync/sync_crypto.dart';

import '../../helpers/test_app.dart';
import '../../services/sync/fakes.dart';

const _path = 'Ремонт кухни.md';

/// Файл заметки, как его пишет хранилище: шапка с id и текст.
String _file(String body) => '---\nid: a\n---\n$body';

/// Текст заметки из файла — тем же разбором, что у хранилища.
String _body(String body) => readVaultNote(_file(body), fileName: _path, fileModified: DateTime(2026)).body;

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> seed({bool versions = true}) async {
    final db = world.db;
    final before = world.now.subtract(const Duration(hours: 2));
    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Ремонт кухни', body: const Value('Ремонт кухни\nплитка 20×20\nклей'), createdAt: before, updatedAt: before),
    );
    if (!versions) return;
    // правка час спустя: прежний текст уходит в историю сам
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(
      ItemsCompanion(body: const Value('Ремонт кухни\nплитка 30×30\nклей\nзатирка серая'), updatedAt: Value(world.now.subtract(const Duration(hours: 1)))),
    );
  }

  Future<void> openHistory(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё').first);
    await tester.pumpAndSettle();
    // меню прокручивается: на узком экране с крупным шрифтом «История» ниже края
    await tester.ensureVisible(find.text('История'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('История'));
    await tester.pumpAndSettle();
  }

  testWidgets('без снимков и без Stowa Sync пункта «История» в меню нет', (tester) async {
    await seed(versions: false);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё').first);
    await tester.pumpAndSettle();
    expect(find.text('История'), findsNothing);
  });

  testWidgets('снимки устройства: «Сейчас», версия, разница с нынешней; без подписки — карточка Stowa Sync', (tester) async {
    await seed();
    await openHistory(tester);
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('Сейчас'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-promo')), findsOneWidget);
    expect(find.text('Только на этом устройстве'), findsNothing);

    await tester.tap(find.text('плитка 20×20'));
    await tester.pumpAndSettle();
    // старше версий нет: открывается разница с нынешней
    expect(find.text('С нынешней'), findsOneWidget);
    expect(find.text('Изменения'), findsNothing);
    expect(find.text('плитка 20×20'), findsOneWidget);
    expect(find.text('плитка 30×30'), findsOneWidget);
    expect(find.text('затирка серая'), findsOneWidget);
  });

  testWidgets('«Вернуть эту версию» возвращает текст, «Отменить» — обратно', (tester) async {
    await seed();
    await openHistory(tester);
    await tester.tap(find.text('плитка 20×20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вернуть эту версию'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsNothing);
    expect(find.byType(ItemScreen), findsOneWidget);
    expect((await world.db.select(world.db.items).getSingle()).body, 'Ремонт кухни\nплитка 20×20\nклей');
    expect(find.text('Версия возвращена'), findsOneWidget);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.items).getSingle()).body, 'Ремонт кухни\nплитка 30×30\nклей\nзатирка серая');
  });

  group('история из облака', () {
    late FakeRemote remote;
    late VaultKey key;

    /// Правка заметки с устройства [device] в [at]: ревизия на поддельном сервере.
    Future<void> push(String body, DateTime at, {String device = 'Pixel 8'}) async {
      final data = utf8.encode(_file(body));
      final box = await key.sealChunk(data);
      final name = sha256Hex(box);
      await remote.putBlob(name, box);
      final file = key.fileId(_path);
      final current = await remote.file(file);
      remote.device = device;
      remote.now = () => at.toUtc();
      final meta = FileMeta(path: _path, mtime: at.millisecondsSinceEpoch, size: data.length, hash: sha256Hex(data));
      await remote.commit(file, baseRev: current?.rev ?? 0, meta: await key.sealMeta(meta), blobs: [name], size: data.length);
    }

    /// Заметка с нынешним текстом [body] и путём файла в хранилище.
    Future<void> note(String body, {DateTime? at}) async {
      final db = world.db;
      final when = at ?? world.now.subtract(const Duration(minutes: 5));
      await db.into(db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Ремонт кухни', body: Value(_body(body)), createdAt: when, updatedAt: when));
      await db.into(db.vaultFiles).insert(VaultFilesCompanion.insert(itemId: 'a', path: _path, modified: 0, size: 0));
    }

    setUp(() {
      remote = FakeRemote();
      key = VaultKey.generate();
      world.cloudHistory = CloudHistory(remote: remote, key: key);
    });

    testWidgets('правки со всех устройств: устройство, снимок без пары — «Только на этом устройстве»', (tester) async {
      final hourAgo = world.now.subtract(const Duration(hours: 1));
      await push('Ремонт кухни\nплитка 20×20', world.now.subtract(const Duration(hours: 2)), device: 'Сайт');
      await push('Ремонт кухни\nплитка 30×30', hourAgo);
      await note('Ремонт кухни\nплитка 30×30', at: hourAgo);
      // снимок с тем же текстом, что и облачная версия, — одна строка; правка без сети — своя
      final db = world.db;
      await db.into(db.noteVersions).insert(NoteVersionsCompanion.insert(id: 's1', itemId: 'a', title: 'Ремонт кухни', body: _body('Ремонт кухни\nплитка 20×20'), savedAt: world.now.subtract(const Duration(hours: 2))));
      await db.into(db.noteVersions).insert(NoteVersionsCompanion.insert(id: 's2', itemId: 'a', title: 'Ремонт кухни', body: _body('Ремонт кухни\nклей без сети'), savedAt: world.now.subtract(const Duration(hours: 3))));
      await openHistory(tester);
      expect(find.text('плитка 20×20'), findsOneWidget);
      expect(find.text('клей без сети'), findsOneWidget);
      // верхняя облачная версия совпала с нынешним текстом: это «Сейчас»
      expect(find.text('плитка 30×30'), findsOneWidget);
      expect(find.textContaining('Сайт'), findsOneWidget);
      expect(find.textContaining('Только на этом устройстве'), findsOneWidget);
      expect(find.byKey(const ValueKey('history-promo')), findsNothing);
      expect(find.textContaining('хранятся на сервере'), findsOneWidget);
    });

    testWidgets('сеанс: правки подряд с одного устройства — одна строка, раскрывается по правкам', (tester) async {
      final start = world.now.subtract(const Duration(hours: 3));
      await push('Ремонт кухни\nа', start);
      await push('Ремонт кухни\nа\nб', start.add(const Duration(minutes: 3)));
      await push('Ремонт кухни\nа\nб\nв', start.add(const Duration(minutes: 5)));
      await push('Ремонт кухни\nсейчас', world.now.subtract(const Duration(minutes: 5)));
      await note('Ремонт кухни\nсейчас');
      await openHistory(tester);
      expect(find.textContaining('3 правки'), findsOneWidget);
      expect(find.text('07:00–07:05'), findsOneWidget);
      await tester.tap(find.byTooltip('Показать правки'));
      await tester.pumpAndSettle();
      expect(find.text('07:03'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
      // правка 07:03 добавила одну строку к 07:00
      await tester.tap(find.text('07:03'));
      await tester.pumpAndSettle();
      expect(find.text('Изменения'), findsOneWidget);
      expect(find.text('б'), findsOneWidget);
    });

    testWidgets('«Изменения» — против предыдущей версии; возврат облачной версии отменяется', (tester) async {
      await push('Ремонт кухни\nплитка\nклей', world.now.subtract(const Duration(hours: 3)));
      await push('Ремонт кухни\nплитка белая\nклей', world.now.subtract(const Duration(hours: 2)));
      await push('Ремонт кухни\nсовсем другое', world.now.subtract(const Duration(hours: 1)));
      await note('Ремонт кухни\nсовсем другое', at: world.now.subtract(const Duration(hours: 1)));
      await openHistory(tester);
      expect(find.textContaining('+1 −1'), findsOneWidget);
      await tester.tap(find.text('плитка белая'));
      await tester.pumpAndSettle();
      expect(find.text('Изменения'), findsOneWidget);
      // слово «белая» подсвечено внутри строки, а не вся строка
      final added = tester.widget<Text>(find.text('плитка белая'));
      expect(added.textSpan, isNotNull);
      await tester.tap(find.text('Вернуть эту версию'));
      await tester.pumpAndSettle();
      expect((await world.db.select(world.db.items).getSingle()).body, _body('Ремонт кухни\nплитка белая\nклей'));
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect((await world.db.select(world.db.items).getSingle()).body, _body('Ремонт кухни\nсовсем другое'));
    });

    testWidgets('нет связи — снимки устройства и тихая строка, без ошибки во весь экран', (tester) async {
      await note('Ремонт кухни\nсейчас');
      await world.db.into(world.db.noteVersions).insert(NoteVersionsCompanion.insert(id: 's1', itemId: 'a', title: 'Ремонт кухни', body: 'Ремонт кухни\nснимок', savedAt: world.now.subtract(const Duration(hours: 3))));
      remote.failWhen = (call) => call == 'revisions';
      await openHistory(tester);
      expect(find.textContaining('Нет связи с сервером'), findsOneWidget);
      expect(find.text('снимок'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('вошли без подписки — снимки и карточка Stowa Sync', (tester) async {
      world.cloudSubscribed = false;
      await note('Ремонт кухни\nсейчас');
      await openHistory(tester);
      expect(find.byKey(const ValueKey('history-promo')), findsOneWidget);
    });
  });

  testWidgets('история и версия влезают в 320 точек при крупном шрифте', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seed();
    await openHistory(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('плитка 20×20'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
