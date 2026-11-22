import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/backup_nudge.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/web/copy_nudge.dart';
import 'package:stowa/l10n/app_localizations.dart';
import 'package:stowa/services/sync/sync_service.dart';

import '../../helpers/test_app.dart';

void main() {
  Future<void> show(WidgetTester tester, {required BackupNudge nudge, bool weak = false, VoidCallback? onSave, VoidCallback? onLater, double width = 900}) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: CopyNudge(nudge: nudge, storageWeak: weak, onSave: onSave ?? () {}, onLater: onLater ?? () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('копии ещё не было: предупреждение, что заметки только в этом браузере, и две кнопки', (tester) async {
    var saved = 0;
    var later = 0;
    await show(tester, nudge: BackupNudge.first, onSave: () => saved++, onLater: () => later++);
    expect(find.text('Заметки лежат только в этом браузере: сохраните копию, чтобы их не потерять.'), findsOneWidget);
    await tester.tap(find.text('Сохранить копию'));
    await tester.tap(find.text('Позже'));
    expect((saved, later), (1, 1));
  });

  // 21.11 хозяин со снимка: «Кнопка Позже кривая, выше чем надо» — в узкой плашке кнопки
  // стояли по верхнему краю, а «Позже» ниже «Сохранить копию». 480 — узкая плашка (кнопки
  // под текстом), но обе ещё в одной строке: шрифт тестов шире настоящего
  for (final width in [480.0, 900.0]) {
    testWidgets('«Позже» на одной высоте с «Сохранить копию», ширина ${width.toInt()}', (tester) async {
      await show(tester, nudge: BackupNudge.first, width: width);
      final save = tester.getCenter(find.widgetWithText(FilledButton, 'Сохранить копию'));
      final later = tester.getCenter(find.widgetWithText(TextButton, 'Позже'));
      expect(later.dy, closeTo(save.dy, 0.5));
    });
  }

  testWidgets('копия устарела — напоминание короче', (tester) async {
    await show(tester, nudge: BackupNudge.stale);
    expect(find.text('Копия заметок устарела: сохраните свежую.'), findsOneWidget);
    expect(find.text('Сохранить копию'), findsOneWidget);
  });

  testWidgets('напоминать не о чем — плашки нет вовсе, места она не занимает', (tester) async {
    await show(tester, nudge: BackupNudge.none);
    expect(find.text('Сохранить копию'), findsNothing);
    expect(tester.getSize(find.byType(CopyNudge)).height, 0);
  });

  testWidgets('браузер не дал надёжного хранилища — отдельное предупреждение без кнопок', (tester) async {
    await show(tester, nudge: BackupNudge.none, weak: true);
    expect(find.text('Браузер не дал надёжного хранилища: заметки могут пропасть, когда вкладку закроют.'), findsOneWidget);
    expect(find.text('Позже'), findsNothing);
  });

  testWidgets('на узком окне кнопки уходят под текст и ничего не вылезает', (tester) async {
    await show(tester, nudge: BackupNudge.first, weak: true, width: 320);
    expect(tester.takeException(), isNull);
    expect(find.text('Сохранить копию'), findsOneWidget);
  });

  // хозяин 20.11, вошедший в Stowa Sync: «у меня платная подписка, синхронизация должна быть серверная»
  group('на главной в браузере', () {
    late TestWorld world;
    setUp(() => world = TestWorld()..inBrowser = true);
    tearDown(() => world.dispose());

    Future<void> home(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      world.settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Мысль', createdAt: world.now, updatedAt: world.now));
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(world.app());
      await tester.pumpAndSettle();
    }

    testWidgets('не вошли в Stowa Sync — плашка о копии есть', (tester) async {
      await home(tester);
      expect(find.textContaining('только в этом браузере'), findsOneWidget);
    });

    testWidgets('вошли в Stowa Sync — заметки и на сервере, плашки о копии нет', (tester) async {
      await world.syncAccount.write(SyncAccount(email: 'me@x.io', token: 't', key: List.filled(32, 1), vaultDb: 'stowa').toJson());
      await home(tester);
      expect(find.textContaining('только в этом браузере'), findsNothing);
      expect(find.text('Сохранить копию'), findsNothing);
    });

    // 22.11.2026: в браузере несколько хранилищ, а Stowa Sync возит одно — то, где вошли
    testWidgets('вошли, но открыто другое хранилище — оно только в браузере, плашка есть', (tester) async {
      await world.syncAccount.write(SyncAccount(email: 'me@x.io', token: 't', key: List.filled(32, 1), vaultDb: 'stowa-other').toJson());
      await home(tester);
      expect(find.textContaining('только в этом браузере'), findsOneWidget);
    });
  });
}
