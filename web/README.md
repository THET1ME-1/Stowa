# web/

Обвязка сборки для браузера (`flutter build web`).

`sqlite3.wasm` и `drift_worker.js` — файлы выпуска drift 2.35.3 (https://github.com/simolus3/drift/releases/tag/drift-2.35.3). Обновляются вместе с drift в `pubspec.lock`: чужая версия воркера с другой версией drift не открывает базу.

| Файл | sha256 |
|---|---|
| sqlite3.wasm | efd308be92a34f3aa15f289a37f213b0230fd80888a1364326ee29579d892d37 |
| drift_worker.js | a54b81412d4c4ab56653bb9e4c02912b0820bb37e2bba00722ddef4d78083d4a |

Значки `icons/` и `favicon.png` — заготовка Flutter, пока у Stowa нет логотипа.
