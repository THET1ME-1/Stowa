import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/features/settings/sync_screen.dart';
import 'package:stowa/services/sync/sync_progress.dart';
import 'package:stowa/services/sync/sync_service.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  late List<http.Request> requests;
  late Directory vault;

  setUp(() {
    world = TestWorld();
    requests = [];
    vault = Directory.systemTemp.createTempSync('stowa_sync_screen');
    world.vaultRoot = vault;
    // сервер: код 123456 верный, ключа ещё нет, остальное пусто
    world.syncHttp = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path == '/v1/auth/start') return http.Response('', 204);
      if (path == '/v1/auth/verify') {
        final code = (jsonDecode(request.body) as Map)['code'];
        return code == '123456'
            ? http.Response(jsonEncode({'token': 't1', 'email': 'me@x.io', 'active': true}), 200, headers: {'content-type': 'application/json'})
            : http.Response('{"error":"code"}', 401);
      }
      if (path == '/v1/key' && request.method == 'GET') return http.Response('{"key":null}', 200);
      if (path == '/v1/key' && request.method == 'PUT') return http.Response('', 204);
      if (path == '/v1/changes') return http.Response('{"cursor":0,"more":false,"changes":[]}', 200);
      if (path == '/v1/session') return http.Response('', 204);
      return http.Response('', 404);
    });
  });

  tearDown(() async {
    await world.dispose();
    vault.deleteSync(recursive: true);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const SyncScreen()));
    await tester.pumpAndSettle();
  }

  // хозяин 20.11 со снимка: «автоподстановка не работает». Менеджер паролей забирает фокус в своё
  // окошко, Flutter закрывает ввод, а значение потом пишется прямо в поле страницы
  testWidgets('менеджер паролей подставил почту, когда фокус ушёл в его окошко, — почта в поле', (tester) async {
    void Function(String value)? fill;
    world.autofill = (hint, onFill) {
      if (hint == 'email') fill = onFill;
      return () {};
    };
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('sync-email')));
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    fill!('me@x.io');
    await tester.pump();
    expect(find.text('me@x.io'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('sync-get-code'))).onPressed, isNotNull);
  });

  testWidgets('пока человек печатает сам, подстановка поле не перебивает', (tester) async {
    void Function(String value)? fill;
    world.autofill = (hint, onFill) {
      fill = onFill;
      return () {};
    };
    await open(tester);
    await tester.enterText(find.byKey(const ValueKey('sync-email')), 'me@');
    await tester.pump();
    fill!('other@x.io');
    await tester.pump();
    expect(find.text('me@'), findsOneWidget);
  });

  Future<void> askCode(WidgetTester tester) async {
    await tester.enterText(find.byKey(const ValueKey('sync-email')), 'me@x.io');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sync-get-code')));
    await tester.pumpAndSettle();
  }

  testWidgets('почта → код: письмо просится с языком, устройством и поясом телефона', (tester) async {
    await open(tester);
    await askCode(tester);
    final start = jsonDecode(requests.single.body) as Map;
    expect(start['email'], 'me@x.io');
    expect(start['lang'], 'ru');
    expect(start.containsKey('device') && start.containsKey('tz_offset'), isTrue);
    expect(find.textContaining('me@x.io'), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-code')), findsOneWidget);
    // повтор не раньше минуты
    expect(find.textContaining('Прислать снова через'), findsOneWidget);
  });

  testWidgets('неверный код — ошибка под кнопкой, верный — вошли, ключ лёг на сервер', (tester) async {
    await open(tester);
    await askCode(tester);
    await tester.enterText(find.byKey(const ValueKey('sync-code')), '000000');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sync-error')), findsOneWidget);
    expect(await world.syncAccount.read(), isNull);

    await tester.enterText(find.byKey(const ValueKey('sync-code')), '123456');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sync-account')), findsOneWidget);
    expect(find.text('me@x.io'), findsOneWidget);
    final account = SyncAccount.fromJson(await world.syncAccount.read())!;
    expect(account.token, 't1');
    expect(account.key.length, 32);
    final put = requests.singleWhere((r) => r.url.path == '/v1/key' && r.method == 'PUT');
    expect(base64.decode((jsonDecode(put.body) as Map)['key'] as String), account.key);

    // выход: аккаунт стёрт, снова шаг почты
    await tester.tap(find.byKey(const ValueKey('sync-sign-out')));
    await tester.pumpAndSettle();
    expect(await world.syncAccount.read(), isNull);
    expect(find.byKey(const ValueKey('sync-email')), findsOneWidget);
  });

  // хозяин 21.11 со снимка: «Синхронизация…» дважды и без хода — «хотел бы показ полного
  // прогресса красиво»
  testWidgets('идёт проход — блок хода: этап, сколько из скольких, файл; кончился — кнопка и итог', (tester) async {
    await open(tester);
    await askCode(tester);
    await tester.enterText(find.byKey(const ValueKey('sync-code')), '123456');
    await tester.pumpAndSettle();
    final service = ProviderScope.containerOf(tester.element(find.byType(SyncScreen))).read(syncServiceProvider);

    const mb = 1024 * 1024;
    service.track(const SyncProgress(SyncStage.receive, done: 1200, total: 3873, bytesDone: 130 * mb, bytesTotal: 633 * mb, file: 'Конспекты/Физика.md'));
    // первый кадр начинает смену кнопки на блок, второй — после неё: блок крутится, settle не дождётся
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('sync-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-now')), findsNothing);
    expect(find.text('Получаю с сервера'), findsOneWidget);
    // внутри половинок пробелы неразрывные: узкий экран переносит только у точки
    expect(find.textContaining('1 200 из 3 873 · 130 из 633 МБ'), findsOneWidget);
    expect(find.text('Физика.md'), findsOneWidget);
    for (final step in ['Папка', 'Приём', 'Отправка', 'Заметки']) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text('Синхронизация…'), findsNothing);

    // сколько всего, ещё не известно — полоса ждёт, цифр нет
    service.track(const SyncProgress(SyncStage.place));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Раскладываю заметки'), findsOneWidget);
    expect(find.textContaining('из'), findsNothing);

    service.track(null);
    service.status.value = service.status.value.copyWith(lastAt: DateTime(2026, 11, 21, 14, 32), received: 12, sent: 3);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sync-progress')), findsNothing);
    expect(find.byKey(const ValueKey('sync-now')), findsOneWidget);
    expect(find.text('Получено: 12, отправлено: 3'), findsOneWidget);
  });

  testWidgets('без хранилища — подсказка выбрать папку, полей нет', (tester) async {
    world.vaultRoot = null;
    await open(tester);
    expect(find.byKey(const ValueKey('sync-email')), findsNothing);
    expect(find.textContaining('папку хранилища'), findsOneWidget);
  });
}
