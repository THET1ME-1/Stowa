import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/folder_guess.dart';

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
}
