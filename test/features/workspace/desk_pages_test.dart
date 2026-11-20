import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/settings/settings_blocks.dart';
import 'package:stowa/features/settings/sync_screen.dart';
import 'package:stowa/features/workspace/workspace_model.dart';
import 'package:stowa/features/workspace/workspace_settings.dart';
import 'package:stowa/features/workspace/workspace_shell.dart';
import 'package:stowa/services/sync/sync_service.dart';

import '../../helpers/test_app.dart';

// хозяин 20.11 со снимка Stowa Sync на мониторе: «слишком всё широкое, как на телефоне. Это ужас»
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  // хозяин 20.11 со снимка: на экране Stowa Sync вошёл, а в правой панели «Синхронизация выключена»
  testWidgets('монитор: вошли в Stowa Sync — правая панель и подпись хранилища сразу пишут «Синхронизировано»', (tester) async {
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    expect(find.text('Синхронизация выключена'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(LineDock)));
    container.read(syncServiceProvider).status.value = const SyncStatus(email: 'me@x.io');
    await tester.pumpAndSettle();
    expect(find.text('Синхронизировано'), findsNWidgets(2));
    expect(find.text('Синхронизация выключена'), findsNothing);
  });

  testWidgets('монитор: экран настроек поверх вкладки — колонкой по центру, а не во всю ширину', (tester) async {
    // у Stowa Sync должно быть открыто хранилище
    final vault = Directory.systemTemp.createTempSync('stowa_desk_pages');
    addTearDown(() => vault.deleteSync(recursive: true));
    world.vaultRoot = vault;
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final shell = WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!;
    shell.open(const WsTab.settings());
    await tester.pumpAndSettle();
    final settings = find.byType(WorkspaceSettings);
    final window = tester.getRect(settings);
    Navigator.of(tester.element(settings)).push(settingsPageRoute(const SyncScreen()));
    await tester.pumpAndSettle();

    final email = tester.getRect(find.byKey(const ValueKey('sync-email')));
    expect(email.width, lessThanOrEqualTo(760));
    expect((email.center.dx - window.center.dx).abs(), lessThan(2), reason: 'колонка по центру окна');
  });
}
