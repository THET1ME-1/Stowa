#!/usr/bin/env python3
"""Собирает таблицы слов для разбора времени и служебных слов на ~100 языках.

Источники (скачать в отдельную папку, не в репозиторий):
  cldr-dates-full 49 и cldr-core 49 (Unicode CLDR, лицензия Unicode v3):
    https://registry.npmjs.org/cldr-dates-full/-/cldr-dates-full-49.0.0.tgz
    https://registry.npmjs.org/cldr-core/-/cldr-core-49.0.0.tgz
  stopwords-iso 1.1.0 (MIT): https://registry.npmjs.org/stopwords-iso/-/stopwords-iso-1.1.0.tgz
  словари LibreOffice: tool/typo_dicts.sh <папка>

Запуск:
  python3 -I tool/cldr_words.py <cldr-dates-full/package> <cldr-core/package> \\
      <stopwords-iso.json> <папка словарей>

Пишет lib/domain/cldr_time_words.dart и lib/domain/stop_words.dart.
"""
import json
import os
import re
import sys
import unicodedata

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib', 'domain')

# языки, у которых время разбирают свои таблицы в reminder_parser.dart
OWN = {'ru', 'uk', 'en', 'de', 'es', 'pl', 'ro'}

# словари LibreOffice по языкам
DICTS = {
    'ru_RU': 'ru', 'uk_UA': 'uk', 'en_US': 'en', 'en_GB': 'en', 'de_DE_frami': 'de', 'es_ES': 'es',
    'ro_RO': 'ro', 'pl_PL': 'pl', 'fr': 'fr', 'it_IT': 'it', 'pt_BR': 'pt', 'pt_PT': 'pt', 'tr_TR': 'tr',
}

PARTS = ['morning', 'day', 'afternoon', 'evening', 'night', 'am', 'pm', 'noon', 'midnight']

# части суток, которые одинаково сдвигают час: утро и AM — как есть, после полудня, вечер и PM — плюс 12
MARK_CLASS = {0: 'as is', 5: 'as is', 2: 'plus 12', 3: 'plus 12', 6: 'plus 12'}
UNITS = ['minute', 'hour', 'day', 'week', 'month']
WEEKDAYS = {'mon': 1, 'tue': 2, 'wed': 3, 'thu': 4, 'fri': 5, 'sat': 6, 'sun': 7}

# часы части суток по умолчанию, как в своих таблицах: «вечером» — 19
DEFAULT_HOURS = {'morning': 9, 'afternoon': 15, 'evening': 19, 'night': 23, 'noon': 12, 'midnight': 0}

# письменности без пробелов между словами: границы слова там не ищутся
NO_SPACES = re.compile('[぀-ヿ㐀-鿿฀-໿က-႟ក-៿]')
LATIN_OR_CYRILLIC = re.compile('[a-zÀ-ɏЀ-ӿ]')


def fold(text):
    """Как foldText в word_forms.dart: нижний регистр, «ё» как «е», латиница без знаков."""
    out = []
    for char in text.lower():
        if char == 'ё':
            out.append('е')
        elif ord(char) < 0x250:
            base = unicodedata.normalize('NFD', char)[0]
            out.append(base)
        else:
            out.append(char)
    return ''.join(out)


def clean(text):
    """Пробелы любого вида — один обычный, апостроф — прямой."""
    text = re.sub(r'[\s  ]+', ' ', text).strip()
    return re.sub('[’ʼ`]', "'", text).lower()


def load(path):
    with open(path, encoding='utf-8') as file:
        return json.load(file)


def languages(core):
    levels = load(os.path.join(core, 'coverageLevels.json'))['effectiveCoverageLevels']
    return sorted(name for name, level in levels.items()
                  if '_' not in name and '-' not in name and name != 'und' and level in ('modern', 'moderate'))


