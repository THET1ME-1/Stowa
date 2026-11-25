"""Знак Stowa: S-оригами, неровнее (25.11.2026). Основа — прежний знак: один лист, сложенный в S.
Цельным его делает то, что верхний край листа и верх серого клапана — одна линия, низ — тоже, а
тонкие щели между гранями — это сгибы. Здесь эта основа сохранена, а ровность снята по степеням:
лист шире и с изломом краёв, клапаны разной величины и наклона, их длинный край слегка выгнут,
как у бумаги, щели сгибов разной ширины, скругления чаш разные.

Запуск: python3 variants.py — три знака и лист сравнения рядом с собой.
"""
import math
import pathlib

import cairosvg

HERE = pathlib.Path(__file__).parent
BACKGROUND, FACE, BACK, BACK_DARK = '#141517', '#F2F2F0', '#96979D', '#7F8086'


def unit(vector):
    length = math.hypot(*vector)
    return (vector[0] / length, vector[1] / length)


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


def bent_sheet(top_left, top_right, bottom_right, bottom_left, right_bulge, left_bulge, radius_top, radius_bottom):
    """Лист: верх и низ прямые, длинные края — плавные дуги (выгиб вправо на right_bulge и
    left_bulge точек), скруглены верхний левый и нижний правый углы — чаши S."""

    def toward(point, other, distance):
        direction = unit((other[0] - point[0], other[1] - point[1]))
        return (point[0] + direction[0] * distance, point[1] + direction[1] * distance)

    def tangent(corner, before, after, radius):
        to_before = unit((before[0] - corner[0], before[1] - corner[1]))
        to_after = unit((after[0] - corner[0], after[1] - corner[1]))
        cosine = to_before[0] * to_after[0] + to_before[1] * to_after[1]
        return radius / math.tan(math.acos(max(-1.0, min(1.0, cosine))) / 2)

    def control(start, end, bulge):
        # середина хорды, сдвинутая вправо по x на bulge — край гнётся в одну сторону
        return ((start[0] + end[0]) / 2 + bulge * 2, (start[1] + end[1]) / 2)

    cut_top = tangent(top_left, bottom_left, top_right, radius_top)
    cut_bottom = tangent(bottom_right, top_right, bottom_left, radius_bottom)
    top_out = toward(top_left, top_right, cut_top)
    top_in = toward(top_left, bottom_left, cut_top)
    bottom_in = toward(bottom_right, top_right, cut_bottom)
    bottom_out = toward(bottom_right, bottom_left, cut_bottom)
    right = control(top_right, bottom_in, right_bulge)
    left = control(bottom_left, top_in, left_bulge)
    return (
        f'M{top_out[0]:.1f} {top_out[1]:.1f} L{top_right[0]:.1f} {top_right[1]:.1f} '
        f'Q{right[0]:.1f} {right[1]:.1f} {bottom_in[0]:.1f} {bottom_in[1]:.1f} '
        f'A{radius_bottom:.0f} {radius_bottom:.0f} 0 0 1 {bottom_out[0]:.1f} {bottom_out[1]:.1f} '
        f'L{bottom_left[0]:.1f} {bottom_left[1]:.1f} '
        f'Q{left[0]:.1f} {left[1]:.1f} {top_in[0]:.1f} {top_in[1]:.1f} '
        f'A{radius_top:.0f} {radius_top:.0f} 0 0 1 {top_out[0]:.1f} {top_out[1]:.1f} Z'
    )


def on_line(start, end, y):
    return (start[0] + (y - start[1]) * (end[0] - start[0]) / (end[1] - start[1]), y)


def shifted(start, end, gap, side):
    """Прямая [start, end], сдвинутая на gap: side 1 — вправо по ходу, -1 — влево."""
    direction = unit((end[0] - start[0], end[1] - start[1]))
    normal = (-direction[1] * side, direction[0] * side)
    return (start[0] + normal[0] * gap, start[1] + normal[1] * gap), (end[0] + normal[0] * gap, end[1] + normal[1] * gap)


