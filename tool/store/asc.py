#!/usr/bin/env python3
"""Доступ к App Store Connect API приложением Stowa («Stowa Notes», `app.stowa`).

Команда та же, что у Togetherly, поэтому ключ общий. Репозиторий открытый:
Issuer ID и Key ID здесь не пишутся, они лежат в `~/keys/asc-team-y2z9.env`
(строки `ASC_ISSUER=…`, `ASC_KEY_ID=…`), ключ — `~/keys/AuthKey_<KEY_ID>.p8`.
Окружение главнее файла. Перенесено из Fern (`docs/appstore/asc.py`), без
частей про версии и снимки Fern.
"""
from __future__ import annotations

import os
import pathlib
import time

import jwt
import requests

_KEYS = pathlib.Path.home() / 'keys'
_FILE = {}
if (_KEYS / 'asc-team-y2z9.env').exists():
    for _line in (_KEYS / 'asc-team-y2z9.env').read_text().splitlines():
        if '=' in _line:
            _name, _value = _line.split('=', 1)
            _FILE[_name.strip()] = _value.strip()

ISSUER = os.environ.get('ASC_ISSUER', _FILE.get('ASC_ISSUER', ''))
KEY_ID = os.environ.get('ASC_KEY_ID', _FILE.get('ASC_KEY_ID', ''))
KEY = pathlib.Path(os.environ.get('ASC_KEY', _KEYS / f'AuthKey_{KEY_ID}.p8'))
APP_ID = os.environ.get('ASC_APP_ID', '6835386941')
BASE = 'https://api.appstoreconnect.apple.com'

_token = {'value': None, 'exp': 0}


def token() -> str:
    now = int(time.time())
    if _token['value'] and _token['exp'] - now > 60:
        return _token['value']
    exp = now + 15 * 60
    t = jwt.encode({'iss': ISSUER, 'iat': now, 'exp': exp, 'aud': 'appstoreconnect-v1'}, KEY.read_text(), algorithm='ES256', headers={'kid': KEY_ID, 'typ': 'JWT'})
    _token.update(value=t, exp=exp)
    return t


def call(method: str, path: str, **kw) -> dict:
    url = path if path.startswith('http') else BASE + path
    headers = {'Authorization': f'Bearer {token()}'}
    headers.update(kw.pop('headers', {}))
    if 'json' in kw:
        headers['Content-Type'] = 'application/json'
    # сеть Apple рвёт соединение чаще, чем хотелось бы
    for attempt in range(4):
        try:
            r = requests.request(method, url, headers=headers, timeout=120, **kw)
            break
        except requests.RequestException:
            if attempt == 3:
                raise
            time.sleep(3 * (attempt + 1))
    if r.status_code >= 400:
        raise SystemExit(f'{method} {url} → {r.status_code}\n{r.text[:2000]}')
    return r.json() if r.content and 'json' in r.headers.get('content-type', '') else {}


def get(path: str, **params) -> dict:
    return call('GET', path, params=params)
