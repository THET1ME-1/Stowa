# Перенос из Google Keep, закладок браузера, Obsidian и mymind — план

> **Сделано 14 ноября 2026, все 6 задач.** Эмулятор: выгрузка Keep из трёх заметок через системный выбор папки — «Перенёс 3 заметки», список закреплён с галочками, дата Keep. mymind на настоящей выгрузке не проверен: формат `cards.csv` не описан. Перенос Telegram не тронут, его строка переехала на экран «Перенос».

**Цель:** остаток шага 4 из `docs/specs/2026-11-03-offline-recall-design.md`, раздел 3. Заметки из Google Keep (Takeout), закладки браузера (HTML), папка Markdown (Obsidian) и выгрузка mymind (`cards.csv`) становятся заметками Stowa со своими датами.

**Как:** как у Telegram. Разбор выгрузки — чистые функции в `domain`, сохранение через `CaptureService.captureAll` пачками по 50: правила, угадыватель, ИИ, файлы и хранилище работают как при обычном сохранении.

## Решения

- **Общая будущая заметка** `ImportedNote {text, title?, files: List<ExportedFile>, at, tags, pinned, folder: List<String>}` в `domain/imported_note.dart`. Файл — `ExportedFile` из переноса Telegram, путь от папки выгрузки.
- **Google Keep.** Вход — папка `Keep` из Takeout (или любая папка выше, `.json` ищутся вглубь). Поля: `title`, `textContent`, `listContent[{text, isChecked}]`, `attachments[{filePath, mimetype}]`, `annotations[{url}]`, `labels[{name}]`, `isTrashed`, `isPinned`, `createdTimestampUsec`. Корзина не переносится. Заголовок — первой строкой текста, список — `- [ ]`/`- [x]`, ссылка из `annotations` — строкой в конце, если её нет в тексте. Ярлыки — теги, закреплённая — закреплённой. Takeout пишет в `filePath` `.jpeg`, а кладёт `.jpg`: файл ищется и с другим расширением картинки.
- **Закладки браузера.** Вход — файл `.html` (формат Netscape, его выгружают Chrome, Firefox, Яндекс, Edge, Safari). Закладка — заметка-ссылка: текст — адрес, заголовок — название закладки, дата — `ADD_DATE`. Папка закладки (ближайшая, кроме «Панели закладок» и «Других закладок») и `TAGS` Firefox — теги. Не `http(s)` (`javascript:`, `place:`) — мимо.
- **Obsidian (папка Markdown).** Вход — папка. Каждый `.md`, кроме папок с точкой, — заметка через `readVaultNote`: заголовок и дата из свойств, иначе имя и время файла; теги из свойств. Подпапки — папки Stowa (создаются, если нет). Картинки `![[имя]]` и `![](путь)` из текста ложатся вложениями, имя ищется по всей папке, как у Obsidian.
- **mymind.** Вход — папка выгрузки с `cards.csv`. Колонки mymind нигде не описаны, поэтому столбцы узнаются по названию: заголовок (`title`, `name`), адрес (`url`, `link`, `source`), текст (`content`, `text`, `note`, `body`, `description`, `highlight`), теги (`tags`, `labels`), дата (`created`, `created_at`, `date`). Ячейка, равная имени файла в папке, — вложение. Не проверено на настоящей выгрузке.
- **Повторный перенос не двоит:** заметка с той же датой до секунды и тем же текстом уже есть — пропуск, как у Telegram.
- **Перенос Telegram не трогаю:** у него свои тесты и заполнение файлов задним числом, общего у них только цикл пачек.
- **Экран «Перенос»:** пять источников не помещаются в раздел настроек, поэтому на главном экране настроек строка «Перенос» с итогом, а источники — отдельным экраном, у каждого подпись одним предложением.

## Задачи

1. `domain/imported_note.dart`, `domain/keep_export.dart` `parseKeepNote(Map json) → ImportedNote?`. Тесты: текст и заголовок, список, ссылка из `annotations`, ярлыки и закрепление, корзина мимо, дата из микросекунд, не заметка Keep — null.
2. `domain/bookmarks_export.dart` `parseBookmarks(String html) → List<ImportedNote>`. Тесты: Chrome с панелью закладок и вложенной папкой, Firefox с `TAGS`, `javascript:` мимо, не закладки — `FormatException`.
3. `domain/mymind_export.dart` `parseMymindCsv(String csv, {Set<String> files}) → List<ImportedNote>`. Тесты: кавычки, переносы и запятые в ячейке, колонки в любом порядке и регистре, файл по имени, нет ни текста, ни адреса — `FormatException`.
4. `services/notes_import.dart` `NotesImport.run(ImportSource, String path, {progress}) → ImportReport {added, repeated, filesMissing}`. Тесты на каждый источник: даты, теги, папки Obsidian, вложения, закреплённая Keep, повторный перенос даёт `repeated`, `.jpeg` → `.jpg`, пустая папка — `NotesImportError`.
5. Экран «Перенос», строки на 7 языков, виджет-тест экрана.
6. FEATURES.md, CLAUDE.md, тесты затронутых файлов локально с потолком.
