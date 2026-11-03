import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/l10n/app_language.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  late SettingsRepository settings;
  final asked = <String>[];

  setUp(() async {
    world = TestWorld();
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
    asked.clear();
  });
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester, {required int keyStatus, bool ownLanguage = false}) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    world
      ..settings = settings
      ..aiHttp = MockClient((request) async {
        asked.add(request.url.path);
        if (request.url.path.endsWith('/models')) {
          return http.Response(jsonEncode({'data': [{'id': 'google/gemma-4:free', 'name': 'Gemma 4', 'pricing': {'prompt': '0'}, 'architecture': {'input_modalities': ['text', 'image']}}]}), 200);
        }
        return http.Response('{}', keyStatus);
      });
    await tester.pumpWidget(ownLanguage ? world.app(locale: null) : world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
  }

  testWidgets('без ключа разбор выключен и сказано, зачем ключ', (tester) async {
    await open(tester, keyStatus: 200);
    expect(find.text('Выключен'), findsOneWidget);
    expect(find.textContaining('Ключ хранится только на этом телефоне'), findsOneWidget);
  });

  testWidgets('рабочий ключ сохраняется после проверки у поставщика', (tester) async {
    await open(tester, keyStatus: 200);
    await tester.tap(find.text('Ключ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ai-key-field')), 'sk-or-good');
    await tester.tap(find.text('Сохранить и проверить'));
    await tester.pumpAndSettle();
    expect(await settings.readKey(), 'sk-or-good');
    expect(asked, contains('/api/v1/key'));
    expect(find.text('Работает'), findsOneWidget);
  });

  testWidgets('ключ, который поставщик не принял, не сохраняется, лист говорит почему', (tester) async {
    await open(tester, keyStatus: 401);
    await tester.tap(find.text('Ключ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ai-key-field')), 'sk-or-bad');
    await tester.tap(find.text('Сохранить и проверить'));
    await tester.pumpAndSettle();
    expect(await settings.readKey(), isNull);
    expect(find.text('Поставщик не принял ключ'), findsOneWidget);
  });

  testWidgets('модель разбора выбирается из живого списка поставщика', (tester) async {
    await settings.saveKey('sk-or-good');
    await open(tester, keyStatus: 200);
    await tester.tap(find.text('Модель разбора'));
    await tester.pumpAndSettle();
    expect(find.text('бесплатная'), findsOneWidget);
    expect(find.text('видит фото'), findsOneWidget);
    await tester.tap(find.text('Gemma 4'));
    await tester.pumpAndSettle();
    expect(settings.ai.sortModel, 'google/gemma-4:free');
  });

  testWidgets('язык меняется сразу, без перезапуска', (tester) async {
    await settings.setLanguage(AppLanguage.ru);
    await open(tester, keyStatus: 200, ownLanguage: true);
    await tester.scrollUntilVisible(find.text('Русский'), 200);
    await tester.ensureVisible(find.text('Русский'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(settings.language, AppLanguage.en);
    // экран прокручен к языку: заголовок раздела уже по-английски
    expect(find.text('Language'), findsWidgets);
    expect(find.text('Язык'), findsNothing);
  });

  testWidgets('журнал показывает, какой запрос упал и почему', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Борщ', createdAt: world.now, updatedAt: world.now));
    await world.db.into(world.db.aiLog).insert(AiLogCompanion.insert(at: world.now, itemId: const Value('a'), request: '{}', error: const Value('AiFailure(timeout): нет ответа за 90 секунд')));
    await open(tester, keyStatus: 200);
    await tester.tap(find.text('Журнал запросов'));
    await tester.pumpAndSettle();
    expect(find.text('Борщ'), findsOneWidget);
    expect(find.textContaining('Модель не ответила вовремя · нет ответа за 90 секунд'), findsOneWidget);
  });

  testWidgets('пауза разбора видна на главной и ведёт в настройки', (tester) async {
    await settings.saveKey('sk-or-good');
    await settings.pause('auth');
    await open(tester, keyStatus: 200);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.text('Разбор на паузе: ключ не принят'), findsOneWidget);
    await tester.tap(find.text('Проверить ключ'));
    await tester.pumpAndSettle();
    expect(find.text('Разбор ИИ'), findsOneWidget);
  });
}
