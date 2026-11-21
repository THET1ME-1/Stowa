import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/widget_snapshot.dart';

import '../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  /// Что приложение отдало Swift: тексты `widget.json` по порядку.
  List<Map<String, Object?>> fakeWidgetChannel(WidgetTester tester) {
    final written = <Map<String, Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(widgetChannel, (call) async {
      if (call.method == 'write') written.add(jsonDecode(call.arguments as String) as Map<String, Object?>);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(widgetChannel, null));
    return written;
  }

  Future<void> note(String id, String title) {
    final at = world.now;
    return world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(title), createdAt: at, updatedAt: at),
    );
  }

  /// Дать базе и паузе службы пройти: база живёт в настоящем времени.
  Future<void> settle(WidgetTester tester) async {
    for (var step = 0; step < 4; step++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('при запуске и после правки заметки виджет получает свежий файл', (tester) async {
    final written = fakeWidgetChannel(tester);
    final sync = WidgetSync(world.db, locked: () => false)..start();
    addTearDown(sync.dispose);
    await settle(tester);
    expect(written, hasLength(1));
    expect(written.last['notes'], isEmpty);
    await tester.runAsync(() => note('buy', 'Купить молоко'));
    await settle(tester);
    expect(written, hasLength(2));
    expect(((written.last['notes'] as List).single as Map)['title'], 'Купить молоко');
  });

  testWidgets('замок включили — файл переписывается без заметок', (tester) async {
    final written = fakeWidgetChannel(tester);
    await tester.runAsync(() => note('wifi', 'Пароль от Wi‑Fi'));
    var locked = false;
    final sync = WidgetSync(world.db, locked: () => locked)..start();
    addTearDown(sync.dispose);
    await settle(tester);
    expect(written.last['notes'], hasLength(1));
    locked = true;
    sync.refresh();
    await settle(tester);
    expect(written.last['locked'], true);
    expect(written.last['notes'], isEmpty);
  });

  // HyperOS убивает процесс смахиванием: текст не должен ждать паузу и остаться на столе
  testWidgets('замок — файл без заметок пишется сразу, без паузы', (tester) async {
    final written = fakeWidgetChannel(tester);
    await tester.runAsync(() => note('wifi', 'Пароль от Wi‑Fi'));
    var locked = false;
    final sync = WidgetSync(world.db, locked: () => locked)..start();
    addTearDown(sync.dispose);
    await settle(tester);
    locked = true;
    sync.refresh(now: true);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    expect(written.last['locked'], true);
  });

  testWidgets('замок включили, пока виджет читал заметки, — последним ложится закрытый файл', (tester) async {
    final written = fakeWidgetChannel(tester);
    await tester.runAsync(() => note('wifi', 'Пароль от Wi‑Fi'));
    var locked = false;
    final sync = WidgetSync(world.db, locked: () => locked);
    addTearDown(sync.dispose);
    // первая запись ждёт базу, вторая — закрытая и сразу
    sync.refresh(now: true);
    locked = true;
    sync.refresh(now: true);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(written, hasLength(2));
    expect(written.last['locked'], true);
    expect(written.last['notes'], isEmpty);
  });
}
