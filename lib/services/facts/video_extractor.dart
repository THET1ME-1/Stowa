import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../data/db/database.dart';
import '../../domain/models.dart';
import '../media_probe.dart';
import '../vault/vault_layout.dart' show coverFile, framesDir;
import 'extractor.dart';

/// Свой ролик: длина, обложка — кадр на десятой части длины — и шесть кадров по шкале.
/// Кадры достаёт система, канал есть только в окнах приложения: в фоновом движке
/// этого правила нет вовсе, ролик разберётся при открытии.
class VideoExtractor extends Extractor {
  VideoExtractor({required MediaProbe probe}) : _probe = probe; // ignore: prefer_initializing_formals

  final MediaProbe _probe;

  /// Что узнал [extract] для [after]: длина и записалась ли обложка.
  final _found = <String, ({Duration length, String? cover})>{};

  static const _frames = 6;

  @override
  String get name => 'video';
  @override
  int get version => 1;
  @override
  String get stampSql => "coalesce((SELECT group_concat(attachments.id) FROM attachments WHERE attachments.item_id = items.id), '')";
  @override
  String get appliesSql => "EXISTS (SELECT 1 FROM attachments WHERE attachments.item_id = items.id AND attachments.mime LIKE 'video/%')";

  @override
  Future<List<FactDraft>> extract(ExtractInput input) async {
    final video = input.files.where((file) => file.mime.startsWith('video/')).firstOrNull;
    if (video == null) return const [];
    final path = input.fileOf(video).path;
    final info = await _probe.probe(path);
    if (info == null || info.length <= Duration.zero) return const [];

    final id = input.item.id;
    final cover = coverFile(id, 'jpg');
    final moments = [for (var index = 0; index < _frames; index++) info.length * ((index + 0.5) / _frames)];
    final relative = [for (var index = 0; index < _frames; index++) '${framesDir(id)}/$index.jpg'];
    final written = await _probe.frames(
      path,
      [info.length * 0.1, ...moments],
      [for (final one in [cover, ...relative]) p.joinAll([input.filesRoot.path, ...one.split('/')])],
    );
    _found[id] = (length: info.length, cover: written.firstOrNull == true ? cover : null);
    return [
      for (var index = 0; index < _frames; index++)
        if (written.length > index + 1 && written[index + 1]) FactDraft(FactKind.frame, relative[index], number: moments[index].inMilliseconds / 1000),
    ];
  }

  /// Длина и обложка — в саму заметку, если их там ещё нет: своё не перезаписывается.
  @override
  Future<void> after(AppDatabase db, Item item, List<FactDraft> facts, {required bool firstRun, required DateTime now}) async {
    final found = _found.remove(item.id);
    if (found == null) return;
    await (db.update(db.items)..where((t) => t.id.equals(item.id))).write(
      ItemsCompanion(
        durationSeconds: item.durationSeconds == null ? Value(found.length.inSeconds) : const Value.absent(),
        coverPath: item.coverPath == null && found.cover != null ? Value(found.cover) : const Value.absent(),
      ),
    );
  }
}
