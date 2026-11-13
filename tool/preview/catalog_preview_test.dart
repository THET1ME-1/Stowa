// Кадры «Каталога» с настоящими шрифтами: верх настроек, экран «Хранилище» с тремя
// хранилищами, лист «Добавить», Stowa Sync, 320 точек с крупным шрифтом.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/catalog_preview_test.dart
// Картинки ложатся в build/previews/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/app.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/known_vaults.dart';
import 'package:stowa/domain/models.dart';

import '../../test/helpers/test_app.dart';

final _out = Directory('build/previews');

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  for (var round = 0; round < 10; round++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    _out.createSync(recursive: true);
    File(p.join(_out.path, '$name.png')).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  Future<Widget> app(WidgetTester tester, {Size size = const Size(392, 850), double textScale = 1}) async {
    final world = TestWorld();
    addTearDown(world.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // память телефона — не папка приложения: иначе хранилище считалось бы «внутри приложения»
    final phone = Directory.systemTemp.createTempSync('phone');
    addTearDown(() => phone.deleteSync(recursive: true));
    final root = Directory(p.join(phone.path, 'Documents', 'Stowa'))..createSync(recursive: true);
    final obsidian = Directory(p.join(phone.path, 'Obsidian'))..createSync();
    final work = Directory(p.join(phone.path, 'Documents', 'Работа'))..createSync(recursive: true);
    // кадры лежат в tool/, а не в test/: анализатор не узнаёт в них тест
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'vault_path': root.path,
      'vault_mode': 'device',
      'known_vaults': KnownVault.encodeList([
        KnownVault(path: obsidian.path, mode: VaultMode.device, db: 'stowa-obs', notes: 214, opened: world.now.subtract(const Duration(days: 1))),
        KnownVault(path: work.path, mode: VaultMode.device, db: 'stowa-work', notes: 37, opened: world.now.subtract(const Duration(days: 3))),
        KnownVault(path: p.join(world.files.path, 'SD', 'Старое'), mode: VaultMode.device, db: 'stowa-old', notes: 9, opened: world.now.subtract(const Duration(days: 30))),
      ]),
    });
    world.settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore(), clock: () => world.now);
    for (var index = 0; index < 128; index++) {
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'n$index', kind: ItemKind.note, title: 'Заметка $index', body: Value('Заметка $index'), createdAt: world.now, updatedAt: world.now));
    }
    return RepaintBoundary(
      key: const ValueKey('shot'),
      child: ProviderScope(
        overrides: [...world.overrides, vaultRootProvider.overrideWith(() => VaultRootNotifier(root))],
        child: const StowaApp(locale: Locale('ru')),
      ),
    );
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
  }

  testWidgets('настройки сверху и экран «Хранилище»', (tester) async {
    await tester.pumpWidget(await app(tester));
    await openSettings(tester);
    await _shot(tester, 'catalog-1-настройки');
    await tester.tap(find.byKey(const ValueKey('settings-catalog')));
    await _shot(tester, 'catalog-2-хранилище');
    await tester.tap(find.text('Добавить хранилище'));
    await _shot(tester, 'catalog-3-добавить');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stowa Sync'));
    await _shot(tester, 'catalog-4-sync');
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('vault-stowa-obs')), matching: find.byTooltip('Ещё')));
    await _shot(tester, 'catalog-5-ещё');
  });

  testWidgets('320 точек, крупный шрифт', (tester) async {
    await tester.pumpWidget(await app(tester, size: const Size(320, 700), textScale: 1.3));
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('settings-catalog')));
    await _shot(tester, 'catalog-6-320');
  });
}
