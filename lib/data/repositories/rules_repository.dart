import 'package:drift/drift.dart';

import '../../domain/sort_rules.dart';
import '../db/database.dart';

SortRule sortRuleFrom(Rule row) => SortRule(
      id: row.id,
      condition: row.conditionKind,
      conditionValue: row.conditionValue,
      action: row.actionKind,
      actionValue: row.actionValue,
    );

class RulesRepository {
  RulesRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$RulesTable, Rule> _enabled() => _db.select(_db.rules)
    ..where((t) => t.enabled.equals(true))
    ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);

  /// Включённые правила по порядку.
  Future<List<SortRule>> enabled() async => [for (final row in await _enabled().get()) sortRuleFrom(row)];

  Stream<List<SortRule>> watchEnabled() => _enabled().watch().map((rows) => [for (final row in rows) sortRuleFrom(row)]);
}
