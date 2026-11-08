import 'package:drift/drift.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:uuid/uuid.dart';

import '../../core/theme/folder_palette.dart';
import '../../domain/folder_tree.dart';
import '../../domain/models.dart';
import '../db/database.dart';

/// Плитка папки на главной.
class FolderCard {
  const FolderCard({
    required this.id,
    required this.name,
    required this.icon,
    required this.shape,
    required this.count,
    required this.covers,
    required this.recentTitles,
    required this.createdByAi,
    this.view = FolderView.auto,
    this.colorKey,
    this.order = 0,
    this.parentId,
    this.path = const [],
    int? ownCount,
  }) : ownCount = ownCount ?? count;

  /// Папка, в которой лежит эта; null — верхняя.
  final String? parentId;

  /// Имена от верхней папки до этой: «Дом», «Ремонт», «Кухня». Пусто — как у одной папки.
  final List<String> path;

  /// Заметки самой папки, без вложенных; [count] — вместе с вложенными.
  final int ownCount;

  /// Родители через «/» для подписи под именем; у верхней — null.
  String? get parentsLabel => path.length < 2 ? null : path.sublist(0, path.length - 1).join(' / ');

  /// Путь целиком: «Дом / Ремонт / Кухня».
  String get pathLabel => path.length < 2 ? name : path.join(' / ');

  int get depth => path.isEmpty ? 1 : path.length;

  /// Как показывать: доска, список или сам по содержимому.
  final FolderView view;

  /// Цвет, выбранный человеком (ключ FolderPalette); null — по месту в списке.
  final String? colorKey;

  /// Место папки в списке.
  final int order;

  Color get color => FolderPalette.of(colorKey, order);

  final String id;
  final String name;
  final String icon;

  /// Имя формы значка (BadgeShape.name).
  final String shape;
  final int count;

  /// До трёх последних картинок, пути от папки приложения.
  final List<String> covers;

  /// Заголовки двух последних вещей: подпись простой плитки.
  final List<String> recentTitles;
  final bool createdByAi;
}

/// Папки деревом: каждая вложенная сразу под своим родителем, порядок внутри уровня прежний.
/// Папка, чьего родителя нет в списке, стоит как верхняя.
List<FolderCard> inTreeOrder(List<FolderCard> folders) {
  final ids = {for (final folder in folders) folder.id};
  final ordered = <FolderCard>[];
  void add(String? parent) {
    for (final folder in folders) {
      final own = folder.parentId != null && ids.contains(folder.parentId) ? folder.parentId : null;
      if (own != parent || ordered.contains(folder)) continue;
      ordered.add(folder);
      add(folder.id);
    }
  }

  add(null);
  return ordered;
}

/// Что подняла удалённая папка: её заметки и вложенные папки. «Вернуть» кладёт их обратно.
class FolderRemoval {
  const FolderRemoval({required this.itemIds, required this.childIds});

  final List<String> itemIds;
  final List<String> childIds;
}

class FoldersRepository {
  FoldersRepository(this._db);

  final AppDatabase _db;

  Stream<List<FolderCard>> watchAll() {
    // счёт, обложки и заголовки — подзапросами, чтобы плитки шли одним запросом
    return _db
        .customSelect(
          '''
SELECT folders.*,
  (SELECT COUNT(*) FROM items WHERE items.folder_id = folders.id AND items.deleted_at IS NULL) AS item_count,
  (SELECT group_concat(path, char(31)) FROM (
    SELECT attachments.path AS path FROM attachments JOIN items ON items.id = attachments.item_id
    WHERE items.folder_id = folders.id AND items.deleted_at IS NULL AND attachments.mime LIKE 'image/%'
    ORDER BY items.created_at DESC, attachments.position LIMIT 3)) AS covers,
  (SELECT group_concat(title, char(31)) FROM (
    SELECT items.title AS title FROM items
    WHERE items.folder_id = folders.id AND items.deleted_at IS NULL
    ORDER BY items.created_at DESC LIMIT 2)) AS recent_titles
FROM folders WHERE folders.deleted_at IS NULL
ORDER BY folders.sort_order, folders.name''',
          readsFrom: {_db.folders, _db.items, _db.attachments},
        )
        .watch()
        .map((rows) {
          final tree = FolderTree([
            for (final row in rows) FolderNode(id: row.read<String>('id'), name: row.read<String>('name'), parentId: row.readNullable<String>('parent_id')),
          ]);
          final own = {for (final row in rows) row.read<String>('id'): row.read<int>('item_count')};
          return [
            for (final row in rows)
              FolderCard(
                id: row.read<String>('id'),
                name: row.read<String>('name'),
                icon: row.read<String>('icon'),
                shape: row.read<String>('shape'),
                // число на пилюле — вместе с вложенными папками
                count: [row.read<String>('id'), ...tree.descendants(row.read<String>('id'))].fold(0, (sum, id) => sum + own[id]!),
                ownCount: row.read<int>('item_count'),
                covers: _split(row.readNullable<String>('covers')),
                recentTitles: _split(row.readNullable<String>('recent_titles')),
                createdByAi: row.read<bool>('created_by_ai'),
                view: FolderView.values.asNameMap()[row.read<String>('view')] ?? FolderView.auto,
                colorKey: row.readNullable<String>('color'),
                order: row.read<int>('sort_order'),
                parentId: tree.parentOf(row.read<String>('id')),
                path: tree.path(row.read<String>('id')),
              ),
          ];
        });
  }

