import 'line_query.dart';
import 'models.dart';
import 'tag_name.dart';

/// Правило «если X, то Y» без сети.
class SortRule {
  const SortRule({required this.id, required this.condition, required this.conditionValue, required this.action, required this.actionValue});

  final String id;
  final RuleConditionKind condition;
  final String conditionValue;
  final RuleActionKind action;
  final String actionValue;
}

class RuleOutcome {
  const RuleOutcome({this.folderId, this.folderRule, this.tags = const []});

  final String? folderId;

  /// Правило, которое выбрало папку: строка ввода показывает его причиной.
  final SortRule? folderRule;

  /// Теги, которые поставили правила, без тех, что уже были.
  final List<String> tags;
}

bool _matches(SortRule rule, {required List<String> words, required List<String> tags, String? host, required ItemKind kind}) {
  final value = rule.conditionValue;
  return switch (rule.condition) {
    RuleConditionKind.hasTag => tags.contains(normalizeTagName(value)),
    RuleConditionKind.domain => host != null && (host == value || host.endsWith('.$value')),
    RuleConditionKind.keyword => words.any((word) => word.startsWith(stem(normalizeQuery(value)))),
    RuleConditionKind.kind => kind.name == value,
  };
}

/// Один проход: сначала правила тегов, потом правила папок с уже добавленными тегами.
/// Порядок правил задан списком.
RuleOutcome applyRules(List<SortRule> rules, {required String text, required List<String> tags, String? host, required ItemKind kind}) {
  final words = searchWords(text);
  final all = [...tags];
  final added = <String>[];
  for (final rule in rules.where((rule) => rule.action == RuleActionKind.addTag)) {
    if (!_matches(rule, words: words, tags: all, host: host, kind: kind)) continue;
    final tag = normalizeTagName(rule.actionValue);
    if (tag.isEmpty || all.contains(tag)) continue;
    all.add(tag);
    added.add(tag);
  }
  for (final rule in rules.where((rule) => rule.action == RuleActionKind.toFolder)) {
    if (_matches(rule, words: words, tags: all, host: host, kind: kind)) {
      return RuleOutcome(folderId: rule.actionValue, folderRule: rule, tags: added);
    }
  }
  return RuleOutcome(tags: added);
}
