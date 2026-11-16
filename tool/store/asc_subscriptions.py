#!/usr/bin/env python3
"""Подписка Stowa в App Store Connect — через API, а не руками.

    python3 tool/store/asc_subscriptions.py state    # что уже заведено
    python3 tool/store/asc_subscriptions.py setup    # группа, товары, цены, тексты

Одна группа «Stowa», три товара: месяц, 3 месяца, год — человек меняет срок
внутри группы, а не покупает вторую подписку. Перенесено из Fern
(`docs/appstore/asc_subscriptions.py`).

Ключ и идентификаторы берутся из `asc.py` (окружение ASC_*). Скрипт
идемпотентный: существующее не пересоздаёт, недостающее добавляет.

ПОРЯДОК ВАЖЕН: сперва страны, потом цена. Пока у подписки нет доступности,
Apple отвечает на цену 409 «An error occurred while processing the pricing
information» и ни слова про территории — ошибка выглядит как неверный формат,
и перебирать формат можно долго.

ЧТО ОСТАЁТСЯ: скриншот экрана покупки для проверки Apple. Экрана подписки в
Stowa ещё нет; пока снимка нет, шаг пропускается и товары стоят в
MISSING_METADATA — на проверку их всё равно подают вместе с версией приложения.
"""
from __future__ import annotations

import hashlib
import pathlib
import sys
import urllib.request

import asc

ГРУППА = 'Stowa'

# Товары. Хвост имени (`_month`, `_quarter`, `_year`) совпадает с базовыми
# планами подписки `stowa_sub` в Google Play: тариф читается по нему и в
# приложении, и на сервере. Описание у Apple не длиннее 55 знаков.
ТОВАРЫ = [
    {
        'productId': 'stowa_sub_month',
        'name': 'Stowa на месяц',
        'period': 'ONE_MONTH',
        'ru': ('Stowa на месяц', 'Все возможности Stowa. Списание раз в месяц'),
        'en': ('Stowa monthly', 'Everything in Stowa. Billed monthly'),
    },
    {
        'productId': 'stowa_sub_quarter',
        'name': 'Stowa на 3 месяца',
        'period': 'THREE_MONTHS',
        'ru': ('Stowa на 3 месяца', 'Все возможности Stowa. Раз в 3 месяца, дешевле'),
        'en': ('Stowa for 3 months', 'Everything in Stowa. Every 3 months, cheaper'),
    },
    {
        'productId': 'stowa_sub_year',
        'name': 'Stowa на год',
        'period': 'ONE_YEAR',
        'ru': ('Stowa на год', 'Все возможности Stowa. Раз в год, выгоднее всего'),
        'en': ('Stowa yearly', 'Everything in Stowa. Billed yearly, best value'),
    },
]

# Цены задаём по базовой территории США: остальные страны Apple считает сама
ЦЕНЫ = {'stowa_sub_month': '2.99', 'stowa_sub_quarter': '6.99', 'stowa_sub_year': '19.99'}
БАЗОВАЯ_СТРАНА = 'USA'

# Экран покупки, отрисованный самим приложением; пока его нет — шаг пропускается
СНИМОК = str(pathlib.Path(__file__).resolve().parents[2] / 'build' / 'store' / 'subscription.png')


def группы() -> list[dict]:
    return asc.get(f'/v1/apps/{asc.APP_ID}/subscriptionGroups', **{'limit': '20'})['data']


def подписки(group_id: str) -> list[dict]:
    return asc.get(f'/v1/subscriptionGroups/{group_id}/subscriptions',
                   **{'limit': '50'})['data']


def завести_группу() -> str:
    для_группы = [g for g in группы()
                  if g['attributes'].get('referenceName') == ГРУППА]
    if для_группы:
        print(f'   группа уже есть: {для_группы[0]["id"]}')
        return для_группы[0]['id']
    g = asc.call('POST', '/v1/subscriptionGroups', json={'data': {
        'type': 'subscriptionGroups',
        'attributes': {'referenceName': ГРУППА},
        'relationships': {'app': {'data': {'type': 'apps', 'id': asc.APP_ID}}},
    }})['data']
    print(f'   группа заведена: {g["id"]}')
    return g['id']


