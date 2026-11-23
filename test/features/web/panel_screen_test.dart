import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/features/web/panel_screen.dart';
import 'package:stowa/features/web/tab_busy_screen.dart';
import 'package:stowa/l10n/app_localizations.dart';
import 'package:stowa/services/panel_bridge.dart';

// STOWA-9: панель при открытой вкладке Stowa — строка, которая пишет и ищет через вкладку
void main() {
  late List<String> saved;
  late List<String> opened;
  late bool locked;
  late PanelBridge tab;

  setUp(() {
    saved = [];
    opened = [];
    locked = false;
    tab = PanelBridge(
      link: PanelLink(),
      locked: () => locked,
      capture: (text) async {
        saved.add(text);
        return (id: 'n${saved.length}', folder: 'Покупки');
      },
      undo: (id) async {},
      search: (query) async => [PanelNote(id: 'a', title: 'Шины на зиму', line: 'замена в ноябре', folder: 'Машина')],
      open: opened.add,
    );
  });

  Future<void> show(WidgetTester tester, {bool withTab = true}) async {
    if (withTab) tab.start();
    addTearDown(tab.stop);
    tester.view.physicalSize = const Size(380, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = PanelClient(PanelLink());
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: PanelScreen(client: client, onOpenHere: () async {}),
      ),
    );
    // ответ вкладки приходит в настоящем времени, не в поддельном
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  // вкладка отвечает в настоящем времени: даём ей ответить и рисуем кадр
  Future<void> settle(WidgetTester tester, [int ms = 50]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pumpAndSettle();
  }

  testWidgets('записал — заметка в списке «Записано сейчас» с папкой, строка пуста', (tester) async {
    await show(tester);
    expect(find.text('Пиши мысль или ищи заметку: строка делает и то и другое.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('panel-field')), 'Купить фильтр для воды');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('panel-send')));
    await settle(tester);
    expect(saved, ['Купить фильтр для воды']);
    expect(find.text('Записано сейчас'), findsOneWidget);
    expect(find.text('Легло в «Покупки»'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('panel-field'))).controller!.text, isEmpty);
  });

  testWidgets('набранное ищется через вкладку, касание найденного открывает его во вкладке', (tester) async {
    await show(tester);
    await tester.enterText(find.byKey(const ValueKey('panel-field')), 'шины');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('Шины на зиму'), findsOneWidget);
    expect(find.text('замена в ноябре · Машина'), findsOneWidget);
    await tester.tap(find.text('Шины на зиму'));
    await settle(tester);
    expect(opened, ['a']);
    expect(find.text('Открыл во вкладке Stowa'), findsOneWidget);
  });

  testWidgets('«Код на вход»: искать нельзя — сказано сразу, записывать можно', (tester) async {
    locked = true;
    await show(tester);
    expect(find.text('Поиск закрыт кодом на вход, записывать можно.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('panel-field')), 'шины');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('Шины на зиму'), findsNothing);
  });

  testWidgets('вкладка не ответила за все попытки — прежний экран «уже открыта в другой вкладке»', (tester) async {
    await show(tester, withTab: false);
    expect(find.text('Жду вкладку Stowa…'), findsOneWidget);
    // ожидание ответа идёт по часам теста: восемь попыток по полторы секунды
    for (var attempt = 0; attempt < 8; attempt++) {
      await tester.pump(const Duration(milliseconds: 1600));
    }
    await tester.pumpAndSettle();
    expect(find.byType(TabBusyScreen), findsOneWidget);
  });

  // хозяин 21.11 со снимка Vivaldi: «дизайн под телефон уже хороший, только текст меньше»
  testWidgets('узкая панель: строка как на телефоне — подсказка в одну строку, «Закинуть» под полем', (tester) async {
    await show(tester);
    tester.view.physicalSize = const Size(340, 800);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(const ValueKey('panel-field')));
    expect(field.decoration!.hintMaxLines, 1);
    expect(tester.getRect(find.byKey(const ValueKey('panel-send'))).top, greaterThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('panel-field'))).bottom));
  });

  testWidgets('панель целиком — текст мельче телефонного: узкая панель уже телефона', (tester) async {
    tab.start();
    addTearDown(tab.stop);
    tester.view.physicalSize = const Size(340, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = PanelClient(PanelLink());
    addTearDown(client.close);
    await tester.pumpWidget(PanelApp(client: client, onOpenHere: () async {}, locale: const Locale('ru')));
    await settle(tester);
    expect(MediaQuery.textScalerOf(tester.element(find.byKey(const ValueKey('panel-field')))), const TextScaler.linear(panelTextScale));
  });

  // хозяин 23.11: панель — по сути расширение, поставить его может любой. Подписка не нужна
  testWidgets('панель работает без подписки: строка сразу, замка нет', (tester) async {
    tab.start();
    addTearDown(tab.stop);
    final client = PanelClient(PanelLink());
    addTearDown(client.close);
    await tester.pumpWidget(PanelApp(client: client, onOpenHere: () async {}, locale: const Locale('ru')));
    await settle(tester);
    expect(find.byKey(const ValueKey('panel-field')), findsOneWidget);
    expect(find.text('Боковая панель входит в Stowa Sync'), findsNothing);
  });

  testWidgets('вкладка ещё грузится — панель ждёт и подключается, когда та ответит', (tester) async {
    await show(tester, withTab: false);
    await tester.pump(const Duration(milliseconds: 1600));
    tab.start();
    await tester.pump(const Duration(milliseconds: 1600));
    await settle(tester);
    expect(find.text('Пиши мысль или ищи заметку: строка делает и то и другое.'), findsOneWidget);
    expect(find.byType(TabBusyScreen), findsNothing);
  });
}
