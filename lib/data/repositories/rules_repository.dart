import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models.dart';
import '../../domain/sort_rules.dart';
import '../../domain/tag_name.dart';
import '../db/database.dart';

SortRule sortRuleFrom(Rule row) =>
    SortRule(id: row.id, condition: row.conditionKind, conditionValue: row.conditionValue, action: row.actionKind, actionValue: row.actionValue);

class RulesRepository {
  RulesRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$RulesTable, Rule> _enabled() => _db.select(_db.rules)
    ..where((t) => t.enabled.equals(true))
    ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);

  /// Включённые правила по порядку.
  Future<List<SortRule>> enabled() async => [for (final row in await _enabled().get()) sortRuleFrom(row)];

  Stream<List<SortRule>> watchEnabled() => _enabled().watch().map((rows) => [for (final row in rows) sortRuleFrom(row)]);

  /// Все правила с выключенными, для экрана правил.
  Stream<List<Rule>> watchAll() => (_db.select(_db.rules)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();

  /// Новое правило или правка старого по [id]. Новое встаёт в конец.
  Future<String> save({
    String? id,
    required RuleConditionKind condition,
    required String conditionValue,
    required RuleActionKind action,
    required String actionValue,
    bool enabled = true,
  }) async {
    final tagLike = condition == RuleConditionKind.hasTag;
    final value = tagLike ? normalizeTagName(conditionValue) : conditionValue.trim().toLowerCase();
    final target = action == RuleActionKind.addTag ? normalizeTagName(actionValue) : actionValue;
    if (id != null) {
      await (_db.update(_db.rules)..where((t) => t.id.equals(id))).write(RulesCompanion(
            conditionKind: Value(condition),
            conditionValue: Value(value),
            actionKind: Value(action),
            actionValue: Value(target),
            enabled: Value(enabled),
          ));
      return id;
    }
    final newId = const Uuid().v4();
    final order = await _db.rules.count().getSingle();
    await _db.into(_db.rules).insert(RulesCompanion.insert(
          id: newId,
          conditionKind: condition,
          conditionValue: value,
          actionKind: action,
          actionValue: target,
          enabled: Value(enabled),
          sortOrder: Value(order),
        ));
    return newId;
  }

  Future<void> setEnabled(String id, bool enabled) =>
      (_db.update(_db.rules)..where((t) => t.id.equals(id))).write(RulesCompanion(enabled: Value(enabled)));

  Future<void> remove(String id) => (_db.delete(_db.rules)..where((t) => t.id.equals(id))).go();

  SimpleSelectStatement<$RulesTable, Rule> _tagFolderRules(String tagName) => _db.select(_db.rules)
    ..where((t) => t.conditionKind.equalsValue(RuleConditionKind.hasTag) & t.conditionValue.equals(normalizeTagName(tagName)) & t.actionKind.equalsValue(RuleActionKind.toFolder));

  /// Папка, в которую кладёт тег, если есть такое правило.
  Future<String?> tagFolder(String tagName) async => (await _tagFolderRules(tagName).get()).firstOrNull?.actionValue;

  /// «Класть в папку» из листа тега: одно правило на тег, null — правило снимается.
  Future<void> setTagFolder(String tagName, String? folderId) async {
    final existing = await _tagFolderRules(tagName).get();
    if (folderId == null) {
      for (final rule in existing) {
        await remove(rule.id);
      }
      return;
    }
    if (existing.isEmpty) {
      await save(condition: RuleConditionKind.hasTag, conditionValue: tagName, action: RuleActionKind.toFolder, actionValue: folderId);
      return;
    }
    await (_db.update(_db.rules)..where((t) => t.id.equals(existing.first.id))).write(RulesCompanion(actionValue: Value(folderId), enabled: const Value(true)));
    for (final extra in existing.skip(1)) {
      await remove(extra.id);
    }
  }
}
