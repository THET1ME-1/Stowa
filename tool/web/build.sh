#!/usr/bin/env bash
# Собрать веб-версию для выкладки: build/web.
#
# Движок рисования и шрифты кладём рядом с приложением (--no-web-resources-cdn): сайт не
# ходит на чужие серверы. Значки приложение выбирает по имени на лету, поэтому шрифт
# значков целиком (--no-tree-shake-icons).
#
# Сборка в WebAssembly (--wasm): браузер с WasmGC (Chrome, Edge, Firefox, свежий Safari) берёт
# main.dart.wasm, и Flutter рисует в отдельном потоке (skwasm), прокрутка не дёргается от работы
# приложения. Остальные берут main.dart.js, он собирается рядом. Отдельный поток рисования
# требует изоляции страницы: заголовки COOP и COEP на сервере уже стоят ради базы.
#
# Запуск: tool/web/build.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

flutter pub get
nice -n 19 flutter build web --wasm --release --no-web-resources-cdn --no-tree-shake-icons

# без этих двух файлов база в браузере не откроется: их версия записана в web/README.md
for file in sqlite3.wasm drift_worker.js main.dart.wasm main.dart.mjs main.dart.js; do
  test -s "build/web/$file" || { echo "нет build/web/$file" >&2; exit 1; }
done
# временные замеры в выкладку не едут
if grep -aq 'DEBUG-perf' build/web/main.dart.js build/web/main.dart.wasm; then
  echo 'в сборке остались временные замеры [DEBUG-perf]' >&2
  exit 1
fi
du -sh build/web
