# Знакомство и подсказки — план

> Исполнение: superpowers:executing-plans, сам, задача за задачей (агентов хозяин запускать не велел). Шаги — флажки `- [ ]`.

**Цель:** шесть шагов знакомства над строкой главной, самообъясняющиеся `#`, `@`, `/`, девять подсказок по месту и правки из отчёта новичка.

**Устройство:** правила — чистые функции в `lib/domain/hints.dart`; состояние в SharedPreferences через `HintsRepository` с потоком; экраны читают `hintsProvider`, `TestWorld` подменяет его памятью (по умолчанию подсказки выключены, чтобы старые тесты не видели карточек). Карточка шага живёт внутри `LineDock`: только он знает, пуста ли строка и панель.

**Стек:** Flutter, Riverpod 3, SharedPreferences, словари `tool/add_strings.py`.

**Описание:** `docs/specs/2026-11-16-onboarding-design.md`.

## Общие правила

- Подсказка — одно предложение; тексты дословно из описания.
- Все строки — на семи языках через `tool/add_strings.py`, потом `flutter gen-l10n`.
- Prefs при отрисовке не читать: только поток `hintsProvider`.
- Тесты — только затронутые файлы, с потолком: `TMPDIR=~/.cache/flutter-tmp systemd-run --user --scope -q -p CPUQuota=500% -p MemoryMax=5G -p MemorySwapMax=0 nice -n 19 flutter test -j 3 <файлы>`.
- Код правится Read + Edit, не скриптами.

## Что проверить отдельно

1. Старый пользователь (место хранилища выбрано до этой версии) не видит ни шагов, ни подсказок — тест в задаче 1.
2. Шаг, сделанный раньше времени (тег до шага 5), не показывается — тест в задаче 1.
3. Строка из одного `#` не закидывается — тест в задаче 2.
4. Карточка шага не перекрывает панель при наборе — тест в задаче 3.
5. Подсказка уходит после трёх заходов и после «×» — тест в задаче 4.

---

### Задача 1: правила и хранилище подсказок

**Файлы:**
- Создать: `lib/domain/hints.dart`, `lib/data/hints_repository.dart`, `test/domain/hints_test.dart`
- Править: `lib/data/providers.dart` (провайдеры), `lib/main.dart` (перенос старых установок), `test/helpers/test_app.dart` (подмена), словари (все строки задач 1–6 одним JSON)

**Даёт:**
- `enum StartStep { stow, search, remind, folder, tag, commands, finish }`
- `enum StartEvent { stowed, found, reminded, foldered, tagged, commanded }`
- `enum Tip { noteBar, longPress, catalog, folderMenu, sort, canvas, base, aiKey, edge }`
- `class HintsState { bool off; Set<StartEvent> done; StartStep? step /* null — знакомство закончено */; int stows; int? doneAt /* stows, когда текущий шаг сделан */; Set<Tip> closed; Map<Tip, int> shows; }` с `static const fresh` и `static const finished`
- `HintsState hintsAfter(HintsState state, Iterable<StartEvent> events)` — события одного сохранения разом: сперва `stowed` прибавляет `stows`, потом события отмечаются. Текущий шаг сделан → `doneAt = stows`. Следующий несделанный шаг открывается, когда `stows > doneAt` (то есть на следующем сохранении); после шага 1 — сразу. Все шесть сделаны → `finish`.
- `StartStep? visibleStep(HintsState state)` — `null`, если `off` или знакомство закончено.
- `bool tipVisible(HintsState state, Tip tip)` — не `off`, не закрыта, показов меньше трёх; `longPress` — только когда `step == null`.
- `class HintsRepository { Stream<HintsState> watch(); Future<void> record(StartEvent); Future<void> skipStep(); Future<void> tipShown(Tip); Future<void> closeTip(Tip); Future<void> restart(); Future<void> setOff(bool); Future<void> settleOldInstall({required bool vaultAskedBefore}); }` на `SharedPreferences`, ключи `hints_off`, `hints_done`, `hints_step`, `hints_stows`, `hints_step_stows`, `hints_closed`, `hints_shows`.
- `hintsRepositoryProvider`, `hintsProvider` (`StreamProvider<HintsState>`).

