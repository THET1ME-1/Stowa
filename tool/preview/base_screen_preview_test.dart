// Кадры базы с панелью: карточки, таблица с итогом, фильтр, свойства, доска; тёмная и светлая.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/base_screen_preview_test.dart
// Своё хранилище: BASE_VAULT=/путь/к/хранилищу и BASE_FILE=папка/Имя.base перед командой —
// заметки папок, на которые смотрит база, берутся оттуда вместе с обложками.
// Картинки ложатся в build/previews/base_screen_<кадр>.png.
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
import 'package:stowa/data/providers.dart';
import 'package:stowa/domain/appearance.dart';
import 'package:stowa/domain/base_edit.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/obsidian_base.dart';
import 'package:stowa/domain/vault_note.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/l10n/app_localizations.dart';

import '../../test/helpers/test_app.dart';

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

const _sample = '''
formulas:
  stars: '"★".repeat(rating)'
properties:
  formula.stars:
    displayName: Оценка
views:
  - type: cards
    name: Прочитано
    filters:
      and:
        - file.folder == "Книги"
    order: [file.name, author, formula.stars]
    sort:
      - property: rating
        direction: DESC
  - type: table
    name: Все книги
    order: [file.name, author, rating, status]
    summaries:
      rating: Average
''';

const _sampleBooks = [
  ('Мастер и Маргарита', {'author': 'Булгаков', 'rating': 5, 'status': 'прочитано'}),
  ('Идиот', {'author': 'Достоевский', 'rating': 4, 'status': 'прочитано'}),
  ('Дюна', {'author': 'Герберт', 'rating': 5, 'status': 'читаю'}),
  ('Пикник на обочине', {'author': 'Стругацкие', 'rating': 4, 'status': 'в очереди'}),
  ('Солярис', {'author': 'Лем', 'rating': 3, 'status': 'в очереди'}),
];

void main() {
  setUpAll(_loadFonts);
  final vault = Platform.environment['BASE_VAULT'];
  final basePath = Platform.environment['BASE_FILE'];
  final own = vault != null && basePath != null;

  /// Папки и заметки: из своего хранилища (все .md папки базы и соседних) или пример.
  Future<String> seed(TestWorld world) async {
    final db = world.db;
    if (!own) {
      await db.into(db.folders).insert(FoldersCompanion.insert(id: 'f', name: 'Книги', icon: 'folder', shape: 'squircle'));
      for (final (i, (title, props)) in _sampleBooks.indexed) {
        await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'n$i', kind: ItemKind.note, title: title, folderId: const Value('f'), properties: Value(packVaultProperties(props)), createdAt: world.now, updatedAt: world.now,
        ));
      }
      return _sample;
    }
    final text = File('$vault/$basePath').readAsStringSync();
    final folders = <String, String>{};
    Future<String> folder(String path) async {
      if (folders[path] case final id?) return id;
      final parts = path.split('/');
      final parent = parts.length > 1 ? await folder(parts.sublist(0, parts.length - 1).join('/')) : null;
      final id = 'f${folders.length}';
      await db.into(db.folders).insert(FoldersCompanion.insert(id: id, name: parts.last, icon: 'folder', shape: 'squircle', parentId: Value(parent)));
      return folders[path] = id;
    }

    final root = Directory('$vault/${basePath.split('/').first}');
    var count = 0;
    for (final file in root.listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.md'))) {
      final relative = file.path.substring(vault.length + 1);
      final note = readVaultNote(file.readAsStringSync(), fileName: relative.split('/').last, fileModified: file.lastModifiedSync());
      final folderPath = relative.substring(0, relative.lastIndexOf('/'));
      await db.into(db.items).insert(ItemsCompanion.insert(
        id: 'n${count++}',
        kind: ItemKind.note,
        title: relative.split('/').last.replaceFirst(RegExp(r'\.md$'), ''),
        folderId: Value(await folder(folderPath)),
        properties: Value(packVaultProperties(note.extra)),
        createdAt: note.created,
        updatedAt: note.updated,
      ));
    }
    return text;
  }

  Future<void> shoot(WidgetTester tester, String name, {required ThemeChoice choice, int view = 0, String Function(String text)? edit, Future<void> Function()? act}) async {
    final world = TestWorld();
    addTearDown(world.dispose);
    var text = await seed(world);
    if (edit != null) text = edit(text);
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
      id: 'base', kind: ItemKind.base, title: own ? basePath.split('/').last.replaceFirst('.base', '') : 'Библиотека', document: Value(text), createdAt: world.now, updatedAt: world.now,
    ));
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
        overrides: [...world.overrides, if (own) filesRootProvider.overrideWithValue(Directory(vault))],
        child: MaterialApp(
          theme: buildAppTheme(palette),
          locale: const Locale('ru'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const ItemScreen(id: 'base'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    if (view > 0) {
      await tester.tap(find.byKey(ValueKey('base-view-$view')));
      await tester.pumpAndSettle();
    }
    if (act != null) await act();
    // обложки с диска тестовая среда не разбирает: на кадре на их месте пустые рамки
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/previews').createSync(recursive: true);
      File('build/previews/base_screen_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  testWidgets('cards_dark', (tester) => shoot(tester, 'cards_dark', choice: ThemeChoice.dark));
  testWidgets('cards_light', (tester) => shoot(tester, 'cards_light', choice: ThemeChoice.light));
  testWidgets('table_dark', (tester) => shoot(tester, 'table_dark', choice: ThemeChoice.dark, view: own ? 1 : 1, edit: (text) {
    final base = ObsidianBase.parse(text);
    final index = base.views.indexWhere((view) => view.type == BaseViewType.table);
    final editor = BaseEditor(text);
    if (index < 0) {
      editor
        ..addView(BaseViewType.table, 'Таблица')
        ..moveView(base.views.length, 1);
    } else if (index != 1) {
      editor.moveView(index, 1);
    }
    return editor.text;
  }));
  testWidgets('filter_dark', (tester) => shoot(tester, 'filter_dark', choice: ThemeChoice.dark, act: () async {
    await tester.tap(find.byKey(const ValueKey('base-filter')));
    await tester.pumpAndSettle();
  }));
  testWidgets('properties_dark', (tester) => shoot(tester, 'properties_dark', choice: ThemeChoice.dark, act: () async {
    await tester.tap(find.byKey(const ValueKey('base-properties')));
    await tester.pumpAndSettle();
  }));
  testWidgets('sort_dark', (tester) => shoot(tester, 'sort_dark', choice: ThemeChoice.dark, act: () async {
    await tester.tap(find.byKey(const ValueKey('base-sort')));
    await tester.pumpAndSettle();
  }));
  testWidgets('kanban_dark', (tester) => shoot(tester, 'kanban_dark', choice: ThemeChoice.dark, edit: (text) {
    final editor = BaseEditor(text)..moveView(0, 0);
    final base = ObsidianBase.parse(text);
    editor
      ..addView(BaseViewType.kanban, 'Доска')
      ..moveView(base.views.length, 0)
      ..setGroupBy(0, (property: own ? 'Формат' : 'status', descending: false))
      ..setOrder(0, ['file.name', if (own) 'Автор' else 'author']);
    return editor.text;
  }));
}
