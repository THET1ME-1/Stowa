#!/usr/bin/env bash
# Выложить собранную веб-версию (build/web) на сервер и проверить, что сайт отвечает.
#
# Куда выкладывать, в репозитории не записано: он открытый.
#   STOWA_WEB_SSH   — кому и куда по ssh, например user@host
#   STOWA_WEB_KEY   — ключ ssh (необязательно)
#   STOWA_WEB_DIR   — папка сайта на сервере, по умолчанию /var/www/stowa-web
#   STOWA_WEB_URL   — адрес сайта для проверки, по умолчанию https://stowa.work
#
# Сервер раздаёт папку как есть. Ему нужны два заголовка на каждый ответ, иначе база
# в браузере работает в медленном и ненадёжном режиме:
#   Cross-Origin-Opener-Policy: same-origin
#   Cross-Origin-Embedder-Policy: require-corp
# и Cache-Control: no-cache — имена файлов от сборки к сборке те же.
#
# Адрес сайта менять нельзя: заметки «в этом браузере» привязаны к нему.
#
# Запуск: tool/web/build.sh && tool/web/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

: "${STOWA_WEB_SSH:?куда выкладывать: STOWA_WEB_SSH=user@host}"
dir="${STOWA_WEB_DIR:-/var/www/stowa-web}"
url="${STOWA_WEB_URL:-https://stowa.work}"
ssh_command=(ssh -o BatchMode=yes)
if [ -n "${STOWA_WEB_KEY:-}" ]; then ssh_command+=(-i "$STOWA_WEB_KEY"); fi

test -s build/web/main.dart.js || { echo 'сначала tool/web/build.sh' >&2; exit 1; }

# новая сборка ложится рядом и встаёт на место одной сменой имён: посетитель не получит
# страницу от новой сборки с кодом от старой
"${ssh_command[@]}" "$STOWA_WEB_SSH" "mkdir -p '$dir.next'"
rsync -a --delete -e "${ssh_command[*]}" build/web/ "$STOWA_WEB_SSH:$dir.next/"
"${ssh_command[@]}" "$STOWA_WEB_SSH" "rm -rf '$dir.prev' && { [ ! -d '$dir' ] || mv '$dir' '$dir.prev'; } && mv '$dir.next' '$dir'"

# сайт отвечает, заголовки на месте, движок базы отдаётся своим типом
headers=$(curl -fsS -m 20 -D - -o /dev/null "$url/")
echo "$headers" | grep -qi '^cross-origin-opener-policy: same-origin' || { echo 'нет заголовка Cross-Origin-Opener-Policy' >&2; exit 1; }
echo "$headers" | grep -qi '^cross-origin-embedder-policy: require-corp' || { echo 'нет заголовка Cross-Origin-Embedder-Policy' >&2; exit 1; }
# без него боковая панель расширения не загрузит сайт (STOWA-9)
echo "$headers" | grep -qi '^cross-origin-resource-policy: cross-origin' || { echo 'нет заголовка Cross-Origin-Resource-Policy' >&2; exit 1; }
curl -fsS -m 20 -D - -o /dev/null "$url/sqlite3.wasm" | grep -qi '^content-type: application/wasm' || { echo 'sqlite3.wasm отдаётся не как application/wasm' >&2; exit 1; }
local_version=$(cat build/web/version.json)
remote_version=$(curl -fsS -m 20 "$url/version.json")
[ "$local_version" = "$remote_version" ] || { echo "на сайте другая сборка: $remote_version" >&2; exit 1; }
echo "выложено: $url, $remote_version"
