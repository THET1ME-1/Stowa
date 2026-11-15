#!/usr/bin/env bash
# Собирает виды виджетов iPhone (ios/StowaWidget/) под macOS и рисует их в картинки.
# Файлы WidgetKit (*Widget.swift, StowaWidgetBundle.swift) не берутся: им нужен телефон.
# Только macOS: SwiftUI на Linux нет. В CI гоняется ios-widget-layout.yml.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/widget_layout"
mkdir -p "$out"
widget="$root/ios/StowaWidget"

swiftc -swift-version 5 -module-name StowaLayout \
  "$widget/Texts.swift" \
  "$widget/Palette.swift" \
  "$widget/Snapshot.swift" \
  "$widget/ComposerViews.swift" \
  "$widget/NoteViews.swift" \
  "$root/tool/widget_layout/main.swift" \
  -o "$out/probe"

# язык подписей Texts берёт из AppleLanguages: рисуем по-русски
"$out/probe" "$out" -AppleLanguages '(ru)'
