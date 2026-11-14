import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/bookmarks_export.dart';
import 'package:stowa/domain/keep_export.dart';
import 'package:stowa/domain/mymind_export.dart';

void main() {
  group('Google Keep', () {
    // 12 мая 2023, 10:00 по UTC — в микросекундах, как пишет Takeout
    const created = 1683885600000000;

    test('заголовок первой строкой, текст под ним, дата из микросекунд', () {
      final note = parseKeepNote({'title': 'Борщ', 'textContent': 'свёкла, капуста', 'isTrashed': false, 'createdTimestampUsec': created, 'userEditedTimestampUsec': created + 1000})!;
      expect(note.text, 'Борщ\nсвёкла, капуста');
      expect(note.at, DateTime.fromMicrosecondsSinceEpoch(created));
      expect(note.pinned, isFalse);
    });

    test('список — пунктами с галочками', () {
      final note = parseKeepNote({
        'title': 'Купить',
        'listContent': [
          {'text': 'хлеб', 'isChecked': false},
          {'text': 'молоко', 'isChecked': true},
        ],
        'createdTimestampUsec': created,
      })!;
      expect(note.text, 'Купить\n- [ ] хлеб\n- [x] молоко');
    });

    test('ссылка из карточки — строкой в конце, если её нет в тексте', () {
      final note = parseKeepNote({
        'textContent': 'посмотреть',
        'annotations': [
          {'url': 'https://example.com/a', 'source': 'WEBLINK', 'title': 'A'},
        ],
        'createdTimestampUsec': created,
      })!;
      expect(note.text, 'посмотреть\nhttps://example.com/a');

      final inside = parseKeepNote({
        'textContent': 'https://example.com/a',
        'annotations': [
          {'url': 'https://example.com/a', 'source': 'WEBLINK'},
        ],
        'createdTimestampUsec': created,
      })!;
      expect(inside.text, 'https://example.com/a');
    });

    test('ярлыки — теги, закреплённая остаётся закреплённой, вложения с типом', () {
      final note = parseKeepNote({
        'textContent': 'море',
        'labels': [
          {'name': 'Отпуск'},
          {'name': 'Идеи'},
        ],
        'isPinned': true,
        'attachments': [
          {'filePath': '1a2b.jpeg', 'mimetype': 'image/jpeg'},
        ],
        'createdTimestampUsec': created,
      })!;
      expect(note.tags, ['Отпуск', 'Идеи']);
      expect(note.pinned, isTrue);
      expect(note.files.single.path, '1a2b.jpeg');
      expect(note.files.single.mime, 'image/jpeg');
    });

    test('корзина и чужой JSON не переносятся', () {
      expect(parseKeepNote({'textContent': 'старое', 'isTrashed': true, 'createdTimestampUsec': created}), isNull);
      expect(parseKeepNote({'name': 'Saved Messages', 'messages': []}), isNull);
      expect(parseKeepNote({'title': '', 'textContent': '', 'createdTimestampUsec': created}), isNull);
    });
  });

  group('закладки браузера', () {
    test('Chrome: адрес, название, дата; панель закладок тегом не становится, папка — тег', () {
      final notes = parseBookmarks('''
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
    <DT><H3 ADD_DATE="1683000000" LAST_MODIFIED="0" PERSONAL_TOOLBAR_FOLDER="true">Панель закладок</H3>
    <DL><p>
        <DT><A HREF="https://flutter.dev/" ADD_DATE="1683885600" ICON="data:image/png;base64,AA">Flutter</A>
        <DT><H3 ADD_DATE="1683000000" LAST_MODIFIED="0">Рецепты</H3>
        <DL><p>
            <DT><A HREF="https://eda.ru/borsch" ADD_DATE="1683889200">Борщ</A>
            <DT><A HREF="javascript:alert(1)" ADD_DATE="1683889200">Букмарклет</A>
        </DL><p>
    </DL><p>
</DL><p>
''');
      expect(notes, hasLength(2));
      final flutter = notes.firstWhere((note) => note.text == 'https://flutter.dev/');
      expect(flutter.title, 'Flutter');
      expect(flutter.at, DateTime.fromMillisecondsSinceEpoch(1683885600 * 1000));
      expect(flutter.tags, isEmpty);
      final borsch = notes.firstWhere((note) => note.text == 'https://eda.ru/borsch');
      expect(borsch.title, 'Борщ');
      expect(borsch.tags, ['Рецепты']);
    });

    test('Firefox: метки TAGS — тоже теги', () {
      final notes = parseBookmarks('''
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<DL><p>
  <DT><H3 ADD_DATE="1683000000" UNFILED_BOOKMARKS_FOLDER="true">Другие закладки</H3>
  <DL><p>
    <DT><A HREF="https://example.com/" ADD_DATE="1683885600" TAGS="чтение,потом">Пример</A>
  </DL><p>
</DL>
''');
      expect(notes.single.tags, ['чтение', 'потом']);
    });

    test('не файл закладок — ошибка формата', () {
      expect(() => parseBookmarks('<html><body><p>Привет</p></body></html>'), throwsFormatException);
    });
  });

  group('mymind', () {
    test('колонки по названию в любом порядке, кавычки, запятые и переносы внутри ячейки', () {
      final notes = parseMymindCsv(
        'Created,Type,Title,URL,Content,Tags\n'
        '2023-05-12T10:00:00Z,WebPage,Борщ,https://eda.ru/borsch,"свёкла, капуста",рецепты\n'
        '2023-05-13T09:00:00Z,Note,,,"первая строка\nвторая ""в кавычках""","идеи, планы"\n',
      );
      expect(notes, hasLength(2));
      expect(notes[0].text, 'Борщ\nhttps://eda.ru/borsch\nсвёкла, капуста');
      expect(notes[0].at, DateTime.utc(2023, 5, 12, 10));
      expect(notes[0].tags, ['рецепты']);
      expect(notes[1].text, 'первая строка\nвторая "в кавычках"');
      expect(notes[1].tags, ['идеи', 'планы']);
    });

    test('ячейка с именем файла из папки — вложение', () {
      final notes = parseMymindCsv('title,file,created\nМоре,sea.jpg,2023-05-12\n', files: {'sea.jpg'});
      expect(notes.single.files.single.path, 'sea.jpg');
      expect(notes.single.files.single.mime, 'image/jpeg');
    });

    test('ни текста, ни адреса в колонках — ошибка формата', () {
      expect(() => parseMymindCsv('a,b\n1,2\n'), throwsFormatException);
    });
  });
}
