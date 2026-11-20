import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/web/tab_busy_screen.dart';

void main() {
  Future<void> open(WidgetTester tester, {required Future<void> Function() onOpenHere, Size size = const Size(1280, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TabBusyApp(onOpenHere: onOpenHere, locale: const Locale('ru')));
    await tester.pumpAndSettle();
  }

  testWidgets('вторая вкладка говорит, что Stowa открыта в другой, и предлагает открыть здесь', (tester) async {
    await open(tester, onOpenHere: () async {});
    expect(find.text('Stowa уже открыта в другой вкладке'), findsOneWidget);
    expect(find.text('Две вкладки разом испортили бы заметки, поэтому работает одна.'), findsOneWidget);
    expect(find.text('Открыть здесь'), findsOneWidget);
  });

  testWidgets('«Открыть здесь» зовёт перенос один раз и показывает, что та вкладка закрывает заметки', (tester) async {
    var asked = 0;
    final other = Completer<void>();
    await open(tester, onOpenHere: () {
      asked++;
      return other.future;
    });
    await tester.tap(find.text('Открыть здесь'));
    // кнопка уходит плавно: первый кадр начинает смену, второй её заканчивает
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(asked, 1);
    expect(find.text('Та вкладка закрывает заметки…'), findsOneWidget);
    expect(find.text('Открыть здесь'), findsNothing);
    other.complete();
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('перенос не удался — кнопка возвращается', (tester) async {
    await open(tester, onOpenHere: () async => throw StateError('та вкладка не ответила'));
    await tester.tap(find.text('Открыть здесь'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Открыть здесь'), findsOneWidget);
  });

  testWidgets('на узком окне текст не вылезает', (tester) async {
    await open(tester, onOpenHere: () async {}, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    expect(find.text('Открыть здесь'), findsOneWidget);
  });
}
