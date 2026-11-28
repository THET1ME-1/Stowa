// Снимки для магазинов: настоящее приложение в симуляторе iPhone.
// Собирается: flutter build ios --simulator --debug --no-tree-shake-icons --target=integration_test/store_shots_test.dart
// Запускается прогоном .github/workflows/ios-store-screenshots.yml.
// Язык задаётся при запуске: -AppleLanguages "(ru)" или "(en)".
// Демо-данные подбираются по языку приложения автоматически.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stowa/app.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/hints_repository.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/hints.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/home/folder_shelf.dart';
import 'package:stowa/features/home/note_timeline.dart';
import 'package:stowa/features/settings/settings_blocks.dart';
import 'package:stowa/l10n/app_localizations.dart';
import 'package:stowa/main.dart' as app;

class _Demo {
  _Demo.ru()
      : folders = [
          ('recipes', 'Рецепты', 'restaurant', 'cookie9'),
          ('work', 'Работа', 'work', 'squircle'),
          ('gifts', 'Подарки Кате', 'redeem', 'gem'),
          ('travel', 'Путешествие', 'flight_takeoff', 'pill'),
        ],
        tags = [
          ('t1', 'рецепт', 'restaurant', true),
          ('t2', 'работа', 'work', true),
          ('t3', 'идея', 'lightbulb', true),
          ('t4', 'кино', 'movie', true),
        ],
        items = [
          _Item('i1', 'Борщ бабушкин', 'Свёкла 2 шт, капуста, морковь, картошка\nВарить час на медленном огне', 'recipes', ['t1']),
          _Item('i2', 'Сырники на рисовой муке', 'Творог 500 г, рисовая мука, яйцо\nЖарить на среднем', 'recipes', ['t1']),
          _Item('i3', 'Паста с тыквой и шалфеем', 'Тыква, пармезан, сливки, шалфей\nЗапечь тыкву 30 мин, смешать с пастой', 'recipes', ['t1']),
          _Item('i4', 'Встреча с дизайнером в пятницу', 'Обсудить новый логотип\nПоказать мудборд', 'work', ['t2']),
          _Item('i5', 'Идея: голосовые заметки', 'Сказал в машине — легло в «Задачи»\nРаспознавание прямо на телефоне', null, ['t3']),
          _Item('i6', 'Наушники Sony WH-1000XM5', 'Шумоподавление, 30 часов, складные', 'gifts', []),
          _Item('i7', 'Билеты в Стамбул', 'Вылет 15 декабря 06:40\n- [ ] Паспорт\n- [ ] Переходник для розетки\n- [ ] Страховка', 'travel', []),
          _Item('i8', 'Дюна', '# Дюна\nЧитаю вторую часть, первая зашла за три вечера', null, ['t4']),
        ],
        rules = [
          ('r1', 'keyword', 'рецепт', 'addTag', 't1'),
          ('r2', 'hasTag', 't1', 'toFolder', 'recipes'),
        ];

  _Demo.en()
      : folders = [
          ('recipes', 'Recipes', 'restaurant', 'cookie9'),
          ('work', 'Work', 'work', 'squircle'),
          ('gifts', 'Gifts for Kate', 'redeem', 'gem'),
          ('travel', 'Travel', 'flight_takeoff', 'pill'),
        ],
        tags = [
          ('t1', 'recipe', 'restaurant', true),
          ('t2', 'work', 'work', true),
          ('t3', 'idea', 'lightbulb', true),
          ('t4', 'movie', 'movie', true),
        ],
        items = [
          _Item('i1', 'Grandma\'s borsch', 'Beetroot, cabbage, carrots, potatoes\nSimmer for an hour on low heat', 'recipes', ['t1']),
          _Item('i2', 'Rice flour pancakes', 'Cottage cheese 500 g, rice flour, egg\nFry on medium', 'recipes', ['t1']),
          _Item('i3', 'Pumpkin sage pasta', 'Pumpkin, parmesan, cream, sage\nRoast pumpkin 30 min, toss with pasta', 'recipes', ['t1']),
          _Item('i4', 'Meeting with designer on Friday', 'Discuss the new logo\nShow the moodboard', 'work', ['t2']),
          _Item('i5', 'Idea: voice notes', 'Said it in the car — lands in Tasks\nOn-device recognition', null, ['t3']),
          _Item('i6', 'Sony WH-1000XM5 headphones', 'Noise cancelling, 30 hours, foldable', 'gifts', []),
          _Item('i7', 'Istanbul tickets', 'Departure Dec 15 at 06:40\n- [ ] Passport\n- [ ] Power adapter\n- [ ] Insurance', 'travel', []),
          _Item('i8', 'Dune', '# Dune\nReading part two, finished part one in three evenings', null, ['t4']),
        ],
        rules = [
          ('r1', 'keyword', 'recipe', 'addTag', 't1'),
          ('r2', 'hasTag', 't1', 'toFolder', 'recipes'),
        ];

