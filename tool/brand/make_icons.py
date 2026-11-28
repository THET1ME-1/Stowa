"""Значки Stowa из мастер-файла знака: iPhone, Android и сайт.

Запуск из корня репозитория: python3 tool/brand/make_icons.py

Знак не перерисовывается: берётся фигура `#half` из design/logo/master/S_logo_master.svg
и её копия, повёрнутая на 180° (как в самом мастер-файле). Меняются только цвета и поля.
Поправил мастер — запусти заново, все значки пересоберутся.
"""
import io
import json
import pathlib
import re

import cairosvg
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
MASTER = ROOT / 'design/logo/master/S_logo_master.svg'

# цвета графитовой темы (lib/core/theme/palette.dart)
GRAPHITE = '#141517'
INK = '#F2F2F0'
PAPER = '#F6F6F4'
INK_ON_PAPER = '#141517'

text = MASTER.read_text()
HALF = re.search(r'<path id="half" d="([^"]+)"', text).group(1)
PIVOT = re.search(r'rotate\(180 ([\d.]+) ([\d.]+)\)', text).groups()
SIZE = 1256


def glyph_svg(color, background=None, size=SIZE, glyph_scale=1.0):
    """Знак во весь холст мастера; glyph_scale < 1 — поля шире (маскируемые значки)."""
    shift = SIZE * (1 - glyph_scale) / 2
    back = f'<rect width="{SIZE}" height="{SIZE}" fill="{background}"/>' if background else ''
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{size}" height="{size}" viewBox="0 0 {SIZE} {SIZE}">{back}'
        f'<g transform="translate({shift} {shift}) scale({glyph_scale})" fill="{color}">'
        f'<path id="half" d="{HALF}"/>'
        f'<use href="#half" xlink:href="#half" transform="rotate(180 {PIVOT[0]} {PIVOT[1]})"/></g></svg>'
    )


def png(svg, size, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = cairosvg.svg2png(bytestring=svg.encode(), output_width=size, output_height=size)
    image = Image.open(io.BytesIO(data))
    # значок iPhone «как в любой теме» без прозрачности: App Store её не принимает
    if svg.count('<rect') and image.mode == 'RGBA':
        image = image.convert('RGB')
    image.save(path, optimize=True)


# iPhone: один размер 1024, три вида — светлый, тёмный и тонированный (iOS 18)
ios = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for old in ios.glob('*.png'):
    old.unlink()
png(glyph_svg(INK_ON_PAPER, PAPER), 1024, ios / 'AppIcon-light.png')
# тёмный и тонированный — знак на прозрачном: фон рисует система
png(glyph_svg(INK), 1024, ios / 'AppIcon-dark.png')
png(glyph_svg('#FFFFFF'), 1024, ios / 'AppIcon-tinted.png')
(ios / 'Contents.json').write_text(json.dumps({
    'images': [
        {'filename': 'AppIcon-light.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'},
        {'appearances': [{'appearance': 'luminosity', 'value': 'dark'}], 'filename': 'AppIcon-dark.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'},
        {'appearances': [{'appearance': 'luminosity', 'value': 'tinted'}], 'filename': 'AppIcon-tinted.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'},
    ],
    'info': {'author': 'xcode', 'version': 1},
}, indent=2) + '\n')

# Android: значок из слоёв. Видимая часть — 72 dp из 108: холст мастера ложится в неё целиком
res = ROOT / 'android/app/src/main/res'
canvas = SIZE * 108 / 72
offset = (canvas - SIZE) / 2
vector = f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Знак Stowa для значка приложения. Собирает tool/brand/make_icons.py из design/logo/master. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="{canvas:g}"
    android:viewportHeight="{canvas:g}">
    <group android:translateX="{offset:g}" android:translateY="{offset:g}">
        <path android:fillColor="@color/ic_launcher_glyph" android:pathData="{HALF}" />
        <group android:rotation="180" android:pivotX="{PIVOT[0]}" android:pivotY="{PIVOT[1]}">
            <path android:fillColor="@color/ic_launcher_glyph" android:pathData="{HALF}" />
        </group>
    </group>
</vector>
'''
(res / 'drawable/ic_launcher_foreground.xml').write_text(vector)
(res / 'drawable/ic_launcher_monochrome.xml').write_text(vector.replace('@color/ic_launcher_glyph', '#FFFFFFFF'))
(res / 'mipmap-anydpi-v26').mkdir(exist_ok=True)
(res / 'mipmap-anydpi-v26/ic_launcher.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<!-- Днём светлый лист и графитовый знак, ночью наоборот; в цвет обоев — одноцветный слой. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
''')
for folder, background, glyph in (('values', PAPER, INK_ON_PAPER), ('values-night', GRAPHITE, INK)):
    (res / folder / 'ic_launcher_colors.xml').write_text(f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Цвета значка приложения. Собирает tool/brand/make_icons.py. -->
<resources>
    <color name="ic_launcher_background">{background}</color>
    <color name="ic_launcher_glyph">{glyph}</color>
</resources>
''')
# запасные картинки для лаунчеров, которые слоёв не читают
for folder, size in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
    png(glyph_svg(INK_ON_PAPER, PAPER), size, res / f'mipmap-{folder}/ic_launcher.png')

# сайт: значок вкладки меняется со светлой и тёмной темой браузера, установленный сайт — графит
web = ROOT / 'web'
favicon = glyph_svg(INK_ON_PAPER).replace(f'fill="{INK_ON_PAPER}"', 'class="glyph"')
favicon = favicon.replace('<g ', '<style>.glyph{fill:#141517}@media (prefers-color-scheme:dark){.glyph{fill:#F2F2F0}}</style><g ', 1)
favicon = re.sub(r' width="\d+" height="\d+"', '', favicon, count=1)
(web / 'favicon.svg').write_text(favicon + '\n')
png(glyph_svg(INK, GRAPHITE), 64, web / 'favicon.png')
png(glyph_svg(INK, GRAPHITE), 180, web / 'icons/apple-touch-icon.png')
png(glyph_svg(INK, GRAPHITE), 192, web / 'icons/Icon-192.png')
png(glyph_svg(INK, GRAPHITE), 512, web / 'icons/Icon-512.png')
# маскируемые: лаунчер может обрезать до круга — знак в безопасной середине
png(glyph_svg(INK, GRAPHITE, glyph_scale=0.86), 192, web / 'icons/Icon-maskable-192.png')
png(glyph_svg(INK, GRAPHITE, glyph_scale=0.86), 512, web / 'icons/Icon-maskable-512.png')

print('значки собраны')
