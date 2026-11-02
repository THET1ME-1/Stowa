import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

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
  });

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
    return FolderCard(id: id, name: name, icon: 'folder', shape: shape, count: 0, covers: const [], recentTitles: const [], createdByAi: false);
  }

  static List<String> _split(String? joined) => joined == null || joined.isEmpty ? const [] : joined.split(String.fromCharCode(31));
}
