import 'package:drift/drift.dart';

import '../data/db/database.dart';
import '../data/repositories/tags_repository.dart';
import '../domain/models.dart';

/// Правила, которые видят факты: «рецепт → в „Рецепты“», «цена > 1000 → #дорого»,
/// «событие → напомнить за день». Факты появляются после разбора, поэтому такие
/// правила срабатывают здесь, а не при сохранении. Каждое — один раз на заметку:
/// что человек потом поменял руками, правило не вернёт ([RuleHits]).
class FactRules {
  FactRules(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Папку правило по фактам меняет, только если её не выбирал человек и не правило при сохранении.
  static const _movable = {SortedBy.none, SortedBy.similar, SortedBy.ai};

  /// Применить правила по фактам к заметке. Зовёт конвейер, когда факты заметки записаны.
  Future<void> apply(String itemId) async {
    final rules = await (_db.select(_db.rules)
          ..where((t) => t.enabled.equals(true) & t.conditionKind.isIn([for (final kind in RuleConditionKind.values) if (isFactCondition(kind)) kind.name]))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    if (rules.isEmpty) return;
    final hit = {for (final row in await (_db.select(_db.ruleHits)..where((t) => t.itemId.equals(itemId))).get()) row.ruleId};
    final facts = await (_db.select(_db.facts)..where((t) => t.itemId.equals(itemId))).get();
    for (final rule in rules) {
      if (hit.contains(rule.id) || !_matches(rule, facts)) continue;
      final item = await (_db.select(_db.items)..where((t) => t.id.equals(itemId) & t.deletedAt.isNull())).getSingleOrNull();
      if (item == null) return;
      if (await _act(rule, item, facts)) {
        await _db.into(_db.ruleHits).insert(RuleHitsCompanion.insert(itemId: itemId, ruleId: rule.id), mode: InsertMode.insertOrIgnore);
      }
    }
  }

  bool _matches(Rule rule, List<Fact> facts) {
    final limit = double.tryParse(rule.conditionValue);
    final prices = [for (final fact in facts) if (fact.kind == FactKind.price && fact.number != null) fact.number!];
    return switch (rule.conditionKind) {
      RuleConditionKind.pageType => facts.any((fact) => fact.kind == FactKind.pageType && fact.detail == rule.conditionValue),
      RuleConditionKind.priceAbove => limit != null && prices.any((price) => price > limit),
      RuleConditionKind.priceBelow => limit != null && prices.any((price) => price < limit),
      _ => false,
    };
  }

  // сделано ли действие: несделанное (человек уже разложил, событие прошло) попробуется при следующем разборе
  Future<bool> _act(Rule rule, Item item, List<Fact> facts) async {
    switch (rule.actionKind) {
      case RuleActionKind.toFolder:
        if (!_movable.contains(item.sortedBy)) return false;
        final folder = await (_db.select(_db.folders)..where((t) => t.id.equals(rule.actionValue) & t.deletedAt.isNull())).getSingleOrNull();
        if (folder == null) return false;
        await (_db.update(_db.items)..where((t) => t.id.equals(item.id))).write(
          ItemsCompanion(folderId: Value(folder.id), sortedBy: const Value(SortedBy.rule), sortState: const Value(SortState.sorted)),
        );
        return true;
      case RuleActionKind.addTag:
        final tag = await TagsRepository(_db).ensure(rule.actionValue);
        await _db.into(_db.itemTags).insert(ItemTagsCompanion.insert(itemId: item.id, tagId: tag.id, source: TagSource.rule), mode: InsertMode.insertOrIgnore);
        return true;
      case RuleActionKind.remindBefore:
        if (item.reminderAt != null) return false;
        final start = facts.where((fact) => fact.kind == FactKind.eventStart).map((fact) => fact.at).nonNulls.firstOrNull;
        final minutes = int.tryParse(rule.actionValue);
        if (start == null || minutes == null) return false;
        final at = start.subtract(Duration(minutes: minutes));
        if (!at.isAfter(_clock())) return false;
        await (_db.update(_db.items)..where((t) => t.id.equals(item.id))).write(ItemsCompanion(reminderAt: Value(at)));
        return true;
    }
  }
}
