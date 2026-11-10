#!/bin/bash
# Словари LibreOffice для tool/typo_neighbors_test.dart: слова от 6 букв, строчные, UTF-8.
# Запуск: tool/typo_dicts.sh <папка>, потом
#   STOWA_DICTS=<папка> flutter test tool/typo_neighbors_test.dart
set -e
dir=${1:?папка для словарей}
mkdir -p "$dir"
base=https://raw.githubusercontent.com/LibreOffice/dictionaries/master
for path in ru_RU/ru_RU uk_UA/uk_UA en/en_US en/en_GB de/de_DE_frami es/es_ES ro/ro_RO pl_PL/pl_PL \
  fr_FR/dictionaries/fr it_IT/it_IT pt_BR/pt_BR pt_PT/pt_PT tr_TR/tr_TR; do
  name=$(basename "$path")
  curl -sfL -o "$dir/$name.dic" "$base/$path.dic"
  curl -sfL -o "$dir/$name.aff" "$base/$path.aff"
  # кодировка словаря — строка SET в .aff (польский и немецкий не в UTF-8)
  encoding=$(grep -a -m1 '^SET' "$dir/$name.aff" | awk '{print $2}' | tr -d '\r')
  tail -n +2 "$dir/$name.dic" | iconv -f "${encoding:-UTF-8}" -t utf-8 | cut -d/ -f1 | tr -d '\r' | cut -f1 \
    | LC_ALL=C.UTF-8 awk 'length($0) >= 6 {print tolower($0)}' | grep -v '[0-9 .]' | sort -u > "$dir/$name.txt"
  rm "$dir/$name.dic" "$dir/$name.aff"
  echo "$name: $(wc -l < "$dir/$name.txt")"
done
