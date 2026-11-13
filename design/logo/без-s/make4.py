"""Знаки Stowa без буквы S, только белым: детали разделяют щели цветом фона."""
import math
import pathlib

import cairosvg

OUT = pathlib.Path(__file__).parent / 'mono'
OUT.mkdir(exist_ok=True)
BACK = '#2A2E33'
INK = '#F4F4F2'


def acorn():
    # белка прячет жёлудь на потом
    stem = f'<rect x="47.5" y="12" width="5" height="12" rx="2.5" fill="{INK}" transform="rotate(14 50 22)"/>'
    cap = f'<path d="M 25 47 C 25 31 37 22 50 22 C 63 22 75 31 75 47 Q 75 51 71 51 H 29 Q 25 51 25 47 Z" fill="{INK}"/>'
    stripe = f'<path d="M 34 40 Q 50 33 66 40" fill="none" stroke="{BACK}" stroke-width="2.8" stroke-linecap="round"/>'
    nut = f'<path d="M 31 55.5 H 69 C 69 72 61 83 50 88 C 39 83 31 72 31 55.5 Z" fill="{INK}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>'
    return stem + cap + stripe + nut


def _point(p, t):
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = p
    u = 1 - t
    return (u**3 * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t**3 * x3,
            u**3 * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t**3 * y3)


def _part(p, a, b, steps=30):
    return 'M ' + ' L '.join(f'{x:.2f} {y:.2f}' for x, y in (_point(p, a + (b - a) * i / steps) for i in range(steps + 1)))


def knot():
    # узелок на память: правый ход ленты лежит поверх левого
    first = ((14, 70), (36, 70), (62, 62), (62, 40))
    last = ((38, 40), (38, 62), (64, 70), (86, 70))
    # где ходы пересекаются: ближайшие точки двух кривых
    _, t = min((math.dist(_point(first, a / 200), _point(last, b / 200)), b / 200) for a in range(201) for b in range(201))
    full = 'M 14 70 C 36 70 62 62 62 40 C 62 22 38 22 38 40 C 38 62 64 70 86 70'
    return (f'<path d="{full}" fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>'
            f'<path d="{_part(last, t - 0.09, t + 0.09)}" fill="none" stroke="{BACK}" stroke-width="16"/>'
            f'<path d="{_part(last, t - 0.16, t + 0.16)}" fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>')


def folded_note():
    # записку сложили и убрали: уголок загнут крупно
    note = 'M 30 22 H 48 L 78 52 V 70 A 8 8 0 0 1 70 78 H 30 A 8 8 0 0 1 22 70 V 30 A 8 8 0 0 1 30 22 Z'
    flap = 'M 48 22 L 78 52 H 54 A 6 6 0 0 1 48 46 Z'
    # загнутый уголок лежит на записке: вокруг него щель цветом фона
    gap = f'<path d="{flap}" fill="{BACK}" stroke="{BACK}" stroke-width="7" stroke-linejoin="round"/>'
    lines = ''.join(f'<path d="M 31 {y} H {end}" stroke="{BACK}" stroke-width="3.4" stroke-linecap="round"/>' for y, end in [(60, 66), (68, 56)])
    return f'<path d="{note}" fill="{INK}"/>{gap}<path d="{flap}" fill="{INK}" stroke="{INK}" stroke-width="1.5" stroke-linejoin="round"/>{lines}'


def honeycomb():
    # соты: две ячейки полны, третья ждёт
    def hexagon(cx, cy, r, filled):
        points = ' '.join(f'{cx + r * math.cos(math.radians(a)):.2f},{cy + r * math.sin(math.radians(a)):.2f}' for a in range(-90, 270, 60))
        if filled:
            return f'<polygon points="{points}" fill="{INK}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
        return f'<polygon points="{points}" fill="none" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    r = 13.5
    step = math.sqrt(3) * (r + 2.5) + 3.2
    left_y = 34 + step * math.sqrt(3) / 2
    return hexagon(50, 34, r, False) + hexagon(50 - step / 2, left_y, r, True) + hexagon(50 + step / 2, left_y, r, True)


def ribbons():
    # блокнот с двумя ленточками-закладками
    tape = ''
    for x, end in [(34, 88), (46, 82)]:
        tape += f'<path d="M {x} 66 V {end} L {x + 4.5} {end - 5} L {x + 9} {end} V 66 Z" fill="{INK}" stroke="{INK}" stroke-width="1.2" stroke-linejoin="round"/>'
    gap = f'<rect x="22" y="71" width="56" height="3.2" fill="{BACK}"/>'
    book = (f'<rect x="24" y="14" width="52" height="57" rx="9" fill="{INK}"/>'
            f'<rect x="63" y="14" width="4" height="57" fill="{BACK}"/>')
    return tape + gap + book


def shelf():
    # полка: корешки разной высоты, крайний прислонился
    def book(x, top, w):
        return (f'<rect x="{x}" y="{top}" width="{w}" height="{72 - top}" rx="3" fill="{INK}"/>'
                f'<rect x="{x + 2.5}" y="{top + 7}" width="{w - 5}" height="3" rx="1.5" fill="{BACK}"/>')
    leaning = f'<g transform="rotate(-14 86 72)">{book(75, 34, 11)}</g>'
    return (book(16, 34, 10) + book(28.5, 26, 12) + book(43, 38, 9.5) + book(55, 30, 9)
            + leaning + f'<path d="M 13 77.5 H 88" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>')


VARIANTS = [
    ('1-жёлудь', acorn),
    ('2-узелок', knot),
    ('3-записка', folded_note),
    ('4-соты', honeycomb),
    ('5-закладки', ribbons),
    ('6-полка', shelf),
]


def svg(inner, size=100):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="{size}" height="{size}"><rect width="100" height="100" fill="{BACK}"/>{inner}</svg>'


for name, make in VARIANTS:
    (OUT / f'{name}.svg').write_text(svg(make()))
    for size in (512, 48):
        cairosvg.svg2png(bytestring=svg(make()).encode(), write_to=str(OUT / f'{name}-{size}.png'), output_width=size, output_height=size)
print('ok')
