import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/smart_folders_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_panel.dart';
import 'package:stowa/features/home/folder_shelf.dart';
import 'package:stowa/features/smart/smart_folder_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> note(String id, String title, {ItemKind kind = ItemKind.note, String? url, int daysAgo = 1}) async {
    final at = world.now.subtract(Duration(days: daysAgo));
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: id,
          kind: kind,
          title: title,
          body: Value(url ?? title),
          url: Value(url),
          sortState: const Value(SortState.sorted),
          createdAt: at,
          updatedAt: at,
        ));
  }

  Future<void> open(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  Finder pill(String name) => find.descendant(of: find.byType(FolderShelf), matching: find.text(name));

  testWidgets('умная папка на главной: экран показывает найденное по запросу, а не всё подряд', (tester) async {
    await note('v', 'Тарт с малиной', kind: ItemKind.video, url: 'https://www.tiktok.com/@chef/1');
    await note('n', 'Купить малину');
    await SmartFoldersRepository(world.db, clock: () => world.now).create(name: 'Ролики', query: 'видео');
    await open(tester);

    await tester.tap(pill('Ролики'));
    await tester.pumpAndSettle();
    expect(find.byType(SmartFolderScreen), findsOneWidget);
    expect(find.text('видео'), findsOneWidget, reason: 'под именем — сам запрос');
    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('Купить малину'), findsNothing);
  });

  testWidgets('умная папка трат показывает итог, как экран папки', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'repair', name: 'Ремонт', icon: 'build', shape: 'squircle'));
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'p',
          kind: ItemKind.note,
          title: 'Штукатурка 4 200 лей',
          folderId: const Value('repair'),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    await world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'p-1', itemId: 'p', extractor: 'text', kind: FactKind.price, value: '4 200 лей', number: const Value(4200), detail: const Value('MDL')));
    await SmartFoldersRepository(world.db, clock: () => world.now).create(name: 'Ремонт: траты', query: 'потратил на ремонт');
    await open(tester);
    await tester.tap(pill('Ремонт: траты'));
    await tester.pumpAndSettle();
    final total = find.byKey(const ValueKey('smart-total'));
    expect(tester.widget<Text>(find.descendant(of: total, matching: find.byType(Text))).data!.replaceAll(' ', ' '), 'Всего 4 200 лей');
  });

  testWidgets('удалить из меню — с «Отменить»', (tester) async {
    await SmartFoldersRepository(world.db, clock: () => world.now).create(name: 'Ролики', query: 'видео');
    await open(tester);
    await tester.tap(pill('Ролики'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить умную папку'));
    await tester.pumpAndSettle();
    expect(pill('Ролики'), findsNothing);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(pill('Ролики'), findsOneWidget);
  });

  testWidgets('в строке: понял фильтр — «Умная папка» сохраняет запрос, он встаёт на полку', (tester) async {
    await note('v', 'Тарт с малиной', kind: ItemKind.video, url: 'https://www.tiktok.com/@chef/1');
    await open(tester);
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'видео за неделю');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(LinePanel), matching: find.textContaining('Ищу:')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(LinePanel), matching: find.text('Умная папка')));
    await tester.pumpAndSettle();
    // имя по умолчанию — сам запрос с заглавной
    expect(find.widgetWithText(TextField, 'Видео за неделю'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final saved = await world.db.select(world.db.smartFolders).getSingle();
    expect((saved.name, saved.query), ('Видео за неделю', 'видео за неделю'));
  });
}
