#!/usr/bin/env python3
"""Письмо с кодом входа Stowa: сборка из шаблона и пробная отправка.

Сервер синхронизации будет собирать письмо этой же функцией `build`.
Пока сервера нет, скрипт шлёт пробное письмо через Brevo аккаунта
Togetherly (ключ SMTP — `~/keys/brevo-smtp.txt`, строки host, port,
login, key).

  python3 tool/mail/login_code.py support@stowa.work        # по-русски
  python3 tool/mail/login_code.py support@stowa.work en     # по-английски
  python3 tool/mail/login_code.py --html ru > письмо.html   # только собрать
"""
from __future__ import annotations

import email.message
import email.utils
import html
import pathlib
import secrets
import smtplib
import sys

TEMPLATE = pathlib.Path(__file__).with_name('login_code.html')
SENDER = 'Stowa <no-reply@stowa.work>'

TEXTS = {
    'ru': {
        'subject': '{code} — код входа в Stowa',
        'preheader': 'Код действует 10 минут.',
        'title': 'Код для входа',
        'lead': 'Введите его в Stowa, чтобы включить синхронизацию на этом телефоне.',
        'hint': 'Действует 10 минут',
        'safety': 'Не входили в Stowa? Просто удалите письмо: без кода в аккаунт никто не войдёт. Код нужен только вам, не сообщайте его никому, даже поддержке.',
        'footer': 'Вопросы и помощь:',
    },
    'en': {
        'subject': '{code} is your Stowa sign-in code',
        'preheader': 'The code expires in 10 minutes.',
        'title': 'Your sign-in code',
        'lead': 'Enter it in Stowa to turn on sync on this phone.',
        'hint': 'Expires in 10 minutes',
        'safety': "Didn't try to sign in? Just delete this email: nobody can get into your account without the code. Don't share it with anyone, including support.",
        'footer': 'Questions and help:',
    },
}


# Собирает тему, HTML и простой текст письма
def build(code: str, lang: str = 'ru') -> tuple[str, str, str]:
    texts = TEXTS.get(lang, TEXTS['en'])
    subject = texts['subject'].format(code=code)
    page = TEMPLATE.read_text()
    fields = dict(texts, subject=subject, code=code, lang=lang)
    for name, value in fields.items():
        page = page.replace('{{' + name + '}}', html.escape(value))
    plain = '\n\n'.join([
        texts['title'],
        texts['lead'],
        code,
        texts['hint'],
        texts['safety'],
        f"{texts['footer']} support@stowa.work",
    ])
    return subject, page, plain


# Отправляет письмо через SMTP Brevo
def send(to: str, code: str, lang: str = 'ru') -> str:
    subject, page, plain = build(code, lang)
    message = email.message.EmailMessage()
    message['From'] = SENDER
    message['To'] = to
    message['Subject'] = subject
    message['Message-ID'] = email.utils.make_msgid(domain='stowa.work')
    message.set_content(plain)
    message.add_alternative(page, subtype='html')

    key_file = pathlib.Path.home() / 'keys' / 'brevo-smtp.txt'
    keys = {name.strip(): value.strip() for name, value in (line.split('=', 1) for line in key_file.read_text().splitlines() if '=' in line)}
    with smtplib.SMTP(keys['host'], int(keys['port']), timeout=30) as smtp:
        smtp.starttls()
        smtp.login(keys['login'], keys['key'])
        smtp.send_message(message)
    return message['Message-ID']


if __name__ == '__main__':
    code = f'{secrets.randbelow(1_000_000):06d}'
    if sys.argv[1:2] == ['--html']:
        print(build(code, sys.argv[2] if len(sys.argv) > 2 else 'ru')[1])
    else:
        to = sys.argv[1]
        lang = sys.argv[2] if len(sys.argv) > 2 else 'ru'
        print('отправлено:', to, code, send(to, code, lang))
