#!/usr/bin/env bash
# Собрать веб-версию для выкладки: build/web.
#
# Движок рисования и шрифты кладём рядом с приложением (--no-web-resources-cdn): сайт не
# ходит на чужие серверы. Значки приложение выбирает по имени на лету, поэтому шрифт
# значков целиком (--no-tree-shake-icons).
#
# Без --wasm. Сборка в WebAssembly рисует в отдельном потоке (skwasm) и прокручивает чуть
# ровнее (папка в 454 заметки: 58 кадров против 49), но портит текст: 21.11.2026 в двух
# заходах из восьми надпись «Найти или записать» теряла и сдвигала буквы, и с видеокартой,
# и без неё. CanvasKit на тех же восьми — ни разу. Включать снова — только после такой же
# проверки на новой версии Flutter (glitch_check: набор в строке, сверка надписей с эталоном).
#
# Запуск: tool/web/build.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

flutter pub get
# --pwa-strategy=none: устаревший service worker Flutter не собирается — на его месте свой,
# web/stowa_sw.js (кнопки уведомлений), а web/flutter_bootstrap.js его и не регистрирует
nice -n 19 flutter build web --release --no-web-resources-cdn --no-tree-shake-icons --pwa-strategy=none

# без этих двух файлов база в браузере не откроется: их версия записана в web/README.md
for file in sqlite3.wasm drift_worker.js main.dart.js; do
  test -s "build/web/$file" || { echo "нет build/web/$file" >&2; exit 1; }
done
# временные замеры в выкладку не едут
if grep -q 'DEBUG-perf' build/web/main.dart.js; then
  echo 'в сборке остались временные замеры [DEBUG-perf]' >&2
  exit 1
fi
du -sh build/web
