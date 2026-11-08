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
import 'package:zxing2/qrcode.dart';

// QR на сером фоне посреди крупного снимка, как наклейка на роутере
Future<List<int>> _photoWithQr(String text) async {
  final code = Encoder.encode(text, ErrorCorrectionLevel.m).matrix!;
  const module = 14.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 2400, 1600), Paint()..color = const Color(0xFF8A8F96));
  final side = (code.width + 8) * module;
  canvas.drawRect(Rect.fromLTWH(900, 400, side, side), Paint()..color = const Color(0xFFFFFFFF));
  for (var y = 0; y < code.height; y++) {
    for (var x = 0; x < code.width; x++) {
      if (code.get(x, y) == 1) canvas.drawRect(Rect.fromLTWH(900 + (x + 4) * module, 400 + (y + 4) * module, module, module), Paint()..color = const Color(0xFF111111));
    }
  }
  final image = await recorder.endRecording().toImage(2400, 1600);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  // обычный test, не testWidgets: в поддельном времени база и декодер ждут друг друга вечно
  test('QR на большом фото находится, Wi-Fi помечен, текст кода ищется', () async {
    final db = AppDatabase.memory();
    final home = await Directory.systemTemp.createTemp('stowa_qr');
    addTearDown(() async {
      await db.close();
      await home.delete(recursive: true);
    });
    final now = DateTime(2026, 11, 8);
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'router', kind: ItemKind.image, title: 'Роутер', createdAt: now, updatedAt: now));
    final file = await File(p.join(home.path, 'Роутер', 'router.png')).create(recursive: true);
    await file.writeAsBytes(await _photoWithQr('WIFI:T:WPA;S:Dacha;P:sunflower42;;'));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'a', itemId: 'router', path: 'Роутер/router.png', mime: 'image/png', size: 1, width: const Value(2400), height: const Value(1600)));

    await FactsPipeline(db, filesRoot: home, clock: () => now, extractors: [QrExtractor()]).sweep().timeout(const Duration(seconds: 60));

    final qr = await (db.select(db.facts)..where((t) => t.kind.equals(FactKind.qr.name))).getSingle();
    expect((qr.value, qr.detail), ('WIFI:T:WPA;S:Dacha;P:sunflower42;;', 'wifi'));
    expect(await db.searchIds('sunflower42'), ['router']);
  });
}
