"""Варианты знака Stowa: буква S, ставшая ручкой или карандашом.

Общая осевая S — две дуги радиуса 15 с центрами (50,35) и (50,65).
Верхний конец B смотрит наружу под 50°, нижний E пишет в сторону -130°.
Вырезы рисуются цветом плитки поверх: маски cairosvg понимает плохо.
"""
import math
import pathlib

import cairosvg

OUT = pathlib.Path(__file__).parent
INK = '#F2F2F0'
TILE = '#141517'
AMBER = '#FEC766'


def s_path(r=15, top=(50, 35), bottom=(50, 65), start=-40, end=140):
    bx = top[0] + r * math.cos(math.radians(start))
    by = top[1] + r * math.sin(math.radians(start))
    ex = bottom[0] + r * math.cos(math.radians(end))
    ey = bottom[1] + r * math.sin(math.radians(end))
    return f'M {bx:.2f} {by:.2f} A {r} {r} 0 1 0 {top[0]} {top[1] + r} A {r} {r} 0 1 1 {ex:.2f} {ey:.2f}', (bx, by), (ex, ey)


S, B, E = s_path()
WRITE = -130
BACK = 50


def at(point, angle, body):
    return f'<g transform="translate({point[0]:.2f} {point[1]:.2f}) rotate({angle})">{body}</g>'


def shape(d, fill=INK, round_=0.0):
    extra = f' stroke="{fill}" stroke-width="{round_}" stroke-linejoin="round"' if round_ else ''
    return f'<path d="{d}" fill="{fill}"{extra}/>'


def body(w, color=INK, cap='butt'):
    return f'<path d="{S}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="{cap}"/>'


def pencil_tip(w, color=INK):
    h = w / 2
    # заточка — дерево, щель, грифель; щель отделяет грифель и в одном цвете
    return (shape(f'M -0.6 {-h} L 2 {-h} L 13.5 -2.6 L 13.5 2.6 L 2 {h} L -0.6 {h} Z', color, 0.8)
            + shape(f'M 15.2 -2.1 L 20.2 0 L 15.2 2.1 Z', color, 1.8)
            + f'<path d="M 1.6 {-h - 1} L 1.6 {h + 1}" stroke="{TILE}" stroke-width="1.6"/>')


def eraser(w, color=INK):
    h = w / 2
    return (shape(f'M -0.6 {-h} H 6 V {h} H -0.6 Z', color)
            + f'<path d="M 2.2 {-h - 1} V {h + 1} M 4.6 {-h - 1} V {h + 1}" stroke="{TILE}" stroke-width="1.1"/>'
            + shape(f'M 6.6 {-h} H 9.6 A 4.6 4.6 0 0 1 14.2 {-h + 4.6} V {h - 4.6} A 4.6 4.6 0 0 1 9.6 {h} H 6.6 Z', color))


def pencil():
    w = 13
    return body(w) + at(B, BACK, eraser(w)) + at(E, WRITE, pencil_tip(w))


def pencil_dot():
    # карандаш ставит точку: заметка легла на место
    w = 13
    return pencil() + at(E, WRITE, f'<circle cx="26" cy="0" r="3.6" fill="{AMBER}"/>')


def nib():
    w = 13
    h = w / 2
    pen = (shape(f'M -0.6 {-h} L 5 {-h} C 11 {-h} 16 -3 23 0 C 16 3 11 {h} 5 {h} L -0.6 {h} Z')
           + f'<path d="M 2 {-h - 1} V {h + 1}" stroke="{TILE}" stroke-width="1.5"/>'
           + f'<circle cx="10" cy="0" r="2.3" fill="{TILE}"/>'
           + f'<path d="M 10 0 L 24 0" stroke="{TILE}" stroke-width="1.4"/>')
    return body(w) + at(B, BACK, f'<circle cx="0" cy="0" r="{h}" fill="{INK}"/>') + at(E, WRITE, pen)


