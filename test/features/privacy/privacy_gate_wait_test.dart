import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/app.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/features/privacy/code_entry.dart';
import 'package:stowa/features/privacy/privacy_flows.dart';
import 'package:stowa/features/privacy/privacy_gate.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  late Directory vault;
  late BuildContext inside;

  setUp(() {
    world = TestWorld();
    vault = Directory(p.join(world.files.path, 'vault'))..createSync();
  });

  // замок пишет файл и считает ключ: у виджет-теста время поддельное, им нужно настоящее
  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 80; round++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester, {bool lockable = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...world.overrides, vaultRootProvider.overrideWith(() => VaultRootNotifier(vault))],
        child: StowaApp(
          locale: const Locale('ru'),
          lockable: lockable,
          home: Builder(
            builder: (context) {
              inside = context;
              return const Scaffold(body: Text('экран'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Код 123456 и «Код на вход»; [after] — через сколько после ухода запирать.
  Future<void> turnLockOn(WidgetTester tester, Duration after) async {
    final container = ProviderScope.containerOf(inside);
    // приложение сперва дочитывает с диска, что замка нет: иначе это чтение затрёт новый код
    await settle(tester);
    await tester.runAsync(() async {
      final privacy = container.read(privacyServiceProvider);
      await privacy.createCode('123456', kdf: container.read(kdfSettingsProvider));
      await privacy.setAppLock(true);
      await privacy.setCloseAfter(after);
    });
    await settle(tester);
  }

  // без кадров между событиями: таймер замка сработать не успевает, решает возврат
  void leave(WidgetTester tester) {
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  void come(WidgetTester tester) {
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    final pad = find.byType(CodeEntry).last;
    for (final digit in code.split('')) {
      await tester.tap(find.descendant(of: pad, matching: find.text(digit)));
      await tester.pump();
    }
    await tester.tap(find.descendant(of: pad, matching: find.text('Готово')));
    await settle(tester);
  }

  testWidgets('без замка возвращается сразу', (tester) async {
    await pumpApp(tester);
    var opened = false;
    PrivacyGate.unlocked(inside).then((_) => opened = true);
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('окно без замка не ждёт', (tester) async {
    await pumpApp(tester, lockable: false);
    var opened = false;
    PrivacyGate.unlocked(inside).then((_) => opened = true);
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('под замком ждёт верного кода', (tester) async {
    await pumpApp(tester);
    await turnLockOn(tester, Duration.zero);
    leave(tester);
    come(tester);
    await settle(tester);
    expect(find.text('Введите код'), findsOneWidget);

    var opened = false;
    PrivacyGate.unlocked(inside).then((_) => opened = true);
    await tester.pump();
    expect(opened, isFalse);
    await enterCode(tester, '000000');
    expect(opened, isFalse);
    await enterCode(tester, '123456');
    expect(find.text('Введите код'), findsNothing);
    expect(opened, isTrue);
  });

  testWidgets('свёрнутое дольше срока приложение сперва запирается', (tester) async {
    await pumpApp(tester);
    await turnLockOn(tester, Duration.zero);
    leave(tester);
    // спросили, пока приложение свёрнуто: замок ещё не встал
    var opened = false;
    PrivacyGate.unlocked(inside).then((_) => opened = true);
    come(tester);
    await settle(tester);
    expect(find.text('Введите код'), findsOneWidget);
    expect(opened, isFalse);
    await enterCode(tester, '123456');
    expect(opened, isTrue);
  });

  testWidgets('свёрнутое ненадолго отпускает на возврате', (tester) async {
    await pumpApp(tester);
    await turnLockOn(tester, const Duration(minutes: 1));
    leave(tester);
    var opened = false;
    PrivacyGate.unlocked(inside).then((_) => opened = true);
    await tester.pump();
    expect(opened, isFalse);
    come(tester);
    await tester.pump();
    expect(find.text('Введите код'), findsNothing);
    expect(opened, isTrue);
  });
}