def hours_of(rules, locale):
    """Час, на который встаёт часть суток без часа: свой по умолчанию, если попадает в её рамки."""
    ruleset = rules.get(locale, {})
    hours = {}
    for key, rule in ruleset.items():
        part = re.sub(r'\d$', '', key)
        if part not in DEFAULT_HOURS:
            continue
        if '_at' in rule:
            hours[key] = int(rule['_at'][:2])
            continue
        start = int(rule['_from'][:2])
        end = int(rule['_before'][:2])
        default = DEFAULT_HOURS[part]
        inside = start <= default < end if start < end else (default >= start or default < end)
        # венгерское «reggel» — с 6 до 9: утро встаёт на 8, а не на привычные 9
        hours[key] = default if inside else (min(max(default, start), end - 1) if start < end else start)
    return hours


def time_words(dates, core, locales):
    rules = load(os.path.join(core, 'supplemental', 'dayPeriods.json'))['supplemental']['dayPeriodRuleSet']
    days, weekdays, months, relative, marks, periods, at_words, hour_marks = {}, {}, {}, {}, {}, {}, {}, {}
    conflicts = set()

    def put(table, word, value, language):
        word = clean(word)
        # «{0}» бывает только в шаблонах «через сколько»
        if not word or ('{' in word and table is not relative):
            return
        # «{0} мин.», «{0} mln» без «через» — просто длина или количество, а не срок
        if table is relative and word.startswith('{0}') and re.fullmatch(r'[\s.a-zа-яәөүұқғңһі]{0,6}', word[3:]):
            return
        # «an», «ap» после числа — это «1 an» по-французски, а не утро
        if table is marks and LATIN_OR_CYRILLIC.search(word) and len(re.sub(r'[\s.]', '', word)) < 3:
            return
        old = table.get(word)
        # «下午» — и «после полудня», и PM: для часа одно и то же, к 3 прибавляется 12
        same = old is not None and table is marks and MARK_CLASS.get(old[0]) == MARK_CLASS.get(value) is not None
        if old is not None and old[0] != value and not same:
            conflicts.add((id(table), word))
        if same:
            value = old[0]
        table[word] = (value, old[1] | {language} if old else {language})

    for locale in locales:
        if locale in OWN:
            continue
        main = os.path.join(dates, 'main', locale)
        if not os.path.isdir(main):
            continue
        fields = load(os.path.join(main, 'dateFields.json'))['main'][locale]['dates']['fields']
        calendar = load(os.path.join(main, 'ca-gregorian.json'))['main'][locale]['dates']['calendars']['gregorian']

        day = fields.get('day', {})
        for shift in (0, 1, 2):
            if f'relative-type-{shift}' in day:
                put(days, day[f'relative-type-{shift}'], shift, locale)

        for unit_index, unit in enumerate(UNITS):
            for width in ('', '-short'):
                future = fields.get(unit + width, {}).get('relativeTime-type-future', {})
                for count, pattern in future.items():
                    if '{0}' not in pattern:
                        number = {'one': 1, 'two': 2}.get(count.rsplit('-', 1)[-1])
                        if number is None:
                            continue
                        pattern = f'{pattern}#{number}'
                    put(relative, pattern, unit_index, locale)

        for context in ('format', 'stand-alone'):
            for key, name in calendar['days'][context]['wide'].items():
                put(weekdays, name, WEEKDAYS[key.split('-')[0]], locale)
            for key, name in calendar['months'][context]['wide'].items():
                # «3月» у китайского и японского — число, его разбирает свой шаблон
                if not re.search(r'\d', name):
                    put(months, name, int(key.split('-')[0]), locale)

        hours = hours_of(rules, locale)
        for context, table in (('format', marks), ('stand-alone', periods)):
            for key, name in calendar['dayPeriods'][context]['wide'].items():
                part = re.sub(r'\d$', '', key)
                if part not in PARTS:
                    continue
                value = PARTS.index(part) if table is marks else (PARTS.index(part), hours.get(key, DEFAULT_HOURS.get(part, 12)))
                if table is periods and part in ('am', 'pm'):
                    continue
                put(table, name, value, locale)

        # «{1} 'à' {0}» — предлог перед часом, «{1}, {0} बजे» — слово после
        relative_format = calendar.get('dateTimeFormats-relative', {}).get('standard', {}).get('full') \
            or calendar.get('dateTimeFormats-atTime', {}).get('standard', {}).get('full') or ''
        if '{0}' in relative_format:
            head, tail = relative_format.split('{0}', 1)
            before = head.split('{1}')[-1]
            after = tail.split('{1}')[0]
            for piece, table in ((before, at_words), (after, hour_marks)):
                piece = re.sub(r"[',.()\-/،]", ' ', piece)
                piece = re.sub(r'\s+', ' ', piece).strip()
                if piece and not piece.isdigit():
                    put(table, piece, 1, locale)
        hour = calendar['dateTimeFormats']['availableFormats'].get('H', '')
        mark = re.sub(r"[H']", '', hour).strip(' .')
        if mark and not (len(mark) == 1 and mark.isascii()):
            put(hour_marks, mark, 1, locale)

    tables = {'days': days, 'weekdays': weekdays, 'months': months, 'relative': relative,
              'marks': marks, 'periods': periods, 'at': at_words, 'hour_marks': hour_marks}
    for name, table in tables.items():
        for word in [word for word in table if (id(table), word) in conflicts]:
            del table[word]
    return tables


