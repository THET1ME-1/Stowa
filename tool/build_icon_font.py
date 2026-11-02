#!/usr/bin/env python3
"""Собирает шрифты иконок Stowa из Material Symbols Rounded.

Иконку тега человек выбирает из всего набора, и в базе она лежит строкой.
Tree-shaking такие обращения не видит и режет глифы вслепую (у Veha так
пропали иконки в релизе), а пакет material_symbols_icons тащит три
вариативных шрифта на 34 МБ. Поэтому вариативный шрифт схлопывается в два
начертания: контурное и залитое, весь набор в каждом.

Запуск: python3 tool/build_icon_font.py
После обновления пакета перезапустить и закоммитить шрифты с реестром.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DART = ROOT / 'lib' / 'core' / 'icons' / 'icon_registry.dart'
FONTS = {
    'StowaSymbols': 'FILL=0',
    'StowaSymbolsFilled': 'FILL=1',
}

# С этих иконок начинается выбор иконки тега, остальное через поиск.
PICKABLE = [
    'directions_car', 'restaurant', 'lightbulb', 'key', 'movie', 'redeem',
    'fitness_center', 'pets', 'school', 'sports_esports', 'menu_book', 'favorite',
    'savings', 'local_cafe', 'checkroom', 'brush', 'park', 'build',
    'flight', 'home', 'shopping_cart', 'music_note', 'smart_display', 'palette',
    'work', 'medical_services', 'child_care', 'celebration', 'photo_camera', 'code',
]


def pub_cache_font() -> tuple[Path, Path]:
    """Вариативный шрифт и карта кодов внутри material_symbols_icons."""
    config = json.loads((ROOT / '.dart_tool' / 'package_config.json').read_text())
    for package in config['packages']:
        if package['name'] == 'material_symbols_icons':
            root = Path(package['rootUri'].replace('file://', ''))
            if not root.is_absolute():
                root = (ROOT / '.dart_tool' / root).resolve()
            return (
                root / 'lib' / 'fonts' / 'MaterialSymbolsRounded.ttf',
                root / 'lib' / 'iconname_to_unicode_map.dart',
            )
    raise SystemExit('Пакет material_symbols_icons не найден, сделайте flutter pub get')


def codepoints(name_map: Path) -> dict[str, int]:
    source = name_map.read_text(encoding='utf-8')
    codes = {
        match.group(1): int(match.group(2), 16)
        for match in re.finditer(r"'([\w]+)':\s*0x([0-9a-fA-F]+)", source)
    }
    missing = set(PICKABLE) - codes.keys()
    if missing:
        raise SystemExit(f'Не нашлись иконки: {sorted(missing)}')
    return codes


def build_font(source: Path, family: str, fill: str, codes: list[int]) -> Path:
    out = ROOT / 'assets' / 'fonts' / f'{family}.ttf'
    unicodes = ','.join(f'U+{code:04X}' for code in codes)
    # оси схлопываем в одно начертание, иначе в сборку едут все промежуточные
    subprocess.run(
        [sys.executable, '-m', 'fontTools.varLib.instancer', str(source),
         fill, 'wght=400', 'GRAD=0', 'opsz=24', '-o', str(out)],
        check=True, stdout=subprocess.DEVNULL,
    )
    subprocess.run(
        [sys.executable, '-m', 'fontTools.subset', str(out), f'--unicodes={unicodes}',
         '--no-layout-closure', '--desubroutinize', f'--output-file={out}'],
        check=True, stdout=subprocess.DEVNULL,
    )
    return out


def write_dart(codes: dict[str, int]) -> None:
    lines = [
        '// Файл собран tool/build_icon_font.py, руками не править.',
        "import 'package:flutter/widgets.dart';",
        '',
        "const symbolFontFamily = 'StowaSymbols';",
        "const symbolFilledFontFamily = 'StowaSymbolsFilled';",
        '',
        '/// Запасная иконка: имя пришло из базы с устройства, где набор шире.',
        "const symbolFallback = 'label';",
        '',
        'const Map<String, int> _codes = {',
    ]
    for name in sorted(codes):
        lines.append(f"  '{name}': 0x{codes[name]:x},")
    lines += [
        '};',
        '',
        '/// Иконка по имени Material Symbols. Неизвестное имя даёт запасную, а не крэш.',
        'IconData symbolIcon(String? name, {bool filled = false}) {',
        '  final code = _codes[name] ?? _codes[symbolFallback]!;',
        '  // имя приходит из базы, поэтому сборка идёт с --no-tree-shake-icons',
        '  // ignore: non_const_argument_for_const_parameter',
        '  return IconData(code, fontFamily: filled ? symbolFilledFontFamily : symbolFontFamily);',
        '}',
        '',
        '/// Есть ли такая иконка в наборе.',
        'bool hasSymbol(String name) => _codes.containsKey(name);',
        '',
        '/// Все имена набора, по ним идёт поиск в выборе иконки.',
        'Iterable<String> get symbolNames => _codes.keys;',
        '',
        '/// Ходовые иконки для тегов: их показывают первыми, до поиска.',
        'const List<String> pickableSymbols = [',
    ]
    for name in PICKABLE:
        lines.append(f"  '{name}',")
    lines += ['];', '']
    OUT_DART.parent.mkdir(parents=True, exist_ok=True)
    OUT_DART.write_text('\n'.join(lines), encoding='utf-8')


def main() -> None:
    source, name_map = pub_cache_font()
    codes = codepoints(name_map)
    for family, fill in FONTS.items():
        out = build_font(source, family, fill, sorted(set(codes.values())))
        print(f'{out.relative_to(ROOT)}: {len(codes)} иконок, {out.stat().st_size // 1024} КБ')
    write_dart(codes)


if __name__ == '__main__':
    main()
