import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/composer/attach_tray.dart';
import 'package:stowa/features/composer/line_dock.dart';

import '../../helpers/test_app.dart';

// хозяин 22.11 со снимка сайта: лоток «+» пишет «Дай доступ к фото», «Разрешить» нажал —
// «не работает». Галерею читает телефонный плагин, в браузере и на компьютере её нет:
// просить доступ там не у кого, фото выбирают обычным окном выбора файлов
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> show(WidgetTester tester, Widget tray) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(Scaffold(body: tray)));
    await tester.pumpAndSettle();
  }

  testWidgets('галереи нет (сайт, компьютер): вместо просьбы о доступе — выбор фото окном', (tester) async {
    var picked = 0;
    await show(
      tester,
      AttachTray(gallery: false, camera: false, selected: const [], onToggle: (_, _) {}, onPickMedia: () => picked++, onCamera: () {}, onVideo: () {}, onFiles: () {}, onLink: () {}),
    );
    expect(find.textContaining('Дай доступ'), findsNothing);
    expect(find.text('Разрешить'), findsNothing);
    // камеры у компьютера в лотке нет: кнопка открыла бы то же окно выбора файла
    expect(find.byTooltip('Камера'), findsNothing);
    expect(find.byTooltip('Видео'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tray-pick')));
    await tester.pump();
    expect(picked, 1);
  });

  testWidgets('сайт на телефоне: галереи нет, а камера есть', (tester) async {
    await show(
      tester,
      AttachTray(gallery: false, camera: true, selected: const [], onToggle: (_, _) {}, onPickMedia: () {}, onCamera: () {}, onVideo: () {}, onFiles: () {}, onLink: () {}),
    );
    expect(find.byKey(const ValueKey('tray-pick')), findsOneWidget);
    expect(find.byTooltip('Камера'), findsOneWidget);
  });

  testWidgets('сайт: лоток строки открывается с выбором фото, а не с просьбой о доступе', (tester) async {
    world.inBrowser = true;
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    tester.state<LineDockState>(find.byType(LineDock)).openTray();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tray-pick')), findsOneWidget);
    expect(find.text('Разрешить'), findsNothing);
  });
}
