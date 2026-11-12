import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/app.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/features/home/home_screen.dart';
import 'package:stowa/features/privacy/code_entry.dart';
import 'package:stowa/features/privacy/privacy_flows.dart';
import 'package:stowa/features/share/share_inbox.dart';
import 'package:stowa/services/share_intake.dart';

import '../../helpers/test_app.dart';

void main() {
  group('перенос из папки расширения', () {
    late Directory root;
    late Directory group;
    late Directory into;

    setUp(() {
      root = Directory.systemTemp.createTempSync('stowa_adopt');
      group = Directory(p.join(root.path, 'group'))..createSync();
      into = Directory(p.join(root.path, 'tmp'));
    });
    tearDown(() => root.deleteSync(recursive: true));

    SharedPiece image(File file) => SharedPiece(value: file.path, kind: SharedKind.image, mime: 'image/png');

    test('файл переезжает во временную папку, в папке расширения его нет', () async {
      final photo = File(p.join(group.path, 'photo.png'))..writeAsStringSync('картинка');

      final adopted = await adoptShared([image(photo)], into);

      expect(adopted.single.value, p.join(into.path, 'photo.png'));
      expect(adopted.single.kind, SharedKind.image);
      expect(adopted.single.mime, 'image/png');
      expect(File(adopted.single.value).readAsStringSync(), 'картинка');
      expect(photo.existsSync(), isFalse);
    });

    test('занятое имя получает номер, первый файл цел', () async {
      final first = File(p.join(group.path, 'TempImage.png'))..writeAsStringSync('первая');
      final one = await adoptShared([image(first)], into);
      // расширение пишет вторую картинку под тем же именем
      final second = File(p.join(group.path, 'TempImage.png'))..writeAsStringSync('вторая');
      final two = await adoptShared([image(second)], into);

      expect(one.single.value, p.join(into.path, 'TempImage.png'));
      expect(two.single.value, p.join(into.path, 'TempImage 2.png'));
      expect(File(one.single.value).readAsStringSync(), 'первая');
      expect(File(two.single.value).readAsStringSync(), 'вторая');
    });

    test('текст и ссылка не трогаются', () async {
      const pieces = [
        SharedPiece(value: 'Паста с креветками', kind: SharedKind.text),
        SharedPiece(value: 'https://vt.tiktok.com/ZSpasta15/', kind: SharedKind.url),
      ];

      final adopted = await adoptShared(pieces, into);

      expect([for (final piece in adopted) piece.value], ['Паста с креветками', 'https://vt.tiktok.com/ZSpasta15/']);
      expect(into.existsSync(), isFalse);
    });

    test('пропавший файл остаётся в списке как был', () async {
      final missing = p.join(group.path, 'нет.png');

      final adopted = await adoptShared([SharedPiece(value: missing, kind: SharedKind.image)], into);

      expect(adopted.single.value, missing);
    });
  });

  group('главное окно принимает присланное', () {
    late TestWorld world;
    setUp(() => world = TestWorld());
    tearDown(() => world.dispose());

    const link = [
      SharedPiece(value: 'Паста с креветками', kind: SharedKind.text),
      SharedPiece(value: 'https://vt.tiktok.com/ZSpasta15/', kind: SharedKind.url),
    ];

    Future<void> open(WidgetTester tester, {List<Object> more = const []}) async {
      tester.view.physicalSize = const Size(400, 880);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...world.overrides, ...more.cast()],
          child: const StowaApp(locale: Locale('ru')),
        ),
      );
      await tester.pumpAndSettle();
    }

    // сохранение и выезд листа, но меньше трёх секунд его отсчёта
    Future<void> frames(WidgetTester tester) async {
      for (var step = 0; step < 8; step++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // чтение файла и счёт ключа замка идут в настоящем времени, у виджет-теста оно поддельное
    Future<void> realTime(WidgetTester tester) async {
      for (var round = 0; round < 80; round++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump();
      }
    }

    Future<int> notes() async => (await world.db.select(world.db.items).get()).length;

    testWidgets('присланный текст становится заметкой и открывает лист', (tester) async {
      await open(tester);
      world.shared.add(link);
      await frames(tester);

      expect((await world.db.select(world.db.items).getSingle()).url, 'https://vt.tiktok.com/ZSpasta15/');
      expect(find.text('Сохранено'), findsOneWidget);
      expect(find.text('пока без папки'), findsOneWidget);
    });

    testWidgets('пустой список ничего не делает', (tester) async {
      await open(tester);
      world.shared.add(const []);
      await frames(tester);

      expect(await notes(), 0);
      expect(find.text('Сохранено'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('несохранённое говорит плашкой, листа нет', (tester) async {
      await open(tester);
      world.shared.add([SharedPiece(value: p.join(world.files.path, 'нет.png'), kind: SharedKind.image)]);
      await realTime(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(await notes(), 0);
      expect(find.text('Сохранено'), findsNothing);
      expect(find.text('Не получилось сохранить: приложение не дало доступ'), findsOneWidget);
    });

    testWidgets('под замком заметка сохранена, лист ждёт кода', (tester) async {
      final vault = Directory(p.join(world.files.path, 'vault'))..createSync();
      await open(tester, more: [vaultRootProvider.overrideWith(() => VaultRootNotifier(vault))]);
      final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
      // приложение сперва дочитывает с диска, что замка нет: иначе это чтение затрёт новый код
      await realTime(tester);
      await tester.runAsync(() async {
        final privacy = container.read(privacyServiceProvider);
        await privacy.createCode('123456', kdf: container.read(kdfSettingsProvider));
        await privacy.setAppLock(true);
        await privacy.setCloseAfter(Duration.zero);
      });
      await realTime(tester);
      // ушли и вернулись: замок встал
      for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused, AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await realTime(tester);
      expect(find.text('Введите код'), findsOneWidget);

      world.shared.add(link);
      await realTime(tester);
      await frames(tester);
      expect(await tester.runAsync(notes), 1);
      expect(find.text('Сохранено'), findsNothing);

      final pad = find.byType(CodeEntry).last;
      for (final digit in '123456'.split('')) {
        await tester.tap(find.descendant(of: pad, matching: find.text(digit)));
        await tester.pump();
      }
      await tester.tap(find.descendant(of: pad, matching: find.text('Готово')));
      await realTime(tester);
      await frames(tester);
      expect(find.text('Введите код'), findsNothing);
      expect(find.text('Сохранено'), findsOneWidget);
    });
  });
}
