#!/bin/bash
# Серый экран после окна виджета: система выгрузила приложение, окно виджета подняло
# новый процесс, потом человек открыл Stowa. Печатает ОК или СЕРЫЙ ЭКРАН.
# Нужен запущенный эмулятор с установленной сборкой и adb root (иначе не убить процесс
# и не открыть закрытое окно виджета).
A=${ADB:-$HOME/Android/Sdk/platform-tools/adb}
nap() { python3 -c "import time; time.sleep($1)"; }
top_activity() { $A shell dumpsys activity activities | grep -m1 topResumedActivity | grep -o 'app.stowa/[.A-Za-z]*'; }
flutter_view() { $A shell dumpsys activity top | awk '/ACTIVITY app.stowa\/.MainActivity/{p=1} p' | grep -A12 'View Hierarchy' | grep -c 'FlutterView'; }

# 1. приложение открыто и ушло в фон с сохранённым состоянием
pid=$($A shell pidof app.stowa); [ -n "$pid" ] && $A shell kill -9 "$pid" && nap 2
$A shell am start -n app.stowa/.MainActivity > /dev/null; nap 12
echo "шаг 1: наверху $(top_activity), вид Flutter в окне: $(flutter_view)"
$A shell input keyevent KEYCODE_HOME; nap 3

# 2. система убила процесс
$A shell kill -9 "$($A shell pidof app.stowa)"; nap 2
echo "шаг 2: процесс после убийства: '$($A shell pidof app.stowa)'"

# 3. окно виджета подняло новый процесс и закрылось
$A shell am start -n app.stowa/.QuickActivity > /dev/null; nap 12
echo "шаг 3: наверху $(top_activity)"
$A shell input keyevent KEYCODE_HOME; nap 6
echo "шаг 3: после ухода процесс $($A shell pidof app.stowa)"

# 4. человек открыл приложение
$A shell am start -n app.stowa/.MainActivity > /dev/null 2>&1; nap 12
views=$(flutter_view)
echo "шаг 4: наверху $(top_activity), вид Flutter в окне: $views"
[ "$views" -ge 1 ] && echo "ОК" || { echo "СЕРЫЙ ЭКРАН"; exit 1; }
