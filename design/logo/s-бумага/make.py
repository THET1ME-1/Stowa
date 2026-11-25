"""Знак Stowa: один лист бумаги, свёрнутый в S (25.11.2026, хозяин: «слишком ровное, хочу
больше хаоса бумаги, центральный чуть кривой широкий, низ и верх разные»; «не тупо наклонить, а
формы поменять»; «должен быть один цельный, будто бумагу свернули в S»).

Один кусок без зазоров. Середина — лицевая сторона листа (белая), широкая и чуть кривая: оба
боковых края с изломом. Концы S — тот же лист, загнутый по линиям сгиба: верхний отогнут вправо
от правого края, нижний — влево от левого, и видна изнанка (серая). Сгиб — общий край белого и
серого, без щели. Концы разные: верхний длиннее и светлее, нижний короче, ниже и в тени. Верхний
край листа и верх клапана идут почти одной линией, как у настоящего сгиба; так же низ.

Запуск: python3 make.py — пишет SVG, глиф без фона и PNG 1024 рядом с собой.
"""
import math
import pathlib

import cairosvg

HERE = pathlib.Path(__file__).parent
BACKGROUND = '#141517'
FACE = '#F2F2F0'
BACK_TOP = '#9A9BA1'
BACK_BOTTOM = '#808187'

# лицевая середина по часовой; у каждого угла своё скругление (0 — острый)
TL, TR, KR, BR, BL, KL = (296, 262), (548, 248), (640, 500), (744, 772), (474, 790), (382, 540)
FRONT = [(TL, 76), (TR, 0), (KR, 0), (BR, 50), (BL, 0), (KL, 0)]


def along(start, end, part):
    return (start[0] + (end[0] - start[0]) * part, start[1] + (end[1] - start[1]) * part)


# сгибы: верхний — по правому краю от угла вниз, нижний — по левому краю от угла вверх
TOP_FOLD = along(TR, KR, 0.55)
BOTTOM_FOLD = along(BL, KL, 0.62)

# верхний конец: отогнут вправо, верх продолжает верхний край листа, низ уходит косо вниз
TOP_END = [TR, (756, 234), (750, 410), TOP_FOLD]
# нижний конец: отогнут влево, короче и ниже верхнего, низ продолжает нижний край листа
BOTTOM_END = [BL, (272, 806), (258, 668), BOTTOM_FOLD]

# у сгиба бумага заворачивается: клин тоном темнее вдоль линии сгиба, у верхнего шире
TOP_CREASE = [TR, (612, 244), TOP_FOLD]
BOTTOM_CREASE = [BL, (432, 793), BOTTOM_FOLD]
CREASE_TOP = '#86878D'
CREASE_BOTTOM = '#6F7076'


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
    # концы рисуются под серединой и заходят под неё на полточки: общий край сгиба без щели
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <!-- Stowa: один лист, свёрнутый в S — лицевая середина и загнутые концы с изнанкой. -->
  {ground}
  <path d="{polygon(TOP_END)}" fill="{BACK_TOP}" stroke="{BACK_TOP}" stroke-width="1" stroke-linejoin="round"/>
  <path d="{polygon(BOTTOM_END)}" fill="{BACK_BOTTOM}" stroke="{BACK_BOTTOM}" stroke-width="1" stroke-linejoin="round"/>
  <path d="{polygon(TOP_CREASE)}" fill="{CREASE_TOP}"/>
  <path d="{polygon(BOTTOM_CREASE)}" fill="{CREASE_BOTTOM}"/>
  <path d="{rounded(FRONT)}" fill="{FACE}"/>
</svg>
'''


(HERE / 'stowa-s-paper.svg').write_text(svg())
(HERE / 'stowa-s-paper-glyph.svg').write_text(svg(background=False))
cairosvg.svg2png(url=str(HERE / 'stowa-s-paper.svg'), write_to=str(HERE / 'stowa-s-paper-1024.png'), output_width=1024, output_height=1024)
