import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/facts/extractors.dart';
import 'package:stowa/services/facts/facts_pipeline.dart';

// синий фон и белый круг на четверть площади
Future<List<int>> _png(Color background, Color spot) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 200, 200), Paint()..color = background);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint()..color = spot);
  final image = await recorder.endRecording().toImage(200, 200);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  // обычный test, не testWidgets: в поддельном времени база и декодер ждут друг друга вечно
  test('главные цвета картинки и обложки ссылки; в текст для поиска не идут', () async {
    final db = AppDatabase.memory();
    final home = await Directory.systemTemp.createTemp('stowa_colors');
    addTearDown(() async {
      await db.close();
      await home.delete(recursive: true);
    });
    final now = DateTime(2026, 11, 8);

    await db.into(db.items).insert(ItemsCompanion.insert(id: 'photo', kind: ItemKind.image, title: 'Море', createdAt: now, updatedAt: now));
    final photo = await File(p.join(home.path, 'Море', 'sea.png')).create(recursive: true);
    await photo.writeAsBytes(await _png(const Color(0xFF1E3CC8), const Color(0xFFFAFAFA)));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'a', itemId: 'photo', path: 'Море/sea.png', mime: 'image/png', size: 1));

    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'link', kind: ItemKind.link, title: 'Книга', url: const Value('https://books.example/1'), coverPath: const Value('.stowa/covers/link.png'), previewAt: Value(now), createdAt: now, updatedAt: now),
    );
    final cover = await File(p.join(home.path, '.stowa', 'covers', 'link.png')).create(recursive: true);
    await cover.writeAsBytes(await _png(const Color(0xFFDC1E1E), const Color(0xFF0F0F0F)));

    await FactsPipeline(db, filesRoot: home, clock: () => now, extractors: [ColorsExtractor()]).sweep().timeout(const Duration(seconds: 30));

    Future<List<String>> colorsOf(String id) async {
      final query = db.select(db.facts)
        ..where((t) => t.itemId.equals(id) & t.kind.equals(FactKind.color.name))
        ..orderBy([(t) => OrderingTerm.asc(t.position)]);
      return [for (final fact in await query.get()) fact.value];
    }

    expect(await colorsOf('photo'), ['blue', 'white']);
    expect(await colorsOf('link'), ['red', 'black']);
    final blue = await (db.select(db.facts)..where((t) => t.itemId.equals('photo') & t.value.equals('blue'))).getSingle();
    expect(blue.number, closeTo(0.75, 0.05));
    expect(blue.detail, startsWith('#'));
    expect((await db.select(db.items).get()).every((item) => item.factsText.isEmpty), isTrue);
  });
}