def dictionary_words(folder, wanted):
    """Какие из слов есть в словаре какого языка: слово → языки."""
    found = {}
    for file_name in sorted(os.listdir(folder)):
        name, extension = os.path.splitext(file_name)
        if extension != '.txt' or name not in DICTS:
            continue
        language = DICTS[name]
        with open(os.path.join(folder, file_name), encoding='utf-8') as file:
            for line in file:
                word = fold(line.strip())
                if word in wanted:
                    found.setdefault(word, set()).add(language)
    return found


def weak_words(tables, folder):
    """Слова, которые в другом языке значат другое, и совсем короткие: только рядом со временем."""
    candidates = {}
    for name in ('days', 'weekdays'):
        for word, (_, owners) in tables[name].items():
            candidates[fold(word)] = (word, owners)
    in_dicts = dictionary_words(folder, set(candidates))
    weak = set()
    for folded, (word, owners) in candidates.items():
        letters = re.sub(r'[\s\'-]', '', folded)
        short = LATIN_OR_CYRILLIC.search(folded) and len(letters) < 4
        foreign = in_dicts.get(folded, set()) - owners
        if short or foreign or ' ' in word and any(owner == 'vi' for owner in owners):
            weak.add(word)
    return weak


def dart_string(text):
    return "'" + text.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def write_time(tables, weak, locales):
    lines = [
        '// Собрано tool/cldr_words.py из Unicode CLDR 49 (cldr-dates-full, лицензия Unicode v3),',
        '// руками не править. Языки со своими таблицами в reminder_parser.dart здесь не стоят.',
        '// ignore_for_file: lines_longer_than_80_chars',
        '',
        '/// Языки, на которых разбирается время: свои таблицы и эти.',
        'const cldrTimeLanguages = <String>{',
    ]
    lines += wrap([dart_string(locale) for locale in locales])
    lines.append('};')

    def map_of(title, comment, table, value):
        lines.extend(['', f'/// {comment}', f'const {title} = <String, {value[0]}>{{'])
        entries = [f'{dart_string(word)}: {value[1](found)}' for word, (found, _) in sorted(table.items())]
        lines.extend(wrap(entries))
        lines.append('};')

    def set_of(title, comment, words):
        lines.extend(['', f'/// {comment}', f'const {title} = <String>{{'])
        lines.extend(wrap([dart_string(word) for word in sorted(words)]))
        lines.append('};')

    number = ('int', str)
    map_of('cldrDayWords', 'Сегодня, завтра, послезавтра: слово → сдвиг в днях.', tables['days'], number)
    map_of('cldrWeekdays', 'Дни недели: слово → 1–7, понедельник первый.', tables['weekdays'], number)
    map_of('cldrMonths', 'Месяцы: слово → 1–12, в обеих формах («mars», «de març»).', tables['months'], number)
    map_of('cldrRelative', 'Через сколько: шаблон, {0} — число, #N — число словом; → 0 минуты, 1 часы, 2 дни, 3 недели, 4 месяцы.',
           tables['relative'], number)
    map_of('cldrPeriodMarks', 'Часть суток рядом с часом («9 du soir», «午後3時»): → вид по порядку утро, день, после полудня, вечер, ночь, am, pm, полдень, полночь.',
           tables['marks'], number)
    map_of('cldrPeriods', 'Часть суток сама по себе («demain soir»): → (вид, час).', tables['periods'],
           ('(int, int)', lambda found: f'({found[0]}, {found[1]})'))
    set_of('cldrAtWords', 'Предлоги перед часом: «à», «om», «alle ore», «klo».', tables['at'])
    set_of('cldrHourMarks', 'Слова и знаки часа после числа: «Uhr», «時», «시», «giờ», «बजे».', tables['hour_marks'])
    set_of('cldrWeakWords', 'Дни и слова дня, которые в другом языке значат другое или слишком коротки: только рядом со временем.', weak)
    with open(os.path.join(OUT, 'cldr_time_words.dart'), 'w', encoding='utf-8') as file:
        file.write('\n'.join(lines) + '\n')


