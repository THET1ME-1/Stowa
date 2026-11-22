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

  testWidgets('компьютер: вместо просьбы о доступе — одна вкладка «Файл» с выбором любых файлов', (tester) async {
    var media = 0, files = 0;
    await show(
      tester,
      AttachTray(gallery: false, camera: false, selected: const [], onToggle: (_, _) {}, onPickMedia: () => media++, onCamera: () {}, onVideo: () {}, onFiles: () => files++, onLink: () {}),
    );
    expect(find.textContaining('Дай доступ'), findsNothing);
    expect(find.text('Разрешить'), findsNothing);
    // камеры у компьютера в лотке нет: кнопка открыла бы то же окно выбора файла
    expect(find.byTooltip('Камера'), findsNothing);
    expect(find.byTooltip('Видео'), findsNothing);
    // хозяин 22.11 со снимка: «зачем 2 кнопки, что делают одно и то же» — «Фото и видео» и
    // «Файл» на компьютере открывали одно окно. Остаётся одна вкладка, окно берёт любые файлы
    expect(find.byTooltip('Фото и видео'), findsNothing);
    expect(find.byTooltip('Файл'), findsOneWidget);
    expect(find.textContaining('файлы'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tray-pick')));
    await tester.pump();
    expect((media, files), (0, 1));
  });

  testWidgets('сайт на телефоне: галереи нет, а камера есть; фото и файлы — разными окнами', (tester) async {
    var media = 0;
    await show(
      tester,
      AttachTray(gallery: false, camera: true, selected: const [], onToggle: (_, _) {}, onPickMedia: () => media++, onCamera: () {}, onVideo: () {}, onFiles: () {}, onLink: () {}),
    );
    expect(find.byTooltip('Камера'), findsOneWidget);
    expect(find.byTooltip('Фото и видео'), findsOneWidget);
    expect(find.byTooltip('Файл'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tray-pick')));
    await tester.pump();
    expect(media, 1);
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
