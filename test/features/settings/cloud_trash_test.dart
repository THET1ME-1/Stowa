import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/settings/trash_screen.dart';
import 'package:stowa/services/sync/cloud_history.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_engine.dart';

import '../../helpers/test_app.dart';
import '../../services/sync/fakes.dart';

var _now = 1763900000000;
int _clock() => _now += 60 * 1000;

void main() {
  late TestWorld world;
  late FakeRemote remote;
  late VaultKey key;
  late Directory vault;

  /// Другое устройство: его правки и удаления уходят на поддельный сервер.
  late MemoryVault phone;
  late SyncEngine engine;

  setUp(() async {
    world = TestWorld();
    remote = FakeRemote(now: () => DateTime.fromMillisecondsSinceEpoch(_now, isUtc: true));
    key = VaultKey.generate();
    world.cloudHistory = CloudHistory(remote: remote, key: key);
    vault = Directory.systemTemp.createTempSync('stowa_vault');
    world.vaultRoot = vault;
    phone = MemoryVault(_clock);
    engine = SyncEngine(vault: phone, remote: remote, state: MemoryState(), key: key);
  });

  tearDown(() async {
    await world.dispose();
    if (vault.existsSync()) vault.deleteSync(recursive: true);
  });

  /// Заметка с фото удалена на другом телефоне, ещё одна стёрта там из корзины.
  Future<void> deleteElsewhere() async {
    phone.putText('Ушла.md', '---\nid: n1\n---\nпрощай\n![[фото.jpg]]\n');
    phone.put('Ушла/фото.jpg', [1, 2, 3, 4]);
    phone.putText('Живая.md', 'живая\n');
    await engine.sync();
    phone.files.remove('Ушла.md');
    phone.files.remove('Ушла/фото.jpg');
    await engine.sync();
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const TrashScreen()));
    await tester.pumpAndSettle();
  }

  /// Подождать настоящий диск: виджет-тест сам по себе файлы не дожидается.
  Future<void> disk(WidgetTester tester, bool Function() done) async {
    for (var step = 0; step < 100 && !done(); step++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Finder cloudRestore() => find.descendant(of: find.byKey(const ValueKey('cloud-trash')), matching: find.text('Вернуть'));

  testWidgets('удалённая на другом телефоне заметка возвращается на место вместе с фото', (tester) async {
    await deleteElsewhere();
    await open(tester);
    expect(find.text('В облаке'), findsOneWidget);
    expect(find.text('Ушла'), findsOneWidget);
    // число и слово склеены неразрывным пробелом: подпись не рвётся по строкам
    expect(find.textContaining('1 вложение'), findsOneWidget);
    expect(find.text('Живая'), findsNothing);
    await tester.tap(cloudRestore());
    await disk(tester, () => File('${vault.path}/Ушла.md').existsSync() && find.text('Ушла').evaluate().isEmpty);
    expect(File('${vault.path}/Ушла.md').readAsStringSync(), '---\nid: n1\n---\nпрощай\n![[фото.jpg]]\n');
    expect(File('${vault.path}/Ушла/фото.jpg').readAsBytesSync(), [1, 2, 3, 4]);
    expect(find.text('Вернул «Ушла»'), findsOneWidget);
  });

  testWidgets('имя занято — заметка ложится рядом, ничего не затёрто', (tester) async {
    await deleteElsewhere();
    File('${vault.path}/Ушла.md').writeAsStringSync('другая заметка с тем же именем\n');
    await open(tester);
    await tester.tap(cloudRestore());
    await disk(tester, () => File('${vault.path}/Ушла 2.md').existsSync() && File('${vault.path}/Ушла 2/фото.jpg').existsSync());
    expect(File('${vault.path}/Ушла.md').readAsStringSync(), 'другая заметка с тем же именем\n');
    expect(File('${vault.path}/Ушла 2.md').readAsStringSync(), contains('прощай'));
    expect(File('${vault.path}/Ушла 2/фото.jpg').readAsBytesSync(), [1, 2, 3, 4]);
  });

  testWidgets('«Стереть навсегда» спрашивает, стирает историю и убирает строку', (tester) async {
    await deleteElsewhere();
    await open(tester);
    await tester.longPress(find.text('Ушла'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Стереть «Ушла» навсегда?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Стереть навсегда'));
    await tester.pumpAndSettle();
    expect(find.text('Ушла'), findsNothing);
    expect(find.text('Стёрто навсегда'), findsOneWidget);
    expect(remote.history[key.fileId('Ушла.md')], isNull);
    expect(remote.history[key.fileId('Ушла/фото.jpg')], isNull);
  });

  testWidgets('нет связи — тихая строка, корзина телефона на месте', (tester) async {
    await deleteElsewhere();
    remote.failWhen = (call) => call == 'deleted';
    await open(tester);
    expect(find.textContaining('Нет связи с сервером'), findsOneWidget);
    expect(find.text('Корзина пуста'), findsOneWidget);
  });

  testWidgets('без Stowa Sync раздела нет', (tester) async {
    world.cloudHistory = null;
    await open(tester);
    expect(find.text('В облаке'), findsNothing);
  });
}