  final List<(String id, String name, String icon, String shape)> folders;
  final List<(String id, String name, String icon, bool pinned)> tags;
  final List<_Item> items;
  final List<(String id, String condKind, String condVal, String actKind, String actVal)> rules;
}

class _Item {
  const _Item(this.id, this.title, this.body, this.folderId, this.tagIds);
  final String id, title, body;
  final String? folderId;
  final List<String> tagIds;
}

Future<void> _seed(AppDatabase db, _Demo demo, DateTime now) async {
  for (final (index, f) in demo.folders.indexed) {
    await db.into(db.folders).insert(FoldersCompanion.insert(
      id: f.$1,
      name: f.$2,
      icon: f.$3,
      shape: f.$4,
      sortOrder: Value(index),
    ));
  }
  for (final (id, name, icon, pinned) in demo.tags) {
    await db.into(db.tags).insert(TagsCompanion.insert(
      id: id,
      name: name,
      createdAt: now,
      pinned: Value(pinned),
      pinOrder: Value(int.parse(id.substring(1))),
      iconValue: Value(icon),
    ));
  }
  for (final (index, item) in demo.items.indexed) {
    await db.into(db.items).insert(ItemsCompanion.insert(
      id: item.id,
      kind: ItemKind.note,
      title: item.title,
      body: Value('${item.title}\n${item.body}'),
      folderId: Value(item.folderId),
      createdAt: now.subtract(Duration(minutes: 100 - index * 10)),
      updatedAt: now,
      pinnedAt: Value(item.id == 'i4' ? now.subtract(const Duration(hours: 1)) : null),
      reminderAt: Value(item.id == 'i7' ? now.add(const Duration(days: 17)) : null),
    ));
    for (final tagId in item.tagIds) {
      await db.into(db.itemTags).insert(ItemTagsCompanion.insert(
        itemId: item.id,
        tagId: tagId,
        source: TagSource.user,
      ));
    }
  }
  for (final (index, r) in demo.rules.indexed) {
    await db.into(db.rules).insert(RulesCompanion.insert(
      id: r.$1,
      conditionKind: RuleConditionKind.values.firstWhere((e) => e.name == r.$2),
      conditionValue: r.$3,
      actionKind: RuleActionKind.values.firstWhere((e) => e.name == r.$4),
      actionValue: r.$5,
      sortOrder: Value(index),
    ));
  }
}

