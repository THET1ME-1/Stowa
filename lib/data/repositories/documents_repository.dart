import 'dart:async';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/folder_tree.dart';
import '../../domain/item_kind.dart' show showsAsImage;
import '../../domain/json_canvas.dart';
import '../../domain/models.dart';
import '../../domain/note_links.dart' show wikiLink;
import '../../domain/obsidian_base.dart';
import '../../domain/vault_note.dart' show packVaultProperties, unpackVaultProperties, vaultFileName;
import '../db/database.dart';
import '../recompute.dart';

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

  /// На что смотрит карточка холста, положенная за заметку. Заметка из одной картинки без
  /// своего текста — сам файл картинки, как кладёт на холст Obsidian: картинку видно и там,
  /// и здесь. Остальные — файл заметки. null — файл ещё не лёг на место (картинка во
  /// входящих, заметка не записана).
  Future<String?> placedPathOf(String itemId) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null) return null;
    final files = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(itemId))).get();
    // вставку картинки `![[…]]` в заметку дописывает писатель: это не текст человека
    final ownText = item.body.replaceAll(_embed, '').trim();
    if (ownText.isEmpty && files.length == 1 && showsAsImage(files.single.mime)) {
      final path = files.single.path;
      return path.startsWith('.stowa/') || p.isAbsolute(path) ? null : path;
    }
    return writtenPathOf(itemId);
  }

  static final _embed = RegExp(r'!\[\[[^\]\n]*\]\]');

  /// Карточка [nodeId] холста [canvasId] положена за заметку [itemId] раньше, чем её файл
  /// лёг на место (картинку переносит из входящих писатель, заметку пишет он же). Как ляжет —
  /// карточка в файле холста переходит на него. Живёт отдельно от экрана: холст закрыли
  /// сразу после вставки — карточка всё равно встанет верно. Карточку убрали, холст или
  /// заметку удалили — слежка снимается.
  void followPlaced(String canvasId, String nodeId, String itemId) {
    late final StreamSubscription<String?> watch;
    var done = false;
    watch = recomputeOn(_db.changesOf([_db.attachments, _db.vaultFiles, _db.items]), () async {
      if (done) return null;
      final alive = await (_db.select(_db.items)..where((t) => t.id.equals(itemId) & t.deletedAt.isNull())).getSingleOrNull();
      final canvas = await (_db.select(_db.items)..where((t) => t.id.equals(canvasId) & t.deletedAt.isNull())).getSingleOrNull();
      final doc = canvas?.document == null ? null : CanvasDoc.parse(canvas!.document!);
      final node = doc?.node(nodeId);
      if (alive == null || node == null) {
        done = true;
        return null;
      }
      final path = await placedPathOf(itemId);
      if (path == null) return null;
      done = true;
      if (node.file != path) await save(canvasId, doc!.updateNode(nodeId, {'file': path}));
      return path;
    }).listen((_) {
      if (done) watch.cancel();
    });
  }

  /// Заметка по пути файла из холста: сперва карта файлов, потом вложения (карточка-картинка),
  /// потом папки и заголовок.
  Future<String?> itemAt(String path) async {
    final known = await (_db.select(_db.vaultFiles)..where((t) => t.path.equals(path))).getSingleOrNull();
    if (known != null) return known.itemId;
    final attached = await (_db.select(_db.attachments)..where((t) => t.path.equals(path))..limit(1)).getSingleOrNull();
    if (attached != null) return attached.itemId;
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
