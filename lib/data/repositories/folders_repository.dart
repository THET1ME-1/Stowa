import 'package:drift/drift.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:uuid/uuid.dart';

import '../../core/theme/folder_palette.dart';
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
  });

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
        .map(
          (rows) => [
            for (final row in rows)
              FolderCard(
                id: row.read<String>('id'),
                name: row.read<String>('name'),
                icon: row.read<String>('icon'),
                shape: row.read<String>('shape'),
                count: row.read<int>('item_count'),
                covers: _split(row.readNullable<String>('covers')),
                recentTitles: _split(row.readNullable<String>('recent_titles')),
                createdByAi: row.read<bool>('created_by_ai'),
                view: FolderView.values.asNameMap()[row.read<String>('view')] ?? FolderView.auto,
                colorKey: row.readNullable<String>('color'),
                order: row.read<int>('sort_order'),
              ),
          ],
        );
  }

  /// Папка из строки «@Имя»: с заглавной буквы, форма значка по очереди, в конец списка.
  Future<FolderCard> create(String rawName) async {
    final trimmed = rawName.trim();
    final name = trimmed[0].toUpperCase() + trimmed.substring(1);
    final count = await _db.folders.count().getSingle();
    const shapes = ['cookie9', 'squircle', 'gem', 'pill', 'cookie6'];
    final id = const Uuid().v4();
    final shape = shapes[count % shapes.length];
    await _db.into(_db.folders).insert(FoldersCompanion.insert(id: id, name: name, icon: 'folder', shape: shape, sortOrder: Value(count)));
    return FolderCard(id: id, name: name, icon: 'folder', shape: shape, count: 0, covers: const [], recentTitles: const [], createdByAi: false, order: count);
  }

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

  /// Папка уходит, её вещи остаются «Без папки». Возвращает их id для «Вернуть».
  Future<List<String>> delete(String id, DateTime at) {
    return _db.transaction(() async {
      final rows = await (_db.select(_db.items)..where((t) => t.folderId.equals(id))).get();
      await (_db.update(_db.items)..where((t) => t.folderId.equals(id))).write(const ItemsCompanion(folderId: Value(null)));
      await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(FoldersCompanion(deletedAt: Value(at)));
      return [for (final row in rows) row.id];
    });
  }

  Future<void> restore(String id, List<String> itemIds) {
    return _db.transaction(() async {
      await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(const FoldersCompanion(deletedAt: Value(null)));
      await (_db.update(_db.items)..where((t) => t.id.isIn(itemIds))).write(ItemsCompanion(folderId: Value(id)));
    });
  }

  static List<String> _split(String? joined) => joined == null || joined.isEmpty ? const [] : joined.split(String.fromCharCode(31));
}
