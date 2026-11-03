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

  testWidgets('тег из листа: имя, иконка, папка, закрепить — встаёт на главную и раскладывает', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'film', name: 'Фильмы', icon: 'movie', shape: 'pill'));
    await open(tester);
    await tester.tap(find.byTooltip('Теги, папки и правила'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Добавить тег'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Кино');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Фильмы').last, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Фильмы').last);
    await tester.tap(find.text('Закрепить на главной'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать тег'));
    await tester.pumpAndSettle();

    final tag = await world.db.select(world.db.tags).getSingle();
    expect((tag.name, tag.pinned), ('кино', true));
    expect(await RulesRepository(world.db).tagFolder('кино'), 'film');
    expect(find.text('кино'), findsWidgets);

    // правило работает при сохранении
    final capture = CaptureService(world.db, tags: TagsRepository(world.db), filesRoot: world.files, clock: () => world.now);
    final id = await capture.capture(const CaptureInput(text: 'Дюна, пересмотреть #кино'));
    final item = await (world.db.select(world.db.items)..where((t) => t.id.equals(id))).getSingle();
    expect(item.folderId, 'film');
  });

  testWidgets('правило из листа: ссылка на tiktok.com ставит тег #видео', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Теги, папки и правила'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Новое правило'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Новое правило'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ссылка на сайт'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'tiktok.com');
    await tester.tap(find.text('поставить тег'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'видео');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final rule = await world.db.select(world.db.rules).getSingle();
    expect((rule.conditionKind, rule.conditionValue, rule.actionKind, rule.actionValue), (RuleConditionKind.domain, 'tiktok.com', RuleActionKind.addTag, 'видео'));
    expect(find.text('tiktok.com'), findsOneWidget);
  });

  testWidgets('крестик снимает тег только у этой вещи', (tester) async {
    final capture = CaptureService(world.db, tags: TagsRepository(world.db), filesRoot: world.files, clock: () => world.now);
    final id = await capture.capture(const CaptureInput(text: 'Шины на зиму #машина #шины'));
    await world.db.update(world.db.items).write(const ItemsCompanion(sortState: Value(SortState.sorted)));
    await open(tester);
    await tester.tap(find.text('Шины на зиму'));
    await tester.pumpAndSettle();
    expect(find.text('#машина'), findsOneWidget);
    await tester.tap(find.descendant(of: find.ancestor(of: find.text('#машина'), matching: find.byType(Row)).first, matching: find.byTooltip('Убрать')));
    await tester.pumpAndSettle();
    expect(find.text('#машина'), findsNothing);
    expect(find.text('#шины'), findsOneWidget);
    expect(id, isNotEmpty);
  });
}
