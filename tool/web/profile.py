"""Чем занят главный поток браузера в покое и во время поиска строки.

Запуск: python3 tool/web/profile.py <папка профиля> <адрес сборки> <покой, с> <запрос> [<запрос> ...]

Сборку брать `flutter build web --profile`: в ней у функций настоящие имена. Печатает,
сколько времени ушло в каждую функцию вместе с вызванными из неё, и паузы главного
потока длиннее 120 мс. Видеокарта включена флагами: без них Chromium рисует программно.

Запросы к базе и шаги поиска видны только по временным строкам в коде: поставить
`print('[DEBUG] …')`, собрать и смотреть журнал этим же сценарием (строки с DEBUG он
печатает с отметкой времени). База в браузере одна и работает в одном потоке, поэтому
долгий запрос — чаще всего очередь перед ним, а не он сам.

Набранное сценарий не сохраняет и кнопку строки не нажимает: пока поиск не досчитал,
на ней «Закинуть», и щелчок завёл бы заметку.
"""
import asyncio
import collections
import sys
import time

from playwright.async_api import async_playwright

profile_dir, url, idle = sys.argv[1], sys.argv[2], int(sys.argv[3])
queries = sys.argv[4:]
GPU = ['--use-angle=vulkan', '--enable-features=Vulkan', '--ignore-gpu-blocklist']
BEAT = """() => { window.__gaps = []; let last = performance.now(); setInterval(() => { const now = performance.now(); if (now - last > 120) window.__gaps.push(Math.round(now - last)); last = now; }, 20); }"""


def report(profile, label):
    nodes = {node['id']: node for node in profile['nodes']}
    parent = {child: node['id'] for node in profile['nodes'] for child in node.get('children', [])}
    own = collections.Counter()
    for node, delta in zip(profile['samples'], profile['timeDeltas']):
        own[node] += delta
    whole = collections.Counter()
    for node, spent in own.items():
        names = set()
        while node is not None:
            names.add(nodes[node]['callFrame']['functionName'] or '(без имени)')
            node = parent.get(node)
        for name in names:
            whole[name] += spent
    total = sum(own.values())
    print(f'--- {label}: {total / 1e6:.1f} с', flush=True)
    for name, spent in whole.most_common(40):
        print(f'{spent / 1000:8.0f} мс {spent * 100 / total:5.1f}%  {name[:100]}')


async def main():
    async with async_playwright() as p:
        ctx = await p.chromium.launch_persistent_context(profile_dir, service_workers='block', args=GPU, viewport={'width': 1600, 'height': 960}, locale='ru-RU', color_scheme='dark')
        page = ctx.pages[0] if ctx.pages else await ctx.new_page()
        started = time.time()
        page.on('console', lambda message: print(f'{time.time() - started:7.2f} {message.text[:400]}', flush=True) if 'DEBUG' in message.text else None)
        await page.goto(url)
        await page.wait_for_timeout(8000)
        await page.evaluate(BEAT)
        cdp = await ctx.new_cdp_session(page)
        await cdp.send('Profiler.enable')
        await cdp.send('Profiler.setSamplingInterval', {'interval': 1000})

        await page.wait_for_timeout(max(0, idle - 18) * 1000)
        await cdp.send('Profiler.start')
        await page.wait_for_timeout(10000)
        report((await cdp.send('Profiler.stop'))['profile'], 'покой')
        print('паузы главного потока, мс:', await page.evaluate('() => window.__gaps.splice(0)'), flush=True)

        # строка в покое — капсула внизу посередине: поле появляется после щелчка
        size = page.viewport_size
        await page.mouse.click(size['width'] * 0.44, size['height'] - 46)
        await page.wait_for_timeout(1500)
        for text in queries:
            await cdp.send('Profiler.start')
            await page.keyboard.type(text, delay=60)
            await page.wait_for_timeout(6000)
            report((await cdp.send('Profiler.stop'))['profile'], f'поиск «{text}»')
            print('паузы главного потока, мс:', await page.evaluate('() => window.__gaps.splice(0)'), flush=True)
            await page.keyboard.press('Control+a')
            await page.keyboard.press('Backspace')
            await page.wait_for_timeout(2500)
        await ctx.close()

asyncio.run(main())
