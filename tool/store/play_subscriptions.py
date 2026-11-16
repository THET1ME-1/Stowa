#!/usr/bin/env python3
"""Подписка Stowa в Google Play — через API, а не руками.

    python3 tool/store/play_subscriptions.py state    # что заведено
    python3 tool/store/play_subscriptions.py setup    # завести, цены, включить

Одна подписка `stowa_sub` с тремя базовыми планами: месяц, 3 месяца, год. Так
Google и задумал подписки: человек меняет срок внутри одной подписки, а не
покупает вторую. Идентификаторы вечные — нейтральные, без «pro» и «plus».

Цены: мир считает сам Google от доллара (`pricing:convertRegionPrices`), Россия
задаётся явно рублями — конвертация от доллара дала бы другие цифры, чем у
остальных способов оплаты. Скрипт перенесён из Fern (`docs/play/`).
"""
from __future__ import annotations

import sys

import play_api as p

ТОВАР = 'stowa_sub'

ПЛАНЫ = [
    {'basePlanId': 'month', 'period': 'P1M', 'usd': ('2', 990000000), 'rub': ('299', 0)},
    {'basePlanId': 'quarter', 'period': 'P3M', 'usd': ('6', 990000000), 'rub': ('749', 0)},
    {'basePlanId': 'year', 'period': 'P1Y', 'usd': ('19', 990000000), 'rub': ('1990', 0)},
]

ТЕКСТЫ = {
    'ru-RU': ('Подписка Stowa', 'Все возможности Stowa. Срок — месяц, 3 месяца или год, отменить можно в любой день.'),
    'en-US': ('Stowa subscription', 'Everything in Stowa. Monthly, every 3 months or yearly, cancel any day.'),
}

# Льгота и удержание: у человека, у которого не прошла оплата, неделя на замену
# карты, потом месяц удержания — подписка не пропадает сразу
ЛЬГОТА = 'P7D'
УДЕРЖАНИЕ = 'P30D'

# Версия справочника стран Google: без неё запрос отвечает «Regions Version must
# be specified». Берётся из ответа конвертации
ВЕРСИЯ_РЕГИОНОВ = '2022/02'


def версия_регионов() -> str:
    global ВЕРСИЯ_РЕГИОНОВ
    ответ = p.call('POST', f'/applications/{p.ПАКЕТ}/pricing:convertRegionPrices', {'price': {'currencyCode': 'USD', 'units': '5'}})
    версия = (ответ.get('regionVersion') or {}).get('version')
    if версия:
        ВЕРСИЯ_РЕГИОНОВ = версия
    return ВЕРСИЯ_РЕГИОНОВ


def цены(usd: tuple[str, int], rub: tuple[str, int]) -> tuple[list[dict], dict]:
    """Региональные цены: мир — конвертацией Google, Россия — рублями."""
    ответ = p.call('POST', f'/applications/{p.ПАКЕТ}/pricing:convertRegionPrices', {'price': {'currencyCode': 'USD', 'units': usd[0], 'nanos': usd[1]}})
    регионы = ответ.get('convertedRegionPrices', {})
    конфиги = []
    for код, значение in регионы.items():
        цена = значение.get('price') or {}
        if код == 'RU':
            цена = {'currencyCode': 'RUB', 'units': rub[0], 'nanos': rub[1]}
        конфиги.append({'regionCode': код, 'price': цена, 'newSubscriberAvailability': True})
    if 'RU' not in регионы:
        конфиги.append({'regionCode': 'RU', 'price': {'currencyCode': 'RUB', 'units': rub[0], 'nanos': rub[1]}, 'newSubscriberAvailability': True})
    прочие = ответ.get('convertedOtherRegionsPrice') or {}
    остальные = {}
    if прочие.get('usdPrice') and прочие.get('eurPrice'):
        остальные = {'usdPrice': прочие['usdPrice'], 'eurPrice': прочие['eurPrice'], 'newSubscriberAvailability': True}
    return конфиги, остальные


