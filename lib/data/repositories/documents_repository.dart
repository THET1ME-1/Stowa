import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/folder_tree.dart';
import '../../domain/item_kind.dart' show showsAsImage;
import '../../domain/json_canvas.dart';
import '../../domain/models.dart';
import '../../domain/note_links.dart' show wikiLink;
import '../../domain/obsidian_base.dart';
import '../../domain/vault_note.dart' show packVaultProperties, unpackVaultProperties, vaultFileName;
import '../db/database.dart';

/// Холсты и базы Obsidian — заметки видов canvas и base, файл целиком в `items.document`.
/// В файл хранилища их кладёт писатель, как и заметки: правка здесь ставит запись в очередь.
class DocumentsRepository {
  DocumentsRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Завести пустой холст или базу папки. Где лежит, решил человек: раскладка не трогает.
  Future<String> create(ItemKind kind, {required String title, String? folderId}) async {
    final id = const Uuid().v4();
    final now = _clock();
    final document = kind == ItemKind.base ? newBaseFor((await _folderNames(folderId)).map(vaultFileName).join('/')) : CanvasDoc.empty().encode();
    await _db.into(_db.items).insert(
      ItemsCompanion.insert(
        id: id,
        kind: kind,
        title: title,
        body: Value(kind == ItemKind.base ? 'Таблица' : ''),
        document: Value(document),
        folderId: Value(folderId),
        sortedBy: const Value(SortedBy.user),
        sortState: const Value(SortState.sorted),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Записать правку холста: файл, текст для поиска, время правки.
  Future<void> save(String id, CanvasDoc doc) => (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
    ItemsCompanion(document: Value(doc.encode()), body: Value(doc.plainText()), updatedAt: Value(_clock())),
  );

  /// Записать правку базы: текст файла целиком, имена видов — для поиска.
  Future<void> saveBase(String id, String text) => (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
    ItemsCompanion(
      document: Value(text),
      body: Value(ObsidianBase.parse(text).views.map((view) => view.name).where((name) => name.isNotEmpty).join('\n')),
      updatedAt: Value(_clock()),
    ),
  );

  /// Пустая заметка из базы, как «Новая» в Obsidian: имя, папка и свойства из условий вида.
  /// Разложена человеком — правила и ИИ её не трогают.
  Future<String> createNote({required String title, String? folderId, Map<String, Object?> properties = const {}}) async {
    final id = const Uuid().v4();
    final now = _clock();
    await _db.into(_db.items).insert(
      ItemsCompanion.insert(
        id: id,
        kind: ItemKind.note,
        title: title,
        folderId: Value(folderId),
        properties: Value(packVaultProperties(properties)),
        sortedBy: const Value(SortedBy.user),
        sortState: const Value(SortState.sorted),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Папка по пути хранилища «Библиотека/Книги»; нет такой — null.
  Future<String?> folderAt(String path) async {
    final want = path.replaceAll(RegExp(r'^/+|/+$'), '').toLowerCase();
    if (want.isEmpty) return null;
    final tree = await _tree();
    final rows = await (_db.select(_db.folders)..where((t) => t.deletedAt.isNull())).get();
    for (final row in rows) {
      if (tree.path(row.id).map(vaultFileName).join('/').toLowerCase() == want) return row.id;
    }
    return null;
  }

  /// Новое имя: файл переедет под него при записи.
  Future<void> rename(String id, String title) =>
      (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(title: Value(title), updatedAt: Value(_clock())));

  /// Путь файла заметки от корня хранилища: из карты файлов, а пока файла нет — по папкам и заголовку.
  /// Путь, под которым заметка уже лежит файлом; не записана ещё — null.
  Future<String?> writtenPathOf(String itemId) async => (await (_db.select(_db.vaultFiles)..where((t) => t.itemId.equals(itemId))).getSingleOrNull())?.path;

  Future<String?> pathOf(String itemId) async {
    final known = await (_db.select(_db.vaultFiles)..where((t) => t.itemId.equals(itemId))).getSingleOrNull();
    if (known != null) return known.path;
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null) return null;
    return [...(await _folderNames(item.folderId)).map(vaultFileName), '${vaultFileName(item.title)}.${_extension(item.kind)}'].join('/');
  }

  /// Заметка по пути файла из холста: сперва карта файлов, потом папки и заголовок.
  Future<String?> itemAt(String path) async {
    final known = await (_db.select(_db.vaultFiles)..where((t) => t.path.equals(path))).getSingleOrNull();
    if (known != null) return known.itemId;
    final paths = await _computedPaths();
    return paths.entries.where((entry) => entry.value.toLowerCase() == path.toLowerCase()).firstOrNull?.key;
  }

  /// Заметки глазами базы: путь, теги, ссылки из текста, свойства шапки. Холсты, базы,
  /// корзина и скрытое закрытым (его строк в базе нет) — мимо.
  Future<List<BaseNote>> baseNotes() async {
    final items = await (_db.select(_db.items)..where((t) => t.deletedAt.isNull())).get();
    final known = {for (final row in await _db.select(_db.vaultFiles).get()) row.itemId: row.path};
    final computed = await _computedPaths();
    final tagNames = {for (final tag in await _db.select(_db.tags).get()) tag.id: tag.name};
    final tags = <String, List<String>>{};
    for (final row in await _db.select(_db.itemTags).get()) {
      if (tagNames[row.tagId] case final name?) tags.putIfAbsent(row.itemId, () => []).add(name);
    }
    final images = <String, String>{};
    for (final row in await (_db.select(_db.attachments)..orderBy([(t) => OrderingTerm.asc(t.position)])).get()) {
      if (showsAsImage(row.mime)) images.putIfAbsent(row.itemId, () => row.path);
    }
    return [
      for (final item in items)
        if (!isDocumentKind(item.kind))
          BaseNote(
            id: item.id,
            path: known[item.id] ?? computed[item.id] ?? '${vaultFileName(item.title)}.md',
            tags: tags[item.id] ?? const [],
            links: [for (final match in wikiLink.allMatches(item.body)) match[1]!.trim().split('/').last],
            properties: unpackVaultProperties(item.properties),
            created: item.createdAt,
            modified: item.updatedAt,
            title: item.title,
            image: images[item.id] ?? item.coverPath,
          ),
    ];
  }

  Future<Map<String, String>> _computedPaths() async {
    final tree = await _tree();
    final items = await (_db.select(_db.items)..where((t) => t.deletedAt.isNull())).get();
    return {
      for (final item in items)
        item.id: [...(item.folderId == null ? const <String>[] : tree.path(item.folderId!)).map(vaultFileName), '${vaultFileName(item.title)}.${_extension(item.kind)}'].join('/'),
    };
  }

  Future<FolderTree> _tree() async {
    final rows = await (_db.select(_db.folders)..where((t) => t.deletedAt.isNull())).get();
    return FolderTree([for (final row in rows) FolderNode(id: row.id, name: row.name, parentId: row.parentId)]);
  }

  Future<List<String>> _folderNames(String? folderId) async => folderId == null ? const [] : (await _tree()).path(folderId);
}

String _extension(ItemKind kind) => isDocumentKind(kind) ? documentExtension(kind) : 'md';
