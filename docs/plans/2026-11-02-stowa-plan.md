# Stowa: план разработки

> **Исполнителю:** план идёт задача за задачей, шаги отмечаются галочками (`- [ ]`). Каждая веха заканчивается рабочим приложением, которое можно поставить на телефон.

> **Сделано (2 ноября 2026):** задачи 0.1, 0.2, 1.1, 1.2, 1.3, 1.4. Отступления от текста ниже: название Stowa (`app.stowa`, шрифты `StowaSymbols` и `StowaSymbolsFilled`); языков семь, шаблон словаря английский; поиск живёт в строке ввода (задачи 5.1–5.2 и 1.4 читать вместе с экраном 2 описания); поисковый индекс сам приводит «ё» к «е» (`normalizeSearchText`). Напоминание из даты в тексте («23 декабря 13:00 зубной») сделано уже в 1.3–1.4 (`reminder_parser.dart`), в 8.1 остаются только уведомления. `ComposerBar` сохраняет сам (`ComposerBar({line, focusNode, onSaved})`), текст строки держит `LineController`: дописанный `#тег ` уходит в чип, дата подчёркнута и встаёт чипом «Напомню …». Вложения принимают всё: фото и видео из галереи, съёмку фото и видео, файлы любого формата (`picked_files.dart`, незнакомый тип ложится как `application/octet-stream`). Живая строка перенесена из прототипа целиком раньше своих задач: поиск в строке (5.1–5.2), правила тегов и папок без сети в `CaptureService` (задача правил, без экрана настройки), голосовое без расшифровки, галерея над строкой, редактор на весь экран, страница вещи в простом виде. Плагины и «Скан» не делаются: первые после версии 1.0 по описанию, второй требует ML Kit.

**Цель:** Android-приложение на Flutter, которое сохраняет что угодно мгновенно и само раскладывает по папкам и тегам: правилами без сети и ИИ по ключу пользователя.

**Устройство:** local-first. База Drift (SQLite + FTS5) на телефоне, состояние Riverpod, чистая логика в `lib/domain` без Flutter и покрыта тестами. Сеть нужна только ИИ-клиенту, превью ссылок и боту Telegram; всё сетевое идёт из очереди в фоне и никогда не держит сохранение.

**Стек:** Flutter 3.47.6, flutter_riverpod, drift + sqlite3_flutter_libs, http, flutter_secure_storage, connectivity_plus, workmanager, flutter_local_notifications + timezone + flutter_timezone, image_picker, file_picker, flutter_image_compress, record, just_audio, receive_sharing_intent, home_widget, material_new_shapes, html, archive, share_plus, uuid, url_launcher, path_provider. Версии ставит `flutter pub add` на момент задачи.

**Описание:** `docs/specs/2026-11-02-stowa-design.md`. Макет: `design/mockup/Stowa.html`. План спорит с описанием, а не с памятью: при сомнении открыть описание.

## Общие требования

- Flutter 3.47.6, Android, `minSdk` 26, `applicationId` `app.stowa`.
- Сохранение вещи: строка очищается меньше чем за 100 мс от нажатия, без единого сетевого вызова на этом пути.
- ИИ только по ключу пользователя. Ключ в `flutter_secure_storage`, адрес поставщика по умолчанию `https://openrouter.ai/api/v1`, протокол OpenAI chat completions.
- Никаких моделей на телефоне.
- Ручное решение главнее: `sortedBy == SortedBy.user` ИИ и правила не перезаписывают.
- Имя тега: нижний регистр, без `#`, края обрезаны, пробелы внутри заменены на `_`.
- В ИИ уходит текст не длиннее 6000 знаков и картинка не больше 1024 px по длинной стороне, JPEG качества 80.
- Все id — UUID v4 с телефона. Удаление мягкое (`deletedAt`), чистка корзины через 30 дней.
- Тема: тёмный графит и белый, токены из таблицы описания, шрифты Unbounded и Onest, теней нет, листы снизу.
- Строки интерфейса через `gen-l10n`, семь языков (`lib/l10n/app_{ru,en,uk,ro,pl,de,es}.arb`), шаблон английский. Новую строку добавляет `tool/add_strings.py`, русский и английский обязательны. Русского текста в `lib/features` и `lib/domain` нет.
- Код: имена полными словами без сокращений, стиль Dart (`lowerCamelCase`), комментарий одной короткой строкой над важным блоком.
- APK: `Stowa-<версия>-<abi>.apk`, сборка выпуска только в CI, с `--no-tree-shake-icons`.
- Коммиты по-русски: заголовок что изменилось для человека, ниже абзац зачем. Работа прямо в `main`, пуш после каждой задачи.

## На что смотреть при проверке

1. **Модель ответила мусором:** не JSON, обрезанный JSON, выдуманный id папки, тег не строкой. Вещь остаётся «Не разобрано», ошибка в журнале, приложение не падает. Тесты в задаче 6.2.
2. **Ключ неверный или кончились деньги** (401, 402, 403, 429). Очередь не долбит поставщика: после 401/402/403 очередь на паузе до смены ключа, после 429 пауза по `retry-after`. На главной видно «Разбор на паузе». Тесты в задаче 6.3.
3. **Человек разложил вещь, пока она ждала ИИ.** Пришедший ответ не трогает папку и теги, только добавляет описание для поиска. Тест в задаче 6.3.
4. **Огромная вставка:** текст на 50 000 знаков, фото на 12 Мп, PDF на 30 МБ. Сохранение такое же мгновенное, в ИИ уходит урезанное. Тесты в задачах 1.3 и 7.2.
5. **Один тег разными буквами:** «#Машина », «машина», «МАШИНА». Это один тег, второй не заводится. Тесты в задачах 2.1 и 2.2.

---

## Карта файлов

```
lib/
  main.dart                      запуск, ProviderScope, инициализация фона
  app.dart                       MaterialApp, тема, маршруты
  core/
    theme/tokens.dart            цвета графитовой темы из описания
    theme/app_theme.dart         ThemeData по M3-ДНК поверх токенов
    theme/shapes.dart            формы значков (печенька, сквиркл, самоцвет, пилюля)
    icons/icon_registry.dart     имя иконки → кодовая точка шрифта StowaSymbols
    widgets/                     общие виджеты: pressable.dart, shape_badge.dart, tag_chip.dart, sheet.dart
  data/
    db/tables.dart               таблицы Drift
    db/schema.drift              FTS5 и триггеры
    db/database.dart             AppDatabase, миграции
    repositories/                items, folders, tags, rules, links, ai_jobs, word_stats
    providers.dart               провайдеры Riverpod
    settings.dart                настройки (shared_preferences) и ключ (secure storage)
  domain/                        чистый Dart, без Flutter
    models.dart                  перечисления и модели
    tag_name.dart                normalizeTagName
    inline_tags.dart             #теги из текста
    item_kind.dart               вид вещи по содержимому
    reminder_parser.dart         русские даты
    rules_engine.dart            правила
    suggestion_stats.dart        подсказки без сети
    search_query.dart            разбор строки поиска
    ai_contract.dart             запрос и ответ ИИ
    link_preview_parser.dart     og-теги и oEmbed
    live_markdown.dart           раскраска Markdown в поле ввода
    wiki_links.dart              [[ссылки]]
    canvas_layout.dart           начальная раскладка холста
    graph_layout.dart            раскладка графа
    telegram_updates.dart        разбор getUpdates
  services/
    capture_service.dart         единая точка «сохранить вещь»
    ai_client.dart               HTTP-клиент поставщика
    ai_worker.dart               очередь разбора
    link_preview_service.dart    загрузка превью
    media_service.dart           картинки, миниатюры, файлы
    voice_service.dart           запись и расшифровка
    reminder_service.dart        уведомления
    share_service.dart           меню «Поделиться»
    telegram_service.dart        свой бот
    widget_service.dart          виджет рабочего стола
    backup_service.dart          резервная копия
    background.dart              workmanager: очередь ИИ и бот
  features/
    home/  composer/  editor/  folder/  item/  search/  tags/  sort_mode/  graph/  settings/
tool/build_icon_font.py           шрифт иконок из Material Symbols
test/                             зеркало lib/
```

---

## Веха 0. Каркас

### Задача 0.1: Проект, зависимости, тема, шрифты, иконки