def written():
    # тонкий росчерк S, ручка ещё стоит на его конце
    w = 5.4
    pen = (shape('M 0 0 L 6.5 -3.8 L 6.5 3.8 Z', INK, 1.6)
           + shape('M 8 -3.8 H 25 A 3.8 3.8 0 0 1 25 3.8 H 8 Z', INK)
           + f'<path d="M 12 -3.8 V -6.6 H 22 V -3.8" fill="none" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>')
    # S сдвинута вверх и влево: ручке нужно место справа внизу, как в руке правши
    end = (E[0] - 5, E[1] - 7)
    return f'<g transform="translate(-5 -7)">{body(w, cap="round")}</g>' + at((end[0] + 0.6, end[1] + 1.2), 58, pen)


def tile():
    # белая плитка M3, в ней S цветом фона с заточенным хвостом
    w = 12.5
    inner = (body(w, TILE) + at(B, BACK, f'<circle cx="0" cy="0" r="{w / 2}" fill="{TILE}"/>')
             + at(E, WRITE, shape(f'M -0.6 {-w / 2} L 15 -1.4 Q 17.4 0 15 1.4 L -0.6 {w / 2} Z', TILE)))
    return (f'<rect x="9" y="9" width="82" height="82" rx="28" fill="{INK}"/>'
            f'<g transform="translate(50 50) scale(0.86) translate(-50 -50)">{inner}</g>')


def color_pencil():
    # тот же карандаш, но заточка цветом папки: знак узнаётся и в цвете
    w = 13
    h = w / 2
    tip = (shape(f'M 2 {-h} L 13.5 -2.6 L 13.5 2.6 L 2 {h} Z', AMBER, 0.8)
           + shape('M 13.5 -2.6 L 20.2 0 L 13.5 2.6 Z', INK, 1.4))
    return body(w) + at(B, BACK, eraser(w)) + at(E, WRITE, shape(f'M -0.6 {-h} H 2 V {h} H -0.6 Z') + tip)


def ballpoint():
    # шариковая ручка: сверху кнопка, снизу конус с шариком
    w = 13
    h = w / 2
    button = at(B, BACK, shape(f'M 2.2 -3.6 H 6 A 3.6 3.6 0 0 1 6 3.6 H 2.2 Z'))
    tip = at(E, WRITE, shape(f'M 2 {-h} L 12.5 -2.2 L 12.5 2.2 L 2 {h} Z', INK, 0.8) + f'<circle cx="15" cy="0" r="1.9" fill="{INK}"/>')
    return body(w) + button + tip


def marker():
    # маркер: S со скошенным кончиком поверх выделенной строки
    w = 14
    h = w / 2
    band = f'<rect x="18" y="43" width="64" height="15" rx="4" fill="{AMBER}"/>'
    tip = at(E, WRITE, shape(f'M -0.6 {-h} L 2 {-h} L 2 {h} L -0.6 {h} Z') + shape(f'M 3.6 {-h} L 8 {-h} L 13 {h - 1.2} L 3.6 {h} Z', INK, 1.2))
    return band + body(w) + at(B, BACK, f'<circle cx="0" cy="0" r="{h}" fill="{INK}"/>') + tip


def bookmark():
    # S-закладка: сверху вырез ленты, снизу перо
    w = 13
    h = w / 2
    notch = at(B, BACK, shape(f'M -0.6 {-h} L 11 {-h} L 5.5 0 L 11 {h} L -0.6 {h} Z', INK, 0.8))
    tip = at(E, WRITE, shape(f'M -0.6 {-h} L 5 {-h} C 11 {-h} 16 -3 22 0 C 16 3 11 {h} 5 {h} L -0.6 {h} Z')
             + f'<path d="M 9 0 L 23 0" stroke="{TILE}" stroke-width="1.4"/>')
    return body(w) + notch + tip


VARIANTS = [
    ('1-карандаш', pencil),
    ('2-перо', nib),
    ('3-точка', pencil_dot),
    ('4-росчерк', written),
    ('5-плитка', tile),
    ('6-цветной', color_pencil),
    ('7-шариковая', ballpoint),
]


def svg(inner, back=TILE, size=100):
    plate = f'<rect width="100" height="100" rx="24" fill="{back}"/>' if back else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="{size}" height="{size}">{plate}{inner}</svg>'


for name, make in VARIANTS:
    (OUT / f'{name}.svg').write_text(svg(make()))
    for size in (512, 48):
        cairosvg.svg2png(bytestring=svg(make()).encode(), write_to=str(OUT / f'{name}-{size}.png'), output_width=size, output_height=size)
print('ok')
