# Фото и файлы — план

**Описание:** `docs/specs/2026-11-08-photos-files-design.md`. Читать вместе.

**Общие правила:** тесты сперва; локально только затронутые файлы с потолком, весь набор — `check.yml`; строки — `tool/add_strings.py`; коммит и пуш после каждой задачи; код только Read+Edit/Write. Новые факты — новыми извлекателями в `defaultExtractors()`, база не меняется (новые значения `FactKind` — только в enum).

**Где может укусить:** декодер картинок `dart:ui` в `testWidgets` с поддельным временем виснет — тесты извлекателей обычным `test()`; канал `stowa/media` есть не во всех движках; PDF бывает с объектами в потоках, с `/Prev` xref, с повреждённым хвостом — разбор ищет объекты по всему файлу, а не по таблице; кадр видео декодер может не отдать (битый файл) — без кадров, но с длиной.

## Задачи

1. **Карта по месту съёмки.** `watchPlaced` берёт `takenPlace` (как `venuePlace`, событие главнее). Тест в `test/data/`: фото с EXIF-местом стоит там, без него — где сохранено.
2. **Цвета.** `domain/image_colors.dart`: `enum ColorFamily`, `colorFamilyOf(r,g,b)`, `mainColors(Uint8List rgba) → List<MainColor>` (семья, доля, средний цвет). `ColorsExtractor` (картинки и обложка, стамп — вложения и `preview_at`). `FactKind.color`. `SearchQuery.colors` и слова цвета на 7 языках; фильтр в `_admitted`. `FolderOrder.color` + `ItemCard.mainHue`. Строки. Тесты: семьи на чистых цветах и границах, доли, порог; запросы «синее фото», «red», «rote»; фильтр; порядок доски.
3. **QR.** `zxing2` в зависимостях. `domain/qr_payload.dart`: `QrPayload.parse(text)` (url, wifi с именем и паролем, текст). `QrExtractor` (декодирует через `dart:ui` в RGBA, `RGBLuminanceSource`, `QRCodeReader`, при неудаче — `GlobalHistogramBinarizer`). `FactKind.qr`. Кнопки на странице заметки в `FactsChips`. Строки. Тесты: разбор строк Wi-Fi с экранированием, ссылка, текст; извлекатель на сгенерированной QR-картинке (кодирует сам `zxing2`).
4. **Видео.** Канал `stowa/media` (`MediaChannel.kt`): `probe(path) → {seconds, width, height}`, `frame(path, ms, maxSide) → jpeg`. Регистрация в `MainActivity` и `ShareActivity`. `services/media_probe.dart` с заменой в тестах, `Extractor.ready` (по умолчанию true): пайплайн пропускает неготовые, не отмечая прогона. `VideoExtractor` → обложка, кадры, факты `frame`; `after` ставит `cover_path` и `duration_seconds`, если пусто. Страница заметки: обложка, полоса кадров. Тесты: извлекатель с поддельным `MediaProbe`, пропуск без канала, полоса кадров.
5. **PDF.** `domain/pdf_text.dart`: `pdfPages(Uint8List) → List<String>`. `documentText` знает `pdf`. Тесты на PDF, собранных в тесте: простой шрифт, кириллица через `ToUnicode` и `Identity-H`, сжатый поток, потоки объектов, `TJ` с промежутками, две страницы по порядку, зашифрованный — пусто. Плюс настоящий PDF из пакета `pdf` в кэше (dev-зависимость, генерирует с кириллицей).
6. **Проверка и документы.** Эмулятор со снимками: цветной поиск, доска по цвету, ролик с кадрами, PDF ищется, QR-кнопка, фото на карте. CLAUDE.md, шапка плана.
