import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/app.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/attach_tray.dart';
import 'package:stowa/features/home/home_screen.dart';
import 'package:stowa/features/quick/quick_host.dart';
import 'package:stowa/services/capture_service.dart';
import 'package:stowa/services/launch_actions.dart';
import 'package:stowa/services/privacy/privacy_service.dart';
import 'package:stowa/services/privacy/seal_crypto.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  var finished = 0;
  final opened = <String>[];

  // код на вход включён: ключи замка окну не нужны, только сам флажок
  const locked = PrivacyLock(
    keys: LockFile(salt: [], kdf: KdfSettings(memoryKib: 256, passes: 1), publicKey: [], wrapped: []),
    appLock: true,
  );

  // окно виджета: одна строка поверх рабочего стола, без главной Stowa
  Future<void> open(
    WidgetTester tester, {
    LaunchAction action = LaunchAction.compose,
    String? carried,
    PrivacyLock? lock,
    Future<List<PickedFile>> Function()? takePhoto,
  }) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    finished = 0;
    opened.clear();
    // прошлый тест мог оставить приложение «свёрнутым»
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...world.overrides, if (lock != null) startLockProvider.overrideWithValue(lock)],
        child: StowaApp(
          locale: const Locale('ru'),
          lockable: false,
          home: QuickHost(
            action: () async => action,
            carried: () async => carried,
            takePhoto: takePhoto ?? () async => const [],
            openNote: (id) async => opened.add(id),
            onFinish: () async => finished++,
          ),
        ),
      ),
    );
    await tester.pump();
    // повторный показ клавиатуры идёт через 450 мс после фокуса
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    // поиск ждёт паузу в наборе
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  Future<void> note(String id, String title) async {
    final at = world.now.subtract(const Duration(days: 3));
    await world.db.into(world.db.items).insert(
          ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(title), sortState: const Value(SortState.sorted), createdAt: at, updatedAt: at),
        );
  }

  Future<void> leave(WidgetTester tester) async {
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
  }

  Future<void> comeBack(WidgetTester tester) async {
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
  }

  bool lineFocused(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText).first).focusNode.hasFocus;

  testWidgets('окно прозрачное, без главной, строка сразу с клавиатурой', (tester) async {
    await open(tester);
    expect(find.byType(HomeScreen), findsNothing);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor, Colors.transparent);
    expect(lineFocused(tester), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(finished, 0);
  });

  testWidgets('закинул — заметка в базе, окно ждёт, пока уйдёт плашка, и закрывается', (tester) async {
    await open(tester);
    await type(tester, 'купить хлеб');
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.items).getSingle()).title, 'Купить хлеб');
    expect(find.text('Закинул'), findsOneWidget);
    expect(finished, 0);

    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('«Отменить» возвращает текст в строку, окно остаётся', (tester) async {
    await open(tester);
    await type(tester, 'купить хлеб');
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'купить хлеб');
    expect(finished, 0);
    // клавиатура просыпается с задержкой, как при открытии
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('касание мимо пустой строки закрывает окно', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(200, 120));
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('набранное не теряется от первого касания мимо: оно прячет клавиатуру, второе закрывает', (tester) async {
    await open(tester);
    await type(tester, 'купить хлеб');
    await tester.tapAt(const Offset(200, 120));
    await tester.pumpAndSettle();
    expect(finished, 0);
    expect(lineFocused(tester), isFalse);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'купить хлеб');

    await tester.tapAt(const Offset(200, 120));
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('рабочий стол под строкой затемнён сразу: живым он не выглядит', (tester) async {
    await open(tester);
    final shade = tester.widget<ColoredBox>(find.byKey(const ValueKey('quick-shade')));
    expect(shade.color.a, greaterThan(0.3));
    expect(shade.color.a, lessThan(0.7));
  });

  testWidgets('снимок с камеры касания мимо не теряют: окно остаётся', (tester) async {
    final photo = File(p.join(world.files.path, 'shot.jpg'))..writeAsBytesSync([1, 2, 3]);
    await open(tester, action: LaunchAction.camera, takePhoto: () async => [PickedFile(path: photo.path, mime: 'image/jpeg', size: 3)]);
    await tester.pumpAndSettle();
    for (var tap = 0; tap < 3; tap++) {
      await tester.tapAt(const Offset(200, 120));
      await tester.pumpAndSettle();
    }
    expect(finished, 0);
    expect(find.text('Закинуть'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('из полки «Под рукой» по «+»: набранное там уже в строке, лоток открыт', (tester) async {
    await open(tester, action: LaunchAction.attach, carried: 'купить хлеб');
    // на открытом лотке крутилка галереи: pumpAndSettle не дождётся
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AttachTray), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text, 'купить хлеб');
    expect(finished, 0);
  });

  testWidgets('из полки «Под рукой» без набранного — просто строка', (tester) async {
    await open(tester, carried: null);
    expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text, isEmpty);
  });

  testWidgets('строка без поиска его и не обещает: ни «или найди», ни «Похожего нет»', (tester) async {
    await open(tester, lock: locked);
    expect(find.text('Закинь что угодно'), findsOneWidget);
    expect(find.text('Закинь что угодно или найди'), findsNothing);
    await type(tester, 'купить батарейки');
    expect(find.text('Похожего нет, это новое'), findsNothing);
    expect(find.text('Закинуть'), findsWidgets);
  });

  testWidgets('найденная заметка открывается в приложении, окно закрывается', (tester) async {
    await note('visa', 'Загранпаспорт и виза');
    await open(tester);
    await type(tester, 'виза');
    expect(find.text('Нашлось 1'), findsOneWidget);

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(opened, ['visa']);
    expect(finished, 1);
  });

  testWidgets('с кодом на вход строка только закидывает: поиска с рабочего стола нет', (tester) async {
    await note('visa', 'Загранпаспорт и виза');
    await open(tester, lock: locked);
    await type(tester, 'виза');
    expect(find.text('Нашлось 1'), findsNothing);
    expect(find.textContaining('Загранпаспорт'), findsNothing);
    expect(find.text('Закинуть'), findsWidgets);
  });

  testWidgets('скрытые папки открыты в приложении — поиска с рабочего стола тоже нет', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'secret', name: 'Секрет', icon: 'lock', shape: 'pill', hidden: const Value(true)));
    await note('visa', 'Загранпаспорт и виза');
    await open(tester);
    await type(tester, 'виза');
    expect(find.text('Нашлось 1'), findsNothing);
    expect(find.textContaining('Загранпаспорт'), findsNothing);
  });

  // папка, правило в неё и тег: всё, что строка могла бы назвать чужому
  Future<void> shelf() async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'shop', name: 'Покупки', icon: 'shopping_basket', shape: 'pill'));
    await world.db.into(world.db.rules).insert(
          RulesCompanion.insert(id: 'milk', conditionKind: RuleConditionKind.keyword, conditionValue: 'молоко', actionKind: RuleActionKind.toFolder, actionValue: 'shop'),
        );
    await world.db.into(world.db.tags).insert(TagsCompanion.insert(id: 'food', name: 'еда', createdAt: world.now));
  }

  testWidgets('без кода строка говорит, куда положит, и подсказывает папки', (tester) async {
    await shelf();
    await open(tester);
    expect(find.text('@'), findsOneWidget);
    await type(tester, 'купить молоко');
    expect(find.textContaining('Покупки'), findsWidgets);
    await type(tester, '@пок');
    expect(find.textContaining('Покупки'), findsWidgets);
  });

  testWidgets('с кодом на вход строка папку не называет: кладёт по правилу молча', (tester) async {
    await shelf();
    await open(tester, lock: locked);
    await type(tester, 'купить молоко');
    expect(find.textContaining('Покупки'), findsNothing);
    expect(find.textContaining('молоко»'), findsNothing);
    // «без папки» было бы неправдой: заметка ляжет по правилу
    expect(find.textContaining('без папки'), findsNothing);

    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    expect(find.text('Закинул'), findsOneWidget);
    expect(find.textContaining('Покупки'), findsNothing);
    expect((await world.db.select(world.db.items).getSingle()).folderId, 'shop');
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pumpAndSettle();
  });

  testWidgets('с кодом на вход «@» и «#» не показывают, какие папки и теги есть', (tester) async {
    await shelf();
    await open(tester, lock: locked);
    expect(find.text('@'), findsNothing);
    expect(find.text('#'), findsOneWidget);

    await type(tester, '@пок');
    expect(find.textContaining('Покупки'), findsNothing);
    expect(find.text('Создать'), findsNothing);
    // и фоном «@пок» не подсвечен: папкой он здесь не станет
    final field = find.byType(EditableText).first;
    expect(tester.widget<EditableText>(field).controller.buildTextSpan(context: tester.element(field), withComposing: false).children, isNull);

    // имя целиком с пробелом чипом не встаёт: иначе по чипу видно, что такая папка есть
    await type(tester, '@покупки ');
    expect(find.textContaining('Покупки'), findsNothing);

    await type(tester, 'хлеб #ед');
    expect(find.textContaining('еда'), findsNothing);
    expect(find.text('Создать'), findsWidgets);
  });

  testWidgets('с кодом на вход редактор на весь экран папку не предлагает', (tester) async {
    await shelf();
    await open(tester, lock: locked);
    await type(tester, 'купить молоко');
    await tester.tap(find.byTooltip('На весь экран'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dest')), findsNothing);
    expect(find.textContaining('Покупки'), findsNothing);
  });

  testWidgets('скрытые папки открыты — строка с рабочего стола папку тоже не называет', (tester) async {
    await shelf();
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'secret', name: 'Секрет', icon: 'lock', shape: 'pill', hidden: const Value(true)));
    await open(tester);
    await type(tester, 'купить молоко');
    expect(find.textContaining('Покупки'), findsNothing);
    await type(tester, '@сек');
    expect(find.textContaining('Секрет'), findsNothing);
  });

  testWidgets('микрофон виджета без доступа: окно говорит об этом и закрывается', (tester) async {
    // телефон отказал в микрофоне: без подмены ответ плагина пришёл бы только в настоящем времени
    const recorder = MethodChannel('com.llfbandit.record/messages');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(recorder, (call) async => call.method == 'hasPermission' ? false : null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(recorder, null));
    await open(tester, action: LaunchAction.voice);
    expect(find.text('Нет доступа к микрофону'), findsOneWidget);
    expect(lineFocused(tester), isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(finished, 1);
  });

  testWidgets('камера виджета: снимок встаёт вложением, строка ждёт подпись', (tester) async {
    final photo = File(p.join(world.files.path, 'shot.jpg'))..writeAsBytesSync([1, 2, 3]);
    await open(tester, action: LaunchAction.camera, takePhoto: () async => [PickedFile(path: photo.path, mime: 'image/jpeg', size: 3)]);
    await tester.pumpAndSettle();
    expect(find.text('Закинуть'), findsWidgets);
    expect(lineFocused(tester), isTrue);
    expect(finished, 0);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('камеру закрыли без снимка — окно закрывается', (tester) async {
    await open(tester, action: LaunchAction.camera);
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('ушли на рабочий стол — окно закрывается, набранное с собой не тащит', (tester) async {
    await open(tester);
    await leave(tester);
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('своё окно (камера, выбор файла) — не уход: окно ждёт возвращения', (tester) async {
    await open(tester);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'stowa/window',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('ownWindow')),
      (_) {},
    );
    await leave(tester);
    await comeBack(tester);
    expect(finished, 0);

    await leave(tester);
    await tester.pumpAndSettle();
    expect(finished, 1);
  });
}
