import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/features/settings/feedback_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('строка телефона из сведений, которые пишет Android', () {
    expect(deviceLine('0.1.3', {'maker': 'Xiaomi', 'model': '2510ERA8BG', 'os': 'Android 16'}), 'Stowa 0.1.3 · Xiaomi 2510ERA8BG · Android 16');
    expect(deviceLine('0.1.3', {}), 'Stowa 0.1.3');
  });

  group('отправка на сервер', () {
    test('тело запроса: вид, текст, почта и телефон, адрес — приём Stowa', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response('{"ok":true,"id":"r1"}', 200);
      });
      final result = await sendFeedback(client, FeedbackDraft(kind: FeedbackKind.idea, text: 'Виджет поменьше бы', email: 'me@x.io', device: 'Stowa 0.1.3', app: '0.1.3', platform: 'android', lang: 'ru'));
      expect(result, FeedbackResult.sent);
      expect(sent.url.toString(), 'https://togetherly.day/api/stowa/feedback');
      expect(jsonDecode(sent.body), {'kind': 'idea', 'text': 'Виджет поменьше бы', 'email': 'me@x.io', 'device': 'Stowa 0.1.3', 'app': '0.1.3', 'platform': 'android', 'lang': 'ru'});
    });

    test('429 — «на сегодня много», обрыв сети — «не отправилось»', () async {
      expect(await sendFeedback(MockClient((_) async => http.Response('{"ok":false,"error":"too_many"}', 429)), _draft), FeedbackResult.tooMany);
      expect(await sendFeedback(MockClient((_) async => throw http.ClientException('нет сети')), _draft), FeedbackResult.failed);
      expect(await sendFeedback(MockClient((_) async => http.Response('', 502)), _draft), FeedbackResult.failed);
    });
  });

  group('экран', () {
    late TestWorld world;
    setUp(() => world = TestWorld());
    tearDown(() => world.dispose());

    Future<List<FeedbackDraft>> open(WidgetTester tester, {FeedbackResult answer = FeedbackResult.sent}) async {
      final sent = <FeedbackDraft>[];
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(world.wrap(FeedbackScreen(send: (draft) async {
        sent.add(draft);
        return answer;
      })));
      await tester.pumpAndSettle();
      return sent;
    }

    testWidgets('выбрал «Идея», написал, оставил почту — уходит на сервер, экран говорит «отправлено»', (tester) async {
      final sent = await open(tester);
      await tester.tap(find.byKey(const ValueKey('feedback-kind-idea')));
      await tester.enterText(find.byKey(const ValueKey('feedback-text')), 'Виджет поменьше бы');
      await tester.enterText(find.byKey(const ValueKey('feedback-email')), ' me@x.io ');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('feedback-send')));
      await tester.pumpAndSettle();
      expect(sent.single.kind, FeedbackKind.idea);
      expect(sent.single.text, 'Виджет поменьше бы');
      expect(sent.single.email, 'me@x.io');
      expect(find.byKey(const ValueKey('feedback-sent')), findsOneWidget);
      expect(find.textContaining('me@x.io'), findsOneWidget);
    });

    testWidgets('меньше десяти знаков не отправляется', (tester) async {
      final sent = await open(tester);
      await tester.enterText(find.byKey(const ValueKey('feedback-text')), 'Сломалось');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('feedback-send')));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
    });

    testWidgets('не отправилось — текст остаётся, под кнопкой причина', (tester) async {
      await open(tester, answer: FeedbackResult.failed);
      await tester.enterText(find.byKey(const ValueKey('feedback-text')), 'Не сохраняется фото');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('feedback-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feedback-sent')), findsNothing);
      expect(find.byKey(const ValueKey('feedback-error')), findsOneWidget);
      expect(find.text('Не сохраняется фото'), findsOneWidget);
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
  });
}

const _draft = FeedbackDraft(kind: FeedbackKind.bug, text: 'Не открывается заметка', email: '', device: null, app: '0.1.3', platform: 'android', lang: 'ru');