def тело() -> dict:
    планы = []
    for план in ПЛАНЫ:
        конфиги, остальные = цены(план['usd'], план['rub'])
        базовый = {
            'basePlanId': план['basePlanId'],
            'state': 'DRAFT',
            'autoRenewingBasePlanType': {
                'billingPeriodDuration': план['period'],
                'gracePeriodDuration': ЛЬГОТА,
                'accountHoldDuration': УДЕРЖАНИЕ,
                'resubscribeState': 'RESUBSCRIBE_STATE_ACTIVE',
                'prorationMode': 'SUBSCRIPTION_PRORATION_MODE_CHARGE_ON_NEXT_BILLING_DATE',
                'legacyCompatible': False,
            },
            'regionalConfigs': конфиги,
        }
        if остальные:
            базовый['otherRegionsConfig'] = остальные
        планы.append(базовый)
    return {
        'packageName': p.ПАКЕТ,
        'productId': ТОВАР,
        'listings': [{'languageCode': язык, 'title': заголовок, 'description': описание} for язык, (заголовок, описание) in ТЕКСТЫ.items()],
        'basePlans': планы,
        'taxAndComplianceSettings': {'isTokenizedDigitalAsset': False},
    }


def список() -> dict:
    ответ = p.call('GET', f'/applications/{p.ПАКЕТ}/subscriptions', pageSize=50)
    return {s['productId']: s for s in ответ.get('subscriptions', [])}


def state() -> None:
    товары = список()
    if not товары:
        print('подписок нет')
        return
    for имя, s in товары.items():
        for b in s.get('basePlans', []):
            регионы = b.get('regionalConfigs') or []
            ru = [r for r in регионы if r.get('regionCode') == 'RU']
            us = [r for r in регионы if r.get('regionCode') == 'US']
            цена_ru = ru[0]['price'] if ru else {}
            цена_us = us[0]['price'] if us else {}
            print(
                f'{имя}/{b.get("basePlanId")} ({b.get("autoRenewingBasePlanType", {}).get("billingPeriodDuration")}): '
                f'{b.get("state")}, регионов {len(регионы)}, Россия {цена_ru.get("units", "—")} {цена_ru.get("currencyCode", "")}, '
                f'США {цена_us.get("units", "—")}.{str(цена_us.get("nanos", 0))[:2]} {цена_us.get("currencyCode", "")}'
            )


def setup() -> None:
    print('   справочник стран:', версия_регионов())
    готовые = список()
    данные = тело()
    if ТОВАР in готовые:
        print(f'   {ТОВАР}: уже есть, обновляю цены и тексты')
        p.call('PATCH', f'/applications/{p.ПАКЕТ}/subscriptions/{ТОВАР}', данные,
               params={'updateMask': 'listings,basePlans,taxAndComplianceSettings', 'regionsVersion.version': ВЕРСИЯ_РЕГИОНОВ})
    else:
        p.call('POST', f'/applications/{p.ПАКЕТ}/subscriptions', данные, params={'productId': ТОВАР, 'regionsVersion.version': ВЕРСИЯ_РЕГИОНОВ})
        print(f'   {ТОВАР}: заведён, планов {len(данные["basePlans"])}')
    # черновик не продаётся: каждый базовый план включается отдельно
    for план in ПЛАНЫ:
        имя = план['basePlanId']
        try:
            p.call('POST', f'/applications/{p.ПАКЕТ}/subscriptions/{ТОВАР}/basePlans/{имя}:activate', {})
            print(f'      план {имя} включён')
        except SystemExit as e:
            print(f'      план {имя}: {str(e).splitlines()[0]}')
    print('готово')


if __name__ == '__main__':
    команда = sys.argv[1] if len(sys.argv) > 1 else 'state'
    {'state': state, 'setup': setup}.get(команда, state)()
