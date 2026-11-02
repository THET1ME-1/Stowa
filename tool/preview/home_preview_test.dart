// Кадры главной с настоящими шрифтами, чтобы посмотреть глазами.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/home_preview_test.dart
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

const _size = Size(392, 850);
final _out = Directory('build/previews');

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

/// Мягкая заглушка вместо фото: градиент и круг, чтобы видеть обложки.
Future<void> _photo(String path, Color from, Color to) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const rect = Rect.fromLTWH(0, 0, 240, 240);
  canvas.drawRect(rect, Paint()..shader = LinearGradient(colors: [from, to], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(rect));
  canvas.drawCircle(const Offset(150, 100), 54, Paint()..color = Colors.white.withValues(alpha: 0.35));
  final image = await recorder.endRecording().toImage(240, 240);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

Future<void> _seed(TestWorld world) async {
  final db = world.db;
  final now = world.now;
  final covers = <String>[];
  final colors = [
    (const Color(0xFFB86B4B), const Color(0xFFE8B07A)),
    (const Color(0xFF3F6F5A), const Color(0xFF9CC9A0)),
    (const Color(0xFF5B5F97), const Color(0xFFB8B5E8)),
    (const Color(0xFF8A4F7D), const Color(0xFFE6A4C4)),
  ];
  for (final (index, pair) in colors.indexed) {
    final relative = 'attachments/c$index/0_photo.png';
    await _photo(p.join(world.files.path, relative), pair.$1, pair.$2);
    covers.add(relative);
  }

  await db.into(db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Рецепты', icon: 'restaurant', shape: 'cookie9'));
  await db.into(db.folders).insert(FoldersCompanion.insert(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill', sortOrder: const Value(1)));
  await db.into(db.folders).insert(FoldersCompanion.insert(id: 'gift', name: 'Подарки Сане', icon: 'redeem', shape: 'gem', sortOrder: const Value(2)));
  await db.into(db.folders).insert(FoldersCompanion.insert(id: 'work', name: 'Togetherly', icon: 'favorite', shape: 'squircle', sortOrder: const Value(3)));

  var minute = 0;
  Future<void> item(String id, String title, {ItemKind kind = ItemKind.note, String body = '', String? url, String? folder, String? cover, DateTime? remind}) async {
    minute++;
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: id,
          kind: cover != null ? ItemKind.image : kind,
          title: title,
          body: Value(body.isEmpty ? title : body),
          url: Value(url),
          folderId: Value(folder),
          reminderAt: Value(remind),
          createdAt: now.subtract(Duration(minutes: 100 - minute)),
          updatedAt: now,
        ));
    if (cover != null) {
      await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'a$id', itemId: id, path: cover, mime: 'image/png', size: 1));
    }
  }

  await item('f1', 'Паста с тыквой', folder: 'food', cover: covers[0]);
  await item('f2', 'Сырники на рисовой муке', folder: 'food', cover: covers[1]);
  await item('f3', 'Том ям дома', folder: 'food', cover: covers[3]);
  await item('c1', 'Замена масла на 120 тысячах', folder: 'car');
  await item('c2', 'Летняя резина: Michelin', folder: 'car');
  await item('g1', 'Наушники с шумодавом', folder: 'gift');
  await item('w1', 'Виджет погоды для пары', folder: 'work', body: 'Виджет погоды для пары\nвидеть погоду у второй половинки');
  await item('r1', 'Зубной', remind: now.add(const Duration(hours: 3)));
  await item('r2', 'Позвонить маме', remind: now.add(const Duration(days: 1)));
  await item('l1', 'Как собрать стол из паллет', kind: ItemKind.video, url: 'https://www.youtube.com/watch?v=1');
  await item('l2', 'Подборка шрифтов для интерфейса', kind: ItemKind.link, url: 'https://fonts.google.com');
  await item('n1', 'Идея: Stowa понимает голосовые', body: 'Идея: Stowa понимает голосовые\nсказал в машине — легло в «Задачи»');

  final tags = [('рецепт', 'restaurant', 1), ('машина', 'directions_car', 2), ('идея', 'lightbulb', 3), ('фильм', 'movie', 4)];
  for (final (name, icon, order) in tags) {
    await db.into(db.tags).insert(TagsCompanion.insert(
          id: 't$order',
          name: name,
          createdAt: now,
          pinned: const Value(true),
          pinOrder: Value(order),
          iconValue: Value(icon),
        ));
  }
  for (final (itemId, tagId) in [('f1', 't1'), ('f2', 't1'), ('f3', 't1'), ('c1', 't2'), ('c2', 't2'), ('n1', 't3'), ('w1', 't3')]) {
    await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: itemId, tagId: tagId, source: TagSource.user));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  // картинки декодируются по-настоящему, им нужно реальное время
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  final context = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(() async {
    // загрузка, начатая в поддельном времени теста, не кончится: начинаем заново в настоящем
    imageCache.clear();
    for (final image in images) {
      await precacheImage(image.image, context).timeout(const Duration(seconds: 3), onTimeout: () => debugPrint('не дождался ${image.image}'));
    }
  });
  // декодер отвечает в настоящем времени, кадры просим между ожиданиями
  for (var round = 0; round < 6; round++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 100));
  }
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

  late TestWorld world;
  setUp(() => world = TestWorld(now: DateTime(2026, 11, 2, 10, 30)));
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: world.app()));
    await tester.pumpAndSettle();
  }

  testWidgets('пустая', (tester) async {
    await open(tester);
    await _shot(tester, '1-пустая');
  });

  testWidgets('с вещами', (tester) async {
    await tester.runAsync(() => _seed(world));
    await open(tester);
    await _shot(tester, '2-с-вещами');
  });

  testWidgets('пишу с датой и тегом', (tester) async {
    await tester.runAsync(() => _seed(world));
    await open(tester);
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'сходить к зубному #здоровье 23 декабря 13:00');
    await tester.pumpAndSettle();
    await _shot(tester, '3-пишу');
  });

  testWidgets('закинул', (tester) async {
    await tester.runAsync(() => _seed(world));
    await open(tester);
    await tester.enterText(find.byType(TextField), '23 декабря 13:00 зубной');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закинуть'));
    await tester.pumpAndSettle();
    await _shot(tester, '4-закинул');
  });

  testWidgets('крупный шрифт на узком', (tester) async {
    await tester.runAsync(() => _seed(world));
    tester.view.physicalSize = const Size(320, 700);
    await open(tester, textScale: 1.3);
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpAndSettle();
    await _shot(tester, '5-узкий');
  });
}
