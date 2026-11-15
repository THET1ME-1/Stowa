// Кадры холста и базы Obsidian с настоящими шрифтами: тёмная и светлая.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/canvas_base_preview_test.dart
// Картинки ложатся в build/previews/canvas_*.png и base_*.png.
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
import 'package:stowa/domain/json_canvas.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/l10n/app_localizations.dart';

import '../../test/helpers/test_app.dart';

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

const _base = '''
filters: file.inFolder("Книги")
properties:
  note.author:
    displayName: Автор
  note.rating:
    displayName: Оценка
views:
  - type: table
    name: Все книги
    order: [file.name, note.author, rating, status]
    sort:
      - property: rating
        direction: DESC
  - type: cards
    name: Обложки
  - type: list
    name: Читаю
''';

CanvasDoc _plan() {
  var doc = CanvasDoc.empty()
      .addGroup('Этап 1 · демонтаж', x: -40, y: -40, width: 760, height: 420)
      .addText('# Замер\n3,2 × 2,6 м, высота 2,7.\nФартук только над рабочей зоной.', x: 0, y: 0, width: 300, height: 180)
      .addText('Снять старую плитку\nв субботу', x: 0, y: 220, width: 300, height: 110)
      .addFile('Дом/Ремонт кухни.md', x: 380, y: 0, width: 300, height: 330)
      .addLink('https://example.com/plitka-20x20', x: 0, y: 460, width: 360, height: 100)
      .addText('Позвонить электрику про розетки', x: 460, y: 460, width: 260, height: 100);
  final ids = [for (final node in doc.nodes) node.id];
  doc = doc.updateNode(ids[1], {'color': '4'}).updateNode(ids[2], {'color': '2'}).updateNode(ids[0], {'color': '5'});
  doc = doc.connect(ids[1], ids[3]).connect(ids[2], ids[5]);
  return doc.updateEdge(doc.edges.first.id, {'label': 'цены тут'});
}

void main() {
  setUpAll(_loadFonts);

  for (final (name, choice) in [('dark', ThemeChoice.dark), ('light', ThemeChoice.light)]) {
    for (final (kind, id) in [('canvas', 'canvas'), ('base', 'base')]) {
      testWidgets('${kind}_$name', (tester) async {
        final world = TestWorld();
        addTearDown(world.dispose);
        final db = world.db;
        await db.into(db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'squircle', color: const Value('amber')));
        await db.into(db.folders).insert(FoldersCompanion.insert(id: 'books', name: 'Книги', icon: 'book', shape: 'squircle', color: const Value('violet')));
        await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'kitchen', kind: ItemKind.note, title: 'Ремонт кухни', folderId: const Value('home'),
          body: const Value('Плитка 20×20, 6 м²\n- [ ] Затирка серая\n- [ ] Смеситель'), createdAt: world.now, updatedAt: world.now,
        ));
        for (final (i, (title, author, rating, status)) in [
          ('Сто лет одиночества', 'Маркес', 5, 'прочитано'),
          ('Мастер и Маргарита', 'Булгаков', 5, 'читаю'),
          ('Идиот', 'Достоевский', 4, 'прочитано'),
          ('Шантарам', 'Робертс', 3, 'брошено'),
          ('Пикник на обочине', 'Стругацкие', 5, 'читаю'),
        ].indexed) {
          await db.into(db.items).insert(ItemsCompanion.insert(
            id: 'b$i', kind: ItemKind.note, title: title, folderId: const Value('books'),
            properties: Value('{"author":"$author","rating":$rating,"status":"$status"}'), createdAt: world.now, updatedAt: world.now,
          ));
        }
        final plan = _plan();
        await db.into(db.items).insert(ItemsCompanion.insert(id: 'canvas', kind: ItemKind.canvas, title: 'План ремонта', folderId: const Value('home'), document: Value(plan.encode()), createdAt: world.now, updatedAt: world.now));
        await db.into(db.items).insert(ItemsCompanion.insert(id: 'base', kind: ItemKind.base, title: 'Библиотека', folderId: const Value('books'), document: const Value(_base), createdAt: world.now, updatedAt: world.now));

        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(392, 850);
        addTearDown(tester.view.reset);
        final palette = paletteFor(Appearance(choice: choice), choice == ThemeChoice.light ? Brightness.light : Brightness.dark);
        Tokens.use(palette);
        addTearDown(() => Tokens.use(StowaPalette.graphiteDark));
        addTearDown(() => tester.pumpWidget(const SizedBox()));
        await tester.pumpWidget(RepaintBoundary(
          key: const ValueKey('shot'),
          child: ProviderScope(
            overrides: world.overrides,
            child: MaterialApp(
              theme: buildAppTheme(palette),
              locale: const Locale('ru'),
              localizationsDelegates: L.localizationsDelegates,
              supportedLocales: L.supportedLocales,
              home: ItemScreen(id: id),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        if (kind == 'canvas') {
          // выбрать карточку: видна полоса действий и уголок размера
          await tester.tap(find.byKey(ValueKey('node-${plan.nodes[1].id}')));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
        }
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/previews').createSync(recursive: true);
          File('build/previews/${kind}_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
        expect(tester.takeException(), isNull);
      });
    }
  }
}