def назвать_группу(group_id: str) -> None:
    """Имя группы видит покупатель в настройках подписок Apple."""
    было = asc.get(f'/v1/subscriptionGroups/{group_id}/subscriptionGroupLocalizations',
                   **{'limit': '10'})['data']
    языки = {л['attributes'].get('locale') for л in было}
    for локаль, имя in (('ru', 'Stowa'), ('en-US', 'Stowa')):
        if локаль in языки:
            continue
        asc.call('POST', '/v1/subscriptionGroupLocalizations', json={'data': {
            'type': 'subscriptionGroupLocalizations',
            'attributes': {'name': имя, 'locale': локаль},
            'relationships': {'subscriptionGroup': {
                'data': {'type': 'subscriptionGroups', 'id': group_id}}},
        }})
        print(f'   имя группы для {локаль}')


def завести_товар(group_id: str, товар: dict, готовые: dict) -> str:
    если_есть = готовые.get(товар['productId'])
    if если_есть:
        print(f'   {товар["productId"]}: уже есть ({если_есть})')
        return если_есть
    s = asc.call('POST', '/v1/subscriptions', json={'data': {
        'type': 'subscriptions',
        'attributes': {
            'name': товар['name'],
            'productId': товар['productId'],
            'subscriptionPeriod': товар['period'],
            # Семейный доступ не включаем: подписка и так открывается на всех
            # устройствах человека, а «поделиться с семьёй» это другая история.
            'familySharable': False,
        },
        'relationships': {'group': {
            'data': {'type': 'subscriptionGroups', 'id': group_id}}},
    }})['data']
    print(f'   {товар["productId"]}: заведён ({s["id"]})')
    return s['id']


def тексты(sub_id: str, товар: dict) -> None:
    было = asc.get(f'/v1/subscriptions/{sub_id}/subscriptionLocalizations',
                   **{'limit': '10'})['data']
    языки = {л['attributes'].get('locale') for л in было}
    for локаль, ключ in (('ru', 'ru'), ('en-US', 'en')):
        if локаль in языки:
            continue
        имя, описание = товар[ключ]
        asc.call('POST', '/v1/subscriptionLocalizations', json={'data': {
            'type': 'subscriptionLocalizations',
            'attributes': {'name': имя, 'description': описание, 'locale': локаль},
            'relationships': {'subscription': {
                'data': {'type': 'subscriptions', 'id': sub_id}}},
        }})
        print(f'      текст {локаль}')


def доступность(sub_id: str) -> None:
    """В каких странах продаётся подписка.

    ЭТО ПЕРВЫЙ ШАГ, а не украшение: пока территорий нет, Apple отвечает на
    любую цену 409 «An error occurred while processing the pricing
    information» — про доступность в ответе ни слова, и ошибка выглядит как
    неверный формат запроса. Перебирать формат бесполезно, надо задать страны.
    """
    try:
        asc.get(f'/v1/subscriptions/{sub_id}/subscriptionAvailability')
        print('      доступность уже задана')
        return
    except SystemExit:
        pass
    коды = [т['id'] for т in asc.get('/v1/territories', **{'limit': '200'})['data']]
    asc.call('POST', '/v1/subscriptionAvailabilities', json={'data': {
        'type': 'subscriptionAvailabilities',
        'attributes': {'availableInNewTerritories': True},
        'relationships': {
            'subscription': {'data': {'type': 'subscriptions', 'id': sub_id}},
            'availableTerritories': {'data': [
                {'type': 'territories', 'id': к} for к in коды]},
        }}})
    print(f'      доступность: {len(коды)} стран')


