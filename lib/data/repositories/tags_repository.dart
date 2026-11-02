import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models.dart';
import '../../domain/tag_name.dart';
import '../db/database.dart';

/// Тег для экрана: плитка-иконка и число живых вещей, как метки в Telegram.
class TagCard {
  const TagCard({required this.id, required this.name, required this.iconKind, required this.iconValue, required this.count});

  final String id;
  final String name;
  final TagIconKind iconKind;
  final String iconValue;
  final int count;
}

// тег и сколько у него живых вещей
const _tagSelect = '''
SELECT tags.*, (SELECT COUNT(*) FROM item_tags JOIN items ON items.id = item_tags.item_id
  WHERE item_tags.tag_id = tags.id AND items.deleted_at IS NULL) AS item_count
FROM tags''';

class TagsRepository {
  TagsRepository(this._db, {Uuid? uuid, DateTime Function()? clock}) : _uuid = uuid ?? const Uuid(), _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Тег по имени: находит или заводит. Имя приводится к одному виду.
  Future<Tag> ensure(String rawName) async {
    final name = normalizeTagName(rawName);
    if (name.isEmpty) throw ArgumentError.value(rawName, 'rawName', 'пустое имя тега');
    final existing = await (_db.select(_db.tags)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing;
    await _db
        .into(_db.tags)
        .insert(
          TagsCompanion.insert(id: _uuid.v4(), name: name, createdAt: _clock()),
          mode: InsertMode.insertOrIgnore,
        );
    return (_db.select(_db.tags)..where((t) => t.name.equals(name))).getSingle();
  }

  /// Закреплённые теги по порядку, число — только живые вещи.
  Stream<List<TagCard>> watchPinned() => _watch('$_tagSelect WHERE tags.pinned = 1 ORDER BY tags.pin_order, tags.name');

  /// Все теги, частые первыми: подсказки после `#`.
  Stream<List<TagCard>> watchAll() => _watch('$_tagSelect ORDER BY item_count DESC, tags.name');

  Stream<List<TagCard>> _watch(String sql) {
    return _db
        .customSelect(sql, readsFrom: {_db.tags, _db.itemTags, _db.items})
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              TagCard(
                id: row.read<String>('id'),
                name: row.read<String>('name'),
                iconKind: TagIconKind.values.byName(row.read<String>('icon_kind')),
                iconValue: row.read<String>('icon_value'),
                count: row.read<int>('item_count'),
              ),
          ],
        );
  }
}
