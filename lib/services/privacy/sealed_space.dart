import 'dart:io';

import '../../data/db/database.dart';
import 'hidden_rows.dart' show hiddenItemIds;

/// Открытое скрытое этого процесса: где лежат его файлы и какие заметки сейчас в нём.
/// Пути таких файлов в базе полные (от корня телефона), остальные — от корня хранилища;
/// `p.join(хранилище, путь)` даёт верный файл в обоих случаях.
class SealedSpace {
  SealedSpace._();

  static Directory? _root;
  static final _items = <String>{};

  /// Папка открытого скрытого: `<данные приложения>/sealed-open`.
  static Directory? get root => _root;

  static void configure(Directory? root) {
    _root = root;
    _items.clear();
  }

  static bool holds(String itemId) => _root != null && _items.contains(itemId);

  /// Путь производного файла заметки: у открытой скрытой — внутри открытой папки.
  static String place(String itemId, String relative) => holds(itemId) ? '${_root!.path}/$relative' : relative;

  /// Файл лежит в открытой папке скрытого.
  static bool isOpenPath(String path) => _root != null && path.startsWith('${_root!.path}/');

  static Future<void> load(AppDatabase db) async {
    final ids = await hiddenItemIds(db);
    _items
      ..clear()
      ..addAll(ids);
  }

  static void take(String itemId) => _items.add(itemId);

  static void release(String itemId) => _items.remove(itemId);

  static void clear() => _items.clear();
}