def цена(sub_id: str, товар_id: str) -> None:
    """Цена задаётся точкой прайса Apple: своих чисел у них нет, есть сетка."""
    уже = asc.get(f'/v1/subscriptions/{sub_id}/prices', **{'limit': '5'})['data']
    if уже:
        print('      цена уже задана')
        return
    нужно = ЦЕНЫ[товар_id]
    # Точек прайса у Apple больше двух сотен, и годовые цены лежат в хвосте:
    # без разбора страниц 34.99 просто не попадала в выборку.
    точки = []
    путь = (f'/v1/subscriptions/{sub_id}/pricePoints'
            f'?filter[territory]={БАЗОВАЯ_СТРАНА}&limit=200')
    while путь:
        ответ = asc.call('GET', путь)
        точки += ответ['data']
        следующая = (ответ.get('links') or {}).get('next')
        путь = следующая.replace(asc.BASE, '') if следующая else None
    подходящие = [т for т in точки
                  if т['attributes'].get('customerPrice') == нужно]
    if not подходящие:
        доступные = sorted({т['attributes'].get('customerPrice') for т in точки})
        print(f'      точки {нужно} нет; рядом: {доступные[:12]}')
        return
    asc.call('POST', '/v1/subscriptionPrices', json={'data': {
        'type': 'subscriptionPrices',
        'attributes': {'startDate': None, 'preserveCurrentPrice': False},
        'relationships': {
            'subscription': {'data': {'type': 'subscriptions', 'id': sub_id}},
            'subscriptionPricePoint': {'data': {
                'type': 'subscriptionPricePoints', 'id': подходящие[0]['id']}},
            'territory': {'data': {'type': 'territories', 'id': БАЗОВАЯ_СТРАНА}},
        },
    }})
    print(f'      цена {нужно} $ по территории {БАЗОВАЯ_СТРАНА}; '
          'остальные страны Apple посчитает сама')


def цены_по_миру(sub_id: str, товар_id: str) -> None:
    """Цена в каждой стране, а не только в базовой.

    Apple отдаёт «эквивалентные» точки прайса: сколько стоит то же самое в
    рупиях, злотых и иенах. Без них подписка остаётся без цены за пределами
    США и висит в MISSING_METADATA.
    """
    # Список уже проставленных цен читаем осторожно: у Apple этот запрос
    # временами отвечает 500, и ронять из-за этого весь проход незачем.
    уже: set[str] = set()
    try:
        ответ = asc.get(f'/v1/subscriptions/{sub_id}/prices',
                        **{'limit': '200', 'include': 'territory'})
        for ц in ответ['data']:
            связь = (ц.get('relationships', {}).get('territory', {}) or {}).get('data')
            if связь:
                уже.add(связь['id'])
    except SystemExit:
        pass
    базовая = None
    путь = (f'/v1/subscriptions/{sub_id}/pricePoints'
            f'?filter[territory]={БАЗОВАЯ_СТРАНА}&limit=200')
    while путь and not базовая:
        ответ = asc.call('GET', путь)
        for т in ответ['data']:
            if т['attributes'].get('customerPrice') == ЦЕНЫ[товар_id]:
                базовая = т['id']
                break
        след = (ответ.get('links') or {}).get('next')
        путь = след.replace(asc.BASE, '') if след else None
    if not базовая:
        print('      базовой точки прайса нет — цены по миру не ставлю')
        return

    # `include=territory` обязателен: без него связь приходит одними ссылками,
    # и страну из точки не достать.
    точки = asc.get(f'/v1/subscriptionPricePoints/{базовая}/equalizations',
                    **{'limit': '200', 'include': 'territory'})['data']
    поставлено = 0
    for точка in точки:
        страна = ((точка.get('relationships', {}).get('territory', {})
                   .get('data') or {}).get('id'))
        if not страна or страна in уже:
            continue
        try:
            asc.call('POST', '/v1/subscriptionPrices', json={'data': {
                'type': 'subscriptionPrices',
                'attributes': {'startDate': None, 'preserveCurrentPrice': False},
                'relationships': {
                    'subscription': {'data': {'type': 'subscriptions', 'id': sub_id}},
                    'subscriptionPricePoint': {'data': {
                        'type': 'subscriptionPricePoints', 'id': точка['id']}},
                    'territory': {'data': {'type': 'territories', 'id': страна}},
                },
            }})
            поставлено += 1
        except SystemExit:
            # Страна, где приложение не продаётся, цену не принимает — это не
            # беда, а её нормальное состояние. Сюда же попадают случайные 500
            # Apple: повтор прогона доберёт пропущенное.
            continue
        except Exception:
            continue
    print(f'      цены по миру: добавлено {поставлено} стран')