Шаги:
- [ ] Строки: все тексты шагов, пояснений `#`/`@`, подсказок, настроек и правок из описания — одним `strings.json` на семь языков, `add_strings.py`, для заменяемых (`reasonNone`, `vaultSetupHint`, `settingsCatalog`, `aiFirstHint`) — `--replace`; `flutter gen-l10n`.
- [ ] Тест `test/domain/hints_test.dart`:
  - `шаги идут по порядку и ждут новую заметку`: fresh — `visibleStep == stow`; `[stowed]` → `search`; `[found]` → `null`; `[stowed]` → `remind`; `[stowed, reminded]` → `null`; `[stowed]` → `folder`.
  - `сделанное заранее засчитано`: `tagged` до шага 5 → после шага 4 сразу `commands`.
  - `шесть событий — финальная карточка, пропуск финала — конец`.
  - `подсказка: три показа или «×»`; `longPress` не видна, пока идёт знакомство.
  - `старая установка — всё закрыто` (репозиторий на `SharedPreferences.setMockInitialValues`), `новичок — fresh`, `restart` возвращает fresh.
- [ ] Красный прогон, затем код, затем зелёный.
- [ ] `TestWorld`: поле `HintsState hints = HintsState(off: true)`, подмена `hintsProvider` потоком и `hintsRepositoryProvider` репозиторием на памяти (`SharedPreferences.setMockInitialValues` в `setUp` не трогать — свой `InMemoryHints` с тем же интерфейсом через абстрактный `HintsStore`).
- [ ] `main.dart`: до первого кадра `settleOldInstall(vaultAskedBefore: settings.vaultAsked)`.
- [ ] Коммит.

Сделанный шаг сразу прячет карточку; следующий появляется на ближайшем сохранении. Исключение — шаг 2: его открывает то же сохранение, что сделало шаг 1.

### Задача 2: строка объясняет `#`, `@`, `/`

**Файлы:** `lib/features/composer/panel_model.dart`, `lib/features/composer/line_panel.dart`, `lib/features/composer/panel_text.dart`; тесты `test/features/composer/panel_model_test.dart`, `test/features/composer/line_dock_test.dart`.

**Даёт:** `class ExplainRow extends PanelRow { final CaretKind kind; }` (ключ `explain`), не нажимается.

- [ ] Тесты модели: `голая решётка — пояснение и теги`, `голая собака — пояснение и папки`, `команды по порядку LineCommand`, `одинокий знак — не заметка` (`plan == null` для `#`, `@`, `# `).
- [ ] Красный, код (`_completions`: при пустом `query` для тега и папки — `ExplainRow` первым; команды сортировать по `command.index`; в `buildPanel` `hasContent` не считает строку из одних `#`/`@`), зелёный.
- [ ] `line_panel.dart`: `ExplainRow` — значок `sell`/`folder`, текст `l.lineExplainTag` / `l.lineExplainFolder`, бледный, без касания.
- [ ] Виджет-тест: набрал `#` — видно пояснение, кнопки «Закинуть» нет.
- [ ] `reasonNone` — «без папки, разложу позже» (строка уже заменена в задаче 1), проверить, что тесты с прежним текстом поправлены.
- [ ] Коммит.

### Задача 3: карточка шага над строкой

**Файлы:** создать `lib/features/composer/start_card.dart`; править `line_dock.dart` (параметр `bool onboarding = false`, события), `home_screen.dart` (`LineDock(onboarding: true)`); тест `test/features/composer/start_card_test.dart`.

**Потребляет:** `hintsProvider`, `hintsRepositoryProvider`, `visibleStep`, `StartEvent`.