**Файлы:**
- Создать: проект `flutter create --org app --project-name stowa --platforms android .`
- Создать: `lib/core/theme/tokens.dart`, `lib/core/theme/app_theme.dart`, `lib/core/theme/shapes.dart`, `lib/core/icons/icon_registry.dart`, `lib/core/widgets/shape_badge.dart`, `lib/core/widgets/pressable.dart`, `lib/app.dart`, `lib/main.dart`, `lib/l10n/app_ru.arb`, `l10n.yaml`, `tool/build_icon_font.py`, `assets/fonts/{Unbounded,Onest,StowaSymbols}.ttf`
- Изменить: `android/app/build.gradle.kts` (`applicationId = "app.stowa"`, `minSdk = 26`), `.gitignore`
- Тест: `test/core/theme_test.dart`, `test/core/icon_registry_test.dart`

**Интерфейсы:**
- Производит: `abstract final class Tokens { static const background = Color(0xFF141517); ... }` с полями `background, containerLow, container, containerHigh, containerHighest, graphite, outline, onSurface, onSurfaceVariant, muted, accent, onAccent`; `ThemeData buildAppTheme()`; `enum BadgeShape { cookie9, cookie6, squircle, gem, pill }`; `Path badgeShapePath(BadgeShape shape, Size size)`; `IconData symbolIcon(String name)`; `const symbolFontFamily = 'StowaSymbols'`.

- [ ] **Шаг 1.** `flutter create`, затем `flutter pub add flutter_riverpod drift sqlite3_flutter_libs path_provider path uuid http flutter_secure_storage shared_preferences connectivity_plus material_new_shapes intl` и `flutter pub add -d drift_dev build_runner material_symbols_icons`.
- [ ] **Шаг 2.** Шрифты: Unbounded и Onest скопировать из `~/Projects/GitHub/m3-dna/assets/fonts/`. `tool/build_icon_font.py` перенести из `~/Projects/GitHub/Veha/tool/build_icon_font.py` с заменой имён на `StowaSymbols` и реестра на `lib/core/icons/icon_registry.dart`. Набор полный (все иконки Material Symbols Rounded одним начертанием, ~1,7 МБ): тегу нужна любая иконка, белый список не годится.
- [ ] **Шаг 3. Тесты темы.**

```dart
test('фон и карточки берутся из токенов графита', () {
  final theme = buildAppTheme();
  expect(theme.brightness, Brightness.dark);
  expect(theme.scaffoldBackgroundColor, const Color(0xFF141517));
  expect(theme.colorScheme.surfaceContainerHigh, const Color(0xFF26272B));
  expect(theme.colorScheme.primary, const Color(0xFFF4F4F2));
  expect(theme.colorScheme.onPrimary, const Color(0xFF141517));
  expect(theme.cardTheme.elevation, 0);
});
test('иконка тега находится по имени', () {
  expect(symbolIcon('directions_car').fontFamily, 'StowaSymbols');
  expect(symbolIcon('нет_такой'), symbolIcon('label')); // запасная иконка
});
```

- [ ] **Шаг 4.** `flutter test test/core` — FAIL, функций нет.
- [ ] **Шаг 5.** `buildAppTheme()`: `ColorScheme.fromSeed(seedColor: Tokens.accent, brightness: Brightness.dark, dynamicSchemeVariant: DynamicSchemeVariant.monochrome)`, затем `copyWith` всех ролей из `Tokens`. Остальное по `~/Projects/GitHub/m3-dna/lib/theme/app_theme.dart`: кнопки `StadiumBorder` высотой 56, карточки радиус 28 с `elevation: 0`, поля с заливкой радиус 28 без рамки, `bottomSheetTheme` радиус 28 сверху, `textTheme` Onest, крупные заголовки Unbounded 700 с `letterSpacing: -0.5`. `badgeShapePath` считает контур так же, как макет (`design/mockup/template.html`, функция `shape_path`): печенька `r = half * (1 - depth * (1 + cos(n * angle)) / 2)`, `cookie9` n=9 depth=0.09, `cookie6` n=6 depth=0.12, `gem` n=5 depth=0.07, сквиркл степень 4, пилюля степень 2.4.
- [ ] **Шаг 6.** `flutter test test/core` — PASS. `flutter analyze` — без замечаний.
- [ ] **Шаг 7.** `app.dart`: `MaterialApp` с темой, локалью `ru`, пустым экраном «Stowa». Запуск на телефоне `flutter run`, глазами: фон графитовый, заголовок Unbounded.
- [ ] **Шаг 8.** Коммит «Каркас: тема графита, шрифты и набор иконок».

### Задача 0.2: CI

**Файлы:** создать `.github/workflows/check.yml`.

