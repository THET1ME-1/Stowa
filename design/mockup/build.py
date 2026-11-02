# Сборка макета: шрифты, иконки и фото вшиваются в одну страницу, сеть не нужна.
import base64
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
b64 = lambda path: base64.b64encode(open(path, 'rb').read()).decode()

fonts = ''.join(
    f"@font-face{{font-family:'{name}';src:url(data:font/woff2;base64,{b64(f'{HERE}/fonts/{file}')}) format('woff2');font-weight:{weight};font-display:block}}\n"
    for name, file, weight in [('Onest', 'onest.woff2', '100 900'), ('Unbounded', 'unbounded.woff2', '200 900'),
                               ('TgSymbols', 'symbols.woff2', '300 600')])

# иконки: имя внутри <i class="ic"> меняется на её знак из шрифта
icons = json.load(open(f'{HERE}/icons.json'))
def icon_glyph(match):
    name = match.group(2)
    if name not in icons:
        raise SystemExit(f'нет иконки {name}')
    return f'{match.group(1)}&#x{icons[name]};</i>'

page = open(f'{HERE}/template.html').read()
page = page.replace('/*FONTS*/', fonts)
page = re.sub(r'(<i class="ic[^"]*"[^>]*>)([a-z0-9_]+)</i>', icon_glyph, page)
# живая строка рисует иконки из скрипта, ей нужна та же таблица
page = page.replace('/*ICONS*/{}', json.dumps(icons))

# фото: img:p49 меняется на data-адрес
page = re.sub(r'img:(p\d+)', lambda match: f'data:image/webp;base64,{b64(f"{HERE}/img/{match.group(1)}.webp")}', page)

out = f'{HERE}/Stowa.html'
open(out, 'w').write(page)
print(os.path.getsize(out) // 1024, 'КБ')
