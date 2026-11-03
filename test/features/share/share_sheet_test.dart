import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/app.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/features/home/home_screen.dart';
import 'package:stowa/features/share/share_receiver.dart';
import 'package:stowa/features/share/share_sheet.dart';
import 'package:stowa/services/share_intake.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  var finished = 0;

  // окно «Поделиться»: только лист поверх чужого приложения, без главной Stowa
  Future<void> share(WidgetTester tester, List<SharedPiece> pieces) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    finished = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: world.overrides,
        child: StowaApp(
          locale: const Locale('ru'),
          home: ShareHost(load: () async => pieces, onFinish: () async => finished++),
        ),
      ),
    );
    // сохранение и выезд листа, но меньше трёх секунд отсчёта
    for (var step = 0; step < 8; step++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }


  const link = [
    SharedPiece(value: 'Паста с креветками', kind: SharedKind.text),
    SharedPiece(value: 'https://vt.tiktok.com/ZSpasta15/', kind: SharedKind.url),
  ];

  testWidgets('окно «Поделиться» прозрачное и без главной', (tester) async {
    await share(tester, link);
    expect(find.byType(HomeScreen), findsNothing);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor, Colors.transparent);
  });

  testWidgets('отсчёт начинается, когда лист выехал целиком, ручка одна', (tester) async {
    await share(tester, link);
    expect(find.text('3'), findsOneWidget);
    // своя ручка уже нарисована, системная лишняя
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle, isFalse);
  });

  testWidgets('ничего не прислали — окно сразу закрывается', (tester) async {
    await share(tester, const []);
    expect(find.text('Сохранено'), findsNothing);
    expect(finished, 1);
  });

  testWidgets('присланное уже сохранено, лист закрывается сам через три секунды', (tester) async {
    await share(tester, link);
    expect(find.text('Сохранено'), findsOneWidget);
    expect(find.text('пока без папки'), findsOneWidget);
    expect((await world.db.select(world.db.items).getSingle()).url, 'https://vt.tiktok.com/ZSpasta15/');

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Сохранено'), findsNothing);
    expect(finished, 1);
  });

  testWidgets('выбрал папку и дописал пару слов — легло туда с этими словами', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Рецепты', icon: 'restaurant', shape: 'cookie9'));
    await share(tester, link);
    await tester.tap(find.descendant(of: find.byType(ShareSheet), matching: find.text('Рецепты')));
    await tester.pumpAndSettle();
    expect(find.text('в папке «Рецепты»'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Добавить пару слов'), 'на ужин в пятницу');
    // отсчёт стоит, пока человек что-то делает
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Сохранено'), findsOneWidget);
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    final item = await world.db.select(world.db.items).getSingle();
    expect(item.folderId, 'food');
    expect(item.body, endsWith('на ужин в пятницу'));
  });
}
