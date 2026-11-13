"""Новые знаки Stowa про заметки, без буквы S и без карандаша. Белое на графите,
детали вырезаны цветом фона. Сетка 100×100.
"""
import pathlib

import cairosvg

OUT = pathlib.Path(__file__).parent / 'notes-2'
OUT.mkdir(exist_ok=True)
BACK = '#2A2E33'
INK = '#F4F4F2'


def rule(x1, x2, y, width=3.6):
    return f'<path d="M {x1} {y} H {x2}" stroke="{BACK}" stroke-width="{width}" stroke-linecap="round"/>'


def margin_page():
    # тетрадный лист: поля слева и строки
    page = f'<rect x="25" y="18" width="50" height="64" rx="9" fill="{INK}"/>'
    margin = f'<rect x="36" y="18" width="3" height="64" fill="{BACK}"/>'
    return page + margin + rule(46, 66, 38) + rule(46, 66, 50) + rule(46, 58, 62)


def tabbed_page():
    # лист с вкладками-разделителями справа: заметки разложены по разделам
    tabs = ''.join(f'<rect x="58" y="{y}" width="22" height="12" rx="4.5" fill="{INK}"/>' for y in (26, 44, 62))
    gap = f'<rect x="18.5" y="16.5" width="53" height="67" rx="10.5" fill="{BACK}"/>'
    page = f'<rect x="20" y="18" width="50" height="64" rx="9" fill="{INK}"/>'
    return tabs + gap + page + rule(30, 58, 38) + rule(30, 58, 50) + rule(30, 48, 62)


def ring_notebook():
    # блокнот на кольцах: кольца выходят из дырок и уходят за верхний край
    # кольца — короткие пилюли поперёк верхнего края, вокруг каждой щель
    page = f'<rect x="24" y="24" width="52" height="60" rx="9" fill="{INK}"/>'
    rings = ''.join(f'<rect x="{x - 4.5}" y="13.5" width="9" height="23" rx="4.5" fill="{BACK}"/>'
                    f'<rect x="{x - 2.5}" y="15.5" width="5" height="19" rx="2.5" fill="{INK}"/>' for x in (36, 50, 64))
    return page + rings + rule(34, 66, 50) + rule(34, 66, 61) + rule(34, 54, 72)


def sticker_stack():
    # стопка стикеров: верхний с отклеенным уголком
    back = f'<rect x="30" y="20" width="48" height="48" rx="7" fill="{INK}" transform="rotate(8 54 44)"/>'
    front_shape = 'M 29 28 H 63 A 7 7 0 0 1 70 35 V 60 L 56 74 H 29 A 7 7 0 0 1 22 67 V 35 A 7 7 0 0 1 29 28 Z'
    gap = f'<path d="{front_shape}" fill="{BACK}" stroke="{BACK}" stroke-width="6" stroke-linejoin="round"/>'
    front = f'<path d="{front_shape}" fill="{INK}"/>'
    # уголок загнут внутрь: треугольник со щелью вокруг
    flap = 'M 70 60 L 56 74 L 56 64 A 4 4 0 0 1 60 60 Z'
    curl = (f'<path d="{flap}" fill="{BACK}" stroke="{BACK}" stroke-width="5" stroke-linejoin="round"/>'
            f'<path d="{flap}" fill="{INK}" stroke="{INK}" stroke-width="1" stroke-linejoin="round"/>')
    return back + gap + front + curl + rule(31, 58, 42) + rule(31, 50, 52)


def perforated():
    # лист, оторванный от блокнота: дырочки сверху и строки
    page = f'<rect x="24" y="18" width="52" height="64" rx="9" fill="{INK}"/>'
    holes = ''.join(f'<circle cx="{x}" cy="27" r="2.4" fill="{BACK}"/>' for x in range(32, 70, 6))
    return page + holes + rule(33, 67, 44) + rule(33, 67, 55) + rule(33, 55, 66)


def tag():
    # тег: знак #, его верхняя перекладина — строка заметки, длиннее остальных
    bars = (f'<path d="M 42 22 L 36 78 M 63 22 L 57 78" stroke="{INK}" stroke-width="8" stroke-linecap="round"/>'
            f'<path d="M 22 40 H 80 M 20 60 H 72" stroke="{INK}" stroke-width="8" stroke-linecap="round"/>')
    return bars


VARIANTS = [
    ('1-поля', 'Тетрадь с полями', margin_page),
    ('2-вкладки', 'Лист с вкладками', tabbed_page),
    ('3-кольца', 'Блокнот на кольцах', ring_notebook),
    ('4-стикеры', 'Стопка стикеров', sticker_stack),
    ('5-перфорация', 'Лист из блокнота', perforated),
    ('6-тег', 'Тег #', tag),
]


def svg(inner, size=100):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="{size}" height="{size}"><rect width="100" height="100" fill="{BACK}"/>{inner}</svg>'


for name, _, make in VARIANTS:
    (OUT / f'{name}.svg').write_text(svg(make()))
    for size in (512, 48):
        cairosvg.svg2png(bytestring=svg(make()).encode(), write_to=str(OUT / f'{name}-{size}.png'), output_width=size, output_height=size)
print('ok')
