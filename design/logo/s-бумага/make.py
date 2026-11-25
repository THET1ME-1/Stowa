"""Знак Stowa: S из бумажных обрезков (25.11.2026, хозяин: «слишком ровное, хочу больше хаоса
бумаги, центральный чуть кривой широкий, низ и верх разные», и следом: «не тупо наклонить, а
формы поменять»).

Посередине — широкая белая полоса, вырезанная от руки: правый и левый края с изломом посередине
(полоса чуть шире в середине), верхний правый угол срезан ножницами, верхняя левая чаша S
скруглена крупно, нижняя правая — мелко. Концы S — разные куски: сверху справа клапан-четырёхугольник
с загнутым тёмным уголком, снизу слева рваный обрывок-пятиугольник тоном темнее. Зазоры между
кусками разные. Цвета из тёмной темы приложения, без цвета.

Запуск: python3 make.py — пишет SVG, глиф без фона и PNG 1024 рядом с собой.
"""
import math
import pathlib

import cairosvg

HERE = pathlib.Path(__file__).parent
BACKGROUND = '#141517'
FACE = '#F2F2F0'
FLAP = '#9A9BA1'
# изнанка загнутого уголка: темнее клапана, как бумага на сгибе
FLAP_BACK = '#6E6F75'
SCRAP = '#84858B'

# полоса по часовой от верхнего левого угла; у каждого угла своё скругление (0 — острый)
STRIP = [
    ((292, 262), 82),  # верхняя чаша S
    ((518, 250), 0),
    ((566, 264), 0),  # срезанный угол
    ((652, 520), 0),  # излом правого края: ниже он круче
    ((748, 784), 52),  # нижняя чаша S, мельче верхней
    ((452, 800), 0),
    ((370, 548), 0),  # излом левого края
]

# верхний клапан: левый край вдоль полосы с зазором 18, уголок справа сверху загнут
FLAP_SHAPE = [(590, 246), (704, 232), (752, 296), (744, 414), (612, 314)]
FLAP_CORNER = [(704, 232), (762, 226), (752, 296)]

# нижний обрывок: рваный пятиугольник, зазор от левого края полосы шире — 22
SCRAP_SHAPE = [(428, 812), (276, 800), (260, 688), (302, 606), (396, 702)]


def unit(vector):
    length = math.hypot(*vector)
    return (vector[0] / length, vector[1] / length)


def rounded(corners):
    """Многоугольник; у вершины с радиусом — дуга этого радиуса."""
    points = [point for point, _ in corners]
    count = len(points)
    path = []
    for index, (point, radius) in enumerate(corners):
        if not radius:
            path.append(('L', point, 0))
            continue
        before, after = points[index - 1], points[(index + 1) % count]
        to_before = unit((before[0] - point[0], before[1] - point[1]))
        to_after = unit((after[0] - point[0], after[1] - point[1]))
        cosine = to_before[0] * to_after[0] + to_before[1] * to_after[1]
        tangent = radius / math.tan(math.acos(max(-1.0, min(1.0, cosine))) / 2)
        path.append(('L', (point[0] + to_before[0] * tangent, point[1] + to_before[1] * tangent), 0))
        path.append(('A', (point[0] + to_after[0] * tangent, point[1] + to_after[1] * tangent), radius))
    out = []
    for index, (kind, (x, y), radius) in enumerate(path):
        if index == 0:
            out.append(f'M{x:.1f} {y:.1f}')
        elif kind == 'L':
            out.append(f'L{x:.1f} {y:.1f}')
        else:
            out.append(f'A{radius} {radius} 0 0 1 {x:.1f} {y:.1f}')
    return ' '.join(out) + ' Z'


def polygon(points):
    return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in points) + ' Z'


def svg(background=True):
    ground = f'<rect width="1024" height="1024" fill="{BACKGROUND}"/>' if background else ''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <!-- Stowa: S из бумажных обрезков — неровная белая полоса, клапан с загнутым уголком и обрывок. -->
  {ground}
  <path d="{polygon(FLAP_SHAPE)}" fill="{FLAP}"/>
  <path d="{polygon(FLAP_CORNER)}" fill="{FLAP_BACK}"/>
  <path d="{rounded(STRIP)}" fill="{FACE}"/>
  <path d="{polygon(SCRAP_SHAPE)}" fill="{SCRAP}"/>
</svg>
'''


(HERE / 'stowa-s-paper.svg').write_text(svg())
(HERE / 'stowa-s-paper-glyph.svg').write_text(svg(background=False))
cairosvg.svg2png(url=str(HERE / 'stowa-s-paper.svg'), write_to=str(HERE / 'stowa-s-paper-1024.png'), output_width=1024, output_height=1024)
