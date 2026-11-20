#!/usr/bin/env bash
# Собрать веб-версию для выкладки: build/web.
#
# Движок рисования и шрифты кладём рядом с приложением (--no-web-resources-cdn): сайт не
# ходит на чужие серверы. Значки приложение выбирает по имени на лету, поэтому шрифт
# значков целиком (--no-tree-shake-icons).
#
# Запуск: tool/web/build.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

flutter pub get
nice -n 19 flutter build web --release --no-web-resources-cdn --no-tree-shake-icons

# без этих двух файлов база в браузере не откроется: их версия записана в web/README.md
for file in sqlite3.wasm drift_worker.js; do
  test -s "build/web/$file" || { echo "нет build/web/$file" >&2; exit 1; }
done
# временные замеры в выкладку не едут
if grep -q 'DEBUG-perf' build/web/main.dart.js; then
  echo 'в сборке остались временные замеры [DEBUG-perf]' >&2
  exit 1
fi
du -sh build/web
