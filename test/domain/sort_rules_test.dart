import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/sort_rules.dart';

SortRule _rule(RuleConditionKind condition, String value, RuleActionKind action, String target) =>
    SortRule(id: '$condition$value', condition: condition, conditionValue: value, action: action, actionValue: target);

void main() {
  final rules = [
    _rule(RuleConditionKind.hasTag, 'машина', RuleActionKind.toFolder, 'car'),
    _rule(RuleConditionKind.keyword, 'шиномонтаж', RuleActionKind.addTag, 'машина'),
    _rule(RuleConditionKind.domain, 'tiktok.com', RuleActionKind.addTag, 'видео'),
    _rule(RuleConditionKind.keyword, 'рецепт', RuleActionKind.toFolder, 'food'),
    _rule(RuleConditionKind.kind, 'image', RuleActionKind.toFolder, 'refs'),
  ];

  test('слово ставит тег, а тег кладёт в папку за один проход', () {
    final outcome = applyRules(rules, text: 'записаться на шиномонтаж завтра', tags: const [], kind: ItemKind.note);
    expect(outcome.tags, ['машина']);
    expect(outcome.folderId, 'car');
    expect(outcome.folderRule!.condition, RuleConditionKind.hasTag);
  });

  test('слово ловится в любой форме', () {
    expect(applyRules(rules, text: 'два рецепта пасты', tags: const [], kind: ItemKind.note).folderId, 'food');
  });

  test('домен ссылки ставит тег, поддомены тоже', () {
    final outcome = applyRules(rules, text: '', tags: const [], host: 'vt.tiktok.com', kind: ItemKind.video);
    expect(outcome.tags, ['видео']);
    expect(outcome.folderId, isNull);
  });

  test('вид вещи кладёт в папку', () {
    expect(applyRules(rules, text: '', tags: const [], kind: ItemKind.image).folderId, 'refs');
  });

  test('ничего не подошло — папки нет', () {
    final outcome = applyRules(rules, text: 'просто мысль', tags: const [], kind: ItemKind.note);
    expect(outcome.folderId, isNull);
    expect(outcome.tags, isEmpty);
  });
}
