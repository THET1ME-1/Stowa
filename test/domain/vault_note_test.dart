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
    for (final place in const [
      PlaceReminder(PlaceReminderKind.home),
      PlaceReminder(PlaceReminderKind.shop),
      PlaceReminder(PlaceReminderKind.point, latitude: 47.0245, longitude: 28.8323, name: 'Ботаника, Кишинёв'),
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
}
