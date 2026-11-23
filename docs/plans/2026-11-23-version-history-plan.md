# История версий в Stowa Sync — план

> Исполняется в этой же сессии (`superpowers:executing-plans`), без агентов. Шаги — галочки `- [ ]`.

**Цель:** история каждой правки со всех устройств, разница строк и слов, возврат версии и удалённого, журнал правок; пункт «История версий» на экране покупки без «Скоро».

**Устройство:** сервер отдаёт ревизии списками (зашифрованные заголовки и номера частей), телефон открывает их сам. `CloudHistory` обходит цепочку переездов по `prev`, складывает правки в сеансы и отдаёт содержимое. Экраны сливают облачные версии со снимками устройства.

**Описание:** `docs/specs/2026-11-23-version-history-design.md`. Сервер — `~/Projects/GitHub/stowa-sync`.

## Общие условия

- Сервер: тесты `nice -n 19 dart test -j 1` (свой Postgres в docker на 55442). Выкатка — по `CLAUDE.md` сервера, перед ней копия базы `/root/stowa-db-before-history-20261123.sql.gz`.
- Телефон: только затронутые тесты локально (`TMPDIR=~/.cache/flutter-tmp systemd-run --user --scope -q -p CPUQuota=500% -p MemoryMax=5G -p MemorySwapMax=0 nice -n 19 flutter test -j 3 <файлы>`), весь набор — `check.yml`.
- Строки — во всех 7 словарях через `tool/add_strings.py`. Код — Read+Edit.
- Сроки: всё 30 дней; до года — последняя за день; старше — последняя за месяц; удалённое — год. Сеанс — перерыв меньше 10 минут, одно устройство.

## На что смотреть при проверке

1. Переименовал заметку, поправил, переименовал обратно — история целая, без петли (задача 7).
2. Нет сети или 402 — экран истории открывается со снимками устройства, без ошибки во весь экран (задача 9).
3. Возврат удалённой заметки, когда её имя уже занято — кладётся рядом, ничего не затёрто (задача 11).
4. Уборка: часть, на которую ссылается оставшаяся ревизия, не стирается; у прорежённой — стирается (задача 3).
5. Версия заметки на 5 МБ — список открывается без скачивания всех версий целиком (задача 7, содержимое лениво).

---

### Задача 1: схема 004 — время и устройство ревизии (сервер)

**Файлы:** создать `migrations/004.sql`; изменить `lib/api.dart` (`_Account` с `device`, `_who`, `_commit`), `test/support.dart` (`truncateAll` без изменений), `test/history_test.dart`.

- [ ] Тест `ревизия помнит устройство и время отправки`: вход с `device: 'Pixel 8'`, две отправки `f1` — у прежней ревизии `device = 'Pixel 8'`, `made_at` = `updated_at` файла до замены.
- [ ] Красный → `004.sql` (`files.device`, `revisions.made_at`, `revisions.device`, заполнение `made_at` из `created_at`, индекс `(account_id, made_at)`) и запись в `_commit` → зелёный → коммит.

### Задача 2: ответы истории (сервер)

**Файлы:** `lib/api.dart`, `test/history_test.dart`.

**Даёт:** `GET /v1/files/<file>/revisions?before=&limit=` → `{revisions: [{rev, deleted, meta, blobs, size, at, device}], more}`; `GET /v1/deleted?after=&limit=` → `{files: [{file, rev, at, device, meta, last: {rev, meta, blobs, size, at, device}?}], next}`; `GET /v1/log?after=&limit=` → `{entries: [{file, rev, deleted, meta, size, at, device}], next}`; `DELETE /v1/files/<file>/history` → 204. Курсор `after` — непрозрачная строка из `next`; `null` — дальше нет.

- [ ] Тесты: `ревизии файла новыми первыми и страницами`; `удалённые с последней живой ревизией`; `журнал по времени через все файлы, страницами`; `стереть историю — ревизий нет, надгробие на месте`; `без подписки — 402, стереть можно и без подписки`; `чужой аккаунт не видит`.
- [ ] Красные → код → зелёные → коммит.

### Задача 3: сроки хранения (сервер)

**Файлы:** `lib/api.dart` (`collectGarbage`), `test/history_test.dart`.

- [ ] Тесты: `месяц — всё, до года — последняя за день, старше — за месяц`; `удалённое старше года стирается целиком`; `часть оставшейся ревизии цела, прорежённой — стёрта`; надгробия не прореживаются.
- [ ] Красные → код → зелёные → коммит → выкатка с копией базы, проверка `/health` и списка ревизий своим токеном.

### Задача 4: переезды в движке (телефон)

**Файлы:** `lib/services/sync/sync_crypto.dart` (`FileMeta.prev`, `FileMeta.to`), `lib/services/sync/sync_engine.dart` (`_push`, `_upload`), `test/services/sync/sync_engine_test.dart`.

- [ ] Тесты: `переименованная заметка несёт номер прежнего пути, надгробие — нового`; `переехала и поправлена в одном проходе — узнаётся по id в шапке`; `вложение переехало — узнаётся по содержимому`; `копия файла не крадёт переезд у оригинала`.
- [ ] Красные → код → зелёные → коммит.

