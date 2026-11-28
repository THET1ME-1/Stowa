#!/usr/bin/env python3
"""Заливка описания и скриншотов Stowa в Google Play.

Запуск:
    python3 tool/store/fill_play_listing.py [--banners ПАПКА]

По умолчанию баннеры берутся из scratchpad-папки CI.
"""
from __future__ import annotations

import json
import pathlib
import sys
import urllib.request
import urllib.error

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from play_api import call, токен, ПАКЕТ, БАЗА, _кэш

TITLE_RU = "Stowa — закинь и забудь"
TITLE_EN = "Stowa — drop and forget"

SHORT_RU = "Быстрые заметки с папками, тегами и ИИ-разбором"
SHORT_EN = "Quick notes with folders, tags and AI sorting"

FULL_RU = """\
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
• Темы: графит, 10 цветов, свой оттенок, AMOLED-чёрный
• Скрытые папки под отпечатком
• Синхронизация между устройствами с шифрованием

ИИ работает по вашему ключу OpenRouter. Нет ключа — разбирайте вручную, правилами тегов или просто не разбирайте. Приложение работает без сети и без аккаунта.

Данные на телефоне. Своего сервера у Stowa нет, аккаунт необязателен. Хранилище можно открыть в Obsidian — файлы лежат обычным Markdown."""

FULL_EN = """\
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
• Themes: graphite, 10 colors, custom shade, AMOLED black
• Hidden folders behind fingerprint
• Cross-device sync with encryption

AI runs on your own OpenRouter key. No key — sort manually, with tag rules, or just don't sort. The app works offline and without an account.

Data stays on your phone. No proprietary server, no mandatory account. You can open the vault in Obsidian — files are plain Markdown."""


def upload_image(edit_id: str, lang: str, image_type: str, path: pathlib.Path):
    """Загрузка одного изображения в Play."""
    if 'token' not in _кэш:
        _кэш['token'] = токен()
    url = (f"https://androidpublisher.googleapis.com/upload"
           f"/androidpublisher/v3/applications/{ПАКЕТ}/edits/{edit_id}"
           f"/listings/{lang}/{image_type}?uploadType=media")
    data = path.read_bytes()
    req = urllib.request.Request(url, data=data, method='POST')
    req.add_header('Authorization', 'Bearer ' + _кэш['token'])
    req.add_header('Content-Type', 'image/png')
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        text = e.read().decode(errors='replace')
        print(f"  ОШИБКА {e.code}: {text[:300]}")
        return None


def delete_all_images(edit_id: str, lang: str, image_type: str):
    """Удалить все изображения типа."""
    call('DELETE',
         f'/applications/{ПАКЕТ}/edits/{edit_id}/listings/{lang}/{image_type}')


def main():
    banner_base = None
    for i, arg in enumerate(sys.argv[1:], 1):
        if arg == '--banners' and i < len(sys.argv) - 1:
            banner_base = pathlib.Path(sys.argv[i + 1])

    if not banner_base:
        banner_base = pathlib.Path(
            "/tmp/claude-1000/-home-alelx/7fd52c49-904f-4adf-9783-dd7069ed758f/"
            "scratchpad/store-screenshots-v4/banners/play"
        )

    print("Создаю правку...")
    edit = call('POST', f'/applications/{ПАКЕТ}/edits')
    edit_id = edit['id']
    print(f"  edit_id: {edit_id}")

    for lang, title, short, full in [
        ('ru-RU', TITLE_RU, SHORT_RU, FULL_RU),
        ('en-US', TITLE_EN, SHORT_EN, FULL_EN),
    ]:
        print(f"\nОписание {lang}...")
        call('PUT', f'/applications/{ПАКЕТ}/edits/{edit_id}/listings/{lang}',
             тело={
                 'language': lang,
                 'title': title,
                 'shortDescription': short,
                 'fullDescription': full,
             })
        print(f"  Готово.")

        lang_short = lang[:2]
        img_dir = banner_base / lang_short
        if img_dir.is_dir():
            print(f"\nСкриншоты {lang}...")
            delete_all_images(edit_id, lang, 'phoneScreenshots')
            files = sorted(img_dir.glob('banner-*.png'))
            for f in files:
                print(f"  {f.name}...", end=' ', flush=True)
                result = upload_image(edit_id, lang, 'phoneScreenshots', f)
                print("ОК" if result else "ОШИБКА")
        else:
            print(f"  Папка {img_dir} не найдена, скриншоты пропущены.")

    print("\nОтправляю правку...")
    call('POST', f'/applications/{ПАКЕТ}/edits/{edit_id}:commit')
    print("Готово. Страница Play обновлена.")


if __name__ == '__main__':
    main()