def wrap(entries, width=110):
    lines, line = [], ''
    for entry in entries:
        if line and len(line) + len(entry) + 2 > width:
            lines.append('  ' + line.rstrip())
            line = ''
        line += entry + ', '
    if line:
        lines.append('  ' + line.rstrip())
    return lines


def write_stop_words(stopwords, folder, short_folder):
    word = re.compile(r'^[^\W\d_]+$')
    by_language = {}
    for language, words in sorted(stopwords.items()):
        clean_words = sorted({entry.lower() for entry in words if word.match(entry)})
        by_language[language] = clean_words
    own = set()
    for language in OWN:
        own.update(fold(entry) for entry in by_language.get(language, []))
    foreign = {fold(entry) for language, words in by_language.items() if language not in OWN for entry in words}
    # чужое служебное слово, которое в своих семи языках — обычное слово: «pour», «man»
    in_dicts = dictionary_words(folder, foreign - own)
    if short_folder:
        for found, owners in dictionary_words(short_folder, foreign - own).items():
            in_dicts.setdefault(found, set()).update(owners)
    content = sorted(found for found, owners in in_dicts.items() if owners & OWN)

    lines = [
        '// Собрано tool/cldr_words.py из stopwords-iso 1.1.0 (MIT), руками не править.',
        '// ignore_for_file: lines_longer_than_80_chars',
        '',
        '/// Служебные слова по языкам, через пробел: по ним узнаётся язык текста.',
        'const stopWordsByLanguage = <String, String>{',
    ]
    for language, words in by_language.items():
        lines.append(f"  '{language}': {dart_string(' '.join(words))},")
    lines += ['};', '',
              '/// Служебные слова чужих языков, которые в семи языках приложения — обычные слова («pour», «man»):',
              '/// ни поиск, ни раскладка их не пропускают.',
              'const notServiceWords = <String>{']
    lines += wrap([dart_string(entry) for entry in content])
    lines.append('};')
    with open(os.path.join(OUT, 'stop_words.dart'), 'w', encoding='utf-8') as file:
        file.write('\n'.join(lines) + '\n')


def main():
    if len(sys.argv) < 5:
        sys.exit(__doc__)
    dates, core, stopwords_path, folder = sys.argv[1:5]
    short_folder = sys.argv[5] if len(sys.argv) > 5 else None
    locales = languages(core)
    tables = time_words(dates, core, locales)
    weak = weak_words(tables, folder)
    write_time(tables, weak, [locale for locale in locales if locale not in OWN])
    write_stop_words(load(stopwords_path), folder, short_folder)
    for name, table in tables.items():
        print(name, len(table))
    print('weak', len(weak))


if __name__ == '__main__':
    main()
