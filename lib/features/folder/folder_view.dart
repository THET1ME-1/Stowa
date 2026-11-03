import '../../data/repositories/items_repository.dart';
import '../../domain/models.dart';

/// Доска, когда в папке почти одни картинки, иначе лента вперемешку.
/// Выбор человека в переключателе главнее.
bool showAsBoard(List<ItemCard> cards, FolderView view) {
  if (view == FolderView.board || view == FolderView.canvas) return true;
  if (view == FolderView.list || cards.isEmpty) return false;
  final pictures = cards.where((card) => card.thumbPath != null).length;
  return pictures / cards.length >= 0.6;
}

enum FolderOrder { newest, oldest, name }

/// Порядок карточек по кнопке в шапке папки.
List<ItemCard> orderCards(Iterable<ItemCard> cards, FolderOrder order) {
  final list = cards.toList();
  switch (order) {
    case FolderOrder.newest:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case FolderOrder.oldest:
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    case FolderOrder.name:
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
  return list;
}

/// Теги вещей папки для чипов над доской: частые первыми, пять штук.
List<String> folderTags(List<ItemCard> cards) {
  final counts = <String, int>{};
  for (final card in cards) {
    for (final tag in card.tags) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  final tags = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return tags.take(5).toList();
}
