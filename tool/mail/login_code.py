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

import datetime
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
        'reason': 'Вы получили это письмо, потому что {when} в Stowa{device} запросили вход с этим адресом.',
        'device': ' на устройстве {name}',
        'advice': 'Это были не вы? Ничего не делайте: без кода в аккаунт никто не войдёт. Не сообщайте код никому, даже поддержке.',
        'footer': 'Вопросы и помощь:',
    },
    'en': {
        'subject': '{code} is your Stowa sign-in code',
        'preheader': 'The code expires in 10 minutes.',
        'title': 'Your sign-in code',
        'lead': 'Enter it in Stowa to turn on sync on this phone.',
        'hint': 'Expires in 10 minutes',
        'reason': "You're getting this email because someone asked to sign in to Stowa with this address {when}{device}.",
        'device': ' from {name}',
        'advice': "Wasn't you? Do nothing: nobody can get into your account without the code. Don't share it with anyone, including support.",
        'footer': 'Questions and help:',
    },
}

_MONTHS = {
    'ru': ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'],
    'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
}


# Когда просили вход: по часам телефона, иначе по UTC с пометкой
def _when(at: datetime.datetime, lang: str, local: bool) -> str:
    clock = f'{at.hour:02d}:{at.minute:02d}'
    zone = '' if local else ' UTC'
    if lang == 'ru':
        return f'{at.day} {_MONTHS["ru"][at.month - 1]} в {clock}{zone}'
    return f'on {_MONTHS["en"][at.month - 1]} {at.day} at {clock}{zone}'


# Собирает тему, HTML и простой текст письма
def build(code: str, lang: str = 'ru', device: str = '', offset_minutes: int | None = None) -> tuple[str, str, str]:
    texts = TEXTS.get(lang, TEXTS['en'])
    subject = texts['subject'].format(code=code)
    now = datetime.datetime.now(datetime.timezone.utc)
    at = now + datetime.timedelta(minutes=offset_minutes or 0)
    when = _when(at, lang, offset_minutes is not None)
    name = device.strip()[:60]

    # строка «откуда письмо»: дата и устройство жирным, остальное как есть
    def reason(bold) -> str:
        part = texts['device'].format(name=bold(name)) if name else ''
        return texts['reason'].format(when=bold(when), device=part)

    page = TEMPLATE.read_text()
    fields = {k: v for k, v in texts.items() if k not in ('reason', 'device')}
    fields.update(subject=subject, code=code, lang=lang)
    for key, value in fields.items():
        page = page.replace('{{' + key + '}}', html.escape(value))
    page = page.replace('{{reason_html}}', reason(lambda s: f'<b style="color:#1B1C1E;">{html.escape(s)}</b>'))
    plain = '\n\n'.join([
        texts['title'],
        texts['lead'],
        code,
        texts['hint'],
        reason(lambda s: s),
        texts['advice'],
        f"{texts['footer']} support@stowa.work",
    ])
    return subject, page, plain


# Отправляет письмо через SMTP Brevo
def send(to: str, code: str, lang: str = 'ru', device: str = '', offset_minutes: int | None = None) -> str:
    subject, page, plain = build(code, lang, device, offset_minutes)
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
    # пробное письмо — как с телефона в Кишинёве: устройство и часы ноутбука
    offset = int(datetime.datetime.now().astimezone().utcoffset().total_seconds() // 60)
    device = 'Xiaomi 14'
    if sys.argv[1:2] == ['--html']:
        print(build(code, sys.argv[2] if len(sys.argv) > 2 else 'ru', device, offset)[1])
    else:
        to = sys.argv[1]
        lang = sys.argv[2] if len(sys.argv) > 2 else 'ru'
        print('отправлено:', to, code, send(to, code, lang, device, offset))