  /// Папка из строки «@Имя»: с заглавной буквы, форма значка по очереди, в конец списка.
  /// С [parentId] — внутри той папки.
  Future<FolderCard> create(String rawName, {String? parentId}) async {
    final trimmed = rawName.trim();
    final name = trimmed[0].toUpperCase() + trimmed.substring(1);
    final count = await _db.folders.count().getSingle();
    const shapes = ['cookie9', 'squircle', 'gem', 'pill', 'cookie6'];
    final id = const Uuid().v4();
    final shape = shapes[count % shapes.length];
    await _db.into(_db.folders).insert(FoldersCompanion.insert(id: id, name: name, icon: 'folder', shape: shape, sortOrder: Value(count), parentId: Value(parentId)));
    final parent = parentId == null ? null : await (_db.select(_db.folders)..where((t) => t.id.equals(parentId))).getSingleOrNull();
    return FolderCard(
      id: id,
      name: name,
      icon: 'folder',
      shape: shape,
      count: 0,
      covers: const [],
      recentTitles: const [],
      createdByAi: false,
      order: count,
      parentId: parentId,
      path: parent == null ? [name] : [...await _path(parent.id), name],
    );
  }

  Future<List<String>> _path(String id) async {
    final rows = await (_db.select(_db.folders)..where((t) => t.deletedAt.isNull())).get();
    return FolderTree([for (final row in rows) FolderNode(id: row.id, name: row.name, parentId: row.parentId)]).path(id);
  }

  /// Переложить папку в другую или наверх (null). Правила глубины проверяет экран (`FolderTree.canMoveInto`).
  Future<void> move(String id, String? parentId) =>
      (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(FoldersCompanion(parentId: Value(parentId)));

  /// Человек открыл папку, которую завёл ИИ: метка «новая» больше не нужна.
  Future<void> markSeen(String id) =>
      (_db.update(_db.folders)..where((t) => t.id.equals(id) & t.createdByAi.equals(true))).write(const FoldersCompanion(createdByAi: Value(false)));

  Future<void> rename(String id, String rawName) {
    final trimmed = rawName.trim();
    final name = trimmed[0].toUpperCase() + trimmed.substring(1);
    return (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(FoldersCompanion(name: Value(name)));
  }

  /// Иконка, форма значка и цвет папки.
  Future<void> setLook(String id, {required String icon, required String shape, String? color}) {
    return (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(FoldersCompanion(icon: Value(icon), shape: Value(shape), color: Value(color)));
  }

  Future<void> setView(String id, FolderView view) {
    return (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(FoldersCompanion(view: Value(view)));
  }

  /// Папка уходит, её заметки и вложенные папки поднимаются к родителю (у верхней —
  /// заметки «Без папки», вложенные становятся верхними). Что подняли — для «Вернуть».
  Future<FolderRemoval> delete(String id, DateTime at) {
    return _db.transaction(() async {
      final folder = await (_db.select(_db.folders)..where((t) => t.id.equals(id))).getSingle();
      final items = await (_db.select(_db.items)..where((t) => t.folderId.equals(id))).get();
      final children = await (_db.select(_db.folders)..where((t) => t.parentId.equals(id) & t.deletedAt.isNull())).get();
      await (_db.update(_db.items)..where((t) => t.folderId.equals(id))).write(ItemsCompanion(folderId: Value(folder.parentId)));
      await (_db.update(_db.folders)..where((t) => t.parentId.equals(id) & t.deletedAt.isNull())).write(FoldersCompanion(parentId: Value(folder.parentId)));
      await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(FoldersCompanion(deletedAt: Value(at)));
      return FolderRemoval(itemIds: [for (final row in items) row.id], childIds: [for (final row in children) row.id]);
    });
  }

  Future<void> restore(String id, FolderRemoval removal) {
    return _db.transaction(() async {
      await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(const FoldersCompanion(deletedAt: Value(null)));
      await (_db.update(_db.items)..where((t) => t.id.isIn(removal.itemIds))).write(ItemsCompanion(folderId: Value(id)));
      await (_db.update(_db.folders)..where((t) => t.id.isIn(removal.childIds))).write(FoldersCompanion(parentId: Value(id)));
    });
  }

  static List<String> _split(String? joined) => joined == null || joined.isEmpty ? const [] : joined.split(String.fromCharCode(31));
}
