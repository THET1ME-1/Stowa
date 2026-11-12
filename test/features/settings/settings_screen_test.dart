import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/return_plan.dart';
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

  Future<void> open(WidgetTester tester, {required int keyStatus, bool ownLanguage = false, Size size = const Size(400, 880), double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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

  /// Большой раздел живёт на своём экране: в настройках от него одна строка.
  Future<void> openSection(WidgetTester tester, String title, {int keyStatus = 200}) async {
    await open(tester, keyStatus: keyStatus);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('большие разделы — одной строкой с итогом: разбор, возврат, хранилище', (tester) async {
    await open(tester, keyStatus: 200);
    expect(find.text('Выключен'), findsOneWidget);
    expect(find.text('Посмотреть потом · В этот день · Сводка недели · Покупки у магазина'), findsOneWidget);
    expect(find.text('Внутри приложения'), findsOneWidget);
    // строк самих разделов на главном экране настроек нет
    expect(find.text('Ключ'), findsNothing);
    expect(find.text('Сводка недели'), findsNothing);
    expect(find.text('Перенести в другую папку'), findsNothing);
    expect(find.text('Корзина'), findsOneWidget);
  });

  testWidgets('итог возврата: только включённое, без него — «Выключено»', (tester) async {
    await settings.setReturns(const ReturnSettings(onThisDay: false, shopping: false));
    await open(tester, keyStatus: 200);
    expect(find.text('Посмотреть потом · Сводка недели'), findsOneWidget);
    await settings.setReturns(const ReturnSettings(watchLater: false, onThisDay: false, week: false, shopping: false));
    await tester.pumpAndSettle();
    expect(find.text('Выключено'), findsOneWidget);
  });

  testWidgets('итог разбора: с ключом — «Работает» и модель', (tester) async {
    await settings.saveKey('sk-or-good');
    await open(tester, keyStatus: 200);
    expect(find.textContaining('Работает · '), findsOneWidget);
  });

  for (final section in ['Разбор ИИ', 'Возвращать', 'Хранилище']) {
    testWidgets('320 точек и крупный шрифт: «$section» влезает', (tester) async {
      await open(tester, keyStatus: 200, size: const Size(320, 700), textScale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('без ключа разбор выключен и сказано, зачем ключ', (tester) async {
    await openSection(tester, 'Разбор ИИ');
    expect(find.text('Выключен'), findsOneWidget);
    expect(find.textContaining('Ключ хранится только на этом телефоне'), findsOneWidget);
  });

  testWidgets('рабочий ключ сохраняется после проверки у поставщика', (tester) async {
    await openSection(tester, 'Разбор ИИ');
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
    await openSection(tester, 'Разбор ИИ', keyStatus: 401);
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
    await openSection(tester, 'Разбор ИИ');
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

  testWidgets('отчёты об ошибках включены с начала и выключаются переключателем', (tester) async {
    await open(tester, keyStatus: 200);
    expect(settings.crashReports, isTrue);
    await tester.scrollUntilVisible(find.text('Отчёты об ошибках'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отчёты об ошибках'));
    await tester.pumpAndSettle();
    expect(settings.crashReports, isFalse);
  });

  testWidgets('«Запуск»: по умолчанию главная, выбор из листа сохраняется', (tester) async {
    await open(tester, keyStatus: 200);
    await tester.scrollUntilVisible(find.text('Открывать'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Главную'), findsOneWidget);
    await tester.tap(find.text('Открывать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Случайную заметку'));
    await tester.pumpAndSettle();
    expect(settings.startScreen, StartScreen.random);
    expect(find.text('Случайную заметку'), findsOneWidget);
  });

  testWidgets('«Название фото и видео»: по умолчанию по дню съёмки, можно выбрать день сохранения', (tester) async {
    await open(tester, keyStatus: 200);
    await tester.scrollUntilVisible(find.text('Название фото и видео'), 200);
    await tester.pumpAndSettle();
    expect(find.text('По дню съёмки'), findsOneWidget);
    await tester.tap(find.text('Название фото и видео'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('По дню сохранения'));
    await tester.pumpAndSettle();
    expect(settings.titleDate, TitleDate.saved);
    expect(find.text('По дню сохранения'), findsOneWidget);
  });

  testWidgets('экран «Хранилище»: где лежит, перенос, «Пересобрать указатель» и копии', (tester) async {
    await openSection(tester, 'Хранилище');
    for (final label in ['Внутри приложения', 'Перенести в другую папку', 'Пересобрать указатель', 'Сохранить копию', 'Выгрузить в Markdown', 'Восстановить из копии']) {
      await tester.scrollUntilVisible(find.text(label), 100);
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('«ИИ в приоритете» по умолчанию выключен, касание включает', (tester) async {
    await openSection(tester, 'Разбор ИИ');
    final row = find.ancestor(of: find.text('ИИ в приоритете'), matching: find.byType(InkWell)).first;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(settings.ai.aiFirst, isFalse);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(settings.ai.aiFirst, isTrue);
  });

  testWidgets('пояснение под переключателем видно целиком, без многоточия', (tester) async {
    await openSection(tester, 'Разбор ИИ');
    final hint = find.textContaining('Модель проверяет и догадки без ИИ');
    await tester.scrollUntilVisible(hint, 100);
    expect(tester.renderObject<RenderParagraph>(hint).didExceedMaxLines, isFalse);
  });

  testWidgets('«Запоминать, где сохранено» без разрешения выключено; включение спрашивает место', (tester) async {
    world.placeGranted = false;
    await open(tester, keyStatus: 200);
    await tester.scrollUntilVisible(find.text('Запоминать, где сохранено'), 100);
    final toggle = find.ancestor(of: find.text('Запоминать, где сохранено'), matching: find.byType(InkWell)).first;
    Switch shown() => tester.widget<Switch>(find.descendant(of: find.ancestor(of: find.text('Запоминать, где сохранено'), matching: find.byType(Row)).first, matching: find.byType(Switch)));
    expect(shown().value, isFalse);
    // строка могла встать у нижнего края, где касание уходит мимо
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(world.placeAsked, 1);
    expect(shown().value, isTrue);
    expect(settings.placeEnabled, isTrue);
  });

  testWidgets('экран «Возвращать»: виды включаются по одному, час вечера и день сводки видны', (tester) async {
    await openSection(tester, 'Возвращать');
    for (final label in ['Посмотреть потом', 'В этот день', 'Сводка недели', 'Покупки у магазина', '20:00', '22:00–08:00', 'воскресенье', 'Работа до', '18:00', 'Места']) {
      await tester.scrollUntilVisible(find.text(label), 100);
      expect(find.text(label), findsOneWidget);
    }

    await tester.ensureVisible(find.text('Сводка недели'));
    await tester.pumpAndSettle();
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

    // выключенный вид уходит из итога на главном экране настроек
    await tester.ensureVisible(find.text('В этот день'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В этот день'));
    await tester.pumpAndSettle();
    // шапка уезжает вместе со списком
    await tester.ensureVisible(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.text('Посмотреть потом · Сводка недели · Покупки у магазина'), findsOneWidget);
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
    await openSection(tester, 'Разбор ИИ');
    await tester.ensureVisible(find.text('Журнал запросов'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Журнал запросов'));
    await tester.pumpAndSettle();
    expect(find.text('Борщ'), findsOneWidget);
    expect(find.textContaining('Модель не ответила вовремя · нет ответа за 90 секунд'), findsOneWidget);
  });

  testWidgets('пауза разбора видна на главной и ведёт прямо к ключу', (tester) async {
    await settings.saveKey('sk-or-good');
    await settings.pause('auth');
    await open(tester, keyStatus: 200);
    // в настройках пауза — итогом строки разбора
    expect(find.text('Разбор на паузе: ключ не принят'), findsOneWidget);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.text('Разбор на паузе: ключ не принят'), findsOneWidget);
    await tester.tap(find.text('Проверить ключ'));
    await tester.pumpAndSettle();
    expect(find.text('Разбор ИИ'), findsOneWidget);
    expect(find.text('Ключ'), findsOneWidget);
  });
}
