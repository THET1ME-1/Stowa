"""Знак Stowa: буква S из трёх граней, в манере образца-оригами.

Посередине белый лист наклоном «\» — спинка S, скруглены его углы сверху слева и снизу справа:
там у S чаши. Сверху справа и снизу слева — серые клапаны, как изнанка на сгибе у образца: это
концы буквы. Между гранями зазор цвета фона. Цвета из тёмной темы приложения.
Запуск: python3 make.py — пишет SVG и PNG 1024 рядом с собой.
"""
import math
import pathlib

import cairosvg

HERE = pathlib.Path(__file__).parent
BACKGROUND, FACE, BACK = '#141517', '#F2F2F0', '#96979D'
CENTER = 512

# лист: верхний край от (LEFT, TOP) шириной EDGE, нижний — то же, повёрнутое на 180°
LEFT, TOP, EDGE = 286, 252, 236
RADIUS = 56
GAP = 16
# клапан: насколько он опускается от верхней линии
FLAP = 150


def turned(point):
    """Та же точка, повёрнутая на 180° вокруг середины: S симметрична."""
    return (2 * CENTER - point[0], 2 * CENTER - point[1])


a = (LEFT, TOP)
b = (LEFT + EDGE, TOP)
c = turned(a)
d = turned(b)


def rounded(points, corners):
    """Многоугольник со скруглёнными вершинами (номера в corners), дугой радиуса RADIUS."""
    out = []
    count = len(points)
    for index, point in enumerate(points):
        if index not in corners:
            out.append(('L', point))
            continue
        before, after = points[index - 1], points[(index + 1) % count]
        to_before = (before[0] - point[0], before[1] - point[1])
        to_after = (after[0] - point[0], after[1] - point[1])
        length_before, length_after = math.hypot(*to_before), math.hypot(*to_after)
        cosine = (to_before[0] * to_after[0] + to_before[1] * to_after[1]) / (length_before * length_after)
        angle = math.acos(max(-1.0, min(1.0, cosine)))
        tangent = RADIUS / math.tan(angle / 2)
        start = (point[0] + to_before[0] / length_before * tangent, point[1] + to_before[1] / length_before * tangent)
        end = (point[0] + to_after[0] / length_after * tangent, point[1] + to_after[1] / length_after * tangent)
        out.append(('L', start))
        out.append(('A', end))
    path = []
    for index, (kind, (x, y)) in enumerate(out):
        if index == 0:
            path.append(f'M{x:.1f} {y:.1f}')
        elif kind == 'L':
            path.append(f'L{x:.1f} {y:.1f}')
        else:
            path.append(f'A{RADIUS} {RADIUS} 0 0 1 {x:.1f} {y:.1f}')
    return ' '.join(path) + ' Z'


def flap():
    """Верхний клапан — конец S: от верхнего края листа вправо, внешний конец свисает вниз,
    как у S верхний кончик. От листа отделён зазором вдоль его правого края."""
    along = (c[0] - b[0]) / (c[1] - b[1])
    shift = GAP / math.cos(math.atan(along))
    near = (b[0] + shift, TOP)
    far = (turned(a)[0], TOP)
    low = (far[0], TOP + FLAP)
    return [near, far, low]


def polygon(points):
    return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in points) + ' Z'


def svg(background=True):
    top_flap = flap()
    bottom_flap = [turned(point) for point in top_flap]
    ground = f'<rect width="1024" height="1024" fill="{BACKGROUND}"/>' if background else ''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <!-- Stowa: S из трёх граней — белый лист и два серых клапана на сгибах. -->
  {ground}
  <path d="{polygon(top_flap)}" fill="{BACK}"/>
  <path d="{rounded([a, b, c, d], corners={0, 2})}" fill="{FACE}"/>
  <path d="{polygon(bottom_flap)}" fill="{BACK}"/>
</svg>
'''


(HERE / 'stowa-s-origami.svg').write_text(svg())
(HERE / 'stowa-s-origami-glyph.svg').write_text(svg(background=False))
cairosvg.svg2png(url=str(HERE / 'stowa-s-origami.svg'), write_to=str(HERE / 'stowa-s-origami-1024.png'), output_width=1024, output_height=1024)
