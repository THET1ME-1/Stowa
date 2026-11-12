import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/launch_actions.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester, {String? initial}) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(launchChannel, (call) async => call.method == 'initial' ? initial : null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(launchChannel, null));
    await tester.pumpWidget(world.app());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> note() => world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Купить кофе', createdAt: world.now, updatedAt: world.now));

  bool lineFocused(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText).first).focusNode.hasFocus;

  testWidgets('касание уведомления по месту открывает заметку', (tester) async {
    await note();
    await open(tester, initial: 'open:note:a');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Править'), findsOneWidget);
    expect(find.text('Купить кофе'), findsWidgets);
  });

  testWidgets('заметка из окна виджета открывается в приложении, которое уже живо', (tester) async {
    await note();
    await open(tester);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      launchChannel.name,
      launchChannel.codec.encodeMethodCall(const MethodCall('open', 'open:note:a')),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Править'), findsOneWidget);
  });

  testWidgets('обычный запуск строку не трогает', (tester) async {
    await open(tester);
    expect(lineFocused(tester), isFalse);
  });

  testWidgets('кнопки виджета главную не будят: у них своё окно', (tester) async {
    await open(tester, initial: 'compose');
    expect(lineFocused(tester), isFalse);
  });
}
