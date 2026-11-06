import 'dart:convert';
import 'dart:io';

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

  testWidgets('показ 18+ выключен с начала и включается переключателем', (tester) async {
    await open(tester, keyStatus: 200);
    expect(settings.showAdult, isFalse);
    await tester.scrollUntilVisible(find.text('Показывать 18+'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показывать 18+'));
    await tester.pumpAndSettle();
    expect(settings.showAdult, isTrue);
  });

  testWidgets('раздел «Хранилище»: где лежит, перенос и «Пересобрать указатель»', (tester) async {
    await open(tester, keyStatus: 200);
    // экран теста короткий: заголовок и строки раздела на нём разом не видны
    for (final label in ['Хранилище', 'Внутри приложения', 'Перенести в другую папку', 'Пересобрать указатель']) {
      await tester.scrollUntilVisible(find.text(label), 100);
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('«Запоминать, где сохранено» без разрешения выключено; включение спрашивает место', (tester) async {
    world.placeGranted = false;
    await open(tester, keyStatus: 200);
    await tester.scrollUntilVisible(find.text('Запоминать, где сохранено'), 100);
    final toggle = find.ancestor(of: find.text('Запоминать, где сохранено'), matching: find.byType(InkWell)).first;
    Switch shown() => tester.widget<Switch>(find.descendant(of: find.ancestor(of: find.text('Запоминать, где сохранено'), matching: find.byType(Row)).first, matching: find.byType(Switch)));
    expect(shown().value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(world.placeAsked, 1);
    expect(shown().value, isTrue);
    expect(settings.placeEnabled, isTrue);
  });

  testWidgets('раздел «Возвращать»: виды включаются по одному, час вечера и день сводки видны', (tester) async {
    await open(tester, keyStatus: 200);
    for (final label in ['Возвращать', 'Посмотреть потом', 'В этот день', 'Сводка недели', '20:00', '22:00–08:00', 'воскресенье']) {
      await tester.scrollUntilVisible(find.text(label), 100);
      expect(find.text(label), findsOneWidget);
    }

    await tester.scrollUntilVisible(find.text('Сводка недели'), -100);
    await tester.tap(find.text('Сводка недели'));
    await tester.pumpAndSettle();
    expect(settings.returns.week, isFalse);
    expect(settings.returns.watchLater, isTrue);
    // выключение не спрашивает, включение — спрашивает разрешение на уведомления
    expect(world.notifications.asked, 0);
    await tester.tap(find.text('Сводка недели'));
    await tester.pumpAndSettle();
    expect(settings.returns.week, isTrue);
    expect(world.notifications.asked, 1);

    await tester.scrollUntilVisible(find.text('День сводки'), 100);
    await tester.tap(find.text('День сводки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('суббота').last);
    await tester.pumpAndSettle();
    expect(settings.returns.weekDay, DateTime.saturday);
    expect(find.text('суббота'), findsOneWidget);
  });

  testWidgets('«Из Telegram»: папка выгрузки становится заметками, итог плашкой', (tester) async {
    final export = Directory.systemTemp.createTempSync('stowa_tg');
    addTearDown(() => export.deleteSync(recursive: true));
    Map<String, Object?> message(int id, String text) => {'id': id, 'type': 'message', 'date_unixtime': '${1683885600 + id * 60}', 'text': text, 'text_entities': [{'type': 'plain', 'text': text}]};
    File('${export.path}/result.json').writeAsStringSync(jsonEncode({'name': 'Saved Messages', 'type': 'saved_messages', 'id': 1, 'messages': [message(1, 'Купить кофе'), message(2, 'Позвонить маме')]}));
    world.pickedFolder = export.path;

    await open(tester, keyStatus: 200);
    await tester.scrollUntilVisible(find.text('Из Telegram'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Из Telegram'));
    // файл читается по-настоящему: время теста и время диска идут по очереди
    for (var step = 0; step < 20 && find.textContaining('Перенёс').evaluate().isEmpty; step++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Перенёс 2 заметки'), findsOneWidget);
    expect((await world.db.select(world.db.items).get()).map((item) => item.body), unorderedEquals(['Купить кофе', 'Позвонить маме']));
  });

  testWidgets('в папке нет выгрузки Telegram — так и сказано', (tester) async {
    final empty = Directory.systemTemp.createTempSync('stowa_tg');
    addTearDown(() => empty.deleteSync(recursive: true));
    world.pickedFolder = empty.path;

    await open(tester, keyStatus: 200);
    await tester.scrollUntilVisible(find.text('Из Telegram'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Из Telegram'));
    for (var step = 0; step < 20 && find.textContaining('result.json').evaluate().isEmpty; step++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('В этой папке нет выгрузки Telegram: нужен messages.html или result.json'), findsOneWidget);
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
