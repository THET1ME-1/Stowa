import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/folder/folder_view.dart';

ItemCard _card(String id, {String? thumb}) =>
    ItemCard(id: id, title: id, kind: thumb == null ? ItemKind.note : ItemKind.image, folderId: 'f', sortState: SortState.sorted, createdAt: DateTime(2026), thumbPath: thumb);

void main() {
  test('почти одни картинки — доска, вперемешку — лента', () {
    expect(showAsBoard([_card('a', thumb: 'a.jpg'), _card('b', thumb: 'b.jpg'), _card('c')], FolderView.auto), isTrue);
    expect(showAsBoard([_card('a', thumb: 'a.jpg'), _card('b'), _card('c')], FolderView.auto), isFalse);
    expect(showAsBoard(const [], FolderView.auto), isFalse);
  });

  test('выбор человека главнее', () {
    expect(showAsBoard([_card('a')], FolderView.board), isTrue);
    expect(showAsBoard([_card('a', thumb: 'a.jpg')], FolderView.list), isFalse);
  });

  test('теги папки для чипов: частые первыми, не больше пяти', () {
    final cards = [
      for (final (index, tags) in [['двери', 'свет'], ['двери'], ['город'], ['двери', 'город'], ['а'], ['б'], ['в']].indexed)
        ItemCard(id: '$index', title: '', kind: ItemKind.image, folderId: 'f', sortState: SortState.sorted, createdAt: DateTime(2026), tags: tags),
    ];
    expect(folderTags(cards).take(2), ['двери', 'город']);
    expect(folderTags(cards), hasLength(5));
  });

  test('доска кладёт каждую карточку в более короткую колонку', () {
    ItemCard pic(String id, double? ratio) =>
        ItemCard(id: id, title: id, kind: ItemKind.image, folderId: 'f', sortState: SortState.sorted, createdAt: DateTime(2026), thumbPath: '$id.jpg', thumbRatio: ratio);
    // высокая слева, справа копятся низкие, пока не перерастут её
    final columns = boardColumns([pic('a', 1.6), pic('b', 0.6), pic('c', 0.6), pic('d', 1.0), pic('e', 0.5)]);
    expect(columns.left.map((card) => card.id), ['a', 'e']);
    expect(columns.right.map((card) => card.id), ['b', 'c', 'd']);
    // без размеров — по очереди, как квадраты
    final unknown = boardColumns([pic('a', null), pic('b', null), pic('c', null)]);
    expect(unknown.left.map((card) => card.id), ['a', 'c']);
  });

  test('порядок в папке: новые, старые, по имени без учёта регистра', () {
    ItemCard at(String title, int day) =>
        ItemCard(id: title, title: title, kind: ItemKind.note, folderId: 'f', sortState: SortState.sorted, createdAt: DateTime(2026, 1, day));
    final cards = [at('банан', 2), at('Арбуз', 1), at('вишня', 3)];
    List<String> titles(FolderOrder order) => [for (final card in orderCards(cards, order)) card.title];
    expect(titles(FolderOrder.newest), ['вишня', 'банан', 'Арбуз']);
    expect(titles(FolderOrder.oldest), ['Арбуз', 'банан', 'вишня']);
    expect(titles(FolderOrder.name), ['Арбуз', 'банан', 'вишня']);
  });

  test('по цвету: по кругу тонов от красного, серое и без цвета в конце, внутри — новые первыми', () {
    ItemCard colored(String title, String? hex, int day) =>
        ItemCard(id: title, title: title, kind: ItemKind.image, folderId: 'f', sortState: SortState.sorted, createdAt: DateTime(2026, 1, day), mainColor: hex);
    final cards = [colored('без цвета', null, 5), colored('синее', '#1E3CC8', 1), colored('серое', '#808080', 2), colored('красное', '#DC1E1E', 3), colored('зелёное', '#28AA3C', 4)];
    expect([for (final card in orderCards(cards, FolderOrder.color)) card.title], ['красное', 'зелёное', 'синее', 'серое', 'без цвета']);
  });
}
