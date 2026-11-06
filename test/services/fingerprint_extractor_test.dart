import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/image_fingerprint.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/facts/extractors.dart';
import 'package:stowa/services/facts/facts_pipeline.dart';

// PNG с полосами: [flip] переворачивает их, [size] меняет размер — как пересжатая копия
Future<List<int>> _png({required int size, bool flip = false}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var band = 0; band < 6; band++) {
    final shade = flip ? 250 - band * 40 : band * 40 + 10;
    canvas.drawRect(Rect.fromLTWH(size * band / 6, 0, size / 6, size.toDouble()), Paint()..color = Color.fromARGB(255, shade, (shade * 2) % 256, 255 - shade));
  }
  canvas.drawCircle(Offset(size * 0.3, size * 0.6), size * 0.2, Paint()..color = const Color(0xFFFFFFFF));
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  // обычный test, не testWidgets: в поддельном времени запросы к базе и декодер ждут друг друга вечно
  test('у картинки появляется отпечаток; копия другого размера — рядом, другая картинка — далеко', () async {
    final db = AppDatabase.memory();
    final home = await Directory.systemTemp.createTemp('stowa_print');
    addTearDown(() async {
      await db.close();
      await home.delete(recursive: true);
    });
    final now = DateTime(2026, 11, 6);

    Future<void> picture(String id, List<int> bytes) async {
      await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.image, title: id, createdAt: now, updatedAt: now));
      final relative = p.join('attachments', id, '0_$id.png');
      await File(p.join(home.path, relative)).create(recursive: true).then((file) => file.writeAsBytes(bytes));
      await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: '$id-0', itemId: id, path: relative, mime: 'image/png', size: bytes.length, width: const Value(10), height: const Value(10)));
    }

    await picture('original', await _png(size: 600));
    await picture('copy', await _png(size: 240));
    await picture('other', await _png(size: 600, flip: true));
    await FactsPipeline(db, filesRoot: home, clock: () => now, extractors: [FingerprintExtractor()]).sweep().timeout(const Duration(seconds: 30));

    final prints = {
      for (final fact in await (db.select(db.facts)..where((t) => t.kind.equals(FactKind.fingerprint.name))).get()) fact.itemId: parseFingerprint(fact.value),
    };
    expect(prints.keys, unorderedEquals(['original', 'copy', 'other']));
    expect(fingerprintDistance(prints['original']!, prints['copy']!), lessThanOrEqualTo(repeatDistance));
    expect(fingerprintDistance(prints['original']!, prints['other']!), greaterThan(repeatDistance));
    // в поиск отпечаток не идёт
    expect((await db.select(db.items).get()).every((item) => item.factsText.isEmpty), isTrue);
  });
}
