# iPhone: виджеты на главном экране и экране блокировки

**Цель:** на iPhone два виджета. Строка «Закинь что угодно» с камерой и микрофоном, как на Android. И заметка: выбранная или случайная (STOWA-8). Оба есть на главном экране и на экране блокировки.

**Описание:** `docs/specs/2026-11-12-iphone-design.md`, шаги 3 «Что открывает приложение снаружи» и 4 «Виджет-строка». Заметка — задача STOWA-8 в Plane.

**Как устроено:** виджет на iPhone умеет только открыть приложение ссылкой. Поэтому сперва приложение учится принимать `stowa://compose`, `stowa://voice`, `stowa://camera` и `stowa://open?payload=note:<id>` (канал `stowa/launch` на Swift). Главный экран выполняет их своей строкой. Заметки виджет берёт из файла `widget.json` в папке группы `group.app.stowa`: его пишет Dart при каждой правке базы, Swift кладёт файл и просит WidgetKit перерисоваться (канал `stowa/widget`). Виджеты — расширение `StowaWidget` на SwiftUI.

## Общие условия

- Расширение `app.stowa.Widget`, группа `group.app.stowa`, версии те же, что у приложения (`Flutter/*.xcconfig`).
- Минимальная iOS расширения — 17.0. Приложение остаётся с 15.0. Урок Togetherly: ни одного `if #available` в наборе виджетов, иначе расширение падает и пропадают все виджеты.
- В виджет не попадают: заметки из скрытых папок (`folders.hidden = 1`), заметки с фактом `adult`, корзина. Включён «Код на вход» — в файле только `locked: true`, виджет пишет «Stowa под замком» и текста не показывает.
- Отмечать пункты списка прямо в виджете не делаем: виджет только показывает. Касание открывает заметку.
- Цвета из `palette` Stowa (тёмная и светлая), шрифт системный, как у андроидного виджета.
- Сборка iPhone только в CI. Раскладку виджетов проверяет стенд `tool/widget_layout` (как в Togetherly): настоящие файлы виджетов собираются под macOS с заглушками и рисуются в картинки, прогон `ios-widget-layout.yml` пара минут. Целиком — `ios.yml`.

## Решения, принятые без владельца

- Случайная заметка меняется раз в день и по кнопке «другая» в углу виджета (кнопка на AppIntent, iOS 17). Касание остального открывает заметку.
- Выбор конкретной заметки — в настройке виджета (долгое касание → «Изменить виджет»), список из того же `widget.json`: закреплённые, потом последние, всего до 60.
- На экране блокировки строка — прямоугольник «Закинь что угодно» (открывает строку) и круг с микрофоном (сразу запись). Заметка — прямоугольник и строка над часами.
- На Android главное окно `compose`, `voice` и `camera` не получает (у них своё окно), поэтому разбор в главном экране общий и Android не задевает.

## Задача 1. Главный экран выполняет кнопки виджета

Файлы: `lib/features/home/home_screen.dart`, тест `test/features/home/launch_buttons_test.dart`.

`_onRawLaunch`: `compose` → `focusLine()`, `voice` → `startVoice()`, `camera` → снимок камерой и `attach` + `focusLine()`. Тесты на подменённом канале `stowa/launch`: `initial` отдаёт `compose` — строка в фокусе; `voice` — запись началась (подменённый плагин записи).

## Задача 2. Что видит виджет: `widget.json`

Файлы: `lib/services/widget_snapshot.dart` (чистая сборка), `lib/services/widget_channel.dart` (канал и подписка), тест `test/services/widget_snapshot_test.dart`.

```dart
/// Заметки для виджета iPhone: закреплённые, потом последние, до [limit].
Map<String, Object?> widgetSnapshot({required List<WidgetNote> notes, required bool locked, required DateTime now});
```

Каждая заметка: `id`, `title`, `lines` (до 8: текст и галочка, как у стикера), `text` (начало обычного текста), `color` (цвет папки ARGB или нет), `pinned`. Тесты: скрытая папка и `adult` не попадают; замок — пусто и `locked`; список раскладывается в строки с галочками.

## Задача 3. Канал запуска и канал виджета на Swift

Файлы: `ios/Runner/Info.plist` (схема `stowa`), `ios/Runner/LaunchChannel.swift`, `ios/Runner/WidgetChannel.swift`, `ios/Runner/AppDelegate.swift`/`SceneDelegate.swift`.

Ссылки разбираются как `actionOf` на Android. `stowa/widget.write(json)` пишет `widget.json` в папку группы и зовёт `WidgetCenter.shared.reloadAllTimelines()`.

## Задача 4. Расширение `StowaWidget`

Файлы: `ios/StowaWidget/` (`StowaWidgetBundle.swift`, `Snapshot.swift`, `ComposerWidget.swift`, `NoteWidget.swift`, `Palette.swift`, `Info.plist`, `StowaWidget.entitlements`), `ios/Runner.xcodeproj/project.pbxproj`.

## Задача 5. Стенд раскладки и проверки CI

Файлы: `tool/widget_layout/` (заглушки, `main.swift`, `run.sh`), `.github/workflows/ios-widget-layout.yml`, проверка `StowaWidget.appex` в `ios.yml`. Снимки всех размеров в тёмной и светлой теме — смотреть глазами до показа.

## На что смотреть при проверке

- Длинное название и пустая заметка: текст не вылезает за край, пустая показывает заголовок.
- Заметку, выбранную в виджете, удалили или спрятали: виджет переходит на случайную, а не рисует пустоту.
- Файла `widget.json` ещё нет (поставили виджет до первого открытия): виджет зовёт открыть Stowa.
- Замок включили: текст пропадает из виджета при следующей записи файла.
