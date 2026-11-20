import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/domain/backup_nudge.dart';
import 'package:stowa/features/web/copy_nudge.dart';
import 'package:stowa/l10n/app_localizations.dart';

void main() {
  Future<void> show(WidgetTester tester, {required BackupNudge nudge, bool weak = false, VoidCallback? onSave, VoidCallback? onLater, double width = 900}) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: CopyNudge(nudge: nudge, storageWeak: weak, onSave: onSave ?? () {}, onLater: onLater ?? () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('копии ещё не было: предупреждение, что заметки только в этом браузере, и две кнопки', (tester) async {
    var saved = 0;
    var later = 0;
    await show(tester, nudge: BackupNudge.first, onSave: () => saved++, onLater: () => later++);
    expect(find.text('Заметки лежат только в этом браузере: сохраните копию, чтобы их не потерять.'), findsOneWidget);
    await tester.tap(find.text('Сохранить копию'));
    await tester.tap(find.text('Позже'));
    expect((saved, later), (1, 1));
  });

  testWidgets('копия устарела — напоминание короче', (tester) async {
    await show(tester, nudge: BackupNudge.stale);
    expect(find.text('Копия заметок устарела: сохраните свежую.'), findsOneWidget);
    expect(find.text('Сохранить копию'), findsOneWidget);
  });

  testWidgets('напоминать не о чем — плашки нет вовсе, места она не занимает', (tester) async {
    await show(tester, nudge: BackupNudge.none);
    expect(find.text('Сохранить копию'), findsNothing);
    expect(tester.getSize(find.byType(CopyNudge)).height, 0);
  });

  testWidgets('браузер не дал надёжного хранилища — отдельное предупреждение без кнопок', (tester) async {
    await show(tester, nudge: BackupNudge.none, weak: true);
    expect(find.text('Браузер не дал надёжного хранилища: заметки могут пропасть, когда вкладку закроют.'), findsOneWidget);
    expect(find.text('Позже'), findsNothing);
  });

  testWidgets('на узком окне кнопки уходят под текст и ничего не вылезает', (tester) async {
    await show(tester, nudge: BackupNudge.first, weak: true, width: 320);
    expect(tester.takeException(), isNull);
    expect(find.text('Сохранить копию'), findsOneWidget);
  });
}
