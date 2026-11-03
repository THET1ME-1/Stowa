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

/// Высота плитки в ширинах колонки: картинка по своей пропорции, без размера —
/// квадрат, текст — чуть ниже квадрата. Плюс зазор между плитками.
double boardTileHeight(ItemCard card) => (card.thumbPath == null ? 0.75 : card.thumbRatio ?? 1.0) + 0.05;

/// Доска в две колонки: каждая следующая плитка ложится в ту, что сейчас короче.
({List<ItemCard> left, List<ItemCard> right}) boardColumns(List<ItemCard> cards) {
  final left = <ItemCard>[];
  final right = <ItemCard>[];
  var leftHeight = 0.0;
  var rightHeight = 0.0;
  for (final card in cards) {
    if (rightHeight < leftHeight) {
      right.add(card);
      rightHeight += boardTileHeight(card);
    } else {
      left.add(card);
      leftHeight += boardTileHeight(card);
    }
  }
  return (left: left, right: right);
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