def скриншот(sub_id: str, файл: str) -> None:
    """Экран, где ревьюер Apple видит покупку.

    Снимок не рисованный: его отрисовывает само приложение настоящими
    шрифтами и настоящим кодом экрана
    (`flutter test test/visual_check_test.dart --update-goldens --run-skipped`),
    поэтому он показывает ровно то, что увидит человек.

    Загрузка трёхшаговая: бронь → куски файла по адресам из ответа →
    подтверждение контрольной суммой.
    """
    было = asc.get(f'/v1/subscriptions/{sub_id}/appStoreReviewScreenshot')
    if было.get('data'):
        print('      скриншот уже есть')
        return

    данные = pathlib.Path(файл).read_bytes()
    бронь = asc.call('POST', '/v1/subscriptionAppStoreReviewScreenshots', json={'data': {
        'type': 'subscriptionAppStoreReviewScreenshots',
        'attributes': {'fileName': pathlib.Path(файл).name,
                       'fileSize': len(данные)},
        'relationships': {'subscription': {
            'data': {'type': 'subscriptions', 'id': sub_id}}},
    }})['data']

    for шаг in бронь['attributes']['uploadOperations']:
        кусок = данные[шаг['offset']:шаг['offset'] + шаг['length']]
        req = urllib.request.Request(шаг['url'], data=кусок, method=шаг['method'])
        for заголовок in шаг.get('requestHeaders', []):
            req.add_header(заголовок['name'], заголовок['value'])
        with urllib.request.urlopen(req, timeout=120) as r:
            if r.status not in (200, 201, 204):
                raise SystemExit(f'кусок снимка не залился: {r.status}')

    asc.call('PATCH', f'/v1/subscriptionAppStoreReviewScreenshots/{бронь["id"]}',
             json={'data': {
                 'type': 'subscriptionAppStoreReviewScreenshots',
                 'id': бронь['id'],
                 'attributes': {'uploaded': True,
                                'sourceFileChecksum': hashlib.md5(данные).hexdigest()},
             }})
    print(f'      скриншот загружен ({len(данные) // 1024} КБ)')


def льгота() -> None:
    """Льготный период Apple: при сбое списания доступ живёт ещё шестнадцать
    дней, пока человек меняет карту.

    Путь именно `/v1/subscriptionGracePeriods/{id}` — на `/v1/apps/{id}/…`
    сервер отвечает 405. Из длительностей приняты только `THREE_DAYS`,
    `SIXTEEN_DAYS` и `TWENTY_EIGHT_DAYS`.
    """
    было = asc.get(f'/v1/apps/{asc.APP_ID}/subscriptionGracePeriod')['data']['attributes']
    if было.get('optIn'):
        print(f'   льготный период уже включён: {было.get("duration")}')
        return
    r = asc.call('PATCH', f'/v1/subscriptionGracePeriods/{asc.APP_ID}', json={'data': {
        'type': 'subscriptionGracePeriods', 'id': asc.APP_ID,
        'attributes': {'optIn': True, 'duration': 'SIXTEEN_DAYS',
                       'renewalType': 'ALL_RENEWALS', 'sandboxOptIn': True}}})
    print(f'   льготный период включён: {r["data"]["attributes"].get("duration")}')


def state() -> None:
    гр = группы()
    if not гр:
        print('групп подписок нет')
        return
    for g in гр:
        print(f'группа {g["attributes"].get("referenceName")} ({g["id"]})')
        for s in подписки(g['id']):
            a = s['attributes']
            цены = asc.get(f'/v1/subscriptions/{s["id"]}/prices', **{'limit': '5'})['data']
            локали = asc.get(f'/v1/subscriptions/{s["id"]}/subscriptionLocalizations',
                             **{'limit': '10'})['data']
            print(f'   {a.get("productId")}: {a.get("subscriptionPeriod")}, '
                  f'состояние {a.get("state")}, цен {len(цены)}, '
                  f'языков {len(локали)}')


def setup() -> None:
    print('→ льготный период')
    льгота()
    print('→ группа подписок')
    group_id = завести_группу()
    назвать_группу(group_id)

    готовые = {s['attributes'].get('productId'): s['id']
               for s in подписки(group_id)}
    print('→ товары')
    for товар in ТОВАРЫ:
        sub_id = завести_товар(group_id, товар, готовые)
        тексты(sub_id, товар)
        доступность(sub_id)
        цена(sub_id, товар['productId'])
        цены_по_миру(sub_id, товар['productId'])
        if pathlib.Path(СНИМОК).exists():
            скриншот(sub_id, СНИМОК)
        else:
            print('      скриншота покупки нет — экрана подписки ещё нет, шаг пропущен')
    print('готово')


if __name__ == '__main__':
    команда = sys.argv[1] if len(sys.argv) > 1 else 'state'
    {'state': state, 'setup': setup}.get(команда, state)()
