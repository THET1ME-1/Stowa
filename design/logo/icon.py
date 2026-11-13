"""Квадратная иконка из обведённого знака: фон как на референсе, знак белым по центру."""
import pathlib
import re
import sys

import cairosvg

HERE = pathlib.Path(__file__).parent
BACK = '#2A2E33'
INK = '#FFFFFF'
# обводка и приставка имён: «trace.svg stowa» — первый знак, «trace2.svg stowa2» — второй
SOURCE, NAME = (sys.argv[1], sys.argv[2]) if len(sys.argv) > 2 else ('trace.svg', 'stowa')

trace = (HERE / SOURCE).read_text()
paths = ''.join(re.findall(r'<path[^>]*/>', trace)).replace('fill="#000000"', f'fill="{INK}"')
width, height = (int(v) for v in re.search(r'width="(\d+)" height="(\d+)"', trace).groups())

# знак занимает 62% высоты: в круглой маске Android видна середина 66%
size = 1024
scale = size * 0.62 / height
dx = (size - width * scale) / 2
dy = (size - height * scale) / 2
glyph = f'<g transform="translate({dx:.2f} {dy:.2f}) scale({scale:.5f})">{paths}</g>'

full = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}"><rect width="{size}" height="{size}" fill="{BACK}"/>{glyph}</svg>'
only = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">{glyph}</svg>'
(HERE / f'{NAME}-icon.svg').write_text(full)
(HERE / f'{NAME}-glyph.svg').write_text(only)
cairosvg.svg2png(bytestring=full.encode(), write_to=str(HERE / f'{NAME}-icon-1024.png'))
cairosvg.svg2png(bytestring=only.encode(), write_to=str(HERE / f'{NAME}-glyph-1024.png'))
print('ok')
