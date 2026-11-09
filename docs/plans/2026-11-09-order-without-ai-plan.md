# Порядок без ИИ — план

**Цель:** шаг 9 — умные места в тексте, время словами, список покупок, сумма по папке, умные папки, предложения папок, правила по фактам.

**Описание:** `docs/specs/2026-11-09-order-without-ai-design.md`. Читать вместе.

**Общие правила:** тесты сперва; локально только затронутые файлы с потолком, весь набор — `check.yml`; строки — `tool/add_strings.py` на всех семи языках; коммит и пуш после каждой задачи; код только Read+Edit/Write; разрешения не нужны. Новые факты — значения `FactKind` в конце enum (в базе текстом, миграция не нужна).

**Где может укусить:**
1. Номер карты и трек-номер из цифр не должны стать телефоном (`findPhones`), а пароль «от Wi-Fi» — паролем «от».
2. Правило по фактам не должно вернуть папку, тег или напоминание, которые человек снял руками: `rule_hits`.
3. Умная папка — запрос, а не список: «за неделю» через месяц показывает последнюю неделю.
4. Предложение папки не должно приходить снова после «Не надо» и после «Сделать».
5. «После работы» в пятницу вечером — понедельник, не суббота.

## Задачи

1. **Умные места в тексте.** `domain/text_places.dart`: `findAddresses`, `findTracking`, `findPromoCodes`, `findPasswords` (с сетью рядом), `findLoyaltyCards` → `List<FoundPlace(kind, value, label?, start, end)>`. `findPhones` пропускает отрезки, занятые картой и трек-номером. `FactKind`: `tracking`, `promoCode`, `password`, `loyaltyCard` (+ `address` уже есть, уточнение `text`). `TextExtractor` версия 2. `FactsChips`: кнопки и действия (карта `geo:`, 17track, копирование). Подпись под найденным: пароль и карта без значения (`_shownFact`). Строки. Тесты: domain на семи языках и ловушки из «Где может укусить» 1; извлекатель; `FactsChips` виджет-тестом.
2. **Время словами.** `parseReminder(text, now, {int workEndMinutes = 18 * 60})`: «на выходных» (с часом и без), «после работы» (пятница вечером → понедельник). Настройка `workEnd` в `SettingsRepository`, строка «Работа до» в «Возвращать», передаётся в `LineController` и `CaptureService` (`workEnd: int Function()`, провайдер `workEndProvider`, тесты подменяют). Тесты: parser на датах субботы, воскресенья, пятницы; настройка виджет-тестом.
3. **Список покупок.** `domain/shopping.dart`: `isShoppingStart(String firstLine)`, `shoppingChecklist(String body) → String?` («купить молоко, хлеб и яйца» → «Купить:\n- [ ] молоко\n- [ ] хлеб\n- [ ] яйца»; уже галочки или не список — null). `ReturnRepository.shopping()` узнаёт первую строку без двоеточия. Кнопка «Списком покупок» на странице заметки с «Отменить». Тесты: domain, репозиторий, кнопка.
4. **Сумма по папке.** `domain/money.dart`: `sumByCurrency(Iterable<(double, String)>) → List<(double, String)>`, `formatTotal`. `ItemsRepository.folderTotal(folderId) → List<(double, String)>` с вложенными. Строка «Всего …» на экране папки. Поиск: `SearchQuery.spentOn` (слово после «потратил на» и переводов), репозиторий находит папку по форме слова, фильтрует заметки папки с ценой, `SearchResults.total`; подпись «Ищу: траты · Ремонт · 23 150 лей». Тесты: domain, репозиторий, поиск.
5. **Умные папки.** Схема v13: `SmartFolders` (id, name, query, icon, color, sortOrder, createdAt) и `RuleHits` (itemId, ruleId) — одна миграция. `vaultMetaTables['folders']` += `smart_folders`, триггеры очереди. `SmartFoldersRepository`: `watchAll`, `create(name, query)`, `rename`, `remove`/`restore`. Кнопка «+ Умная папка» у «Ищу: …» в панели строки, лист имени. Пилюли на полке главной после папок. `features/smart/smart_folder_screen.dart`: запрос разбирается заново (`parseSearch(query, now)`), лента найденного. Тесты: миграция, репозиторий, файл хранилища, экран.
6. **Папку предлагают сами.** `ItemsRepository.folderSuggestion(dismissed: Set<String>) → FolderSuggestion?` (ключ `site:<host>` или `kind:<вид>`, число, имя, id заметок), порог 8. Карточка на главной; «Сделать» — папка, перенос (`sortedBy = rule`), правило сайта, «Отменить»; «Не надо» — prefs `folder_suggest_dismissed`. Тесты: репозиторий (группы, порог, без папки, удалённые), карточка.
7. **Правила видят факты.** `RuleConditionKind` += `pageType`, `priceAbove`, `priceBelow`; `RuleActionKind` += `remindBefore` (значение — минуты). При сохранении такие условия не срабатывают. `services/fact_rules.dart`: `FactRules.apply(itemId)` после записи фактов (`FactsPipeline.onFacts`), один раз на пару заметка-правило (`rule_hits`), папка — только при `sortedBy` none/similar/ai. Лист правила: новые условия и «Напомнить за» (час, день, неделя) только для события. Тесты: сервис (каждое условие, повтор, ручная папка, прошедшее событие), лист правила.
8. **Проверка и документы.** Эмулятор со снимками по каждой задаче. CLAUDE.md, шапка плана.
