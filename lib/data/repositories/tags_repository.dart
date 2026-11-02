import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/tag_name.dart';
import '../db/database.dart';

class TagsRepository {
  TagsRepository(this._db, {Uuid? uuid, DateTime Function()? clock})
      : _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Тег по имени: находит или заводит. Имя приводится к одному виду.
  Future<Tag> ensure(String rawName) async {
    final name = normalizeTagName(rawName);
    if (name.isEmpty) throw ArgumentError.value(rawName, 'rawName', 'пустое имя тега');
    final existing = await (_db.select(_db.tags)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing;
    await _db.into(_db.tags).insert(
          TagsCompanion.insert(id: _uuid.v4(), name: name, createdAt: _clock()),
          mode: InsertMode.insertOrIgnore,
        );
    return (_db.select(_db.tags)..where((t) => t.name.equals(name))).getSingle();
  }
}
