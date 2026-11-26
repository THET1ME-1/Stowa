"""Знак Stowa: S из одного листа в манере образца-оригами хозяина (25.11.2026, картинка-пример:
белый лист неправильной формы и под ним загнутый серый уголок).

Как устроен образец и что из него взято:
- лист — неправильный многоугольник: края не параллельны, один угол мягко срезан со скруглением,
  один торчит острым;
- серый треугольник — уголок того же листа, загнутый под него: длинная сторона идёт параллельно
  краю листа через тонкую щель сгиба, остальные стороны продолжают контур листа.

S: белый лист широкий и кривой — сверху слева мягкий срез, справа внизу острый выступ, края с
разным наклоном. Концы S — загнутые уголки: верхний — вдоль верхней части правого края, крупный и
светлый, его верх продолжает верх листа; нижний — вдоль нижней части левого края, мельче и в тени,
его низ продолжает низ листа. Щель сгиба одна — 14 точек, как в образце.

Запуск: python3 make.py — SVG, глиф без фона, PNG 1024.
"""
import math
import pathlib

import cairosvg

HERE = pathlib.Path(__file__).parent
BACKGROUND = '#161718'
FACE = '#F2F2F0'
BACK_TOP = '#9A9BA0'
BACK_BOTTOM = '#86878C'
GAP = 14

# лист по часовой: мягкий срез сверху слева (скруглён), верх, правый край до острого выступа,
# скос к низу, низ, левый край
CHAMFER_LOW, CHAMFER_HIGH = (292, 352), (352, 252)
TOP_RIGHT = (566, 240)
POINT = (762, 626)
BOTTOM_RIGHT = (676, 790)
BOTTOM_LEFT = (464, 792)
SHEET = [(CHAMFER_LOW, 0), (CHAMFER_HIGH, 0), (TOP_RIGHT, 0), (POINT, 0), (BOTTOM_RIGHT, 30), (BOTTOM_LEFT, 0)]
# мягкость среза: скругление обоих его углов, как у образца
SOFT = 34


def unit(vector):
    length = math.hypot(*vector)
    return (vector[0] / length, vector[1] / length)


def offset(start, end, gap):
    """Прямая [start, end], сдвинутая на gap наружу листа (лист обходится по часовой)."""
    direction = unit((end[0] - start[0], end[1] - start[1]))
    normal = (-direction[1], direction[0])
    # по часовой в экранных координатах наружу — влево от хода: нормаль с обратным знаком
    return (start[0] - normal[0] * gap, start[1] - normal[1] * gap), direction


def at_y(line, y):
    (x0, y0), (dx, dy) = line
    return (x0 + (y - y0) * dx / dy, y)


def rounded(corners):
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
        out.append(f'M{x:.1f} {y:.1f}' if index == 0 else (f'L{x:.1f} {y:.1f}' if kind == 'L' else f'A{radius} {radius} 0 0 1 {x:.1f} {y:.1f}'))
    return ' '.join(out) + ' Z'


def polygon(points):
    return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in points) + ' Z'


# мягкий срез: оба его угла скруглены
SHEET[0] = (CHAMFER_LOW, SOFT)
SHEET[1] = (CHAMFER_HIGH, SOFT)

# верхний уголок: вдоль правого края листа через щель; верх — продолжение верха листа
right_fold = offset(TOP_RIGHT, POINT, GAP)
top_slope = (TOP_RIGHT[1] - CHAMFER_HIGH[1]) / (TOP_RIGHT[0] - CHAMFER_HIGH[0])
fold_top = at_y(right_fold, TOP_RIGHT[1] + top_slope * GAP * 1.1)
corner_top = (774, TOP_RIGHT[1] + top_slope * (774 - TOP_RIGHT[0]))
fold_low = at_y(right_fold, 436)
TOP_FLAP = [fold_top, corner_top, fold_low]

# нижний уголок: вдоль левого края листа через щель; низ — продолжение низа листа, мельче верхнего
left_fold = offset(BOTTOM_LEFT, CHAMFER_LOW, GAP)
bottom_slope = (BOTTOM_LEFT[1] - BOTTOM_RIGHT[1]) / (BOTTOM_LEFT[0] - BOTTOM_RIGHT[0])
fold_bottom = at_y(left_fold, BOTTOM_LEFT[1] - bottom_slope * GAP * 1.1)
corner_bottom = (272, BOTTOM_LEFT[1] + bottom_slope * (272 - BOTTOM_LEFT[0]))
fold_high = at_y(left_fold, 640)
BOTTOM_FLAP = [fold_bottom, corner_bottom, fold_high]


def svg(background=True):
    ground = f'<rect width="1024" height="1024" fill="{BACKGROUND}"/>' if background else ''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <!-- Stowa: S из одного листа — белая лицевая сторона и загнутые под неё серые уголки. -->
  {ground}
  <path d="{polygon(TOP_FLAP)}" fill="{BACK_TOP}"/>
  <path d="{rounded(SHEET)}" fill="{FACE}"/>
  <path d="{polygon(BOTTOM_FLAP)}" fill="{BACK_BOTTOM}"/>
</svg>
'''


(HERE / 'stowa-s-paper.svg').write_text(svg())
(HERE / 'stowa-s-paper-glyph.svg').write_text(svg(background=False))
cairosvg.svg2png(url=str(HERE / 'stowa-s-paper.svg'), write_to=str(HERE / 'stowa-s-paper-1024.png'), output_width=1024, output_height=1024)