- [ ] **Шаг 1.** Workflow на push в `main`: `subosito/flutter-action` с `flutter-version: 3.47.6`, `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, `flutter test`.
- [ ] **Шаг 2.** Пуш, `gh run watch` — зелёный.
- [ ] **Шаг 3.** Коммит «CI: анализ и тесты на каждый пуш».

---

## Веха 1. База и мгновенное сохранение

### Задача 1.1: Модели и таблицы

**Файлы:**
- Создать: `lib/domain/models.dart`, `lib/data/db/tables.dart`, `lib/data/db/schema.drift`, `lib/data/db/database.dart`
- Тест: `test/data/database_test.dart`

**Интерфейсы:**
- Производит:
  - `enum ItemKind { note, link, video, image, file, voice }`
  - `enum SortState { pending, queued, sorted, failed }`
  - `enum SortedBy { none, rule, ai, user }`
  - `enum FolderView { auto, board, canvas, list }`
  - `enum TagIconKind { symbol, emoji, image }`
  - `enum RuleConditionKind { hasTag, domain, keyword, kind }`
  - `enum RuleActionKind { toFolder, addTag }`
  - `enum TagSource { user, inline, rule, ai }`
  - `enum LinkSource { manual, ai }`
  - Таблицы Drift: `Items(id, kind, title, body, url, folderId?, sortState, sortedBy, aiDescription?, transcript?, reminderAt?, createdAt, updatedAt, deletedAt?)`, `Attachments(id, itemId, path, mime, size, width?, height?, thumbPath?, position)`, `Folders(id, name, icon, shape, sortOrder, createdByAi, view, deletedAt?)`, `Tags(id, name UNIQUE, iconKind, iconValue, pinned, pinOrder, createdAt)`, `ItemTags(itemId, tagId, source, PRIMARY KEY(itemId, tagId))`, `Rules(id, conditionKind, conditionValue, actionKind, actionValue, enabled, sortOrder)`, `Links(fromId, toId, source, reason?, rejected, PRIMARY KEY(fromId, toId))`, `AiJobs(itemId PRIMARY KEY, kind, attempts, nextTryAt, lastError?)`, `AiLog(id, at, itemId?, request, response?, error?)`, `WordStats(word, targetKind, targetId, count, PRIMARY KEY(word, targetKind, targetId))`, `Corrections(id, itemId, fromFolderId?, toFolderId, at)`, `CanvasPositions(folderId, itemId, x, y, width, PRIMARY KEY(folderId, itemId))`
  - `schema.drift`: виртуальная таблица `items_fts USING fts5(title, body, ai_description, transcript, url, content='items', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2')` и три триггера (вставка, правка, удаление).
  - `class AppDatabase` с `AppDatabase.memory()` для тестов.

- [ ] **Шаг 1. Тесты.**

```dart
test('вещь пишется и находится полнотекстом', () async {
  final db = AppDatabase.memory();
  await db.into(db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Тарт с малиной', body: 'испечь в субботу', ...));
  final found = await db.searchIds('малин*');
  expect(found, ['a']);
});
test('тег с тем же именем не заводится второй раз', () async {
  final db = AppDatabase.memory();
  await db.into(db.tags).insert(TagsCompanion.insert(id: '1', name: 'машина', ...));
  expect(() => db.into(db.tags).insert(TagsCompanion.insert(id: '2', name: 'машина', ...)), throwsA(isA<SqliteException>()));
});
test('мягко удалённая вещь не ищется', () async { ... expect(await db.searchIds('малин*'), isEmpty); });
```

- [ ] **Шаг 2.** `flutter test test/data/database_test.dart` — FAIL.
- [ ] **Шаг 3.** Таблицы, `schema.drift`, `AppDatabase` (`drift_flutter` для открытия файла `stowa.sqlite` в папке документов), `Future<List<String>> searchIds(String ftsMatch)` с отбором `deletedAt IS NULL`. `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Шаг 4.** Тесты — PASS.
- [ ] **Шаг 5.** Коммит «База: вещи, папки, теги, правила, связи и полнотекстовый поиск».

### Задача 1.2: Вид вещи и теги из текста

**Файлы:** создать `lib/domain/tag_name.dart`, `lib/domain/inline_tags.dart`, `lib/domain/item_kind.dart`; тесты `test/domain/tag_name_test.dart`, `test/domain/inline_tags_test.dart`, `test/domain/item_kind_test.dart`.

**Интерфейсы:**
- Производит: `String normalizeTagName(String raw)`; `List<String> extractInlineTags(String text)` (уже нормализованные, без повторов, в порядке появления); `Uri? firstUrl(String text)`; `ItemKind detectKind({String text = '', String? mime})`.

- [ ] **Шаг 1. Тесты.**

```dart
expect(normalizeTagName('#Машина '), 'машина');
expect(normalizeTagName('МАШИНА'), 'машина');
expect(normalizeTagName('  ремонт кухни '), 'ремонт_кухни');
expect(extractInlineTags('купить #Шины и #шины, #машина!'), ['шины', 'машина']);
expect(extractInlineTags('цвет #FF0000 и почта a#b'), isEmpty); // хекс и середина слова не теги
expect(extractInlineTags('# Заголовок'), isEmpty);                // заголовок Markdown не тег
expect(detectKind(text: 'vm.tiktok.com/ZM8x'), ItemKind.video);
expect(detectKind(text: 'смотри https://youtu.be/abc'), ItemKind.video);
expect(detectKind(text: 'https://coffee-guide.ru/turka'), ItemKind.link);
expect(detectKind(text: 'код домофона 4512'), ItemKind.note);
expect(detectKind(mime: 'image/jpeg'), ItemKind.image);
expect(detectKind(mime: 'audio/mp4'), ItemKind.voice);
expect(detectKind(mime: 'application/pdf'), ItemKind.file);
```

- [ ] **Шаг 2.** Запуск — FAIL.
- [ ] **Шаг 3.** Реализация. Тег: `(?<![\p{L}\p{N}_#])#([\p{L}_][\p{L}\p{N}_]*)` с `unicode: true`; совпадение из шести шестнадцатеричных символов отбрасывается. Видео-домены: `tiktok.com`, `vm.tiktok.com`, `youtube.com`, `youtu.be`, `instagram.com/reel`. Адрес без схемы распознаётся, если домен с точкой и зоной из 2+ букв.
- [ ] **Шаг 4.** PASS.
- [ ] **Шаг 5.** Коммит «Вид вещи и теги из текста определяются сами».

### Задача 1.3: Сохранение вещи

**Файлы:** создать `lib/data/repositories/items_repository.dart`, `lib/data/repositories/tags_repository.dart`, `lib/services/capture_service.dart`, `lib/data/providers.dart`; тест `test/services/capture_service_test.dart`.

**Интерфейсы:**
- Потребляет: `normalizeTagName`, `extractInlineTags`, `detectKind`, `AppDatabase`.
- Производит:
  - `class CaptureInput { final String text; final List<PickedFile> files; final String? forcedFolderId; final List<String> forcedTagNames; final DateTime? forcedReminder; }`
  - `class PickedFile { final String path; final String mime; final int size; }`
  - `class CaptureService { Future<String> capture(CaptureInput input); }` — возвращает id вещи. Пишет вещь и теги одной транзакцией, файлы копирует после возврата (вещь видна сразу, вложение дорисуется), затем вызывает `afterCapture(itemId)` (пока пустой хук; в задачах 2.3, 4.2, 6.3 сюда встают правила, напоминания и очередь).
  - `ItemsRepository.watchRecent({int limit = 20}) → Stream<List<ItemCard>>`, `ItemsRepository.get(String id) → Future<ItemFull?>`
  - `TagsRepository.ensure(String rawName) → Future<Tag>` (находит или заводит, имя через `normalizeTagName`)

- [ ] **Шаг 1. Тесты.**

```dart
test('сохранение отдаёт id до копирования файлов и укладывается в 100 мс', () async {
  final stopwatch = Stopwatch()..start();
  final id = await capture.capture(CaptureInput(text: 'x' * 50000, files: [bigImage]));
  expect(stopwatch.elapsedMilliseconds, lessThan(100));
  expect((await items.get(id))!.body.length, 50000);
});
test('теги из текста ставятся с источником inline', ...
  expect(tagsOf(id), {'машина': TagSource.inline});
test('«#Машина» и «машина» дают один тег', ...
  expect(await db.tags.count().getSingle(), 1);
test('вид вещи по тексту: ссылка на tiktok даёт video', ...
```

- [ ] **Шаг 2.** FAIL. **Шаг 3.** Реализация. **Шаг 4.** PASS.
- [ ] **Шаг 5.** Коммит «Вещь сохраняется сразу, файлы докладываются следом».

### Задача 1.4: Главная и строка ввода

**Файлы:** создать `lib/features/home/home_screen.dart`, `lib/features/home/recent_strip.dart`, `lib/features/home/folders_grid.dart`, `lib/features/composer/composer_bar.dart`, `lib/features/composer/attach_sheet.dart`; тест `test/features/composer_bar_test.dart`.

**Интерфейсы:**
- Потребляет: `CaptureService.capture`, `ItemsRepository.watchRecent`, `FoldersRepository.watchAll` (заводится здесь: `Stream<List<FolderCard>>` с числом вещей и тремя последними картинками).
- Производит: `ComposerBar({required void Function(CaptureInput) onSend, VoidCallback? onExpand, Widget? panel})`.

- [ ] **Шаг 1. Виджет-тест.**

```dart
testWidgets('отправка очищает строку сразу', (tester) async {
  CaptureInput? sent;
  await tester.pumpWidget(wrap(ComposerBar(onSend: (input) => sent = input)));
  await tester.enterText(find.byType(TextField), 'код домофона 4512');
  await tester.tap(find.byKey(const Key('composer-send')));
  await tester.pump();
  expect(sent!.text, 'код домофона 4512');
  expect(find.text('код домофона 4512'), findsNothing);
});
testWidgets('пустая строка показывает микрофон, с текстом — отправку', ...
```

- [ ] **Шаг 2.** FAIL.
- [ ] **Шаг 3.** Вёрстка по экрану 1 макета: строка во всю ширину (контейнер `containerHighest`, радиус 28, ручка-полоска сверху), ряд кнопок «+», камера, раскрыть, белый круг 48 микрофон/отправка. «+» открывает лист: фото, файл, камера. Главная: шапка, «Только что» (карточки 132 шириной, листаются вбок), «Папки» плиткой в две колонки, первая большая с мозаикой. «Сегодня» и строка тегов — пустые места до вех 2 и 4. Плитки папок без тени, `container`, радиус 28, иконка в форме `BadgeShape`.
- [ ] **Шаг 4.** PASS. Запуск на телефоне: закинуть текст, фото, файл — карточки появляются в «Только что» сразу.
- [ ] **Шаг 5.** Коммит «Главная и строка ввода: закинул и вышел».

### Задача 1.5: Папки руками и страница вещи

**Файлы:** изменить `lib/data/repositories/folders_repository.dart` (заведён в задаче 1.4); создать `lib/features/item/item_screen.dart`, `lib/features/folder/folder_screen.dart`, `lib/features/folder/folder_sheet.dart`; тест `test/data/folders_repository_test.dart`.

**Интерфейсы:**
- Производит: `FoldersRepository.create({required String name, required String icon, required BadgeShape shape, bool createdByAi = false}) → Future<Folder>`, `rename`, `delete(String id)` (вещи уходят в «Без папки», `sortedBy` не меняется), `ItemsRepository.moveToFolder(String itemId, String? folderId, {required SortedBy by})` (при `by == SortedBy.user` пишет строку в `Corrections`), `ItemsRepository.delete(String id)` (мягко), `ItemsRepository.purgeDeleted(DateTime now)` (стирает вещи и их файлы, удалённые больше 30 дней назад; зовётся при запуске).

- [ ] **Шаг 1. Тесты.**

```dart
test('удаление папки оставляет вещи без папки', ...
  expect((await items.get(itemId))!.folderId, isNull);
test('ручной перенос пишется в исправления', ...
  expect(await db.corrections.count().getSingle(), 1);
test('чистка стирает только удалённое больше 30 дней назад', ...
```

- [ ] **Шаг 2–4.** FAIL → реализация → PASS. Подпись под карточкой в «Только что» открывает лист выбора папки. Страница вещи пока простая: заголовок, текст, вложения, папка чипом.
- [ ] **Шаг 5.** Коммит «Папки руками: завести, переложить, удалить».

---

## Веха 2. Теги и правила без сети

### Задача 2.1: Теги: иконки, закрепление, слияние

**Файлы:** изменить `lib/data/repositories/tags_repository.dart`; создать `lib/core/widgets/tag_chip.dart`, `lib/features/home/pinned_tags_row.dart`; тест `test/data/tags_repository_test.dart`.

**Интерфейсы:**
- Производит: `TagsRepository.create({required String name, required TagIconKind iconKind, required String iconValue, bool pinned = false})`, `update(String id, {String? name, TagIconKind? iconKind, String? iconValue, bool? pinned})`, `reorderPinned(List<String> idsInOrder)`, `delete(String id) → Future<DeletedTag>` (снимок для «Вернуть»), `restore(DeletedTag snapshot)`, `merge({required String fromId, required String intoId})`, `watchPinned() → Stream<List<TagCount>>`, `watchAll({TagSort sort}) → Stream<List<TagCount>>`; `enum TagSort { count, name, recent }`; `TagChip({required TagCount tag, bool showName = true, bool selected = false, bool excluded = false})`.

- [ ] **Шаг 1. Тесты.**

```dart
test('переименование в уже существующее имя сливает теги', ...
  expect(tagsOf(item), ['машина']);
test('слияние переносит вещи и удаляет исходный тег', ...
test('удаление и «Вернуть» восстанавливают тег у всех 9 вещей', ...
  expect(await countItemsWithTag('машина'), 9);
test('порядок закреплённых сохраняется', ...
```

- [ ] **Шаг 2–4.** FAIL → реализация → PASS. Строка закреплённых на главной: одна строка, `ListView` вбок, плитка-иконка 24 и число, в конце «+». Долгое нажатие показывает имя всплывашкой. Иконка: символ из `symbolIcon`, эмодзи текстом, своя картинка из папки приложения.
- [ ] **Шаг 5.** Коммит «Теги с иконками, закрепление на главной, слияние».

### Задача 2.2: Движок правил

**Файлы:** создать `lib/domain/rules_engine.dart`; тест `test/domain/rules_engine_test.dart`.

**Интерфейсы:**
- Производит:
  - `class Rule { final String id; final RuleConditionKind conditionKind; final String conditionValue; final RuleActionKind actionKind; final String actionValue; final bool enabled; final int sortOrder; }`
  - `class RuleInput { final Set<String> tagNames; final String? domain; final String text; final ItemKind kind; }`
  - `class RuleOutcome { final Set<String> addedTagNames; final String? folderId; final List<String> firedRuleIds; }`
  - `RuleOutcome applyRules(RuleInput input, List<Rule> rules)`

- [ ] **Шаг 1. Тесты.**

```dart
test('тег кладёт в папку', () {
  final outcome = applyRules(input(tags: {'машина'}), [rule(hasTag, 'машина', toFolder, 'f-car')]);
  expect(outcome.folderId, 'f-car');
});
test('домен ставит тег, а тег потом кладёт в папку за один проход', () {
  final outcome = applyRules(input(domain: 'vm.tiktok.com'), [
    rule(hasTag, 'видео', toFolder, 'f-video', order: 0),
    rule(domain, 'tiktok.com', addTag, 'видео', order: 1),
  ]);
  expect(outcome.addedTagNames, {'видео'});
  expect(outcome.folderId, 'f-video');
});
test('слово в тексте без учёта регистра и окончаний не ловит часть другого слова', () {
  expect(applyRules(input(text: 'Новый Пароль от wifi'), [rule(keyword, 'пароль', addTag, 'код')]).addedTagNames, {'код'});
  expect(applyRules(input(text: 'запаролить'), [rule(keyword, 'пароль', addTag, 'код')]).addedTagNames, isEmpty);
});
test('из двух правил папки побеждает первое по порядку', ...
test('выключенное правило не срабатывает', ...
test('условие по виду: картинки в «Референсы»', ...
```

- [ ] **Шаг 2.** FAIL.
- [ ] **Шаг 3.** Алгоритм: сначала все правила с действием `addTag` по порядку (условия видят теги, добавленные раньше в этом же проходе), затем первое сработавшее `toFolder`. Домен совпадает, если домен вещи равен условию или кончается на `.` + условие. Слово: граница слова `\b` с `unicode: true`, сравнение в нижнем регистре.
- [ ] **Шаг 4.** PASS.
- [ ] **Шаг 5.** Коммит «Правила: тег в папку, домен и слово в тег».

### Задача 2.3: Правила при сохранении, экраны тегов и правил

**Файлы:** создать `lib/data/repositories/rules_repository.dart`, `lib/features/tags/tags_screen.dart`, `lib/features/tags/tag_sheet.dart`, `lib/features/tags/rule_sheet.dart`, `lib/features/tags/icon_picker.dart`; изменить `lib/services/capture_service.dart`; тест `test/services/capture_rules_test.dart`.

**Интерфейсы:**
- Потребляет: `applyRules`, `TagsRepository`, `RulesRepository.all()`.
- Производит: в `afterCapture` правила применяются, вещь получает `sortedBy = SortedBy.rule` и `sortState = SortState.sorted`, если папка найдена.

- [ ] **Шаг 1. Тесты.**

```dart
test('вещь с #машина сразу ложится в «Машину» без сети', ...
  expect(item.folderId, carFolderId); expect(item.sortedBy, SortedBy.rule);
test('явно выбранная в строке папка главнее правил', ...
  expect(item.sortedBy, SortedBy.user);
```

- [ ] **Шаг 2–4.** FAIL → реализация → PASS. Экран 10 и лист 11 по макету: вкладки «Теги · Папки», закреплённые перетаскиваются (`ReorderableWrap` своими силами на `LongPressDraggable`), правила карточками «условие → действие», «Новое правило». Лист тега: имя, сегменты «Иконки · Эмодзи · Своя картинка», сетка иконок 6 в ряд с поиском по имени по всему набору, «Класть в папку», переключатель «Закрепить на главной». Удаление свайпом с вопросом и пятисекундной кнопкой «Вернуть». На странице вещи теги чипами с крестиком, крестик снимает тег только у этой вещи.
- [ ] **Шаг 5.** Коммит «Теги и правила: экран, лист тега, правила при сохранении».

---

## Веха 3. Подсказки и разбор без сети

### Задача 3.1: Частоты «слово → папка, тег»

**Файлы:** создать `lib/domain/suggestion_stats.dart`, `lib/data/repositories/word_stats_repository.dart`; тест `test/domain/suggestion_stats_test.dart`.

**Интерфейсы:**
- Производит: `List<String> tokenizeForStats(String text)`; `class Scored { final String id; final double score; }`; `class SuggestionStats { SuggestionStats(Map<(String word, String targetKind, String targetId), int> counts); List<Scored> suggest(String text, {required String targetKind, int limit = 3}); }`; `WordStatsRepository.learn(String text, {String? folderId, Iterable<String> tagIds = const []})`, `WordStatsRepository.load() → Future<SuggestionStats>`.

- [ ] **Шаг 1. Тесты.**

```dart
expect(tokenizeForStats('Рецепт тарта с малиной https://vm.tiktok.com/x'), ['рецепт', 'тарта', 'малиной', 'tiktok.com']);
test('чаще клал «рецепт» в «Рецепты» — она первая', () {
  final stats = SuggestionStats({('рецепт', 'folder', 'f-rec'): 5, ('рецепт', 'folder', 'f-idea'): 1});
  expect(stats.suggest('новый рецепт', targetKind: 'folder').first.id, 'f-rec');
});
test('пустая статистика — пустой ответ, без исключений', ...
```

- [ ] **Шаг 2.** FAIL.
- [ ] **Шаг 3.** Токены: слова от 3 букв в нижнем регистре, без стоп-слов (`это, как, что, для, или, при, без, все, был, она, они, его, так, уже, где, там, тут`), домены ссылок целиком без `www.`. Оценка цели: сумма по словам `count(word, target) / total(word)`, деление на число слов текста. Учёт: при `capture` с явной папкой, при ручном переносе, при применении ответа ИИ.
- [ ] **Шаг 4.** PASS. **Шаг 5.** Коммит «Подсказки папок и тегов по прошлым раскладкам».

### Задача 3.2: Панель над строкой

**Файлы:** создать `lib/features/composer/composer_panel.dart`, `lib/features/composer/composer_controller.dart`; тест `test/features/composer_panel_test.dart`.

**Интерфейсы:**
- Потребляет: `extractInlineTags`, `applyRules`, `SuggestionStats.suggest`, `parseReminder` (задача 4.1 подключает напоминание; до неё чип не показывается), `ItemsRepository.searchSimilar` (задача 5.2; до неё блок «Уже есть похожее» скрыт).
- Производит: `class ComposerDraft { String text; String? folderId; bool folderChosenByUser; Set<String> tagNames; DateTime? reminder; }`, `ComposerController extends Notifier<ComposerDraft>` с `onTextChanged(String)` (дребезг 150 мс), `chooseFolder(String?)`, `toggleTag(String)`.

- [ ] **Шаг 1. Тесты.**

```dart
testWidgets('пишешь «#машина» — в панели чип тега и папка из правила', ...
testWidgets('без правил папка берётся из частот, помечена как подсказка', ...
testWidgets('выбранная руками папка не перебивается подсказкой при дальнейшем вводе', ...
```

- [ ] **Шаг 2–4.** FAIL → реализация → PASS. Вёрстка по экрану 2: панель `containerHigh` радиус 28 над строкой, ряды «Папка» и «Теги» одной строкой каждый, листаются вбок. При отправке черновик уходит в `CaptureInput` с `forcedFolderId`, только если папку выбрал человек.
- [ ] **Шаг 5.** Коммит «Над строкой видно, куда ляжет вещь».

### Задача 3.3: Режим «Разобрать» и выделение

**Файлы:** создать `lib/features/sort_mode/sort_mode_screen.dart`, `lib/features/home/selection_bar.dart`; тест `test/features/sort_mode_test.dart`.

**Интерфейсы:**
- Потребляет: `ItemsRepository.watchUnsorted() → Stream<List<ItemCard>>` (заводится здесь: `folderId IS NULL AND deletedAt IS NULL`), `moveToFolder`, `SuggestionStats`.

- [ ] **Шаг 1. Тесты.**

```dart
testWidgets('касание кнопки папки раскладывает и показывает следующую', ...
testWidgets('свайп вниз пропускает, вещь остаётся неразобранной', ...
```

- [ ] **Шаг 2–4.** FAIL → реализация → PASS. Карточка во весь экран, внизу ряд папок, первые три — подсказки по частотам. Долгое нажатие на карточку в «Только что» и в папке включает выделение: «В папку», «Добавить тег», «Снять тег», «Удалить». Перетаскивание карточки из «Только что» на плитку папки.
- [ ] **Шаг 5.** Коммит «Разобрать руками: по одной карточке и пачкой».

---

## Веха 4. Напоминания

### Задача 4.1: Русские даты

**Файлы:** создать `lib/domain/reminder_parser.dart`; тест `test/domain/reminder_parser_test.dart`.

**Интерфейсы:**
- Производит: `class ParsedReminder { final DateTime at; final int start; final int end; }`; `ParsedReminder? parseReminder(String text, DateTime now)`.

- [ ] **Шаг 1. Тесты** (сейчас — понедельник 2 ноября 2026, 14:48):

```dart
final now = DateTime(2026, 11, 2, 14, 48);
expect(parseReminder('позвонить завтра в 10', now)!.at, DateTime(2026, 11, 3, 10));
expect(parseReminder('в 10:30 созвон', now)!.at, DateTime(2026, 11, 3, 10, 30)); // 10:30 уже прошло — завтра
expect(parseReminder('в 18 забрать', now)!.at, DateTime(2026, 11, 2, 18));
expect(parseReminder('испечь в субботу', now)!.at, DateTime(2026, 11, 7, 9));
expect(parseReminder('в понедельник', now)!.at, DateTime(2026, 11, 9, 9));    // сегодня понедельник — следующий
expect(parseReminder('через 2 часа', now)!.at, DateTime(2026, 11, 2, 16, 48));
expect(parseReminder('через полчаса', now)!.at, DateTime(2026, 11, 2, 15, 18));
expect(parseReminder('12 ноября', now)!.at, DateTime(2026, 11, 12, 9));
expect(parseReminder('1 ноября', now)!.at, DateTime(2027, 11, 1, 9));         // прошло — следующий год
expect(parseReminder('послезавтра вечером', now)!.at, DateTime(2026, 11, 4, 19));
expect(parseReminder('сегодня утром', now)!.at, DateTime(2026, 11, 3, 9));     // утро прошло — завтра
expect(parseReminder('код 4512', now), isNull);
expect(parseReminder('купить 10 яиц', now), isNull);                           // число без «в» не время
```

- [ ] **Шаг 2–4.** FAIL → реализация → PASS. Части: день (`сегодня|завтра|послезавтра|в <день недели>|<число> <месяц в родительном>`), время (`в H`, `в H:MM`, `в H.MM`, `утром`=9, `днём`=13, `вечером`=19), сдвиг (`через N минут|часов|дней`, `через час|полчаса`). День без времени — 9:00. Время без дня — сегодня, если ещё не прошло, иначе завтра. `start`/`end` — где в тексте нашлось, чтобы подсветить.
- [ ] **Шаг 5.** Коммит «Напоминания понимают „завтра в 10“ и „в субботу“».

### Задача 4.2: Уведомления и карточка «Сегодня»

**Файлы:** создать `lib/services/reminder_service.dart`, `lib/features/home/today_card.dart`; изменить `capture_service.dart`; тест `test/services/reminder_service_test.dart`.

**Интерфейсы:**
- Производит: `ReminderService.schedule(String itemId, DateTime at, String title)`, `cancel(String itemId)`, `ItemsRepository.watchToday(DateTime now) → Stream<List<ItemCard>>`.

- [ ] **Шаг 1–4.** Тест через подменный планировщик: сохранение с «завтра в 10» планирует одно уведомление на нужное время; правка напоминания переносит; удаление вещи снимает. `flutter_local_notifications` с `zonedSchedule`, часовой пояс через `flutter_timezone`, разрешение `POST_NOTIFICATIONS` и точные будильники. Карточка «Сегодня» белая (`Tokens.accent`), значок-печенька с будильником, «10:00 · ещё 2 на сегодня», кнопка «Готово».
- [ ] **Шаг 5.** Коммит «Напоминания приходят уведомлением, ближайшее — на главной».

---

## Веха 5. Поиск

### Задача 5.1: Разбор строки поиска

**Файлы:** создать `lib/domain/search_query.dart`; тест `test/domain/search_query_test.dart`.

**Интерфейсы:**
- Производит: `class SearchQuery { final List<String> words; final Set<String> includeTags; final Set<String> excludeTags; String? toFtsMatch(); }`; `SearchQuery parseSearchQuery(String input)`.

- [ ] **Шаг 1. Тесты.**

```dart
final query = parseSearchQuery('#рецепт -#видео курица из тиктока');
expect(query.includeTags, {'рецепт'});
expect(query.excludeTags, {'видео'});
expect(query.words, ['курица', 'из', 'тиктока']);
expect(query.toFtsMatch(), '"курица"* AND "тиктока"*');   // слова короче 3 букв в поиск не идут
expect(parseSearchQuery('"кавычки" и OR').toFtsMatch(), '"кавычки"*'); // спецсимволы FTS не ломают запрос
expect(parseSearchQuery('#только_тег').toFtsMatch(), isNull);
```

- [ ] **Шаг 2–4.** FAIL → реализация → PASS. **Шаг 5.** Коммит «Строка поиска понимает теги и „без тега“».

### Задача 5.2: Поиск в строке и «похожее» при вводе

Отдельного экрана поиска нет: выдача растёт панелью над строкой ввода (экран 2 описания, живой прототип макета). Ранжирование как в прототипе: начало слова, срезанное окончание, одна опечатка у слов от 4 букв, вес полей (заголовок выше текста), свежесть; кнопку определяет белая подсветка — точное совпадение короткого запроса или новая запись.

**Файлы:** создать `lib/domain/line_query.dart` (разбор строки: команда, `#`, `@`, ссылка, дата, разметка), `lib/domain/line_rank.dart` (ранжирование), `lib/features/composer/line_panel.dart`; изменить `items_repository.dart`; тест `test/data/search_test.dart`, `test/domain/line_query_test.dart`, `test/domain/line_rank_test.dart`.

**Интерфейсы:**
- Производит: `ItemsRepository.search(SearchQuery query, {Set<String> folderIds = const {}, Set<ItemKind> kinds = const {}, DateTimeRange? range}) → Future<List<SearchHit>>`; `class SearchHit { final ItemCard item; final String snippet; final HitField field; }`; `enum HitField { title, body, aiDescription, transcript, url, tagOnly }`; `ItemsRepository.searchSimilar(String draftText, {int limit = 3}) → Future<List<ItemCard>>`.

- [ ] **Шаг 1. Тесты.**

```dart
test('находится по тексту с картинки из описания ИИ и показывает, где нашлось', ...
  expect(hits.single.field, HitField.aiDescription);
test('-#видео убирает вещи с тегом видео', ...
test('выдача по тегу без слов работает', ...
test('похожее при вводе не показывает удалённые', ...
```

- [ ] **Шаг 2–4.** FAIL → реализация → PASS. Сниппет — функция FTS5 `snippet()` с отметками, которые экран красит белой подложкой. Панель по живому прототипу: внизу строка «Закинуть», выше найденное, лучшее у пальца; фильтры видов в шапке панели; `#` и `@` открывают теги и папки, выбранное уходит в чип над строкой; касание по чипу тега переключает «с тегом → без тега → убрать».
- [ ] **Шаг 5.** Коммит «Поиск обычными словами и тегами, похожее прямо при вводе».

---

## Веха 6. ИИ по ключу

### Задача 6.1: Настройки и клиент поставщика

**Файлы:** создать `lib/data/settings.dart`, `lib/services/ai_client.dart`, `lib/features/settings/settings_screen.dart`; тест `test/services/ai_client_test.dart`.

**Интерфейсы:**
- Производит:
  - `class AiSettings { final String baseUrl; final String sortModel; final String? speechModel; final bool paused; final String? pauseReason; }`, `SettingsRepository.watchAi()`, `saveKey(String)`, `readKey() → Future<String?>`
  - `class AiClient { AiClient({required http.Client http, required String baseUrl, required String apiKey}); Future<String> chat({required String model, required List<Map<String, Object?>> messages, Map<String, Object?>? responseFormat}); Future<String> transcribe({required String model, required String audioPath}); Future<void> check(); }`
  - `class AiFailure implements Exception { final AiFailureKind kind; final Duration? retryAfter; final String message; }`, `enum AiFailureKind { auth, payment, rateLimit, network, server, badResponse }`

- [ ] **Шаг 1. Тесты** на `MockClient` из `package:http/testing.dart`:

```dart
test('401 и 403 дают auth, 402 — payment', ...
test('429 с retry-after: 30 даёт rateLimit и паузу 30 секунд', ...
  expect(failure.retryAfter, const Duration(seconds: 30));
test('ответ без choices даёт badResponse', ...
test('заголовки: Bearer-ключ и X-Title: Stowa', ...
test('нет сети даёт network', ...
```

- [ ] **Шаг 2–4.** FAIL → реализация → PASS. `chat` шлёт `POST {baseUrl}/chat/completions`, тело `{model, messages, response_format, temperature: 0}`, таймаут 30 секунд, возвращает `choices[0].message.content`. `check` — `GET {baseUrl}/models` с ключом. Экран настроек: поле ключа (скрытое), адрес поставщика, модель разбора (по умолчанию бесплатная модель OpenRouter с поддержкой картинок; на момент задачи выбрать из `GET /models` с `:free` и `image` во входах), модель речи (пусто = не расшифровывать), «Проверить ключ» с ответом строкой.
- [ ] **Шаг 5.** Коммит «Свой ключ ИИ: настройки и клиент поставщика».

### Задача 6.2: Договор с моделью

**Файлы:** создать `lib/domain/ai_contract.dart`; тест `test/domain/ai_contract_test.dart`, фикстуры `test/fixtures/ai/*.json`.

**Интерфейсы:**
- Производит:
  - `class SortContext { final ItemForAi item; final List<FolderForAi> folders; final List<TagForAi> tags; final List<CorrectionExample> examples; final List<LinkCandidate> candidates; final DateTime now; final String timeZone; }`
  - `class ItemForAi { final String id; final ItemKind kind; final String text; final String? url; final String? pageTitle; final String? pageDescription; final String? imageBase64Jpeg; }`
  - `class SortDecision { final String? folderId; final NewFolder? newFolder; final List<String> tagNames; final List<NewTag> newTags; final String? title; final String description; final DateTime? reminder; final List<ProposedLink> links; }`
  - `List<Map<String, Object?>> buildSortMessages(SortContext context)`; `Map<String, Object?> sortResponseFormat()` (JSON Schema для `response_format`); `SortDecision? parseSortDecision(String content, SortContext context)`
  - `List<Map<String, Object?>> buildClusterMessages(List<ItemForAi> unsorted, List<FolderForAi> folders)`; `ClusterDecision? parseClusterDecision(String content, Set<String> itemIds)`; `class ClusterDecision { final List<ProposedFolder> folders; }`, `class ProposedFolder { final String name; final String icon; final List<String> itemIds; }`

- [ ] **Шаг 1. Тесты** (по одному на фикстуру):

```dart
test('нормальный ответ разбирается целиком', ...
test('JSON внутри ```json-ограды и с текстом вокруг тоже разбирается', ...
test('обрезанный JSON — null', ...
test('выдуманный folderId отбрасывается, остальное сохраняется', ...
  expect(decision.folderId, isNull); expect(decision.tagNames, ['рецепт']);
test('связи только на кандидатов, на себя — нет', ...
test('теги нормализуются: «#Видео» → «видео», повторы убираются', ...
test('напоминание в прошлом отбрасывается', ...
test('иконка нового тега не из набора заменяется на label', ...
test('текст длиннее 6000 знаков урезается в сообщении, картинка идёт image_url data:', ...
test('кластер: папка меньше чем из 3 вещей отбрасывается', ...
```

- [ ] **Шаг 2.** FAIL.
- [ ] **Шаг 3.** Системное сообщение (по-русски, коротко): что такое приложение, правило «папку выбирай из списка, новую предлагай, только если ни одна не подходит», «теги короткие, в нижнем регистре, 1–3 штуки, по возможности из списка», «description — что это и весь текст с картинки, для поиска», «reminder — только если в тексте явно есть время». Пользовательское сообщение: блоки «Папки», «Теги», «Примеры, как раскладывает хозяин» (последние 20 исправлений: текст вещи в 100 знаков → папка), «Кандидаты для связей» (id, заголовок, 120 знаков), «Вещь», «Сейчас: <дата> <пояс>». Разбор: схема через `response_format: {type: 'json_schema', strict: true}`, при ответе не по схеме — вырезать первый `{...}` верхнего уровня и проверить поля руками.
- [ ] **Шаг 4.** PASS. **Шаг 5.** Коммит «Договор с моделью: запрос и строгий разбор ответа».

### Задача 6.3: Очередь разбора

**Файлы:** создать `lib/services/ai_worker.dart`, `lib/services/background.dart`, `lib/data/repositories/ai_jobs_repository.dart`, `lib/domain/link_candidates.dart`; изменить `capture_service.dart`, `main.dart`; тест `test/services/ai_worker_test.dart`.

**Интерфейсы:**
- Потребляет: `AiClient`, `buildSortMessages`, `parseSortDecision`, `ItemsRepository.search` (кандидаты связей), `WordStatsRepository.learn`.
- Производит: `class AiWorker { Future<WorkerReport> runOnce({int maxJobs = 10}); }`; `AiJobsRepository.enqueue(String itemId, {AiJobKind kind = AiJobKind.sort})`; `enum AiJobKind { sort, cluster, transcribe }`; `Future<List<LinkCandidate>> pickLinkCandidates(ItemFull item, ItemsRepository items, {int limit = 25})`.

- [ ] **Шаг 1. Тесты** с подменным `AiClient`:

```dart
test('после сохранения без папки вещь в очереди, после runOnce — в папке с sortedBy ai', ...
test('ответ пришёл после ручного переноса — папка и теги не тронуты, описание записано', ...
  expect(item.folderId, userFolder); expect(item.aiDescription, isNotNull);
test('401 ставит очередь на паузу и больше не зовёт клиента', ...
  expect(client.calls, 1); expect(settings.paused, isTrue);
test('смена ключа снимает паузу', ...
test('429 переносит задачу на retryAfter', ...
test('битый ответ: sortState failed, попытка +1, следующая через 2^n минут, не больше 6 часов', ...
test('новая папка от ИИ заводится с createdByAi и меткой «новая»', ...
test('в «Без папки» стало 4 вещи — ставится задача cluster', ...
test('применённый ответ учит частоты', ...
```

- [ ] **Шаг 2.** FAIL.
- [ ] **Шаг 3.** `runOnce` берёт задачи с `nextTryAt <= now`, по одной (вещь разбирается за 1–2 секунды, параллель не нужна), собирает `SortContext` (картинка — `MediaService.imageForAi`, задача 7.2; до неё картинки идут без пикселей, с именем файла). Запуск: сразу после `capture` при наличии сети, при возврате сети (`connectivity_plus`), при открытии приложения, и `workmanager` раз в 15 минут с требованием сети. Каждый запрос и ответ — в `AiLog` (последние 500 строк). На главной при паузе тонкая плашка «Разбор на паузе: проверь ключ» с переходом в настройки. Плашка «Положил в „Рецепты“ · Другая» на 3 секунды после ИИ-разбора, если приложение открыто.
- [ ] **Шаг 4.** PASS. Проверка на телефоне со своим ключом: 10 разных вещей разложились, авиарежим — вещи ждут, сеть вернулась — разобрались.
- [ ] **Шаг 5.** Коммит «ИИ разбирает очередь в фоне по своему ключу».

---

## Веха 7. Содержимое

### Задача 7.1: Превью ссылок и роликов

**Файлы:** создать `lib/domain/link_preview_parser.dart`, `lib/services/link_preview_service.dart`; тест `test/domain/link_preview_parser_test.dart`, фикстуры `test/fixtures/html/*.html`.

**Интерфейсы:**
- Производит: `class LinkPreview { final String? title; final String? description; final Uri? imageUrl; final String siteName; final Duration? duration; }`; `LinkPreview parseHtmlPreview(String html, Uri pageUrl)`; `LinkPreview parseOembed(Map<String, Object?> json, Uri pageUrl)`; `Uri? oembedEndpoint(Uri pageUrl)` (tiktok, youtube); `LinkPreviewService.fetchFor(String itemId)`.

- [ ] **Шаг 1. Тесты:** og-теги важнее `<title>`; относительный `og:image` достраивается до полного; страница без тегов даёт `siteName` из домена; oEmbed TikTok и YouTube дают заголовок и обложку; кодировка `windows-1251` из `<meta charset>` читается.
- [ ] **Шаг 2–4.** FAIL → реализация (`package:html`) → PASS. Загрузка превью — задача в той же очереди сети, до ИИ: ИИ получает заголовок и описание страницы. Обложка скачивается в папку приложения миниатюрой.
- [ ] **Шаг 5.** Коммит «Ссылки и ролики с заголовком и обложкой».

### Задача 7.2: Картинки, файлы, голосовые

**Файлы:** создать `lib/services/media_service.dart`, `lib/services/voice_service.dart`, `lib/features/composer/voice_recorder.dart`; тест `test/services/media_service_test.dart`.

**Интерфейсы:**
- Производит: `MediaService.store(PickedFile file, String itemId) → Future<Attachment>` (копия + миниатюра 512 px для картинок), `MediaService.imageForAi(String path) → Future<String>` (base64 JPEG, длинная сторона 1024, качество 80), `VoiceService.start()`, `stop() → Future<PickedFile>`, `VoiceService.transcribeLater(String itemId)` (ставит задачу `transcribe`, если задана модель речи).

- [ ] **Шаг 1. Тесты:** фото 4000×3000 даёт для ИИ картинку 1024×768; PDF на 30 МБ копируется, вещь сохраняется сразу (копирование не на пути сохранения); без модели речи задача расшифровки не ставится; расшифровка пишется в `transcript` и попадает в поиск.
- [ ] **Шаг 2–4.** FAIL → реализация (`flutter_image_compress`, `record` в m4a, `just_audio`) → PASS. Микрофон в строке: удержание пишет, отпускание сохраняет, свайп влево отменяет.
- [ ] **Шаг 5.** Коммит «Фото, файлы и голосовые с расшифровкой по своему ключу».

### Задача 7.3: Карточки по видам и экраны папки

**Файлы:** создать `lib/features/folder/item_cards.dart` (видео, голосовое, ссылка, заметка, картинка, файл), `lib/features/folder/board_view.dart`, `lib/features/folder/list_view.dart`; изменить `folder_screen.dart`; тест `test/features/item_cards_test.dart`.

- [ ] **Шаг 1–4.** Виджет-тесты: каждая карточка рисуется без переполнения на ширине 320; у видео пилюля источника и длина; у голосового волна из сохранённых уровней громкости и расшифровка. Вёрстка по экранам 4 и 6: доска — две колонки, высоты по пропорциям картинок; чипы тегов фильтруют; переключатель «Доска · Холст · Список» помнит выбор по папке (`Folders.view`); вид `auto` выбирает доску, если картинок больше половины.
- [ ] **Шаг 5.** Коммит «Папка показывает каждую вещь по-своему».

---

## Веха 8. Редактор и связи

### Задача 8.1: Живой Markdown в поле

**Файлы:** создать `lib/domain/live_markdown.dart`, `lib/features/editor/live_markdown_controller.dart`; тест `test/domain/live_markdown_test.dart`.

**Интерфейсы:**
- Производит: `enum MarkStyle { heading1, heading2, bold, italic, code, quote, checkboxOpen, checkboxDone, bullet, marker, link, wikiLink, tag }`; `class MarkRange { final int start; final int end; final MarkStyle style; }`; `List<MarkRange> markdownRanges(String text)`; `class LiveMarkdownController extends TextEditingController` с переопределённым `buildTextSpan`.

- [ ] **Шаг 1. Тесты:**

```dart
expect(markdownRanges('**Бюджет:** 12 000'), containsAll([range(0, 2, marker), range(2, 9, bold), range(9, 11, marker)]));
expect(markdownRanges('- [x] Вынести шкаф').map((r) => r.style), contains(MarkStyle.checkboxDone));
expect(markdownRanges('# Ремонт').first.style, MarkStyle.marker);
expect(markdownRanges('смета `30×60`').last.style, MarkStyle.code);
expect(markdownRanges('см. [[Ремонт кухни]]').last.style, MarkStyle.wikiLink);
```

- [ ] **Шаг 2–4.** FAIL → реализация → PASS. В `buildTextSpan` метки (`**`, `#`, `- [ ]`) на строке с курсором красятся приглушённым цветом, на остальных получают `fontSize: 0.01` и прозрачный цвет: символы остаются в тексте, каретка не сбивается, глазу видна только отрисовка. Чек-бокс на строке без курсора рисуется значком через `WidgetSpan` поверх нулевых меток, касание по нему переключает `[ ]` ↔ `[x]` в тексте.
- [ ] **Шаг 5.** Коммит «Markdown рисуется прямо при наборе».

### Задача 8.2: Редактор на весь экран и страница заметки

**Файлы:** создать `lib/features/editor/editor_screen.dart`, `lib/features/editor/markdown_toolbar.dart`; изменить `lib/features/item/item_screen.dart`; тест `test/features/editor_test.dart`.

- [ ] **Шаг 1–4.** Виджет-тесты: кнопка «Ж» оборачивает выделение в `**`; «чек-лист» превращает строку в `- [ ] `; повторное нажатие снимает; прикреплённый файл встаёт в текст строкой `![кухня.jpg](attachment:<id>)` и рисуется карточкой. Вёрстка по экранам 3 и 7: сверху свернуть, чип папки («Авто»), «Закинуть»; панель Markdown над клавиатурой; строка ввода тянется вверх жестом и раскрывается в этот же редактор с тем же текстом. Страница заметки — тот же редактор в режиме правки существующей вещи, плавающая панель снизу, сохранение при каждом изменении с дребезгом 500 мс.
- [ ] **Шаг 5.** Коммит «Редактор на весь экран: Markdown, чек-листы, файлы в тексте».

### Задача 8.3: Связи

**Файлы:** создать `lib/domain/wiki_links.dart`, `lib/data/repositories/links_repository.dart`, `lib/features/item/related_block.dart`, `lib/features/editor/wiki_link_popup.dart`; тесты `test/domain/wiki_links_test.dart`, `test/data/links_repository_test.dart`.

**Интерфейсы:**
- Производит: `class WikiLink { final String title; final int start; final int end; }`; `List<WikiLink> findWikiLinks(String text)`; `String? activeWikiQuery(String text, int cursor)` (текст после незакрытого `[[` до курсора); `LinksRepository.syncManual(String itemId, List<WikiLink> links)` (ссылка на несуществующую заметку создаёт пустую заметку с этим заголовком), `addAi(String fromId, List<ProposedLink> links)`, `reject(String fromId, String toId)`, `watchRelated(String itemId) → Stream<RelatedItems>`; `class RelatedItems { final List<RelatedLink> outgoing; final List<RelatedLink> backlinks; }`.

- [ ] **Шаг 1. Тесты:** `[[Ремонт кухни]]` находится, `[[` без закрытия — нет; `activeWikiQuery('см. [[Рем', 9) == 'Рем'`; отклонённая автосвязь не возвращается следующим ответом ИИ; удаление ссылки из текста убирает ручную связь; обратные ссылки видны у цели.
- [ ] **Шаг 2–4.** FAIL → реализация → PASS. ИИ-связи приходят из `SortDecision.links` (задача 6.3 зовёт `addAi`). Блок «Связано» внизу заметки: автосвязи с причиной мелким шрифтом и крестиком, ручные, «Ссылаются сюда».
- [ ] **Шаг 5.** Коммит «Связи между заметками: [[ссылки]], обратные ссылки и автосвязи».

---

## Веха 9. Холст и граф

### Задача 9.1: Холст

**Файлы:** создать `lib/domain/canvas_layout.dart`, `lib/features/folder/canvas_view.dart`; тест `test/domain/canvas_layout_test.dart`.

**Интерфейсы:**
- Производит: `class CanvasPlacement { final String itemId; final double x; final double y; final double width; }`; `List<CanvasPlacement> placeNew(List<CanvasPlacement> existing, List<CanvasSize> newItems, {double gap = 24})`.

- [ ] **Шаг 1–4.** Тест: новые вещи встают справа от занятого без пересечений; пустой холст начинается с (0, 0). Вид: `InteractiveViewer` на бесконечной точечной сетке, вещи в `Stack`, перетаскивание, ручка в углу меняет ширину с сохранением пропорций, двойное касание открывает вещь, «Т» добавляет записку (вещь-заметку в этой папке), «уместить» показывает всё. Положения пишутся в `CanvasPositions` при отпускании. Масштаб пилюлей в углу.
- [ ] **Шаг 5.** Коммит «Холст как PureRef».

### Задача 9.2: Граф

**Файлы:** создать `lib/domain/graph_layout.dart`, `lib/features/graph/graph_screen.dart`; тест `test/domain/graph_layout_test.dart`.

**Интерфейсы:**
- Производит: `Map<String, Offset> layoutGraph(List<String> nodes, List<(String, String)> edges, {int iterations = 300, int seed = 1})`.

- [ ] **Шаг 1–4.** Тесты: раскладка детерминирована при одном `seed`; связанные точки в среднем ближе несвязанных; 500 точек раскладываются меньше чем за 300 мс. Простой силовой алгоритм (отталкивание всех, притяжение по рёбрам, охлаждение). Экран: `CustomPainter`, щипок и сдвиг, касание по точке открывает заметку, вход из меню папки и тега.
- [ ] **Шаг 5.** Коммит «Граф связей для папки и тега».

---

## Веха 10. Снаружи

### Задача 10.1: Меню «Поделиться»

**Файлы:** создать `lib/services/share_service.dart`, `lib/features/share/share_sheet.dart`; изменить `AndroidManifest.xml`.

- [ ] **Шаг 1–4.** `receive_sharing_intent`: текст, ссылки, картинки, файлы, несколько сразу. Вещь сохраняется через `CaptureService` до показа листа. Лист по экрану 9: «Сохранено», папка, чипы других папок, «Добавить пару слов», «Готово», кольцо обратного отсчёта 3 секунды. Тест: из `SharedMedia` собирается правильный `CaptureInput`. Проверка на телефоне из браузера, галереи, TikTok.
- [ ] **Шаг 5.** Коммит «Закинуть из любого приложения через „Поделиться“».

### Задача 10.2: Свой бот Telegram

**Файлы:** создать `lib/domain/telegram_updates.dart`, `lib/services/telegram_service.dart`; тест `test/domain/telegram_updates_test.dart`, фикстуры `test/fixtures/telegram/*.json`.

**Интерфейсы:**
- Производит: `class IncomingMessage { final int updateId; final String text; final List<TelegramFileRef> files; final DateTime date; }`; `List<IncomingMessage> parseUpdates(Map<String, Object?> json)`; `TelegramService.pull()` (берёт `getUpdates?offset=<последний+1>&timeout=0`, сохраняет каждое сообщение вещью, скачивает файлы через `getFile`, двигает offset только после записи).

- [ ] **Шаг 1–4.** Тесты: пересланное сообщение с подписью даёт текст подписи; альбом из трёх фото — одна вещь с тремя вложениями (по `media_group_id`); стикеры и служебные сообщения пропускаются; ссылка из `entities` попадает в текст. Опрос при открытии и в `workmanager` раз в 15 минут. В настройках поле токена и «Проверить» (`getMe` показывает имя бота).
- [ ] **Шаг 5.** Коммит «Свой бот Telegram: переслал боту — лежит в Stowa».

### Задача 10.3: Виджет рабочего стола

**Файлы:** создать `lib/services/widget_service.dart`, `android/app/src/main/res/layout/composer_widget.xml`, `android/app/src/main/kotlin/app/stowa/ComposerWidgetProvider.kt`.

- [ ] **Шаг 1–3.** `home_widget`: строка «Закинь что угодно» и кнопка микрофона, касание открывает приложение сразу в строке ввода с клавиатурой, микрофон — сразу запись. Цвета из токенов. Проверка на телефоне.
- [ ] **Шаг 4.** Коммит «Виджет: закинуть, не открывая главную».

---

## Веха 11. Резервная копия и выпуск

### Задача 11.1: Резервная копия

**Файлы:** создать `lib/services/backup_service.dart`; тест `test/services/backup_service_test.dart`.

**Интерфейсы:**
- Производит: `BackupService.export() → Future<File>` (zip: снимок базы через `VACUUM INTO` и папка вложений), `BackupService.import(File zip)` (проверка версии схемы, замена после подтверждения).

- [ ] **Шаг 1–4.** Тест: экспорт → импорт в чистую базу даёт те же вещи, теги, правила, связи и файлы. Ключ ИИ и токен бота в копию не попадают. Кнопки в настройках, отправка файла через `share_plus`.
- [ ] **Шаг 5.** Коммит «Резервная копия всей Stowa одним файлом».

### Задача 11.2: Выпуск через CI

**Файлы:** создать `.github/workflows/release.yml`; изменить `android/app/build.gradle.kts` (подпись из переменных окружения).

- [ ] **Шаг 1.** Ключ выпуска: `keytool -genkeypair -v -keystore stowa-release.jks -alias stowa -keyalg RSA -keysize 4096 -validity 36500`, хранить вне репозитория рядом с ключами других приложений; в секреты репозитория через `gh secret set`: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
- [ ] **Шаг 2.** Workflow на тег `v*`: `flutter build apk --release --split-per-abi`, переименование в `Stowa-<версия из pubspec>-<abi>.apk` (`arm64-v8a`, `armeabi-v7a`, `x86_64`), `gh release create v<версия> *.apk` с заметками из коммитов.
- [ ] **Шаг 3.** Тег `v0.1.0`, `gh run watch`, проверить файлы в выпуске.
- [ ] **Шаг 4.** Коммит «Выпуск собирается в CI и выкладывается на GitHub».

---

## Порядок и что ставить на телефон

| Веха | Что уже умеет приложение |
|---|---|
| 0 | Открывается, тема и шрифты на месте |
| 1 | Закинул текст, фото, файл — лежит; папки руками |
| 2 | Теги с иконками на главной, правила раскладывают без сети |
| 3 | Подсказки над строкой, «Разобрать» по карточке |
| 4 | Напоминания из «завтра в 10» |
| 5 | Поиск словами и тегами, похожее при вводе |
| 6 | ИИ раскладывает по своему ключу в фоне |
| 7 | Превью ссылок, фото, файлы, голосовые с расшифровкой |
| 8 | Редактор Markdown на весь экран, связи как в Obsidian |
| 9 | Холст как PureRef, граф |
| 10 | «Поделиться», свой бот Telegram, виджет |
| 11 | Резервная копия, выпуск в CI |

С вехи 6 приложением можно пользоваться вместо «Избранного». Вехи 7–10 независимы друг от друга, их порядок можно менять по желанию.
