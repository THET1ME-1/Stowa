import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/app.dart';
import 'package:stowa/core/theme/folder_palette.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/spine_colors.dart';
import 'package:stowa/features/composer/attach_tray.dart';
import 'package:stowa/features/edge/edge_host.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/features/settings/edge_screen.dart';
import 'package:stowa/services/edge_channel.dart';
import 'package:stowa/services/privacy/privacy_service.dart';
import 'package:stowa/services/privacy/seal_crypto.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> note(String id, String title, {String? folder, bool pinned = false, int minutes = 1}) async {
    final at = world.now.subtract(Duration(minutes: minutes));
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(
        id: id,
        kind: ItemKind.note,
        title: title,
        body: Value(title),
        folderId: Value(folder),
        sortState: const Value(SortState.sorted),
        pinnedAt: Value(pinned ? at : null),
        createdAt: at,
        updatedAt: at,
      ),
    );
  }

  // код на вход включён: ключи замка полке не нужны, только сам флажок
  const locked = PrivacyLock(
    keys: LockFile(salt: [], kdf: KdfSettings(memoryKib: 256, passes: 1), publicKey: [], wrapped: []),
    appLock: true,
  );

  /// Окно полки стоит, полка за краем — как сразу после запуска службы.
  Future<void> start(WidgetTester tester, {PrivacyLock? lock}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...world.overrides, if (lock != null) startLockProvider.overrideWithValue(lock)],
        child: const StowaApp(locale: Locale('ru'), lockable: false, home: EdgeHost()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Коснулись корешков: полка выехала.
  Future<void> open(WidgetTester tester, {PrivacyLock? lock}) async {
    await start(tester, lock: lock);
    world.edge.send(const EdgeOpen());
    await tester.pumpAndSettle();
  }

  Finder inShelf(String text) => find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.text(text, findRichText: true));

  // экран 1080×2400 при 2,75: корешки справа, полка 312 с отступом 8 от края
  const screenWidth = 1080 / 2.75;
  const openLeft = screenWidth - 8 - 312;
  Rect shelf(WidgetTester tester) => tester.getRect(find.byKey(const ValueKey('edge-shelf')));

  testWidgets('полка: шапка, папки, «Закреплено» и «Недавние», заметка один раз', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'dacha', name: 'Дача', icon: 'cottage', shape: 'pill', color: const Value('amber')));
    await note('wifi', 'Wi‑Fi на даче', folder: 'dacha', pinned: true);
    await note('milk', 'Купить молоко', minutes: 5);
    await open(tester);
    expect(inShelf('Stowa'), findsOneWidget);
    expect(inShelf('Дача'), findsWidgets);
    expect(inShelf('Закреплено'), findsOneWidget);
    expect(inShelf('Недавние'), findsOneWidget);
    expect(inShelf('Wi‑Fi на даче'), findsOneWidget);
    expect(inShelf('Купить молоко'), findsOneWidget);
    // строка ввода — та же, что в приложении
    expect(find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.byKey(const ValueKey('composer'))), findsOneWidget);
  });

  testWidgets('кнопка в углу карточки вешает стикер, «Открыть Stowa» ведёт в приложение', (tester) async {
    await note('wifi', 'Wi‑Fi на даче', pinned: true);
    await open(tester);
    await tester.tap(find.byTooltip('Повесить стикером'));
    await tester.pumpAndSettle();
    expect(world.edge.calls, contains('pinSticker:wifi'));
    // полка уходит: стикер встаёт поверх самого приложения
    expect(world.edge.calls.last, 'close');
    world.edge.send(const EdgeOpen());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Открыть Stowa'));
    await tester.pumpAndSettle();
    expect(world.edge.calls, contains('openApp:null'));
  });

  testWidgets('касание карточки открывает заметку в самой полке, «назад» возвращает к полке', (tester) async {
    await note('wifi', 'Wi‑Fi на даче', pinned: true);
    await open(tester);
    await tester.tap(inShelf('Wi‑Fi на даче'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.byType(ItemScreen)), findsOneWidget);
    expect(world.edge.calls.where((call) => call.startsWith('openApp')), isEmpty);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsNothing);
    expect(inShelf('Закреплено'), findsOneWidget);
  });

  testWidgets('«+» в полке отдаёт лоток окну виджета вместе с набранным: камере и файлам нужно окно приложения', (tester) async {
    await open(tester);
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.byType(TextField)), 'купить хлеб');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Прикрепить'));
    await tester.pumpAndSettle();
    expect(world.edge.calls, contains('handOff:attach:купить хлеб'));
    expect(find.byType(AttachTray), findsNothing);
    // набранное ушло в окно виджета: в полке его больше нет, второй раз не сохранится
    expect(tester.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.byType(EditableText))).controller.text, isEmpty);
  });

  testWidgets('карточку унесли за край полки: полка отъезжает, отпустил — стикер там, где отпустили', (tester) async {
    await note('wifi', 'Wi‑Fi на даче', pinned: true);
    await open(tester);
    final card = find.byKey(const ValueKey('edge-card-wifi'));
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-160, 120));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // полка уехала, чтобы было видно, куда кладёшь
    expect(shelf(tester).left, greaterThan(openLeft + 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(world.edge.calls.where((call) => call.startsWith('pinSticker:wifi@')), hasLength(1));
    expect(world.edge.calls.last, 'close');
  });

  testWidgets('карточку подержали и отпустили в полке — меню действий, стикера нет', (tester) async {
    await note('wifi', 'Wi‑Fi на даче', pinned: true);
    await open(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('edge-card-wifi'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(world.edge.calls.where((call) => call.startsWith('pinSticker')), isEmpty);
  });

  testWidgets('микрофон без права: запись уходит в окно виджета, там спросят разрешение', (tester) async {
    world.edge.micAnswer = false;
    await open(tester);
    await tester.tap(find.byTooltip('Записать голосовое'));
    await tester.pumpAndSettle();
    expect(world.edge.calls, contains('micGranted'));
    expect(world.edge.calls, contains('handOff:voice:'));
  });

  testWidgets('«Рядом»: заметка, чьё напоминание по месту только что сработало, — первой и один раз', (tester) async {
    await note('wifi', 'Wi‑Fi на даче', pinned: true);
    await note('milk', 'Купить молоко', minutes: 5);
    world.edge.nearbyAnswer = ['milk'];
    await open(tester);
    expect(inShelf('Рядом'), findsOneWidget);
    expect(inShelf('Купить молоко'), findsOneWidget);
    final nearby = tester.getTopLeft(inShelf('Рядом')).dy;
    expect(nearby, lessThan(tester.getTopLeft(inShelf('Закреплено')).dy));
    expect(tester.getTopLeft(inShelf('Купить молоко')).dy, lessThan(tester.getTopLeft(inShelf('Закреплено')).dy));
  });

  testWidgets('без сработавших мест раздела «Рядом» нет', (tester) async {
    await note('milk', 'Купить молоко', minutes: 5);
    await open(tester);
    expect(inShelf('Рядом'), findsNothing);
    expect(world.edge.calls, contains('nearby'));
  });

  testWidgets('буфер в полке читается только по касанию подсказки: Android сообщает о каждом чтении', (tester) async {
    final platform = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platform.add(call.method);
      return switch (call.method) {
        'Clipboard.hasStrings' => {'value': true},
        'Clipboard.getData' => {'text': 'https://example.com/recipe'},
        _ => null,
      };
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await open(tester);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.byType(TextField)));
    await tester.pumpAndSettle();
    expect(platform, contains('Clipboard.hasStrings'));
    expect(platform, isNot(contains('Clipboard.getData')));
    await tester.tap(find.text('Вставить из буфера'));
    await tester.pumpAndSettle();
    expect(platform, contains('Clipboard.getData'));
    expect(tester.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.byType(EditableText))).controller.text, 'https://example.com/recipe');
  });

  testWidgets('свайп вниз по корешкам: полка выезжает, строка сразу в фокусе', (tester) async {
    await start(tester);
    world.edge.send(const EdgeOpen(typing: true));
    await tester.pumpAndSettle();
    expect(shelf(tester).left, moreOrLessEquals(openLeft, epsilon: 0.5));
    final field = tester.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.byType(EditableText)));
    expect(field.focusNode.hasFocus, isTrue);
  });

  testWidgets('двойное касание корешков: полка сразу с последней открытой заметкой', (tester) async {
    await note('wifi', 'Wi‑Fi на даче', pinned: true);
    await note('milk', 'Купить молоко', minutes: 5);
    await world.db.customStatement("UPDATE items SET opened_at = '2026-11-14T10:00:00.000' WHERE id = 'milk'");
    await start(tester);
    world.edge.send(const EdgeOpenLast());
    await tester.pumpAndSettle();
    expect(shelf(tester).left, moreOrLessEquals(openLeft, epsilon: 0.5));
    expect(find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.byType(ItemScreen)), findsOneWidget);
    expect(find.text('Купить молоко'), findsWidgets);
  });

  testWidgets('удержание без права на микрофон: запись уходит в окно виджета, там спросят разрешение', (tester) async {
    world.edge.micAnswer = false;
    await start(tester);
    world.edge.send(const EdgeVoiceStart());
    await tester.pumpAndSettle();
    expect(world.edge.calls, contains('handOff:voice:'));
    expect(find.byKey(const ValueKey('edge-voice')), findsNothing);
  });

  testWidgets('полка подтверждает службе, что выезжает: без ответа служба уберёт окно сама', (tester) async {
    await start(tester);
    world.edge.send(const EdgeOpen());
    await tester.pump();
    expect(world.edge.calls, contains('opened'));
    await tester.pumpAndSettle();
    world.edge.calls.clear();
    world.edge.send(const EdgeDragStart());
    await tester.pump();
    expect(world.edge.calls, isNot(contains('opened')));
    world.edge.send(const EdgeDismiss());
    await tester.pumpAndSettle();
    world.edge.calls.clear();
    world.edge.send(const EdgeDragStart());
    await tester.pump();
    expect(world.edge.calls, contains('opened'));
  });

  testWidgets('окно убрала служба («Открыть Stowa», камера) — следующее касание снова выдвигает полку', (tester) async {
    await note('wifi', 'Wi‑Fi на даче', pinned: true);
    await open(tester);
    await tester.tap(inShelf('Wi‑Fi на даче'));
    await tester.pumpAndSettle();
    world.edge.send(const EdgeClosed());
    await tester.pumpAndSettle();
    // полка за краем и снова на своей первой странице
    expect(shelf(tester).left, greaterThanOrEqualTo(screenWidth));
    expect(find.byType(ItemScreen), findsNothing);
    world.edge.calls.clear();
    world.edge.send(const EdgeOpen());
    await tester.pump();
    expect(world.edge.calls, contains('opened'));
    await tester.pumpAndSettle();
    expect(shelf(tester).left, moreOrLessEquals(openLeft, epsilon: 0.5));
  });

  /// Плагин записи без телефона: вызовы пишутся, «stop» отдаёт [recorded] — путь готового файла.
  List<String> fakeRecorder(WidgetTester tester, {String? recorded}) {
    final calls = <String>[];
    const channel = MethodChannel('com.llfbandit.record/messages');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        // плагин слушает состояние записи по своему каналу событий с id записи
        case 'create':
          final id = (call.arguments as Map)['recorderId'];
          tester.binding.defaultBinaryMessenger.setMockStreamHandler(
            EventChannel('com.llfbandit.record/events/$id'),
            MockStreamHandler.inline(onListen: (arguments, events) {}),
          );
          return null;
        case 'getAmplitude':
          return {'current': -40.0, 'max': -20.0};
        case 'stop':
          return recorded;
        default:
          return null;
      }
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  // папка записи и файл — на диске: в поддельном времени теста это не идёт, нужно настоящее
  Future<void> realTime(WidgetTester tester, [int frames = 10]) async {
    for (var frame = 0; frame < frames; frame++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder voice() => find.byKey(const ValueKey('edge-voice'));

  testWidgets('удержание: у корешков плашка записи, полка не выезжает; отпустил — запись идёт дальше', (tester) async {
    final recorder = fakeRecorder(tester);
    await start(tester);
    world.edge.send(const EdgeVoiceStart());
    await realTime(tester);
    expect(voice(), findsOneWidget);
    expect(recorder, contains('start'));
    // без службы с микрофоном Android глушит запись из окна поверх
    expect(world.edge.calls, contains('recording:true'));
    expect(shelf(tester).left, greaterThanOrEqualTo(screenWidth));
    world.edge.send(const EdgeVoiceStop());
    await realTime(tester, 4);
    // руки свободны: запись не останавливается и не уходит сама
    expect(recorder, isNot(contains('stop')));
    expect(voice(), findsOneWidget);
    await tester.tap(find.descendant(of: voice(), matching: find.byTooltip('Отменить запись')));
    await realTime(tester, 6);
  });

  testWidgets('«Сохранить» на плашке: голосовое легло, плашка и окно уходят', (tester) async {
    final file = File(p.join(world.files.path, 'voice.m4a'));
    await tester.runAsync(() => file.writeAsBytes(List.filled(64, 1)));
    final recorder = fakeRecorder(tester, recorded: file.path);
    await start(tester);
    world.edge.send(const EdgeVoiceStart());
    await realTime(tester);
    world.edge.send(const EdgeVoiceStop());
    await realTime(tester, 3);
    await tester.tap(find.descendant(of: voice(), matching: find.byTooltip('Сохранить')));
    await realTime(tester, 8);
    expect(recorder, contains('stop'));
    final saved = await tester.runAsync(() => world.db.select(world.db.items).get());
    expect(saved!.map((item) => item.title), contains('Голосовое'));
    // «Голосовое легло» видно чуть меньше секунды, потом плашка уезжает
    expect(find.descendant(of: voice(), matching: find.text('Голосовое легло')), findsOneWidget);
    await realTime(tester, 30);
    expect(voice(), findsNothing);
    // окно убрано; следом ещё приходят цвета корешков — новая заметка в базе
    expect(world.edge.calls, contains('close'));
    expect(world.edge.calls.where((call) => call.startsWith('recording')).last, 'recording:false');
  });

  testWidgets('«Отменить запись» на плашке: ничего не сохранено, окно уходит', (tester) async {
    final recorder = fakeRecorder(tester);
    await start(tester);
    world.edge.send(const EdgeVoiceStart());
    await realTime(tester);
    await tester.tap(find.descendant(of: voice(), matching: find.byTooltip('Отменить запись')));
    await realTime(tester, 10);
    expect(recorder, contains('cancel'));
    expect(world.edge.calls.where((call) => call.startsWith('recording')).last, 'recording:false');
    final saved = await tester.runAsync(() => world.db.select(world.db.items).get());
    expect(saved, isEmpty);
    expect(voice(), findsNothing);
    expect(world.edge.calls.last, 'close');
  });

  testWidgets('запись кнопкой микрофона в полке: строка записи помещается в узкую полку', (tester) async {
    fakeRecorder(tester);
    await open(tester);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.byTooltip('Записать голосовое')));
    await realTime(tester);
    expect(find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.byTooltip('Отменить запись')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(world.edge.calls, contains('recording:true'));
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.byTooltip('Отменить запись')));
    await realTime(tester, 6);
    expect(world.edge.calls.where((call) => call.startsWith('recording')).last, 'recording:false');
  });

  testWidgets('шестерёнка открывает настройку корешков в самой полке', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Настроить корешки'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('edge-shelf')), matching: find.byType(EdgeScreen)), findsOneWidget);
  });

  testWidgets('касание корешков: полка выезжает из-за края, «Свернуть» уводит её и только потом убирает окно', (tester) async {
    await note('wifi', 'Wi‑Fi на даче', pinned: true);
    await start(tester);
    expect(shelf(tester).left, greaterThanOrEqualTo(screenWidth));
    world.edge.send(const EdgeOpen());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // на полпути: уже видна, но ещё не на месте
    expect(shelf(tester).left, lessThan(screenWidth));
    expect(shelf(tester).left, greaterThan(openLeft + 1));
    await tester.pumpAndSettle();
    expect(shelf(tester).left, moreOrLessEquals(openLeft, epsilon: 0.5));

    await tester.tap(find.byTooltip('Свернуть'));
    await tester.pump();
    expect(world.edge.calls, contains('closing'));
    expect(world.edge.calls, isNot(contains('close')));
    await tester.pumpAndSettle();
    expect(world.edge.calls.last, 'close');
    expect(shelf(tester).left, greaterThanOrEqualTo(screenWidth));
  });

  testWidgets('свайп: полка идёт за пальцем, отпустил дальше трети — доезжает', (tester) async {
    await start(tester);
    world.edge.send(const EdgeDragStart());
    world.edge.send(const EdgeDrag(312 * 0.4));
    await tester.pump();
    // ровно за пальцем, без догоняния: из-за края вышло столько, сколько прошёл палец
    expect(shelf(tester).left, moreOrLessEquals(openLeft + 320 - 312 * 0.4, epsilon: 0.5));
    world.edge.send(const EdgeDragEnd(0));
    await tester.pumpAndSettle();
    expect(shelf(tester).left, moreOrLessEquals(openLeft, epsilon: 0.5));
    expect(world.edge.calls, isNot(contains('close')));
  });

  testWidgets('свайп: отпустил ближе трети — полка возвращается за край и окно убирается', (tester) async {
    await start(tester);
    world.edge.send(const EdgeDragStart());
    world.edge.send(const EdgeDrag(312 * 0.2));
    await tester.pump();
    world.edge.send(const EdgeDragEnd(0));
    await tester.pumpAndSettle();
    expect(shelf(tester).left, greaterThanOrEqualTo(screenWidth));
    expect(world.edge.calls.last, 'close');
  });

  testWidgets('свайп: быстрый короткий бросок внутрь открывает полку', (tester) async {
    await start(tester);
    world.edge.send(const EdgeDragStart());
    world.edge.send(const EdgeDrag(312 * 0.15));
    world.edge.send(const EdgeDragEnd(900));
    await tester.pumpAndSettle();
    expect(shelf(tester).left, moreOrLessEquals(openLeft, epsilon: 0.5));
  });

  testWidgets('полку тянут к краю — уходит за пальцем и закрывается', (tester) async {
    await open(tester);
    final gesture = await tester.startGesture(shelf(tester).center);
    // первый сдвиг уходит на порог жеста, дальше полка идёт ровно за пальцем
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(140, 0));
    await tester.pump();
    expect(shelf(tester).left, moreOrLessEquals(openLeft + 140, epsilon: 0.5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(shelf(tester).left, greaterThanOrEqualTo(screenWidth));
    expect(world.edge.calls.last, 'close');
  });

  testWidgets('касание мимо полки и «назад» от службы её сворачивают', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();
    expect(world.edge.calls.last, 'close');

    world.edge.send(const EdgeOpen());
    await tester.pumpAndSettle();
    world.edge.calls.clear();
    world.edge.send(const EdgeDismiss());
    await tester.pumpAndSettle();
    expect(world.edge.calls.last, 'close');
  });

  testWidgets('«Убрать анимацию» в системе: полка сразу на месте', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await start(tester);
    world.edge.send(const EdgeOpen());
    await tester.pump();
    await tester.pump();
    expect(shelf(tester).left, moreOrLessEquals(openLeft, epsilon: 0.5));
  });

  testWidgets('корешки получают цвета папок закреплённых заметок', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'dacha', name: 'Дача', icon: 'cottage', shape: 'pill', color: const Value('amber')));
    await note('wifi', 'Wi‑Fi на даче', folder: 'dacha', pinned: true);
    await open(tester);
    expect(world.edge.calls, contains('spines'));
    expect(world.edge.lastSpines.single.color, FolderPalette.of('amber', 0));
  });

  testWidgets('замок: заметок на полке нет, корешок один — цвета папок не выдают закреплённое', (tester) async {
    await note('wifi', 'Wi‑Fi на даче', pinned: true);
    await open(tester, lock: locked);
    expect(inShelf('Wi‑Fi на даче'), findsNothing);
    expect(inShelf('Закреплено'), findsNothing);
    expect(world.edge.lastSpines, hasLength(1));
    expect(world.edge.lastSpines.single, isA<Spine>());
  });
}