- [ ] Тесты (`world.hints = HintsState.fresh`): `пустая главная — шаг 1, набор прячет карточку`; `закинул — шаг 2, «Попробовать» вставляет слово из заметки`; `«×» пропускает шаг`; `заметка с напоминанием засчитывает шаг 3`; `тег, папка через @, команда — события`; `финальная карточка закрывается навсегда`.
- [ ] Красный.
- [ ] `StartCard({required StartStep step, required int index, required VoidCallback onTry, required VoidCallback onSkip})`: блок `Tokens.container`, радиус 24, круг 40 со значком (`edit`, `search`, `alarm`, `folder`, `sell`, `bolt`, финал — `celebration`), текст 15/600, пилюля «Попробовать» (нет у шага 1 и финала), «×», точки «N из 6».
- [ ] `LineDock`: карточка в месте панели, когда `widget.onboarding`, строка пуста, вложений нет и `_panel.rows` пусты. «Попробовать»: шаг 1 — `focusLine()`; 2 — `prefill(слово)` из `recentItemsProvider` (первое слово заголовка от 4 букв, иначе заголовок); 3–6 — `prefill(пример)` из словаря. События в `_save` после успешного сохранения: `stowed`; `reminded`, если у сохранённого `reminderAt`/`remindPlace`; `foldered`, если `_line.folder != null` или `newFolder != null`; `tagged`, если теги есть; `commanded`, если `command != null`. В `_createDocument` — `commanded` и `stowed`. `found` — после кадра, когда `_panel.header == PanelHeader.found` и строка набрана руками.
- [ ] Зелёный, кадры глазами (задача 6), коммит.

### Задача 4: подсказки по месту

**Файлы:** создать `lib/core/widgets/hint_banner.dart`; править `item_screen.dart` (над нижней панелью), `home_screen.dart` (над лентой, от пяти заметок), `catalog_screen.dart` (от двух папок), `folder_screen.dart`, `sort`-экран «Без папки» (`folder_screen.dart`, где «Разобрать»), `canvas_file_screen.dart`, `base_file_screen.dart`, `ai_screen.dart` (пока ключа нет), экран «Под рукой»; тест `test/core/hint_banner_test.dart`.

**Даёт:** `HintBanner({required Tip tip, bool when = true})` — `ConsumerStatefulWidget`: на монтировании, если `tipVisible` и `when`, один раз зовёт `tipShown`; решение «показывать» фиксируется на монтировании; «×» → `closeTip`. Вид: пилюля `Tokens.containerHigh`, значок `tips_and_updates` цвета `Tokens.accent`, текст 14, «×» 40.

- [ ] Тесты: `показывается, «×» закрывает навсегда`; `после трёх заходов не показывается`; `when: false — нет`; `выключенные подсказки — нет`.
- [ ] Красный, код, зелёный.
- [ ] Поставить девять подсказок по таблице описания, ключи `hint-<tip>`; виджет-тест на заметку: первое открытие — подсказка над панелью.
- [ ] Коммит.

### Задача 5: настройки и мелкие правки

**Файлы:** `settings_screen.dart`, `vault_setup_screen.dart` (текст уже заменён), `note_timeline.dart`, `home_screen.dart`; тесты `settings_screen_test.dart`, `note_timeline_test.dart` (или ближайший тест ленты).

- [ ] «Помощь»: `SettingsSwitchRow` «Подсказки» (`setOff`) и `SettingsRow` «Начать знакомство заново» (`restart`, плашка `showUndo`-стилем без «Отменить»). Тест: сброс возвращает шаг 1 на главной.
- [ ] Раздел «Каталог» в настройках — «Хранилище» (строка заменена в задаче 1); поправить тесты, что ищут старое слово.
- [ ] Лента: метка «Без папки» не рисуется, когда у человека нет ни одной папки (`NoteTimeline(hasFolders:)` из `foldersProvider`); отрывок не рисуется, когда текст — одна строка, а заголовок — её начало. Тесты на оба.
- [ ] Коммит.

### Задача 6: кадры, проход новичка, память

- [ ] `tool/preview/onboarding_preview_test.dart`: шаги 1–6 и финал, пояснения `#`/`@`, подсказки заметки, каталога, базы; тёмная и светлая; 320 точек с крупным шрифтом. Посмотреть все кадры, поправить, что режет глаз.
- [ ] Проход новичка с главной (как 16.11), посмотреть снимки.
- [ ] `flutter analyze`, тесты затронутых папок, `CLAUDE.md` проекта — раздел про знакомство (где правила, где карточка, как не сломать старые тесты), отметка в описании.
- [ ] Коммит, пуш, проверка GitHub зелёная.
