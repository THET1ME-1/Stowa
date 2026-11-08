import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/facts/facts_pipeline.dart';
import 'package:stowa/services/facts/video_extractor.dart';
import 'package:stowa/services/media_probe.dart';

/// Проба без телефона: длина известна, кадр — файл с отметкой времени.
class _FakeProbe implements MediaProbe {
  _FakeProbe(this.length, {this.broken = false});

  final Duration? length;
  final bool broken;
  final asked = <Duration>[];

  @override
  Future<VideoInfo?> probe(String path) async => length == null ? null : VideoInfo(length: length!, width: 1080, height: 1920);

  @override
  Future<List<bool>> frames(String path, List<Duration> at, List<String> outs, {int maxSide = 720}) async {
    asked.addAll(at);
    return [
      for (final (index, out) in outs.indexed)
        if (broken)
          false
        else
          (File(out)..createSync(recursive: true)..writeAsStringSync('${at[index].inMilliseconds}')).existsSync(),
    ];
  }
}

void main() {
  late AppDatabase db;
  late Directory home;
  final now = DateTime(2026, 11, 8);

  setUp(() async {
    db = AppDatabase.memory();
    home = await Directory.systemTemp.createTemp('stowa_video');
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'v', kind: ItemKind.video, title: 'Отпуск', createdAt: now, updatedAt: now));
    await File(p.join(home.path, 'Отпуск', 'clip.mp4')).create(recursive: true);
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'a', itemId: 'v', path: 'Отпуск/clip.mp4', mime: 'video/mp4', size: 1));
  });
  tearDown(() async {
    await db.close();
    await home.delete(recursive: true);
  });

  Future<void> sweep(MediaProbe probe) => FactsPipeline(db, filesRoot: home, clock: () => now, extractors: [VideoExtractor(probe: probe)]).sweep();

  test('у своего ролика длина, обложка и шесть кадров по шкале', () async {
    final probe = _FakeProbe(const Duration(minutes: 2));
    await sweep(probe);
    final item = await (db.select(db.items)..where((t) => t.id.equals('v'))).getSingle();
    expect(item.durationSeconds, 120);
    expect(item.coverPath, '.stowa/covers/v.jpg');
    // обложка — кадр на десятой части длины
    expect(File(p.join(home.path, '.stowa', 'covers', 'v.jpg')).readAsStringSync(), '12000');

    final frames = await (db.select(db.facts)
          ..where((t) => t.kind.equals(FactKind.frame.name))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    expect(frames.map((fact) => fact.number), [10.0, 30.0, 50.0, 70.0, 90.0, 110.0]);
    expect(frames.first.value, '.stowa/frames/v/0.jpg');
    expect(File(p.join(home.path, frames.last.value)).existsSync(), isTrue);
  });

  test('своя обложка и известная длина не перезаписываются', () async {
    await (db.update(db.items)..where((t) => t.id.equals('v'))).write(const ItemsCompanion(coverPath: Value('Отпуск/свой.jpg'), durationSeconds: Value(118)));
    await sweep(_FakeProbe(const Duration(minutes: 2)));
    final item = await (db.select(db.items)..where((t) => t.id.equals('v'))).getSingle();
    expect((item.coverPath, item.durationSeconds), ('Отпуск/свой.jpg', 118));
  });

  test('система не прочитала ролик — без кадров и без ошибки; кадры не достались — длина всё равно есть', () async {
    await sweep(_FakeProbe(null));
    expect(await db.select(db.facts).get(), isEmpty);
    expect((await db.select(db.extractorRuns).getSingle()).error, isNull);

    await (db.delete(db.extractorRuns)).go();
    await sweep(_FakeProbe(const Duration(seconds: 30), broken: true));
    final item = await (db.select(db.items)..where((t) => t.id.equals('v'))).getSingle();
    expect((item.durationSeconds, item.coverPath), (30, null));
    expect(await db.select(db.facts).get(), isEmpty);
  });
}
