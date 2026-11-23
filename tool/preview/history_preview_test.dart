// Кадры истории версий: история заметки с сеансами из облака, версия с подсветкой слов,
// «В облаке» в корзине, журнал правок. Настоящие шрифты, тёмная и светлая, телефон, узкий
// телефон и монитор. Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/history_preview_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/core/theme/palette.dart';
import 'package:stowa/core/theme/tokens.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/appearance.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/vault_note.dart';
import 'package:stowa/features/item/history_screen.dart';
import 'package:stowa/features/settings/sync_log_screen.dart';
import 'package:stowa/features/settings/trash_screen.dart';
import 'package:stowa/l10n/app_localizations.dart';
import 'package:stowa/services/sync/cloud_history.dart';
import 'package:stowa/services/sync/sync_crypto.dart';

import '../../test/helpers/test_app.dart';
import '../../test/services/sync/fakes.dart';

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

const _path = 'Дом/Ремонт кухни.md';

String _file(String body) => '---\nid: a\n---\n$body';

String _body(String body) => readVaultNote(_file(body), fileName: 'Ремонт кухни.md', fileModified: DateTime(2026)).body;

void main() {
  setUpAll(_loadFonts);

  for (final (theme, choice) in [('dark', ThemeChoice.dark), ('light', ThemeChoice.light)]) {
    testWidgets('история $theme', (tester) async {
      final world = TestWorld(now: DateTime(2026, 11, 23, 18));
      final remote = FakeRemote();
      final key = VaultKey.generate();
      world.cloudHistory = CloudHistory(remote: remote, key: key);
      addTearDown(world.dispose);

      Future<void> push(String path, String text, DateTime at, String device, {bool deleted = false}) async {
        final data = utf8.encode(text);
        final box = await key.sealChunk(data);
        if (!deleted) await remote.putBlob(sha256Hex(box), box);
        final file = key.fileId(path);
        final current = await remote.file(file);
        remote.device = device;
        remote.now = () => at.toUtc();
        final meta = FileMeta(path: path, mtime: at.millisecondsSinceEpoch, size: deleted ? 0 : data.length, hash: deleted ? '' : sha256Hex(data), deleted: deleted);
        await remote.commit(file, baseRev: current?.rev ?? 0, meta: await key.sealMeta(meta), blobs: deleted ? const [] : [sha256Hex(box)], size: deleted ? 0 : data.length, deleted: deleted);
      }

      final day = DateTime(2026, 11, 23);
      final yesterday = DateTime(2026, 11, 22);
      // вчера на сайте — план; сегодня утром сеанс на телефоне; днём правка с сайта
      await push(_path, _file('Ремонт кухни\nплитка 20×20\nклей'), yesterday.add(const Duration(hours: 21, minutes: 40)), 'Сайт');
      await push(_path, _file('Ремонт кухни\nплитка 30×30\nклей'), day.add(const Duration(hours: 9, minutes: 2)), 'Redmi Note 13');
      await push(_path, _file('Ремонт кухни\nплитка 30×30\nклей\nзатирка'), day.add(const Duration(hours: 9, minutes: 6)), 'Redmi Note 13');
      await push(_path, _file('Ремонт кухни\nплитка 30×30 белая\nклей\nзатирка серая'), day.add(const Duration(hours: 9, minutes: 11)), 'Redmi Note 13');
      await push(_path, _file('Ремонт кухни\nплитка 30×30 белая\nклей\nзатирка серая\nкупить в субботу'), day.add(const Duration(hours: 14, minutes: 20)), 'Сайт');
      // удалённое: заметка с фото
      await push('Старые чеки.md', _file('Старые чеки\nчек за плитку'), yesterday.add(const Duration(hours: 10)), 'Redmi Note 13');
      await push('Старые чеки/чек.jpg', 'картинка', yesterday.add(const Duration(hours: 10)), 'Redmi Note 13');
      await push('Старые чеки.md', '', day.add(const Duration(hours: 12)), 'Сайт', deleted: true);
      await push('Старые чеки/чек.jpg', '', day.add(const Duration(hours: 12)), 'Сайт', deleted: true);

      final db = world.db;
      final current = _body('Ремонт кухни\nплитка 30×30 белая\nклей\nзатирка серая\nкупить в субботу');
      final at = day.add(const Duration(hours: 14, minutes: 20));
      await db.into(db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Ремонт кухни', body: Value(current), createdAt: yesterday, updatedAt: at));
      await db.into(db.vaultFiles).insert(VaultFilesCompanion.insert(itemId: 'a', path: _path, modified: 0, size: 0));
      await db.into(db.noteVersions).insert(NoteVersionsCompanion.insert(id: 's', itemId: 'a', title: 'Ремонт кухни', body: _body('Ремонт кухни\nплитка без сети'), savedAt: yesterday.add(const Duration(hours: 8))));

      final palette = paletteFor(Appearance(choice: choice), choice == ThemeChoice.light ? Brightness.light : Brightness.dark);
      Tokens.use(palette);
      addTearDown(() => Tokens.use(StowaPalette.graphiteDark));
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() => tester.pumpWidget(const SizedBox()));

      Future<void> show(Widget home, Size size) async {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('shot'),
            child: ProviderScope(
              // своё дерево на каждый кадр: раскрытый сеанс прошлого кадра не переезжает
              key: ValueKey('$size ${home.runtimeType}'),
              overrides: world.overrides,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(palette),
                locale: const Locale('ru'),
                localizationsDelegates: L.localizationsDelegates,
                supportedLocales: L.supportedLocales,
                home: home,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> shot(String file) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: file);
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/previews').createSync(recursive: true);
          File('build/previews/history_$file.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      for (final (label, size) in [('phone', const Size(392, 850)), ('narrow', const Size(320, 700)), ('desk', const Size(1280, 800))]) {
        await show(const HistoryScreen(itemId: 'a'), size);
        await shot('${theme}_${label}_list');
        await tester.tap(find.byTooltip('Показать правки'));
        await shot('${theme}_${label}_session');
        // первая — «Сейчас», вторая — строка сеанса
        await tester.tap(find.text('плитка 30×30 белая').at(1));
        await shot('${theme}_${label}_version');
        await show(const TrashScreen(), size);
        await shot('${theme}_${label}_trash');
        await show(const SyncLogScreen(), size);
        await shot('${theme}_${label}_log');
      }
    });
  }
}
