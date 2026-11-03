import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/folder_guess.dart';
import 'package:stowa/domain/models.dart';

void main() {
  // две книги и бытовая папка, как у хозяина
  final index = FolderIndex([
    const FolderDoc(folderId: 'wireless', text: 'Мальчик с телекинезом проходит тесты способностей'),
    const FolderDoc(folderId: 'wireless', text: 'Лаборатория, где изучают детей со способностями. Опыт за стеклом'),
    const FolderDoc(folderId: 'wireless', text: 'Глава 3: мальчик сбегает из лаборатории'),
    const FolderDoc(folderId: 'novel', text: 'Милтон работает курьером и боится высоты'),
    const FolderDoc(folderId: 'novel', text: 'Сцена: Милтон спорит с сестрой из-за денег'),
    const FolderDoc(folderId: 'novel', text: 'Мальчик из соседней квартиры дразнит Милтона'),
    const FolderDoc(folderId: 'car', text: 'Замена масла и фильтра, мастер сказал прийти через месяц'),
  ]);

  test('заметка про телекинез уходит в книгу, где были телекинез и способности', () {
    final guess = index.guess(
      'Мальчик с телекинезом на тестировании способностей поднял все предметы, что дали, раскрутил до жидкого, '
      'слепил из них человека, что смотрит из-за потайного стекла-зеркала за опытом.',
    )!;
    expect(guess.folderId, 'wireless');
    expect(guess.byName, isFalse);
    expect(guess.words, contains('телекинезом'));
  });

  test('имя в любой форме ведёт в книгу, где этот герой уже был', () {
    final guess = index.guess('Пусть у Милтона будет личная проблема, которой он стыдится: быстрый метаболизм')!;
    expect(guess.folderId, 'novel');
    expect(guess.byName, isTrue);
    expect(guess.words.first, 'Милтона');
  });

  test('слово, которое есть во всех книгах, папку не решает', () {
    expect(index.guess('мальчик пошёл гулять'), isNull);
  });

  test('слова даты и времени папку не решают', () {
    // как на телефоне: «сегодня» есть только в одной папке и кажется редким словом
    final errands = FolderIndex([
      const FolderDoc(folderId: 'errands', text: 'Забрать посылку сегодня в 15:38'),
      const FolderDoc(folderId: 'doors', text: 'Dver4'),
      const FolderDoc(folderId: 'doors', text: 'Dver3'),
    ]);
    expect(errands.guess('Полить цветы сегодня в 16:41'), isNull);
    expect(errands.guess('Полить цветы завтра утром в пятницу'), isNull);
    // а слова, похожие на дату, но про дело, работают
    final things = FolderIndex([
      const FolderDoc(folderId: 'watch', text: 'Ремонт часов у мастера'),
      const FolderDoc(folderId: 'watch', text: 'Ремешок для часов'),
      const FolderDoc(folderId: 'home', text: 'Средство для посуды'),
      const FolderDoc(folderId: 'home', text: 'Купить лампочки в коридор'),
      const FolderDoc(folderId: 'home', text: 'Позвонить сантехнику про кран'),
      const FolderDoc(folderId: 'home', text: 'Шторы в спальню'),
    ]);
    expect(things.guess('Батарейка для часов')?.folderId, 'watch');
  });

  test('ничего общего — папки нет', () {
    expect(index.guess('купить хлеб и молоко'), isNull);
  });

  test('заглавная буква в начале предложения — не имя', () {
    final guess = index.guess('Лаборатория снова. Мастер пришёл');
    expect(guess?.byName ?? false, isFalse);
  });

  test('подсказки для «Разобрать»: папки по похожести, даже когда уверенности нет', () {
    expect(index.rank('мальчик пошёл гулять').take(2), ['wireless', 'novel']);
    expect(index.rank('купить хлеб'), isEmpty);
  });

  test('пустая база ничего не угадывает', () {
    expect(FolderIndex(const []).guess('Милтон'), isNull);
  });

  group('приметы кроме слов', () {
    List<String> link(String url) => itemSignals(kind: ItemKind.link, url: url);
    final docs = [
      FolderDoc(folderId: 'read', text: 'Сборщик мусора в Dart', signals: link('https://habr.com/ru/articles/1/')),
      FolderDoc(folderId: 'read', text: 'Как устроен Flutter', signals: link('https://habr.com/ru/articles/2/')),
      FolderDoc(folderId: 'refs', text: 'Фото от 1 ноября', signals: itemSignals(kind: ItemKind.image)),
      FolderDoc(folderId: 'refs', text: 'Фото от 2 ноября', signals: itemSignals(kind: ItemKind.image)),
      FolderDoc(folderId: 'docs', text: 'Договор аренды', signals: itemSignals(kind: ItemKind.file, fileName: 'dogovor.pdf')),
      const FolderDoc(folderId: 'car', text: 'Замена масла и фильтра'),
      const FolderDoc(folderId: 'car', text: 'Шины на зиму'),
    ];
    final signalIndex = FolderIndex(docs);

    test('ссылка с того же сайта ложится к другим ссылкам сайта, даже без общих слов', () {
      final guess = signalIndex.guess('https://habr.com/ru/articles/3/', signals: link('https://habr.com/ru/articles/3/'));
      expect(guess?.folderId, 'read');
      expect(guess?.words, contains('habr.com'));
    });

    test('фото без текста — туда, где уже лежат фото', () {
      expect(signalIndex.guess('', signals: itemSignals(kind: ItemKind.image))?.folderId, 'refs');
    });

    test('одно фото в папке ещё не делает её местом для всех фото', () {
      final single = FolderIndex([...docs.where((doc) => doc.folderId != 'refs'), FolderDoc(folderId: 'refs', text: 'Кадр', signals: itemSignals(kind: ItemKind.image))]);
      expect(single.guess('', signals: itemSignals(kind: ItemKind.image)), isNull);
    });

    test('PDF к документам по типу файла', () {
      expect(signalIndex.guess('', signals: itemSignals(kind: ItemKind.file, fileName: 'schet.pdf'))?.folderId, 'docs');
    });

    test('у заметки вид не примета, у ссылки — сайт без www', () {
      expect(itemSignals(kind: ItemKind.note), isEmpty);
      expect(itemSignals(kind: ItemKind.link, url: 'https://www.youtube.com/watch?v=1'), ['site:youtube.com', 'kind:link']);
    });
  });
}
