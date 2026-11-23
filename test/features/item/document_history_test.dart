import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/json_canvas.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/history_screen.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/services/sync/cloud_history.dart';
import 'package:stowa/services/sync/sync_crypto.dart';

import '../../helpers/test_app.dart';
import '../../services/sync/fakes.dart';

const _path = 'План ремонта.canvas';

void main() {
  late TestWorld world;
  late FakeRemote remote;
  late VaultKey key;
  late Directory vault;

  setUp(() {
    world = TestWorld();
    remote = FakeRemote();
    key = VaultKey.generate();
    world.cloudHistory = CloudHistory(remote: remote, key: key);
    vault = Directory.systemTemp.createTempSync('stowa_vault');
    world.vaultRoot = vault;
  });

  tearDown(() async {
    await world.dispose();
    if (vault.existsSync()) vault.deleteSync(recursive: true);
  });

  /// Версия холста на поддельном сервере.
  Future<void> push(String text, DateTime at) async {
    final data = utf8.encode(text);
    final box = await key.sealChunk(data);
    final name = sha256Hex(box);
    await remote.putBlob(name, box);
    final file = key.fileId(_path);
    final current = await remote.file(file);
    remote.now = () => at.toUtc();
    final meta = FileMeta(path: _path, mtime: at.millisecondsSinceEpoch, size: data.length, hash: sha256Hex(data));
    await remote.commit(file, baseRev: current?.rev ?? 0, meta: await key.sealMeta(meta), blobs: [name], size: data.length);
  }

  /// Подождать настоящий диск: виджет-тест сам по себе файлы не дожидается.
  Future<void> disk(WidgetTester tester, bool Function() done) async {
    for (var step = 0; step < 100 && !done(); step++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('холст: история в «Ещё», возврат версии меняет файл, «Отменить» — обратно', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final old = CanvasDoc.empty().addText('купить плитку', x: 0, y: 0).encode();
    final now = CanvasDoc.empty().addText('купить плитку', x: 0, y: 0).addText('и клей', x: 0, y: 200).encode();
    await push(old, world.now.subtract(const Duration(hours: 2)));
    await push(now, world.now.subtract(const Duration(hours: 1)));
    final file = File('${vault.path}/$_path')..writeAsStringSync(now);
    final doc = CanvasDoc.parse(now);
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'c', kind: ItemKind.canvas, title: 'План ремонта', document: Value(now), body: Value(doc.plainText()), createdAt: world.now, updatedAt: world.now),
    );
    await world.db.into(world.db.vaultFiles).insert(VaultFilesCompanion.insert(itemId: 'c', path: _path, modified: 0, size: 0));

    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'c')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('История'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    // в строке версии — то, что на холсте написано
    expect(find.text('купить плитку'), findsWidgets);
    // первая строка — «Сейчас», вторая — прежняя версия
    await tester.tap(find.text('купить плитку').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вернуть эту версию'));
    await disk(tester, () => find.text('Версия возвращена').evaluate().isNotEmpty);
    expect(file.readAsStringSync(), old);
    expect(find.byType(HistoryScreen), findsNothing);
    expect(find.text('Версия возвращена'), findsOneWidget);

    await tester.tap(find.text('Отменить'));
    await disk(tester, () => file.readAsStringSync() == now);
    expect(file.readAsStringSync(), now);
  });
}
