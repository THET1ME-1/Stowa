import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/capture_service.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/data/repositories/rules_repository.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  // теги, папки и правила живут в настройках
  Future<void> openTags(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Теги, папки и правила'), 200);
    await tester.ensureVisible(find.text('Теги, папки и правила'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Теги, папки и правила'));
    await tester.pumpAndSettle();
  }

  // правила — своя вкладка: раньше они прятались под длинным списком тегов
  Future<void> openRules(WidgetTester tester) async {
    await openTags(tester);
    await tester.tap(find.text('Правила'));
    await tester.pumpAndSettle();
  }

  Future<void> newRule(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Новое правило'));
    await tester.pumpAndSettle();
  }

  // «Когда» и «Что сделать» — строки, которые открывают список с пояснениями
  Future<void> pick(WidgetTester tester, String step, String option) async {
    await tester.tap(find.byKey(ValueKey(step)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
  }

  // ключ стоит то на самом поле, то на поле тега с подсказками
  Finder field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField), matchRoot: true);

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('тег из листа: имя, иконка, папка, закрепить — встаёт на главную и раскладывает', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'film', name: 'Фильмы', icon: 'movie', shape: 'pill'));
    await open(tester);
    await openTags(tester);
    await tester.tap(find.byTooltip('Добавить тег'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Кино');
    await tester.pumpAndSettle();
    // папка — одной строкой, выбор тем же окном, что «Переложить»
    await tester.tap(find.byKey(const ValueKey('tag-folder')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Фильмы').last);
    await tester.pumpAndSettle();
    expect(find.text('Это правило: его видно и можно выключить во вкладке «Правила».'), findsOneWidget);
    await tester.tap(find.text('Закрепить на главной'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать тег'));
    await tester.pumpAndSettle();

    final tag = await world.db.select(world.db.tags).getSingle();
    expect((tag.name, tag.pinned), ('кино', true));
    expect(await RulesRepository(world.db).tagFolder('кино'), 'film');
    expect(find.text('#кино'), findsOneWidget);

    // правило работает при сохранении
    final capture = CaptureService(world.db, tags: TagsRepository(world.db), filesRoot: world.files, clock: () => world.now);
    final id = await capture.capture(const CaptureInput(text: 'Дюна, пересмотреть #кино'));
    final item = await (world.db.select(world.db.items)..where((t) => t.id.equals(id))).getSingle();
    expect(item.folderId, 'film');
  });

  testWidgets('правило из листа: ссылка на tiktok.com ставит тег #видео', (tester) async {
    await open(tester);
    await openRules(tester);
    await newRule(tester);
    await pick(tester, 'rule-when', 'Ссылка с сайта');
    await tester.enterText(field('rule-value'), 'tiktok.com');
    await pick(tester, 'rule-do', 'Поставить тег');
    await tester.enterText(field('rule-tag'), 'видео');
    await tester.pumpAndSettle();
    // фраза сверху говорит, что выйдет
    final preview = find.byKey(const ValueKey('rule-preview'));
    expect(find.descendant(of: preview, matching: find.text('Ссылка с сайта tiktok.com')), findsOneWidget);
    expect(find.descendant(of: preview, matching: find.text('поставить тег #видео')), findsOneWidget);
    await save(tester);

    final rule = await world.db.select(world.db.rules).getSingle();
    expect((rule.conditionKind, rule.conditionValue, rule.actionKind, rule.actionValue), (RuleConditionKind.domain, 'tiktok.com', RuleActionKind.addTag, 'видео'));
    // карточка правила словами; такой же «тег #видео» ниже у примера — смотрим в карточке
    final card = find.byKey(ValueKey('rule-${rule.id}'));
    expect(find.descendant(of: card, matching: find.text('Ссылка с сайта tiktok.com')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('поставить тег #видео')), findsOneWidget);
  });

  testWidgets('правило по фактам: «напомнить» только у события, сохраняется сроком в минутах', (tester) async {
    await open(tester);
    await openRules(tester);
    await newRule(tester);
    await pick(tester, 'rule-when', 'Тип страницы');
    await tester.tap(find.byKey(const ValueKey('rule-do')));
    await tester.pumpAndSettle();
    expect(find.text('Напомнить заранее'), findsNothing, reason: 'рецепт по умолчанию — у него нет начала');
    // «Положить в папку» есть и в строке шага под списком: касаемся строки списка
    await tester.tap(find.text('Положить в папку').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('событие'));
    await tester.pumpAndSettle();
    await pick(tester, 'rule-do', 'Напомнить заранее');
    await tester.tap(find.text('за неделю'));
    await tester.pumpAndSettle();
    await save(tester);

    final rule = await world.db.select(world.db.rules).getSingle();
    expect((rule.conditionKind, rule.conditionValue, rule.actionKind, rule.actionValue), (RuleConditionKind.pageType, 'event', RuleActionKind.remindBefore, '10080'));
    expect(find.text('напомнить за неделю'), findsOneWidget, reason: 'карточка правила на экране');
  });

  testWidgets('правило «цена больше 1000» сохраняется числом', (tester) async {
    await open(tester);
    await openRules(tester);
    await newRule(tester);
    await pick(tester, 'rule-when', 'Цена больше');
    await tester.enterText(field('rule-value'), '1 000');
    await pick(tester, 'rule-do', 'Поставить тег');
    await tester.enterText(field('rule-tag'), 'дорого');
    await tester.pumpAndSettle();
    await save(tester);

    final rule = await world.db.select(world.db.rules).getSingle();
    expect((rule.conditionKind, rule.conditionValue, rule.actionValue), (RuleConditionKind.priceAbove, '1000', 'дорого'));
    expect(find.text('Цена больше 1000'), findsOneWidget);
  });

  testWidgets('правило в новую папку, когда папок ещё нет', (tester) async {
    await open(tester);
    await openRules(tester);
    await newRule(tester);
    await pick(tester, 'rule-when', 'Слово в тексте');
    await tester.enterText(field('rule-value'), 'рецепт');
    expect(find.byKey(const ValueKey('rule-save')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('rule-save'))).onPressed, isNull, reason: 'папка ещё не выбрана');
    await tester.tap(find.byKey(const ValueKey('rule-folder')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Новая папка'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'кухня');
    await tester.tap(find.text('Сохранить').last);
    await tester.pumpAndSettle();
    await save(tester);

    final folder = await world.db.select(world.db.folders).getSingle();
    final rule = await world.db.select(world.db.rules).getSingle();
    expect((folder.name, rule.actionKind, rule.actionValue), ('Кухня', RuleActionKind.toFolder, folder.id));
    expect(find.text('в папку «Кухня»'), findsOneWidget);
  });

  testWidgets('выключатель на карточке правила выключает его без листа', (tester) async {
    await RulesRepository(world.db).save(condition: RuleConditionKind.domain, conditionValue: 'tiktok.com', action: RuleActionKind.addTag, actionValue: 'видео');
    await open(tester);
    await openRules(tester);
    final card = find.ancestor(of: find.text('Ссылка с сайта tiktok.com'), matching: find.byWidgetPredicate((widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('rule-')));
    await tester.tap(find.descendant(of: card, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.rules).getSingle()).enabled, isFalse);
    expect(find.byKey(const ValueKey('rule-sheet')), findsNothing, reason: 'лист не открылся');
  });

  testWidgets('пример правила: касание открывает лист уже заполненным, сохраняется сразу', (tester) async {
    await open(tester);
    await openRules(tester);
    expect(find.text('Правил пока нет: начни с примера ниже.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ссылка с сайта youtube.com'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Ссылка с сайта youtube.com'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('rule-preview')), matching: find.text('поставить тег #видео')), findsOneWidget);
    await save(tester);

    final rule = await world.db.select(world.db.rules).getSingle();
    expect((rule.conditionKind, rule.conditionValue, rule.actionKind, rule.actionValue), (RuleConditionKind.domain, 'youtube.com', RuleActionKind.addTag, 'видео'));
    expect(find.byKey(const ValueKey('rule-example-domain')), findsNothing, reason: 'заведённый пример не повторяется');
  });

  testWidgets('с клавиатурой «Сохранить правило» видна без прокрутки', (tester) async {
    await open(tester);
    await openRules(tester);
    await newRule(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(field('rule-value'), 'работа');
    await tester.pumpAndSettle();
    final button = tester.getRect(find.byKey(const ValueKey('rule-save')));
    expect(button.bottom, lessThanOrEqualTo(880 - 320), reason: 'кнопка над клавиатурой');
    expect(find.byKey(const ValueKey('rule-save')).hitTestable(), findsOneWidget);
  });

  testWidgets('свайп удаляет тег: пустой сразу, с вещами — после вопроса; «Вернуть» возвращает', (tester) async {
    final tags = TagsRepository(world.db, clock: () => world.now);
    await tags.ensure('пусто');
    final capture = CaptureService(world.db, tags: tags, filesRoot: world.files, clock: () => world.now);
    await capture.capture(const CaptureInput(text: 'Шины на зиму #машина'));
    await open(tester);
    await openTags(tester);

    await tester.drag(find.text('#пусто'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('Убрать тег'), findsNothing);
    expect(find.text('#пусто'), findsNothing);

    await tester.drag(find.text('#машина'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('Убрать тег #машина'), findsOneWidget);
    await tester.tap(find.text('Удалить тег'));
    await tester.pumpAndSettle();
    expect(find.text('#машина'), findsNothing);

    await tester.tap(find.text('Вернуть'));
    await tester.pumpAndSettle();
    expect(find.text('#машина'), findsOneWidget);
  });

  testWidgets('поле тега в правиле подсказывает существующие теги, служебный «конфликт» — нет', (tester) async {
    final tags = TagsRepository(world.db, clock: () => world.now);
    await tags.ensure('машина');
    await tags.ensure('рецепт');
    await tags.ensure('конфликт');
    await open(tester);
    await openRules(tester);
    await newRule(tester);

    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text('#конфликт')), findsNothing);
    await tester.enterText(field('rule-value'), 'ма');
    await tester.pumpAndSettle();
    expect(find.descendant(of: sheet, matching: find.text('#машина')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('#рецепт')), findsNothing);
    await tester.tap(find.descendant(of: sheet, matching: find.text('#машина')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('rule-value')).controller!.text, 'машина');
    expect(find.descendant(of: find.byKey(const ValueKey('rule-preview')), matching: find.text('Есть тег #машина')), findsOneWidget);
  });

  testWidgets('удалил правило — «Вернуть» возвращает его как было', (tester) async {
    await RulesRepository(world.db).save(condition: RuleConditionKind.domain, conditionValue: 'tiktok.com', action: RuleActionKind.addTag, actionValue: 'видео');
    await open(tester);
    await openRules(tester);
    await tester.tap(find.text('Ссылка с сайта tiktok.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Удалить правило'));
    await tester.pumpAndSettle();
    expect(await world.db.select(world.db.rules).get(), isEmpty);

    await tester.tap(find.text('Вернуть'));
    await tester.pumpAndSettle();
    final rule = await world.db.select(world.db.rules).getSingle();
    expect((rule.conditionValue, rule.actionValue), ('tiktok.com', 'видео'));
  });

  testWidgets('крестик снимает тег только у этой вещи', (tester) async {
    final capture = CaptureService(world.db, tags: TagsRepository(world.db), filesRoot: world.files, clock: () => world.now);
    final id = await capture.capture(const CaptureInput(text: 'Шины на зиму #машина #шины'));
    await world.db.update(world.db.items).write(const ItemsCompanion(sortState: Value(SortState.sorted)));
    await open(tester);
    await tester.tap(find.text('Шины на зиму'));
    await tester.pumpAndSettle();
    expect(find.text('#машина'), findsOneWidget);
    // в просмотре тег только называется, крестик у него появляется в правке
    expect(find.byTooltip('Убрать'), findsNothing);
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    await tester.tap(find.ancestor(of: find.text('#машина'), matching: find.byTooltip('Убрать')));
    await tester.pumpAndSettle();
    expect(find.text('#машина'), findsNothing);
    expect(find.text('#шины'), findsOneWidget);
    expect(id, isNotEmpty);
  });
}
