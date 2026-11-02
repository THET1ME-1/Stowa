#!/usr/bin/env python3
"""Дописывает строки в словари разом.

Читает JSON вида

    {"ключ": {"ru": "...", "en": "...", "de": "...", "@": "описание для переводчика"}}

Русский и английский обязательны, остальные языки — сколько есть: чего нет,
то приложение покажет по-английски. После запуска — flutter gen-l10n.

Запуск: python3 tool/add_strings.py строки.json
"""

import json
import sys
from collections import OrderedDict
from pathlib import Path

LOCALES = ['ru', 'en', 'uk', 'ro', 'pl', 'de', 'es']
REQUIRED = ['ru', 'en']
L10N = Path(__file__).resolve().parent.parent / 'lib' / 'l10n'


def main() -> int:
    source = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
    for key, translations in source.items():
        for locale in REQUIRED:
            if not translations.get(locale, '').strip():
                raise SystemExit(f'Нет перевода {key} на {locale}')

    for locale in LOCALES:
        path = L10N / f'app_{locale}.arb'
        data = json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=OrderedDict)
        for key, translations in source.items():
            if locale not in translations:
                continue
            data[key] = translations[locale]
            if locale == 'en':
                meta = {'description': translations.get('@', key)}
                # типы подстановок нужны для чисел во множественном числе
                if 'placeholders' in translations:
                    meta['placeholders'] = translations['placeholders']
                data[f'@{key}'] = meta
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    print(f'Добавлено {len(source)} строк')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