### Задача 5: порты истории (телефон)

**Файлы:** `lib/services/sync/sync_ports.dart` (`RemoteRevision`, `RevisionPage`, `DeletedPage`, `LogPage`, методы `revisions`, `deleted`, `log`, `purgeHistory`), `sync_http.dart`, `test/services/sync/fakes.dart` (те же правила, что у сервера: ревизии, устройство, время).

- [ ] Тест разбора ответов `HttpSyncRemote` на подставном клиенте; `FakeRemote` хранит прежние ревизии.
- [ ] Красный → код → зелёный → коммит.

### Задача 6: разница слов

**Файлы:** `lib/domain/text_diff.dart` (`diffWords(String before, String after) → List<WordPiece>`; `WordPiece {String text; DiffKind kind}`; `pairChanged(List<DiffLine>)` — убранная и добавленная строки рядом становятся парой), `test/domain/text_diff_test.dart`.

- [ ] Тесты: слово заменено в середине строки; знаки препинания отдельно; кириллица; длинная строка без зависания.
- [ ] Красные → код → зелёные → коммит.

### Задача 7: `CloudHistory`

**Файлы:** создать `lib/services/sync/cloud_history.dart`, `test/services/sync/cloud_history_test.dart`; провайдер в `lib/data/providers.dart`.

**Даёт:** `CloudVersion {String file; String path; int rev; DateTime at; String? device; int size; String hash; List<String> blobs; bool deleted}`; `VersionSession {List<CloudVersion> versions /* новые первыми */; CloudVersion get last; DateTime get from; DateTime get to}`; `List<VersionSession> sessionsOf(List<CloudVersion>, {Duration gap = const Duration(minutes: 10)})`; `class CloudHistory {Future<List<CloudVersion>> versions(String path); Future<List<int>> content(CloudVersion v); Future<String> text(CloudVersion v); Future<List<DeletedFile>> deleted(); Future<List<LogEntry>> log({int limit}); Future<void> purge(String path)}`; `DeletedFile {CloudVersion last; DateTime deletedAt; String? device}`; `LogEntry {CloudVersion version}`.

- [ ] Тесты: цепочка переездов A→B→A без петли; сеансы по устройству и перерыву; служебное и переезды не в удалённых; содержимое берётся из кэша второй раз; битый заголовок — версия пропускается, остальные есть.
- [ ] Красные → код → зелёные → коммит.

### Задача 8: экран истории заметки

**Файлы:** `lib/features/item/history_screen.dart` (слить облако и снимки, сеансы, устройство, состояния), `lib/data/repositories/history_repository.dart` (`restoreText(itemId, {title, body}, at)`), `lib/features/item/item_screen.dart` (пункт «История» у подписчика всегда), строки, `test/features/item/history_screen_test.dart`.

- [ ] Тесты: облако и снимок с тем же текстом — одна строка; снимок без пары — «Только на этом устройстве»; нет сети — снимки и тихая строка «Нет связи»; без подписки — карточка Stowa Sync; возврат облачной версии — снимок нынешнего и плашка «Отменить»; «Изменения» против предыдущей версии.
- [ ] Красные → код → зелёные → коммит.

### Задача 9: история холста, базы и рисунка

**Файлы:** экраны `features/canvas/canvas_file_screen.dart`, `features/base/base_file_screen.dart`, `features/drawing/*` — пункт «История» в меню; экран версий документа (время, устройство, размер, «Вернуть»).

- [ ] Тест: возврат версии холста меняет документ и отменяется.
- [ ] Красный → код → зелёный → коммит.

### Задача 10: «В облаке» в корзине

**Файлы:** `lib/features/settings/trash_screen.dart`, служба возврата файла (`SyncService.restoreFile`), строки, тесты корзины.

- [ ] Тесты: удалённая заметка возвращается с вложениями; имя занято — «(2)»; лежит в корзине телефона — возвращается оттуда, не из облака; «Стереть навсегда» спрашивает и убирает строку.
- [ ] Красные → код → зелёные → коммит.

### Задача 11: журнал правок

**Файлы:** создать `lib/features/settings/sync_log_screen.dart`; вход из `sync_screen.dart`; строки; тест.

- [ ] Тест: дни, имена, устройство; касание открывает историю файла.
- [ ] Красный → код → зелёный → коммит.

### Задача 12: витрина, документы, сайт

- [ ] `paywall_screen.dart`: у истории `soon: false`, тест «один — скоро»; `featureHistoryHint` во всех словарях — по срокам.
- [ ] Таблица в `docs/specs/2026-11-22-stowa-sync-subscription-design.md`; `site/privacy.html`, `site/ru/privacy.html`, `site/terms.html`, `site/ru/terms.html`, `docs/store/privacy-answers.md` — сколько живут версии.
- [ ] `CLAUDE.md` Stowa и сервера — раздел об истории.
- [ ] `flutter analyze` — 0, `check.yml` зелёный, сайт собран и выложен.
