// Кадры верха главной с настоящими шрифтами: папки одной строкой, «+N», пилюли возврата.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/shelf_preview_test.dart
// Картинки ложатся в build/previews/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';

import '../../test/helpers/test_app.dart';

final _out = Directory('build/previews');

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final (name, folders) in [
    ('shelf-1-три', [('adult', '18+', 'explicit', 1), ('health', 'Здоровье', 'healing', 4), ('refs', 'Референсы', 'perm_media', 1)]),
    (
      'shelf-2-восемь',
      [
        ('adult', '18+', 'explicit', 1), ('health', 'Здоровье', 'healing', 4), ('refs', 'Референсы', 'perm_media', 1), ('car', 'Машина', 'directions_car', 3),
        ('food', 'Рецепты', 'restaurant', 6), ('gift', 'Подарки', 'redeem', 2), ('work', 'Работа', 'work', 5), ('books', 'Книги', 'menu_book', 2),
      ],
    ),
  ]) {
    testWidgets(name, (tester) async {
      final world = TestWorld();
      addTearDown(world.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(392, 850);
      addTearDown(tester.view.reset);
      final db = world.db;
      var order = 0;
      var number = 0;
      Future<void> note(String title, {String? folder, DateTime? at, DateTime? remind}) async {
        number++;
        final created = at ?? world.now.subtract(Duration(minutes: number));
        await db.into(db.items).insert(ItemsCompanion.insert(
              id: 'n$number',
              kind: ItemKind.note,
              title: title,
              body: Value(title),
              folderId: Value(folder),
              reminderAt: Value(remind),
              sortState: const Value(SortState.sorted),
              createdAt: created,
              updatedAt: created,
            ));
      }

      for (final (id, label, icon, count) in folders) {
        await db.into(db.folders).insert(FoldersCompanion.insert(id: id, name: label, icon: icon, shape: 'pill', sortOrder: Value(order++)));
        for (var index = 0; index < count; index++) {
          await note('$label $index', folder: id);
        }
      }
      await note('Мысль без папки');
      await note('Неделю назад сохранил', at: world.now.subtract(const Duration(days: 7)));
      await note('Вечером пить пиво', remind: world.now.add(const Duration(hours: 3)));
      await note('Позвонить маме', remind: world.now.add(const Duration(days: 1)));
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: world.app()));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        _out.createSync(recursive: true);
        File(p.join(_out.path, '$name.png')).writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}