/// Генерирует простую картинку-заглушку для обложки.
Future<File> _gradientPhoto(String path, Color from, Color to) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const rect = Rect.fromLTWH(0, 0, 400, 400);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        colors: [from, to],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect),
  );
  canvas.drawCircle(const Offset(260, 160), 80, Paint()..color = Colors.white.withValues(alpha: 0.3));
  final image = await recorder.endRecording().toImage(400, 400);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(png!.buffer.asUint8List());
  return file;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('снимки для магазина', (tester) async {
    final folder = Directory('${Directory.systemTemp.path}/store-shots')..createSync(recursive: true);
    final lines = <String>[];

    Future<void> wait() async {
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    Future<void> shot(String name) async {
      final request = File('${folder.path}/$name.request')..writeAsStringSync('');
      for (var tick = 0; tick < 300 && request.existsSync(); tick++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (request.existsSync()) {
        request.deleteSync();
        lines.add('MISS $name');
      } else {
        lines.add('ok $name');
      }
    }

    Future<void> home() async {
      appNavigator.currentState?.popUntil((route) => route.isFirst);
      await wait();
      final line = find.byType(TextField);
      if (line.evaluate().length == 1) {
        tester.binding.focusedEditable = null;
        await tester.enterText(line, '');
      }
      await tester.binding.handlePopRoute();
      await tester.binding.handlePopRoute();
      await wait();
    }

    try {
      await app.main();
      for (var tick = 0; tick < 240 && find.byType(TextField).evaluate().isEmpty; tick++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (find.byType(TextField).evaluate().isEmpty) throw StateError('главная не открылась');
      await wait();

      // язык определяется из живого приложения
      final scaffold = find.byType(Scaffold).first;
      final l = L.of(tester.element(scaffold));
      final isRu = l.localeName == 'ru';
      final lang = isRu ? 'ru' : 'en';

      // база живого приложения
      final container = ProviderScope.containerOf(tester.element(scaffold));
      final db = container.read(databaseProvider);
      final filesRoot = container.read(filesRootProvider);
      final now = DateTime.now();
      final demo = isRu ? _Demo.ru() : _Demo.en();

      // убрать онбординг и баннер «Возвращать сохранённое?»
      await container.read(hintsRepositoryProvider).restore(HintsState.finished);
      await container.read(settingsRepositoryProvider).setReturnsAsked();
      await wait();

      // обложки к рецептам
      final covers = <String, String>{};
      final colors = [
        (const Color(0xFFB86B4B), const Color(0xFFE8B07A)),
        (const Color(0xFF3F6F5A), const Color(0xFF9CC9A0)),
        (const Color(0xFF5B5F97), const Color(0xFFB8B5E8)),
      ];
      for (var i = 0; i < 3; i++) {
        final rel = 'attachments/i${i + 1}/0_photo.png';
        await _gradientPhoto('${filesRoot.path}/$rel', colors[i].$1, colors[i].$2);
        covers['i${i + 1}'] = rel;
      }

      await _seed(db, demo, now);

      // обложки
      for (final entry in covers.entries) {
        await db.into(db.attachments).insert(AttachmentsCompanion.insert(
          id: 'a${entry.key}',
          itemId: entry.key,
          path: entry.value,
          mime: 'image/png',
          size: 1,
        ));
        await (db.update(db.items)..where((t) => t.id.equals(entry.key))).write(const ItemsCompanion(kind: Value(ItemKind.image)));
      }

      // ждём обновления ленты после засева
      await wait();
      await wait();
      await wait();

      // 1. Главная с лентой
      await shot('$lang-01-home');

      // 2. Папка «Рецепты» доской
      final recipeName = demo.folders.first.$2;
      final pill = find.descendant(of: find.byType(FolderPill), matching: find.text(recipeName));
      if (pill.evaluate().isEmpty) {
        final more = find.textContaining(isRu ? 'Ещё' : 'More');
        if (more.evaluate().isNotEmpty) {
          await tester.tap(more.first);
          await wait();
        }
      }
      if (pill.evaluate().isNotEmpty) {
        await tester.tap(pill.first);
        await wait();
      }
      await shot('$lang-02-folder');
      await home();

      // 3. Страница заметки — тапаем по закреплённой «Встреча/Meeting»
      final noteTitle = demo.items[3].title;
      final noteCard = find.text(noteTitle);
      if (noteCard.evaluate().isNotEmpty) {
        await tester.tap(noteCard.first);
        await wait();
        await wait();
        await shot('$lang-03-note');
        await home();
      }

      // 4. Поиск
      final line = find.byType(TextField);
      tester.binding.focusedEditable = null;
      await tester.enterText(line, isRu ? 'паста' : 'pasta');
      await wait();
      await shot('$lang-04-search');
      tester.binding.focusedEditable = null;
      await tester.enterText(line, '');
      await tester.binding.handlePopRoute();
      await tester.binding.handlePopRoute();
      await wait();

      // 5. Редактор на весь экран
      final line2 = find.byType(TextField);
      tester.binding.focusedEditable = null;
      await tester.enterText(line2, isRu
          ? '# Поездка в Грецию\n- [ ] паспорт\n- [ ] переходник\n- [ ] страховка\n**Вылет** в пятницу'
          : '# Trip to Greece\n- [ ] passport\n- [ ] adapter\n- [ ] insurance\n**Departure** on Friday');
      await wait();
      await wait();
      final expand = find.byTooltip(l.fullExpand);
      if (expand.evaluate().isNotEmpty) {
        await tester.tap(expand.first);
        await wait();
        await wait();
      }
      await shot('$lang-05-editor');
      await home();

      // 6. Каталог
      await tester.tap(find.byTooltip(l.catalogTitle));
      await wait();
      await shot('$lang-06-catalog');
      await home();

      // 7. Настройки → Оформление
      await tester.tap(find.byTooltip(l.settingsTitle));
      await wait();
      final lookRow = find.widgetWithText(SettingsRow, l.appearanceTitle);
      await tester.scrollUntilVisible(lookRow, 240, scrollable: find.byType(Scrollable).first);
      await wait();
      await tester.tap(lookRow);
      await wait();
      await shot('$lang-07-themes');
      await home();

      // 8. Теги и правила
      await tester.tap(find.byTooltip(l.settingsTitle));
      await wait();
      final tagsRow = find.widgetWithText(SettingsRow, l.settingsTooltip);
      await tester.scrollUntilVisible(tagsRow, 240, scrollable: find.byType(Scrollable).first);
      await tester.tap(tagsRow);
      await wait();
      await shot('$lang-08-tags');
      await home();

    } catch (error) {
      lines.add('FAIL: ${'$error'.split('\n').first}');
      await shot('error');
    } finally {
      File('${folder.path}/result.txt').writeAsStringSync([...lines, 'done', ''].join('\n'));
    }
  });
}
