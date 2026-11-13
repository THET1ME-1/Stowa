"""Ещё знаки Stowa без буквы S, только белым: детали разделяют щели цветом фона."""
import math
import pathlib

import cairosvg

OUT = pathlib.Path(__file__).parent / 'mono-2'
OUT.mkdir(exist_ok=True)
BACK = '#2A2E33'
INK = '#F4F4F2'


def chest():
    # сундук: убрать и сохранить
    lid = f'<path d="M 18 47 V 40 C 18 27 30 20 50 20 C 70 20 82 27 82 40 V 47 Z" fill="{INK}"/>'
    body = f'<path d="M 18 51 H 82 V 74 A 8 8 0 0 1 74 82 H 26 A 8 8 0 0 1 18 74 Z" fill="{INK}"/>'
    bands = ''.join(f'<rect x="{x}" y="18" width="3.4" height="66" fill="{BACK}"/>' for x in (29, 67.6))
    lock = (f'<rect x="42" y="40" width="16" height="19" rx="4" fill="{BACK}"/>'
            f'<rect x="45" y="43" width="10" height="13" rx="2.5" fill="{INK}"/>'
            f'<circle cx="50" cy="48" r="2" fill="{BACK}"/><rect x="49" y="48" width="2" height="5" rx="1" fill="{BACK}"/>')
    return lid + body + bands + lock


def mailbox():
    # почтовый ящик с поднятым флажком: заметка легла
    # ящик сбоку: полукруглый верх, дверца слева, столбик, флажок поднят
    box = f'<path d="M 14 66 V 50 A 14 14 0 0 1 28 36 H 70 A 14 14 0 0 1 84 50 V 66 Z" fill="{INK}"/>'
    door = f'<path d="M 26 42 V 66" stroke="{BACK}" stroke-width="3.4"/>'
    post = f'<rect x="45" y="66" width="10" height="22" fill="{INK}"/>'
    flag = (f'<rect x="61.5" y="17.5" width="9" height="40" rx="4.5" fill="{BACK}"/>'
            f'<rect x="64" y="20" width="4" height="35" rx="2" fill="{INK}"/>'
            f'<path d="M 64 20 H 79 A 3 3 0 0 1 82 23 V 28 A 3 3 0 0 1 79 31 H 64 Z" fill="{INK}"/>')
    return box + door + post + flag


def pushpin():
    # канцелярская кнопка: заметка приколота
    pin = (f'<rect x="-11" y="-36" width="22" height="9" rx="4.5" fill="{INK}"/>'
           f'<path d="M -6.5 -27 H 6.5 L 8 -14 H -8 Z" fill="{INK}"/>'
           f'<rect x="-16" y="-14" width="32" height="9" rx="4.5" fill="{INK}"/>'
           f'<path d="M 0 -5 V 22" stroke="{INK}" stroke-width="3.4" stroke-linecap="round"/>')
    return f'<g transform="translate(52 52) rotate(32)">{pin}</g>'


def return_arrow():
    # вернуть в нужный момент: стрелка обходит круг и приходит к точке
    r = 25
    start, end = -55, 235
    sx, sy = 50 + r * math.cos(math.radians(start)), 50 + r * math.sin(math.radians(start))
    ex, ey = 50 + r * math.cos(math.radians(end)), 50 + r * math.sin(math.radians(end))
    arc = f'<path d="M {sx:.2f} {sy:.2f} A {r} {r} 0 1 1 {ex:.2f} {ey:.2f}" fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>'
    # наконечник в конце дуги, по направлению хода (угол растёт — касательная (-sin, cos))
    direction = math.degrees(math.atan2(math.cos(math.radians(end)), -math.sin(math.radians(end))))
    head = f'<g transform="translate({ex:.2f} {ey:.2f}) rotate({direction:.1f})"><path d="M 9 0 L -4 -9 L -4 9 Z" fill="{INK}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/></g>'
    return arc.replace(f'{ex:.2f} {ey:.2f}"', f'{ex:.2f} {ey:.2f}"').replace('stroke-linecap="round"', 'stroke-linecap="butt"') + f'<circle cx="{sx:.2f}" cy="{sy:.2f}" r="4.5" fill="{INK}"/>' + head + f'<circle cx="50" cy="50" r="7" fill="{INK}"/>'


def matryoshka():
    # матрёшка: папка в папке, каждая внутри большей
    # большая — контуром: та же фигура, раздутая обводкой, поверх неё фигура цветом фона;
    # так кольцо всюду одной толщины. Внутри — маленькая сплошная
    def doll(cx, cy, scale, fill, grow=0.0):
        stroke = f' stroke="{fill}" stroke-width="{grow}" stroke-linejoin="round"' if grow else ''
        shape = 'M 0 -16 C 20 -16 26 6 22 22 Q 21 28 14 28 H -14 Q -21 28 -22 22 C -26 6 -20 -16 0 -16 Z'
        return (f'<g transform="translate({cx} {cy}) scale({scale})">'
                f'<path d="{shape}" fill="{fill}"{stroke}/><circle cx="0" cy="-25" r="12" fill="{fill}"{stroke}/></g>')
    return doll(50, 56, 1.05, INK, grow=11) + doll(50, 56, 1.05, BACK) + doll(50, 62, 0.5, INK)


def clipped_note():
    # записка со скрепкой
    note = f'<rect x="26" y="24" width="48" height="58" rx="8" fill="{INK}"/>'
    lines = ''.join(f'<path d="M 35 {y} H {end}" stroke="{BACK}" stroke-width="3.4" stroke-linecap="round"/>' for y, end in [(50, 65), (59, 65), (68, 54)])
    clip = 'M 39 44 V 20 A 6 6 0 0 1 51 20 V 38 A 3 3 0 0 1 45 38 V 24'
    return (note + lines + f'<path d="{clip}" fill="none" stroke="{BACK}" stroke-width="8.5" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="{clip}" fill="none" stroke="{INK}" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/>')


VARIANTS = [
    ('7-сундук', chest),
    ('8-почта', mailbox),
    ('9-кнопка', pushpin),
    ('10-вернуть', return_arrow),
    ('11-матрёшка', matryoshka),
    ('12-скрепка', clipped_note),
]


def svg(inner, size=100):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="{size}" height="{size}"><rect width="100" height="100" fill="{BACK}"/>{inner}</svg>'


for name, make in VARIANTS:
    (OUT / f'{name}.svg').write_text(svg(make()))
    for size in (512, 48):
        cairosvg.svg2png(bytestring=svg(make()).encode(), write_to=str(OUT / f'{name}-{size}.png'), output_width=size, output_height=size)
print('ok')
