import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../db/database.dart';
import 'folders_repository.dart';
import 'rules_repository.dart';

/// Вид заметок, которым приложение само предлагает папку.
enum SuggestKind { screenshot, video, file, voice }

/// «12 ссылок с habr.com без папки — сделать папку?»: группа заметок без папки.
class FolderSuggestion {
  const FolderSuggestion({required this.key, required this.ids, this.host, this.name, this.kind});

  /// «site:habr.com» или «kind:screenshot» — по нему «Не надо» запоминается навсегда.
  final String key;
  final List<String> ids;
  final String? host;

  /// Имя сайта из превью («Хабр»); у вида имя даёт экран на языке человека.
  final String? name;
  final SuggestKind? kind;

  int get count => ids.length;
}

/// Что сделала «Сделать»: всё, что нужно «Отменить».
class AcceptedSuggestion {
  const AcceptedSuggestion({required this.folderId, required this.ruleId, required this.before});

  final String folderId;
  final String? ruleId;

  /// Как заметки были разложены до переноса.
  final Map<String, (SortedBy, SortState)> before;
}

/// Меньше этого — не повод заводить папку.
const suggestThreshold = 8;

/// Папку предлагают сами: от [suggestThreshold] заметок без папки с одного сайта
/// или одного вида. Одна группа за раз — самая большая.
class FolderSuggestions {
  FolderSuggestions(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Самая большая группа, которую человек ещё не отклонил, или null.
  Future<FolderSuggestion?> find({required Set<String> dismissed}) async {
    final loose = await (_db.select(_db.items)..where((t) => t.folderId.isNull() & t.deletedAt.isNull())).get();
    final screenshots = {
      for (final fact in await (_db.select(_db.facts)..where((t) => t.kind.equals(FactKind.screenshot.name))).get()) fact.itemId,
    };
    final groups = <String, FolderSuggestion>{};
    void add(String key, String id, {String? host, String? name, SuggestKind? kind}) {
      final group = groups[key];
      groups[key] = FolderSuggestion(key: key, ids: [...?group?.ids, id], host: host, name: group?.name ?? name, kind: kind);
    }

    for (final item in loose) {
      final host = Uri.tryParse(item.url ?? '')?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
      if (host != null && host.isNotEmpty) {
        add('site:$host', item.id, host: host, name: item.previewSite);
      } else if (screenshots.contains(item.id)) {
        add('kind:screenshot', item.id, kind: SuggestKind.screenshot);
      } else if (switch (item.kind) {
        ItemKind.video => SuggestKind.video,
        ItemKind.file => SuggestKind.file,
        ItemKind.voice => SuggestKind.voice,
        _ => null,
      } case final kind?) {
        add('kind:${kind.name}', item.id, kind: kind);
      }
    }
    final fitting = [for (final group in groups.values) if (group.count >= suggestThreshold && !dismissed.contains(group.key)) group];
    if (fitting.isEmpty) return null;
    // при равенстве сайт главнее: у него будет и правило на будущее
    fitting.sort((a, b) => b.count != a.count ? b.count.compareTo(a.count) : (a.host == null ? 1 : 0) - (b.host == null ? 1 : 0));
    return fitting.first;
  }

  /// Папка с именем [name], заметки группы в ней; для сайта — правило «сайт → папка».
  Future<AcceptedSuggestion> accept(FolderSuggestion suggestion, {required String name}) => _db.transaction(() async {
    final folder = await FoldersRepository(_db).create(name);
    final items = await (_db.select(_db.items)..where((t) => t.id.isIn(suggestion.ids))).get();
    await (_db.update(_db.items)..where((t) => t.id.isIn(suggestion.ids))).write(
      ItemsCompanion(folderId: Value(folder.id), sortedBy: const Value(SortedBy.rule), sortState: const Value(SortState.sorted), updatedAt: Value(_clock())),
    );
    final host = suggestion.host;
    final ruleId = host == null
        ? null
        : await RulesRepository(_db).save(condition: RuleConditionKind.domain, conditionValue: host, action: RuleActionKind.toFolder, actionValue: folder.id);
    return AcceptedSuggestion(folderId: folder.id, ruleId: ruleId, before: {for (final item in items) item.id: (item.sortedBy, item.sortState)});
  });

  /// «Отменить»: заметки снова без папки и разложены как были, правила и папки нет.
  Future<void> undo(AcceptedSuggestion done) => _db.transaction(() async {
    for (final MapEntry(key: id, value: (sortedBy, sortState)) in done.before.entries) {
      await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
        ItemsCompanion(folderId: const Value(null), sortedBy: Value(sortedBy), sortState: Value(sortState), updatedAt: Value(_clock())),
      );
    }
    if (done.ruleId case final ruleId?) await RulesRepository(_db).remove(ruleId);
    await FoldersRepository(_db).delete(done.folderId, _clock());
  });
}
