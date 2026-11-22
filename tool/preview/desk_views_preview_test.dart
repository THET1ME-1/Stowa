// Кадр шапки папки на мониторе: переключатель видов «Доска · Холст · Список».
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/desk_views_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/workspace/workspace_model.dart';
import 'package:stowa/features/workspace/workspace_shell.dart';

import '../../test/helpers/test_app.dart';

void main() {
  setUpAll(() async {
    for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
      final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
      await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  testWidgets('desk_views', (tester) async {
    final world = TestWorld();
    addTearDown(world.dispose);
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'k', name: 'Курсы', icon: 'school', shape: 'gem'));
    for (final title in ['Основы программирования', 'История права', 'Линейная алгебра']) {
      await world.db.into(world.db.items).insert(
        ItemsCompanion.insert(id: title, kind: ItemKind.note, title: title, body: Value('$title\nтемы'), folderId: const Value('k'), createdAt: world.now, updatedAt: world.now),
      );
    }
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: world.app()));
    await tester.pumpAndSettle();
    WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!.open(const WsTab.folder('k'));
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/previews').createSync(recursive: true);
      File('build/previews/desk_views.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