def flap(corner, near, far, bulge):
    """Треугольный клапан: угол, ближняя точка у сгиба, дальняя; длинный край near→far выгнут на bulge."""
    middle = ((near[0] + far[0]) / 2, (near[1] + far[1]) / 2)
    direction = unit((far[0] - near[0], far[1] - near[1]))
    control = (middle[0] - direction[1] * bulge, middle[1] + direction[0] * bulge)
    return f'M{near[0]:.1f} {near[1]:.1f} L{corner[0]:.1f} {corner[1]:.1f} L{far[0]:.1f} {far[1]:.1f} Q{control[0]:.1f} {control[1]:.1f} {near[0]:.1f} {near[1]:.1f} Z'


def mark(level):
    """level 0 — прежний ровный знак, 1 — заметно неровный."""
    # верхняя линия листа и клапана: чуть поднимается вправо; нижняя — чуть опускается влево
    top_left = (286 - 10 * level, 252 + 10 * level)
    top_right = (522 + 34 * level, 252 - 2 * level)
    top_far = (738 + 14 * level, 252 - 16 * level)
    bottom_right = (738 + 6 * level, 772 - 8 * level)
    bottom_left = (502 - 26 * level, 772 + 6 * level)
    bottom_far = (286 - 6 * level, 772 + 16 * level)
    # лист чуть изогнут, как гнётся бумага: оба длинных края плавно выгнуты вправо, правый сильнее —
    # посередине лист шире; чаши S скруглены по-разному
    sheet = bent_sheet(top_left, top_right, bottom_right, bottom_left, right_bulge=18 * level, left_bulge=-10 * level, radius_top=56 + 22 * level, radius_bottom=56 - 14 * level)
    # сгибы идут вдоль хорд краёв: клапаны отступают от листа на щель
    right_kink = ((top_right[0] + bottom_right[0]) / 2, (top_right[1] + bottom_right[1]) / 2)
    left_kink = ((top_left[0] + bottom_left[0]) / 2, (top_left[1] + bottom_left[1]) / 2)

    # верхний клапан: верх — та же линия, что верх листа; сгиб — щель вдоль правого края листа
    gap_top = 16 - 2 * level
    fold_top = shifted(top_right, right_kink, gap_top, -1)
    near_top = on_line(*fold_top, top_right[1] + (top_far[1] - top_right[1]) * gap_top / (top_far[0] - top_right[0]))
    low_top = (top_far[0] + 4 * level, 402 + 26 * level)
    upper = flap(top_far, near_top, low_top, 10 * level)

    # нижний клапан меньше и в тени: сгиб шире, длинный край выгнут в другую сторону
    gap_bottom = 16 + 6 * level
    fold_bottom = shifted(bottom_left, left_kink, gap_bottom, -1)
    near_bottom = on_line(*fold_bottom, bottom_left[1] + (bottom_far[1] - bottom_left[1]) * gap_bottom / (bottom_left[0] - bottom_far[0]))
    high_bottom = (bottom_far[0] - 2 * level, 622 + 36 * level)
    lower = flap(bottom_far, near_bottom, high_bottom, -6 * level)
    bottom_tone = BACK if level == 0 else BACK_DARK

    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <rect width="1024" height="1024" fill="{BACKGROUND}"/>
  <path d="{upper}" fill="{BACK}"/>
  <path d="{sheet}" fill="{FACE}"/>
  <path d="{lower}" fill="{bottom_tone}"/>
</svg>
'''


if __name__ == '__main__':
    for name, level in [('чуть', 0.45), ('заметно', 0.8), ('сильно', 1.25)]:
        (HERE / f'вариант-{name}.svg').write_text(mark(level))
        cairosvg.svg2png(url=str(HERE / f'вариант-{name}.svg'), write_to=str(HERE / f'вариант-{name}.png'), output_width=1024, output_height=1024)
