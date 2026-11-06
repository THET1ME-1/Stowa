import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/app.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_sync.dart';
import 'package:stowa/services/vault/vault_writer.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  late VaultSync sync;
  setUp(() {
    world = TestWorld();
    sync = VaultSync(reader: VaultReader(world.db, root: null, clock: () => world.now), writer: VaultWriter(world.db, root: null, clock: () => world.now));
  });
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(ProviderScope(overrides: [...world.overrides, vaultSyncProvider.overrideWithValue(sync)], child: const StowaApp(locale: Locale('ru'))));
    await tester.pumpAndSettle();
  }

  testWidgets('пришло много заметок снаружи — на главной «Синхронизация заметок 340 из 1000», кончилось — полоски нет', (tester) async {
    await open(tester);
    expect(find.textContaining('Синхронизация заметок'), findsNothing);
    sync.status.value = (340, 1000);
    await tester.pump();
    expect(find.text('Синхронизация заметок 340 из 1000'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(find.descendant(of: find.byKey(const ValueKey('vault-sync-bar')), matching: find.byType(LinearProgressIndicator))).value, closeTo(0.34, 0.001));
    sync.status.value = null;
    await tester.pump();
    expect(find.textContaining('Синхронизация заметок'), findsNothing);
  });
}
