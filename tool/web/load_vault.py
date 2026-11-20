"""Залить папку с заметками в профиль браузера для проверок: как будто человек держит её «в этом браузере».

Запуск: python3 tool/web/load_vault.py <папка профиля> <адрес сборки> <папка с заметками>

Прежние заметки профиля стираются. После заливки открыть сборку и дать первой сверке
дойти до конца (на 3700 файлах — около десяти минут), иначе заметки заведутся дважды.
"""
import asyncio
import base64
import json
import os
import sys
import time
import unicodedata

from playwright.async_api import async_playwright

profile, url, root = sys.argv[1], sys.argv[2].rstrip('/'), os.path.expanduser(sys.argv[3])

WIPE = """async () => { const root = await navigator.storage.getDirectory(); for await (const [name] of root.entries()) await root.removeEntry(name, {recursive: true}); localStorage.clear(); }"""
WRITE = """async (batch) => {
  const root = await (await navigator.storage.getDirectory()).getDirectoryHandle('stowa-files', {create: true});
  for (const [path, b64, append] of batch) {
    const parts = path.split('/'); let dir = root;
    for (const p of parts.slice(0, -1)) dir = await dir.getDirectoryHandle(p, {create: true});
    const fh = await dir.getFileHandle(parts[parts.length - 1], {create: true});
    const bin = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
    const w = await fh.createWritable({keepExistingData: append});
    if (append) { const f = await fh.getFile(); await w.seek(f.size); }
    await w.write(bin); await w.close();
  }
}"""
META = """async (text) => { const root = await navigator.storage.getDirectory(); const fh = await root.getFileHandle('stowa-files-meta.json', {create: true}); const w = await fh.createWritable(); await w.write(text); await w.close(); }"""
CHUNK = 3 * 1024 * 1024


def vault_files():
    for folder, folders, names in os.walk(root):
        folders[:] = [name for name in folders if not name.startswith('.')]
        for name in names:
            if name.startswith('.'):
                continue
            full = os.path.join(folder, name)
            yield full, unicodedata.normalize('NFC', os.path.relpath(full, root).replace(os.sep, '/'))


async def main():
    files = list(vault_files())
    async with async_playwright() as p:
        ctx = await p.chromium.launch_persistent_context(profile, service_workers='block', locale='ru-RU')
        page = ctx.pages[0] if ctx.pages else await ctx.new_page()
        await page.goto(f'{url}/version.json')
        await page.evaluate(WIPE)
        started, batch, size, times, total = time.time(), [], 0, {}, 0
        for done, (full, relative) in enumerate(files, 1):
            data = open(full, 'rb').read()
            total += len(data)
            times['/vault/' + relative] = int(os.path.getmtime(full) * 1000)
            if not data:
                batch.append(['vault/' + relative, '', False])
            for offset in range(0, len(data), CHUNK):
                piece = data[offset:offset + CHUNK]
                batch.append(['vault/' + relative, base64.b64encode(piece).decode(), offset > 0])
                size += len(piece)
                if size > CHUNK:
                    await page.evaluate(WRITE, batch)
                    batch, size = [], 0
            if done % 500 == 0:
                print(f'{done}/{len(files)} файлов, {total / 1e6:.0f} МБ, {time.time() - started:.0f} с', flush=True)
        if batch:
            await page.evaluate(WRITE, batch)
        # время правки файлов: хранилище браузера ставит своё, а сверка сравнивает по времени
        await page.evaluate(META, json.dumps(times, ensure_ascii=False))
        print(f'готово: {len(files)} файлов, {total / 1e6:.0f} МБ за {time.time() - started:.0f} с', flush=True)
        await ctx.close()

asyncio.run(main())
