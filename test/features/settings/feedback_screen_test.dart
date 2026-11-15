import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/settings/feedback_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('письмо: адрес, тема с видом обращения, текст и сведения о телефоне', () {
    final mail = feedbackMail(subject: 'Stowa — ошибка', text: 'Не открывается заметка', device: 'Stowa 0.1.3 · Xiaomi 2510ERA8BG · Android 16');
    expect(mail.scheme, 'mailto');
    expect(mail.path, supportEmail);
    expect(mail.queryParameters['subject'], 'Stowa — ошибка');
    expect(mail.queryParameters['body'], 'Не открывается заметка\n\n—\nStowa 0.1.3 · Xiaomi 2510ERA8BG · Android 16');
    // пробелы — %20, а не «+»: почтовые программы плюс показывают плюсом
    expect(mail.toString(), isNot(contains('+')));
  });

  test('без сведений о телефоне в письме только текст', () {
    final mail = feedbackMail(subject: 'Stowa — идея', text: 'Тёмная тема для виджета', device: null);
    expect(mail.queryParameters['body'], 'Тёмная тема для виджета');
  });

  test('строка телефона из сведений, которые пишет Android', () {
    expect(deviceLine('0.1.3', {'maker': 'Xiaomi', 'model': '2510ERA8BG', 'os': 'Android 16'}), 'Stowa 0.1.3 · Xiaomi 2510ERA8BG · Android 16');
    expect(deviceLine('0.1.3', {}), 'Stowa 0.1.3');
  });

  group('экран', () {
    late TestWorld world;
    setUp(() => world = TestWorld());
    tearDown(() => world.dispose());

    Future<List<Uri>> open(WidgetTester tester, {bool mailApp = true}) async {
      final opened = <Uri>[];
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(world.wrap(FeedbackScreen(open: (uri) async {
        opened.add(uri);
        return mailApp;
      })));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('выбрал «Идея», написал — письмо уходит в почту с этой темой', (tester) async {
      final opened = await open(tester);
      await tester.tap(find.byKey(const ValueKey('feedback-kind-idea')));
      await tester.enterText(find.byKey(const ValueKey('feedback-text')), 'Виджет поменьше');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('feedback-send')));
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(opened.single.queryParameters['subject'], 'Stowa — идея');
      expect(opened.single.queryParameters['body'], startsWith('Виджет поменьше'));
    });

    testWidgets('в настройках раздел «Помощь»: строка «Сообщить о проблеме» ведёт на экран', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(world.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Настройки'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('settings-feedback')), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text(supportEmail), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-feedback')));
      await tester.pumpAndSettle();
      expect(find.byType(FeedbackScreen), findsOneWidget);
    });

    testWidgets('пустое письмо не отправляется', (tester) async {
      final opened = await open(tester);
      await tester.tap(find.byKey(const ValueKey('feedback-send')));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
    });

    testWidgets('нет почтовой программы — говорим об этом и даём адрес', (tester) async {
      await open(tester, mailApp: false);
      await tester.enterText(find.byKey(const ValueKey('feedback-text')), 'Не сохраняется фото');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('feedback-send')));
      await tester.pumpAndSettle();
      expect(find.textContaining(supportEmail), findsWidgets);
    });
  });
}
