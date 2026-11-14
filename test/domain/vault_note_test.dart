import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/vault_note.dart';

void main() {
  final created = DateTime(2026, 11, 5, 18, 30, 32);
  final updated = DateTime(2026, 11, 5, 18, 37, 20);

  VaultNote full() => VaultNote(
    id: '7c1e0b6a',
    kind: ItemKind.link,
    title: 'Человек-бензопила',
    body: 'Первая строка\n- [ ] купить «молоко»\n---\nтекст после черты "в кавычках"',
    created: created,
    updated: updated,
    tags: ['манга', 'боевик'],
    url: 'https://mangalib.me/ru/manga/7965--chainsaw-man',
    previewSite: 'MangaLib',
    previewAuthor: 'Tatsuki Fujimoto',
    previewText: 'Денджи охотится на демонов.\nВторая строка.',
    cover: '.stowa/covers/7c1e.jpg',
    durationSeconds: 47,
    reminder: DateTime(2026, 11, 20, 18),
    latitude: 47.0245,
    longitude: 28.8323,
    placeName: 'ул. Пушкина, 1',
    sortedBy: SortedBy.user,
    attachments: ['Человек-бензопила/фото 1.jpg', 'Человек-бензопила/скан.pdf'],
  );

  test('вещь проходит круг файл → вещь без потерь', () {
    final note = full();
    final text = writeVaultNote(note, fileName: 'Человек-бензопила.md');
    final back = readVaultNote(text, fileName: 'Человек-бензопила.md', fileModified: DateTime(2000));
    expect(back.id, note.id);
    expect(back.kind, note.kind);
    expect(back.title, note.title);
    expect(back.body, note.body);
    expect(back.created, note.created);
    expect(back.updated, note.updated);
    expect(back.tags, note.tags);
    expect(back.url, note.url);
    expect(back.previewSite, note.previewSite);
    expect(back.previewAuthor, note.previewAuthor);
    expect(back.previewText, note.previewText);
    expect(back.cover, note.cover);
    expect(back.durationSeconds, note.durationSeconds);
    expect(back.reminder, note.reminder);
    expect(back.latitude, note.latitude);
    expect(back.longitude, note.longitude);
    expect(back.placeName, note.placeName);
    expect(back.sortedBy, note.sortedBy);
    expect(back.attachments, note.attachments);
    // второй круг даёт тот же файл слово в слово
    expect(writeVaultNote(back, fileName: 'Человек-бензопила.md'), text);
  });

  test('напоминание по месту проходит круг файл → заметка: дом, магазин и точка с названием', () {
    for (final place in [
      const PlaceReminder(PlaceReminderKind.home),
      const PlaceReminder(PlaceReminderKind.shop),
      const PlaceReminder(PlaceReminderKind.point, latitude: 47.0245, longitude: 28.8323, name: 'Ботаника, Кишинёв'),
      // своё место и день: «завтра буду у Саши»
      PlaceReminder(PlaceReminderKind.place, ref: 'sasha', name: 'Саша', day: DateTime(2026, 11, 14)),
      PlaceReminder(PlaceReminderKind.pharmacy, day: DateTime(2026, 11, 14)),
    ]) {
      final note = VaultNote(id: 'a', kind: ItemKind.note, title: 'Кофе', body: 'Кофе', created: created, updated: updated, remindPlace: place);
      final back = readVaultNote(writeVaultNote(note, fileName: 'Кофе.md'), fileName: 'Кофе.md', fileModified: DateTime(2000));
      expect(back.remindPlace, place);
      expect(back.extra, isEmpty);
    }
    final none = VaultNote(id: 'a', kind: ItemKind.note, title: 'Кофе', body: 'Кофе', created: created, updated: updated);
    expect(writeVaultNote(none, fileName: 'Кофе.md'), isNot(contains('remind_place')));
  });

  test('вложения — строки ![[…]] в конце, текст их не содержит', () {
    final text = writeVaultNote(
      VaultNote(id: 'a', kind: ItemKind.note, title: 'Карбонара', body: 'Карбонара\nгуанчиале', created: created, updated: updated, attachments: ['Карбонара/фото 1.jpg']),
      fileName: 'Карбонара.md',
    );
    expect(text, endsWith('гуанчиале\n\n![[Карбонара/фото 1.jpg]]\n'));
    final back = readVaultNote(text, fileName: 'Карбонара.md', fileModified: created);
    expect(back.body, 'Карбонара\nгуанчиале');
    expect(back.attachments, ['Карбонара/фото 1.jpg']);
  });

  test('закреплённая заметка: время закрепления в свойстве pinned, круг без потерь', () {
    final pinnedAt = DateTime(2026, 11, 14, 9, 15);
    final note = VaultNote(id: 'a', kind: ItemKind.note, title: 'Пароли Wi-Fi', body: 'Пароли Wi-Fi', created: created, updated: updated, pinned: pinnedAt);
    final text = writeVaultNote(note, fileName: 'Пароли Wi-Fi.md');
    expect(text, contains('pinned: 2026-11-14T09:15:00.000'));
    final back = readVaultNote(text, fileName: 'Пароли Wi-Fi.md', fileModified: DateTime(2000));
    expect(back.pinned, pinnedAt);
    expect(back.extra, isEmpty);
    expect(isOwnVaultProperty('pinned'), isTrue);
    // не закреплена — свойства нет
    final plain = VaultNote(id: 'a', kind: ItemKind.note, title: 'Кофе', body: 'Кофе', created: created, updated: updated);
    expect(writeVaultNote(plain, fileName: 'Кофе.md'), isNot(contains('pinned')));
  });

  test('pinned: true, поставленное в Obsidian руками, — закреплена с времени правки файла', () {
    final back = readVaultNote('---\npinned: true\n---\nТекст', fileName: 'Важное.md', fileModified: created);
    expect(back.pinned, created);
    expect(readVaultNote('---\npinned: false\n---\nТекст', fileName: 'Важное.md', fileModified: created).pinned, isNull);
  });

  test('заметка Obsidian без свойств: заголовок из имени, время файла', () {
    final back = readVaultNote('Текст', fileName: 'Идеи.md', fileModified: created);
    expect(back.title, 'Идеи');
    expect(back.body, 'Текст');
    expect(back.created, created);
    expect(back.updated, created);
    expect(back.id, '');
    expect(back.kind, ItemKind.note);
  });

  test('чужие свойства возвращаются как были', () {
    const text = '---\nid: "a"\naliases: [a, b]\ncssclass: wide\n---\nТекст\n';
    final back = readVaultNote(text, fileName: 'Текст.md', fileModified: created);
    expect(back.extra, {'aliases': ['a', 'b'], 'cssclass': 'wide'});
    final again = readVaultNote(writeVaultNote(back, fileName: 'Текст.md'), fileName: 'Текст.md', fileModified: created);
    expect(again.extra, {'aliases': ['a', 'b'], 'cssclass': 'wide'});
  });

  // время зависит от пояса машины: в сверке текста оно заменено меткой
  String masked(String text) => text.replaceAll(RegExp(r'\d{4}-\d\d-\d\dT[\d:.]+[+-]\d\d:\d\d'), '<время>');

  test('свойства пишутся как в Obsidian: списки столбиком, строки без кавычек', () {
    final text = writeVaultNote(full(), fileName: 'Человек-бензопила.md');
    final properties = text.substring(0, text.indexOf('\n---\n', 4) + 5);
    expect(
      masked(properties),
      '---\n'
      'id: 7c1e0b6a\n'
      'kind: link\n'
      'created: <время>\n'
      'updated: <время>\n'
      'tags:\n'
      '  - манга\n'
      '  - боевик\n'
      'url: https://mangalib.me/ru/manga/7965--chainsaw-man\n'
      'preview:\n'
      '  site: MangaLib\n'
      '  author: Tatsuki Fujimoto\n'
      '  text: "Денджи охотится на демонов.\\nВторая строка."\n'
      'cover: .stowa/covers/7c1e.jpg\n'
      'duration: 47\n'
      'reminder: <время>\n'
      'place:\n'
      '  lat: 47.0245\n'
      '  lon: 28.8323\n'
      '  name: ул. Пушкина, 1\n'
      'sorted_by: user\n'
      '---\n',
    );
  });

  test('цитаты пишутся списком блоков', () {
    final note = VaultNote(
      id: 'a',
      kind: ItemKind.link,
      title: 'Кофе',
      body: 'x',
      created: created,
      updated: updated,
      highlights: [
        VaultHighlight(quote: 'вода важнее зёрен', note: 'купить фильтр', at: created, position: 3),
        VaultHighlight(quote: 'помол: средний', at: updated),
      ],
    );
    expect(
      masked(writeVaultNote(note, fileName: 'Кофе.md')),
      contains(
        'highlights:\n'
        '  - quote: вода важнее зёрен\n'
        '    note: купить фильтр\n'
        '    at: <время>\n'
        '    pos: 3\n'
        '  - quote: "помол: средний"\n'
        '    at: <время>\n',
      ),
    );
  });

  test('строка, которую YAML прочёл бы иначе, остаётся строкой', () {
    const tricky = [
      'true', 'null', 'Null', 'yes', '~', '12', '12.5', '.5', '+7', '1e3', '1_000', '0x1F', '12:30', '123e4567',
      '- пункт', 'a: b', 'a #b', 'конец:', ' с пробелом', 'пробел в конце ', 'две\nстроки', 'таб\tвнутри', 'в "кавычках"', "it's",
      '[[Заметка]]', '#тег', '@имя', '{a}', '*звезда', '& и', '!важно', '%5', '`код`', '|', '>', '?', ',', '...', '---', '',
      '2026-11-05', '2026-11-05T18:30', '👋 привет', r'C:\Users', 'https://example.com/a?b=1#c', 'ул. Пушкина, 1',
    ];
    final note = VaultNote(
      id: 'a',
      kind: ItemKind.note,
      title: 'Текст',
      body: 'x',
      created: created,
      updated: updated,
      extra: {
        'список': tricky,
        for (final (index, value) in tricky.indexed) 'k$index': value,
        'a: b': 'ключ с двоеточием',
        '12': 'ключ-число',
        'true': 'ключ-слово',
        'с пробелом': 'ключ из двух слов',
      },
    );
    final text = writeVaultNote(note, fileName: 'Текст.md');
    final back = readVaultNote(text, fileName: 'Текст.md', fileModified: created);
    expect(back.extra, note.extra);
    expect(back.id, 'a');
    // то, что безопасно, пишется без кавычек
    expect(text, contains('\n  - 2026-11-05\n'));
    expect(text, contains('\n  - https://example.com/a?b=1#c\n'));
    expect(text, contains('\n  - ул. Пушкина, 1\n'));
    expect(text, contains('\n  - "true"\n'));
  });

  test('чужие свойства любого вида возвращаются в файл слово в слово', () {
    const foreign =
        'aliases:\n'
        '  - a\n'
        '  - b\n'
        'cssclasses: []\n'
        'done: true\n'
        'rating: 4\n'
        'price: 12.5\n'
        'publish:\n'
        'summary: ""\n'
        'author:\n'
        '  name: Саня\n'
        '  links:\n'
        '    - https://example.com\n'
        'steps:\n'
        '  - name: раз\n'
        '    done: false\n'
        '  - name: два\n'
        'grid:\n'
        '  - - 1\n'
        '    - 2\n'
        '  - - 3\n';
    final back = readVaultNote('---\nid: a\n$foreign---\nТекст\n', fileName: 'Текст.md', fileModified: created);
    expect(back.extra, {
      'aliases': ['a', 'b'],
      'cssclasses': <Object?>[],
      'done': true,
      'rating': 4,
      'price': 12.5,
      'publish': null,
      'summary': '',
      'author': {
        'name': 'Саня',
        'links': ['https://example.com'],
      },
      'steps': [
        {'name': 'раз', 'done': false},
        {'name': 'два'},
      ],
      'grid': [
        [1, 2],
        [3],
      ],
    });
    expect(masked(writeVaultNote(back, fileName: 'Текст.md')), '---\nid: a\nkind: note\ncreated: <время>\nupdated: <время>\n$foreign---\nТекст\n');
  });

  test('заметка Obsidian: теги столбиком, время без пояса', () {
    const text = '---\ntags:\n  - дом\n  - сад/розы\ncreated: 2026-11-05T18:30:32\nupdated: 2026-11-05 18:37\n---\nТекст\n';
    final back = readVaultNote(text, fileName: 'Текст.md', fileModified: DateTime(2026, 11, 9));
    expect(back.tags, ['дом', 'сад/розы']);
    expect(back.created, created);
    expect(back.updated, DateTime(2026, 11, 5, 18, 37));
    expect(back.extra, isEmpty);
  });

  test('свойство date служит датой записи, когда created нет', () {
    final modified = DateTime(2026, 11, 9, 12);
    VaultNote read(String properties) => readVaultNote('---\n$properties\n---\nТекст\n', fileName: 'Текст.md', fileModified: modified);
    expect(read('date: 2026-10-01').created, DateTime(2026, 10, 1));
    expect(read('date: 2026-10-01T09:15').created, DateTime(2026, 10, 1, 9, 15));
    expect(read('date: 2026-10-01 09:15').created, DateTime(2026, 10, 1, 9, 15));
    expect(read('date: 2026-10-01\ncreated: 2026-09-01').created, DateTime(2026, 9, 1), reason: 'created главнее');
    // дата позже самого файла — это день события, а не записи
    expect(read('date: 2026-12-31').created, modified);
    // свойство остаётся в файле как было
    expect(read('date: 2026-10-01').extra, {'date': '2026-10-01'});
  });

  test('файл прежнего вида, где значения в JSON, читается', () {
    const text =
        '---\n'
        'id: "a"\n'
        'kind: "link"\n'
        'created: "2026-11-05T18:30:32.000"\n'
        'tags: ["манга","боевик"]\n'
        'preview: {"site":"MangaLib","text":"раз\\nдва"}\n'
        'place: {"lat":47.0245,"lon":28.8323,"name":"ул. Пушкина, 1"}\n'
        'highlights: [{"quote":"вода","at":"2026-11-05T18:37:20.000","pos":3}]\n'
        '---\n'
        'Текст\n';
    final back = readVaultNote(text, fileName: 'Текст.md', fileModified: DateTime(2000));
    expect(back.id, 'a');
    expect(back.kind, ItemKind.link);
    expect(back.created, created);
    expect(back.tags, ['манга', 'боевик']);
    expect(back.previewSite, 'MangaLib');
    expect(back.previewText, 'раз\nдва');
    expect(back.latitude, 47.0245);
    expect(back.placeName, 'ул. Пушкина, 1');
    expect(back.highlights.single.quote, 'вода');
    expect(back.highlights.single.position, 3);
  });

  test('цитаты статьи с пометками проходят круг файл → заметка, порядок цел', () {
    final note = VaultNote(
      id: 'a',
      kind: ItemKind.link,
      title: 'Кофе без турки',
      body: 'https://blog.example.com/kofe',
      created: created,
      updated: updated,
      url: 'https://blog.example.com/kofe',
      highlights: [
        VaultHighlight(quote: 'вода важнее зёрен', note: 'купить фильтр', at: created),
        VaultHighlight(quote: 'Кофе — «повод» проснуться.\nВторая строка', at: updated),
      ],
    );
    final text = writeVaultNote(note, fileName: 'Кофе без турки.md');
    final back = readVaultNote(text, fileName: 'Кофе без турки.md', fileModified: DateTime(2000));
    expect([for (final one in back.highlights) one.quote], ['вода важнее зёрен', 'Кофе — «повод» проснуться.\nВторая строка']);
    expect([for (final one in back.highlights) one.note], ['купить фильтр', null]);
    expect([for (final one in back.highlights) one.at], [created, updated]);
    expect(back.extra, isEmpty, reason: 'цитаты — своё свойство, а не чужое');
    expect(writeVaultNote(back, fileName: 'Кофе без турки.md'), text);
  });

  test('теги из свойств и из текста', () {
    const text = '---\ntags: [дом]\n---\nКупить плитку #ремонт\n';
    expect(readVaultNote(text, fileName: 'Плитка.md', fileModified: created).tags, ['дом', 'ремонт']);
    // Obsidian пишет и строкой через запятую, и с решёткой
    const obsidian = '---\ntags: "#дом, сад"\n---\nТекст\n';
    expect(readVaultNote(obsidian, fileName: 'Текст.md', fileModified: created).tags, ['дом', 'сад']);
  });

  test('имя файла без запрещённых символов', () {
    expect(vaultFileName('a/b: c?'), 'a b c');
    expect(vaultFileName('...'), 'Без названия');
    expect(vaultFileName('  '), 'Без названия');
    expect(vaultFileName('.скрытый'), 'скрытый');
    expect(vaultFileName('конец.'), 'конец');
    expect(vaultFileName('я' * 300).length, lessThanOrEqualTo(120));
    expect(vaultFileName('Привет 👋'), 'Привет 👋');
    // эмодзи не режется пополам
    expect(vaultFileName('👋' * 100).runes.every((rune) => rune == 0x1F44B), isTrue);
  });

  test('заголовок, который не влез в имя, хранится в свойстве title', () {
    final note = VaultNote(id: 'a', kind: ItemKind.note, title: 'a/b: c?', body: 'x', created: created, updated: updated);
    final text = writeVaultNote(note, fileName: '${vaultFileName(note.title)}.md');
    expect(text, contains('title: "a/b: c?"'));
    expect(readVaultNote(text, fileName: 'a b c.md', fileModified: created).title, 'a/b: c?');
    // заголовок совпал с именем — свойство не пишется
    expect(writeVaultNote(VaultNote(id: 'a', kind: ItemKind.note, title: 'Идеи', body: 'x', created: created, updated: updated), fileName: 'Идеи.md'), isNot(contains('title:')));
  });

  test('сломанные свойства не теряют текст', () {
    const text = '---\ntags: [не закрыто\n---\nТекст\n';
    final back = readVaultNote(text, fileName: 'Текст.md', fileModified: created);
    expect(back.body, contains('Текст'));
  });

  test('картинка в конце текста остаётся в тексте: хвост — только строки с путём', () {
    final note = VaultNote(
      id: 'a',
      kind: ItemKind.note,
      title: 'Плитка',
      body: 'Плитка\nвот так\n![[IMG-1.jpg]]',
      created: created,
      updated: updated,
      attachments: ['Плитка/скан.pdf'],
    );
    final text = writeVaultNote(note, fileName: 'Плитка.md');
    expect(text, endsWith('вот так\n![[IMG-1.jpg]]\n\n![[Плитка/скан.pdf]]\n'));
    final back = readVaultNote(text, fileName: 'Плитка.md', fileModified: created);
    expect(back.body, 'Плитка\nвот так\n![[IMG-1.jpg]]');
    expect(back.attachments, ['Плитка/скан.pdf']);
  });

  test('заметка Obsidian с картинкой в конце: картинка в тексте на своём месте', () {
    final back = readVaultNote('Ремонт\n![[Pasted image 20261108.png]]\n', fileName: 'Ремонт.md', fileModified: created);
    expect(back.body, 'Ремонт\n![[Pasted image 20261108.png]]');
    expect(back.attachments, isEmpty);
  });
}
