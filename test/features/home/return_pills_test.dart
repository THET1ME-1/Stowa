import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/models.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld(now: DateTime(2026, 11, 6, 20, 30)));
  tearDown(() => world.dispose());

  Future<void> note(String title, DateTime created, {ItemKind kind = ItemKind.note, int? seconds}) => world.db.into(world.db.items).insert(
        ItemsCompanion.insert(id: title, kind: kind, title: title, body: Value(title), durationSeconds: Value(seconds), createdAt: created, updatedAt: created),
      );

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  testWidgets('очередь не пуста — пилюля «Посмотреть потом · 13 мин», касание открывает очередь', (tester) async {
    await note('Турка', world.now.subtract(const Duration(days: 1)), kind: ItemKind.video, seconds: 754);
    await open(tester);
    expect(find.text('Посмотреть потом · 13 мин'), findsOneWidget);
    await tester.tap(find.text('Посмотреть потом · 13 мин'));
    await tester.pumpAndSettle();
    expect(find.text('1 ролик — 13 минут'), findsOneWidget);
  });

  testWidgets('год назад что-то сохранили — круглая кнопка «Год назад» в шапке, а не блок под напоминаниями', (tester) async {
    await note('Борщ бабушкин', DateTime(2025, 11, 6, 9));
    await open(tester);
    final button = find.byKey(const ValueKey('return-onThisDay'));
    expect(find.byTooltip('Год назад'), findsOneWidget);
    // круг в строке шапки, рядом с каталогом и картой
    final rect = tester.getRect(button);
    expect(rect.width, closeTo(rect.height, 1));
    expect(rect.center.dy, closeTo(tester.getCenter(find.byTooltip('Карта')).dy, 1));
    expect(find.text('Год назад'), findsNothing);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Борщ бабушкин'), findsWidgets);
  });

  testWidgets('вспомнить нечего — кнопки в шапке нет', (tester) async {
    await note('Мысль', world.now);
    await open(tester);
    expect(find.byKey(const ValueKey('return-onThisDay')), findsNothing);
  });

  testWidgets('«Посмотреть потом» — во всю строку', (tester) async {
    await note('Турка', world.now.subtract(const Duration(days: 1)), kind: ItemKind.video, seconds: 754);
    await open(tester);
    expect(tester.getRect(find.byKey(const ValueKey('return-watchLater'))).width, closeTo(400 - 32, 1));
  });

  testWidgets('карточка «Возвращать сохранённое?» один раз: «Не сейчас» прячет её насовсем', (tester) async {
    SharedPreferences.setMockInitialValues({});
    world.settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
    await note('Мысль', world.now);
    await open(tester);
    expect(find.text('Возвращать сохранённое?'), findsOneWidget);
    await tester.tap(find.text('Не сейчас'));
    await tester.pumpAndSettle();
    expect(find.text('Возвращать сохранённое?'), findsNothing);
    expect(world.settings!.returnsAsked, isTrue);
  });

  testWidgets('пустое приложение карточку не показывает', (tester) async {
    SharedPreferences.setMockInitialValues({});
    world.settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
    await open(tester);
    expect(find.text('Возвращать сохранённое?'), findsNothing);
  });
}
