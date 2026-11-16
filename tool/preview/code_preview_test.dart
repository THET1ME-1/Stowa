// Кадры заметки с блоками кода, тёмная и светлая тема. Моноширинный шрифт телефона в тестах
// подменяет Noto Sans Mono системы (на Android «monospace» — тот же Droid/Noto Mono).
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/code_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/core/theme/palette.dart';
import 'package:stowa/core/theme/tokens.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/appearance.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/l10n/app_localizations.dart';

import '../../test/helpers/test_app.dart';

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  final mono = File('/usr/share/fonts/truetype/noto/NotoSansMono-Regular.ttf');
  if (mono.existsSync()) await (FontLoader('monospace')..addFont(Future.value(ByteData.sublistView(mono.readAsBytesSync())))).load();
}

const _body = '''Шпаргалка по Python
Сортировка списка словарей по ключу, `sorted` возвращает новый список:

```python
def by_age(people):
    # младшие первыми
    return sorted(people, key=lambda p: p["age"])

print(by_age([{"age": 30}, {"age": 7}]))  # [{'age': 7}, ...]
```

Запрос к базе:

```sql
SELECT name, COUNT(*) AS total
FROM orders
WHERE created_at > '2026-01-01'
GROUP BY name;
```

```
Он так работает
```

```dataviewjs
const это = dv.current();
const ключи = [это["Ключи"] ?? []].flat().map(k => String(k).toLowerCase());
const папки = [это["Папки"] ?? []].flat().map(String);
const страницы = dv.pages('"01 Конспекты" or "02 База знаний"')
  .where(p => p.file.path !== это.file.path)
  .where(p => !папки.length || папки.includes(p.file.folder.split("/").pop()));
const строки = [];
for (const p of страницы) {
  const текст = (await dv.io.load(p.file.path)) ?? "";
  const найдено = ключи.filter(k => текст.toLowerCase().includes(k));
  if (найдено.length) строки.push([p.file.link, найдено.join(", ")]);
}
dv.table(["Заметка", "Ключи"], строки);
// ещё строки, чтобы блок свернулся
// 1
// 2
// 3
// 4
// 5
// 6
// 7
```''';

void main() {
  setUpAll(_loadFonts);
  for (final (name, choice) in [('code_dark', ThemeChoice.dark), ('code_light', ThemeChoice.light)]) {
    testWidgets(name, (tester) async {
      final world = TestWorld();
      addTearDown(world.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(392, 2000);
      addTearDown(tester.view.reset);
      final palette = paletteFor(Appearance(choice: choice), choice == ThemeChoice.light ? Brightness.light : Brightness.dark);
      Tokens.use(palette);
      addTearDown(() => Tokens.use(StowaPalette.graphiteDark));
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Шпаргалка по Python', body: const Value(_body), createdAt: world.now, updatedAt: world.now));
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: world.overrides,
          child: MaterialApp(
            theme: buildAppTheme(palette),
            locale: const Locale('ru'),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: const ItemScreen(id: 'a'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/previews').createSync(recursive: true);
        File('build/previews/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
    });
  }
}
