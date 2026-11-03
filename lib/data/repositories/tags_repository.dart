import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models.dart';
import '../../domain/tag_name.dart';
import '../db/database.dart';

/// Тег для экрана: плитка-иконка и число живых вещей, как метки в Telegram.
class TagCard {
  const TagCard({required this.id, required this.name, required this.iconKind, required this.iconValue, required this.count, this.pinned = false});

  final String id;
  final String name;
  final TagIconKind iconKind;
  final String iconValue;
  final int count;
  final bool pinned;
}

/// Снимок удалённого тега: «Вернуть» восстанавливает его у всех вещей и с правилами.
class DeletedTag {
  const DeletedTag({required this.tag, required this.links, required this.rules});

  final Tag tag;
  final List<ItemTag> links;
  final List<Rule> rules;
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

  /// Тег из листа «Новый тег». Такое имя уже есть — тот тег и правится.
  Future<Tag> create({required String name, required TagIconKind iconKind, required String iconValue, bool pinned = false}) async {
    final tag = await ensure(name);
    await update(tag.id, iconKind: iconKind, iconValue: iconValue, pinned: pinned);
    return (_db.select(_db.tags)..where((t) => t.id.equals(tag.id))).getSingle();
  }

  /// Правка тега. Новое имя уже занято — теги сливаются в тот, что был.
  Future<void> update(String id, {String? name, TagIconKind? iconKind, String? iconValue, bool? pinned}) async {
    await _db.transaction(() async {
      final tag = await (_db.select(_db.tags)..where((t) => t.id.equals(id))).getSingle();
      if (name != null) {
        final next = normalizeTagName(name);
        if (next.isNotEmpty && next != tag.name) {
          final other = await (_db.select(_db.tags)..where((t) => t.name.equals(next))).getSingleOrNull();
          if (other != null) {
            await merge(fromId: id, intoId: other.id);
            return;
          }
          await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(TagsCompanion(name: Value(next)));
          await _renameInRules(tag.name, next);
        }
      }
      var order = tag.pinOrder;
      if (pinned == true && !tag.pinned) {
        // новый закреплённый встаёт в конец строки
        final last = await _db.customSelect('SELECT COALESCE(MAX(pin_order), -1) AS last FROM tags WHERE pinned = 1').getSingle();
        order = last.read<int>('last') + 1;
      }
      await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(TagsCompanion(
            iconKind: iconKind == null ? const Value.absent() : Value(iconKind),
            iconValue: iconValue == null ? const Value.absent() : Value(iconValue),
            pinned: pinned == null ? const Value.absent() : Value(pinned),
            pinOrder: Value(order),
          ));
    });
  }

  /// Перенести вещи тега [fromId] в [intoId] и убрать первый.
  Future<void> merge({required String fromId, required String intoId}) async {
    await _db.transaction(() async {
      final from = await (_db.select(_db.tags)..where((t) => t.id.equals(fromId))).getSingle();
      final into = await (_db.select(_db.tags)..where((t) => t.id.equals(intoId))).getSingle();
      final links = await (_db.select(_db.itemTags)..where((t) => t.tagId.equals(fromId))).get();
      for (final link in links) {
        await _db.into(_db.itemTags).insert(ItemTagsCompanion.insert(itemId: link.itemId, tagId: intoId, source: link.source), mode: InsertMode.insertOrIgnore);
      }
      await (_db.delete(_db.itemTags)..where((t) => t.tagId.equals(fromId))).go();
      await (_db.delete(_db.tags)..where((t) => t.id.equals(fromId))).go();
      await _renameInRules(from.name, into.name);
    });
  }

  Future<void> _renameInRules(String from, String to) async {
    await (_db.update(_db.rules)..where((t) => t.conditionKind.equalsValue(RuleConditionKind.hasTag) & t.conditionValue.equals(from)))
        .write(RulesCompanion(conditionValue: Value(to)));
    await (_db.update(_db.rules)..where((t) => t.actionKind.equalsValue(RuleActionKind.addTag) & t.actionValue.equals(from)))
        .write(RulesCompanion(actionValue: Value(to)));
  }

  SimpleSelectStatement<$RulesTable, Rule> _rulesOf(String name) => _db.select(_db.rules)
    ..where(
      (t) =>
          (t.conditionKind.equalsValue(RuleConditionKind.hasTag) & t.conditionValue.equals(name)) |
          (t.actionKind.equalsValue(RuleActionKind.addTag) & t.actionValue.equals(name)),
    );

  /// Удалить тег у всех вещей вместе с его правилами. Снимок — для «Вернуть».
  Future<DeletedTag> delete(String id) {
    return _db.transaction(() async {
      final tag = await (_db.select(_db.tags)..where((t) => t.id.equals(id))).getSingle();
      final links = await (_db.select(_db.itemTags)..where((t) => t.tagId.equals(id))).get();
      final rules = await _rulesOf(tag.name).get();
      await (_db.delete(_db.rules)..where((t) => t.id.isIn([for (final rule in rules) rule.id]))).go();
      await (_db.delete(_db.itemTags)..where((t) => t.tagId.equals(id))).go();
      await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
      return DeletedTag(tag: tag, links: links, rules: rules);
    });
  }

  Future<void> restore(DeletedTag snapshot) {
    return _db.transaction(() async {
      await _db.into(_db.tags).insert(snapshot.tag, mode: InsertMode.insertOrIgnore);
      for (final link in snapshot.links) {
        await _db.into(_db.itemTags).insert(link, mode: InsertMode.insertOrIgnore);
      }
      for (final rule in snapshot.rules) {
        await _db.into(_db.rules).insert(rule, mode: InsertMode.insertOrIgnore);
      }
    });
  }

  /// Порядок закреплённых на главной.
  Future<void> reorderPinned(List<String> idsInOrder) {
    return _db.transaction(() async {
      for (final (index, id) in idsInOrder.indexed) {
        await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(TagsCompanion(pinOrder: Value(index)));
      }
    });
  }

  /// Снять тег с одной вещи: крестик на странице вещи.
  Future<void> unlink(String itemId, String name) async {
    final tag = await (_db.select(_db.tags)..where((t) => t.name.equals(normalizeTagName(name)))).getSingleOrNull();
    if (tag == null) return;
    await (_db.delete(_db.itemTags)..where((t) => t.itemId.equals(itemId) & t.tagId.equals(tag.id))).go();
  }

  /// Поставить тег одной вещи руками.
  Future<void> link(String itemId, String name) async {
    final tag = await ensure(name);
    await _db.into(_db.itemTags).insert(ItemTagsCompanion.insert(itemId: itemId, tagId: tag.id, source: TagSource.user), mode: InsertMode.insertOrIgnore);
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
                pinned: row.read<bool>('pinned'),
              ),
          ],
        );
  }
}
