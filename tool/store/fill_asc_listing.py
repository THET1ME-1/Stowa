#!/usr/bin/env python3
"""Заливка описания и скриншотов Stowa в App Store Connect.

Запуск:
    python3 tool/store/fill_asc_listing.py [--banners ПАПКА]
"""
from __future__ import annotations

import hashlib
import pathlib
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from asc import call, get, APP_ID

VERSION_ID = 'fc7f2ce5-f037-4bdf-8ca8-cbb084ec90f1'

DESC_RU = """\
Закинул — и пошёл. Stowa сохраняет заметку за долю секунды: текст, ссылку, фото, голосовое. Потом сама раскладывает по папкам, ставит теги и вытаскивает напоминание из текста.

Одна строка — и ищет, и сохраняет. Набрал «рецепт» — заметка сама ушла в нужную папку. Дописал «завтра в 10» — напомнит.

Что умеет:
• Папки с иконками и цветами — 12 оттенков на выбор
• Теги и правила сортировки — набрал слово, заметка ложится куда надо
• Markdown — заголовки, списки, код, формулы
• Напоминания из текста — «в пятницу», «через 2 часа», «12 декабря в 09:00»
• Чеклисты с галочками прямо в ленте
• Превью ссылок, статьи целиком, обложки роликов
• Бот Telegram — пересылай сюда, Stowa заберёт
• Поиск по всему: тексту, тегам, папкам, вложениям
• Каталог деревом — все папки и заметки одним экраном
• Темы: графит, 10 цветов, свой оттенок, чёрный фон
• Скрытые папки под отпечатком
• Синхронизация между устройствами с шифрованием

ИИ работает по вашему ключу OpenRouter. Нет ключа — разбирайте вручную, правилами тегов или просто не разбирайте. Приложение работает без сети и без аккаунта.

Данные на телефоне. Своего сервера у Stowa нет, аккаунт необязателен. Хранилище можно открыть в Obsidian — файлы лежат обычным Markdown."""

DESC_EN = """\
Drop it and go. Stowa saves a note in a split second: text, link, photo, voice memo. Then it sorts everything into folders, adds tags and pulls reminders from the text.

One bar — search and save. Type "recipe" and the note lands in the right folder. Add "tomorrow at 10" and it reminds you.

What it does:
• Folders with icons and colors — 12 shades to choose from
• Tags and sorting rules — type a word, the note goes where it should
• Markdown — headings, lists, code, formulas
• Reminders from text — "on Friday", "in 2 hours", "December 12 at 9 AM"
• Checklists with checkboxes right in the feed
• Link previews, full articles, video thumbnails
• Telegram bot — forward here, Stowa picks it up
• Search everything: text, tags, folders, attachments
• Tree catalog — all folders and notes on one screen
• Themes: graphite, 10 colors, custom shade, true black
• Hidden folders behind fingerprint
• Cross-device sync with encryption

AI runs on your own OpenRouter key. No key — sort manually, with tag rules, or just don't sort. The app works offline and without an account.

Data stays on your phone. No proprietary server, no mandatory account. You can open the vault in Obsidian — files are plain Markdown."""

KEYWORDS_RU = "заметки, блокнот, markdown, напоминания, папки, теги, чеклист, дневник, сортировка, telegram"
KEYWORDS_EN = "notes, notepad, markdown, reminders, folders, tags, checklist, journal, sorting, telegram"

PROMO_RU = "Закинул и пошёл. Заметки с папками, тегами и ИИ-разбором."
PROMO_EN = "Drop it and go. Notes with folders, tags and AI sorting."

WHATS_NEW_RU = "Первый выпуск Stowa."
WHATS_NEW_EN = "First release of Stowa."


def ensure_locale(version_id: str, locale: str) -> str:
    """Создаёт локализацию, если нет. Возвращает id."""
    locs = get(f'/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations')
    for l in locs.get('data', []):
        if l['attributes']['locale'] == locale:
            return l['id']
    result = call('POST', '/v1/appStoreVersionLocalizations', json={
        'data': {
            'type': 'appStoreVersionLocalizations',
            'attributes': {'locale': locale},
            'relationships': {
                'appStoreVersion': {
                    'data': {'type': 'appStoreVersions', 'id': version_id}
                }
            }
        }
    })
    return result['data']['id']


def update_locale(loc_id: str, description: str, keywords: str,
                  promo: str):
    """Обновляет тексты локализации."""
    call('PATCH', f'/v1/appStoreVersionLocalizations/{loc_id}', json={
        'data': {
            'type': 'appStoreVersionLocalizations',
            'id': loc_id,
            'attributes': {
                'description': description,
                'keywords': keywords,
                'promotionalText': promo,
            }
        }
    })


