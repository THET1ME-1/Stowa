import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../services/facts/facts_pipeline.dart' show refreshFactsText;
import '../db/database.dart';

/// Цитаты статьи: выделенный кусок текста и пометка к нему. Файл заметки
/// обновят триггеры очереди хранилища, поиск — [refreshFactsText] здесь же.
class HighlightsRepository {
  HighlightsRepository(this._db, {required DateTime Function() clock}) : _clock = clock;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Цитаты заметки по порядку в тексте статьи.
  Stream<List<Highlight>> watch(String itemId) => (_db.select(_db.highlights)
        ..where((t) => t.itemId.equals(itemId))
        ..orderBy([(t) => OrderingTerm.asc(t.position), (t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  /// [position] — где цитата в тексте статьи, знаков от начала.
  Future<String> add(String itemId, String quote, {required int position, String? note}) async {
    final id = const Uuid().v4();
    await _db.transaction(() async {
      await _db.into(_db.highlights).insert(
        HighlightsCompanion.insert(id: id, itemId: itemId, quote: quote.trim(), note: Value(_note(note)), position: Value(position), createdAt: _clock()),
      );
      await refreshFactsText(_db, itemId);
    });
    return id;
  }

  Future<void> setNote(String id, String? note) => _db.transaction(() async {
    final row = await (_db.select(_db.highlights)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.highlights)..where((t) => t.id.equals(id))).write(HighlightsCompanion(note: Value(_note(note))));
    await refreshFactsText(_db, row.itemId);
  });

  /// Убрать цитату. Возвращает её саму — для «Отменить».
  Future<Highlight?> remove(String id) => _db.transaction(() async {
    final row = await (_db.select(_db.highlights)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    await (_db.delete(_db.highlights)..where((t) => t.id.equals(id))).go();
    await refreshFactsText(_db, row.itemId);
    return row;
  });

  Future<void> restore(Highlight row) => _db.transaction(() async {
    await _db.into(_db.highlights).insertOnConflictUpdate(row);
    await refreshFactsText(_db, row.itemId);
  });

  String? _note(String? note) {
    final text = note?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
