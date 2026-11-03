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
}