def delete_all_screenshots(loc_id: str):
    """Удаляет все скриншоты локализации."""
    shots = get(f'/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets',
                **{'filter[screenshotDisplayType]': 'APP_IPHONE_67'})
    for s in shots.get('data', []):
        existing = get(f'/v1/appScreenshotSets/{s["id"]}/appScreenshots')
        for sc in existing.get('data', []):
            call('DELETE', f'/v1/appScreenshots/{sc["id"]}')
        time.sleep(0.3)


def get_or_create_screenshot_set(loc_id: str) -> str:
    """Получает или создаёт набор скриншотов для 6.7 дюймов."""
    sets = get(f'/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets',
               **{'filter[screenshotDisplayType]': 'APP_IPHONE_67'})
    if sets.get('data'):
        return sets['data'][0]['id']
    result = call('POST', '/v1/appScreenshotSets', json={
        'data': {
            'type': 'appScreenshotSets',
            'attributes': {'screenshotDisplayType': 'APP_IPHONE_67'},
            'relationships': {
                'appStoreVersionLocalization': {
                    'data': {'type': 'appStoreVersionLocalizations', 'id': loc_id}
                }
            }
        }
    })
    return result['data']['id']


def upload_screenshot(set_id: str, path: pathlib.Path, position: int):
    """Загружает один скриншот в App Store Connect."""
    data = path.read_bytes()
    md5 = hashlib.md5(data).hexdigest()
    size = len(data)

    reservation = call('POST', '/v1/appScreenshots', json={
        'data': {
            'type': 'appScreenshots',
            'attributes': {
                'fileName': path.name,
                'fileSize': size,
            },
            'relationships': {
                'appScreenshotSet': {
                    'data': {'type': 'appScreenshotSets', 'id': set_id}
                }
            }
        }
    })

    screenshot_id = reservation['data']['id']
    ops = reservation['data']['attributes'].get('uploadOperations', [])

    for op in ops:
        url = op['url']
        headers_list = op.get('requestHeaders', [])
        offset = op.get('offset', 0)
        length = op.get('length', size)
        chunk = data[offset:offset + length]

        import urllib.request
        req = urllib.request.Request(url, data=chunk, method=op['method'])
        for h in headers_list:
            req.add_header(h['name'], h['value'])
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                r.read()
        except Exception as e:
            print(f"    Ошибка загрузки чанка: {e}")
            return None

    call('PATCH', f'/v1/appScreenshots/{screenshot_id}', json={
        'data': {
            'type': 'appScreenshots',
            'id': screenshot_id,
            'attributes': {
                'uploaded': True,
                'sourceFileChecksum': md5,
            }
        }
    })

    return screenshot_id


def main():
    banner_base = None
    for i, arg in enumerate(sys.argv[1:], 1):
        if arg == '--banners' and i < len(sys.argv) - 1:
            banner_base = pathlib.Path(sys.argv[i + 1])

    if not banner_base:
        banner_base = pathlib.Path(
            "/tmp/claude-1000/-home-alelx/7fd52c49-904f-4adf-9783-dd7069ed758f/"
            "scratchpad/store-screenshots-v4/banners/ios"
        )

    for locale, desc, kw, promo in [
        ('ru', DESC_RU, KEYWORDS_RU, PROMO_RU),
        ('en-US', DESC_EN, KEYWORDS_EN, PROMO_EN),
    ]:
        print(f"\n{'='*40}")
        print(f"Локализация {locale}")
        print(f"{'='*40}")

        loc_id = ensure_locale(VERSION_ID, locale)
        print(f"  id: {loc_id}")

        print("  Описание...", end=' ', flush=True)
        update_locale(loc_id, desc, kw, promo)
        print("ОК")

        lang_short = locale[:2]
        img_dir = banner_base / lang_short
        if not img_dir.is_dir():
            print(f"  Папка {img_dir} не найдена, скриншоты пропущены.")
            continue

        print("  Удаляю старые скриншоты...")
        delete_all_screenshots(loc_id)

        set_id = get_or_create_screenshot_set(loc_id)
        print(f"  Набор скриншотов: {set_id}")

        files = sorted(img_dir.glob('banner-*.png'))
        for i, f in enumerate(files):
            print(f"  {f.name} ({i+1}/{len(files)})...", end=' ', flush=True)
            result = upload_screenshot(set_id, f, i)
            if result:
                print("ОК")
            else:
                print("ОШИБКА")
            time.sleep(1)

    print("\nГотово. Страница App Store обновлена.")


if __name__ == '__main__':
    main()
