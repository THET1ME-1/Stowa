import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/db/database.dart';
import '../../domain/document_text.dart';
import '../../domain/models.dart';
import 'extractor.dart';
import 'extractors.dart';

/// Факты этих видов ищутся вместе с вещью. Дата и место съёмки — для фильтров и карты.
const searchableFacts = {
  FactKind.price,
  FactKind.phone,
  FactKind.email,
  FactKind.link,
  FactKind.fileText,
  FactKind.author,
  FactKind.site,
  FactKind.description,
  FactKind.camera,
  FactKind.pageType,
  FactKind.ingredient,
  FactKind.shop,
  FactKind.venue,
  FactKind.address,
  FactKind.year,
  FactKind.chapter,
  FactKind.hashtag,
  FactKind.subtitle,
};

/// За один проход разбирается не больше: остальное — в следующий, экран не ждёт.
const _batch = 50;
const _sweepLimit = 1000;

/// Конвейер извлекателей: каждая вещь проходит все правила, факты ложатся в базу и в поиск.
///
/// Вещь разбирается заново, когда прогона не было, версия извлекателя выросла
/// или сменилось то, от чего зависят его факты. Местные правила идут сразу после
/// сохранения, сетевые — только при сети и с отсрочкой после неудачи.
class FactsPipeline {
  FactsPipeline(
    this._db, {
    required Directory filesRoot,
    required DateTime Function() clock,
    List<Extractor>? extractors,
    Future<bool> Function()? online,
  }) : _filesRoot = filesRoot, // ignore: prefer_initializing_formals
       _clock = clock, // ignore: prefer_initializing_formals
       _extractors = extractors ?? defaultExtractors(),
       _online = online ?? (() async => true);

  final AppDatabase _db;
  final Directory _filesRoot;
  final DateTime Function() _clock;
  final List<Extractor> _extractors;
  final Future<bool> Function() _online;
  Future<void>? _sweeping;

  /// Разобрать одну вещь местными правилами: после сохранения, правки, когда легли файлы.
  /// С [network] — и сетевыми, если сеть есть: превью страницы только что пришло.
  Future<void> runItem(String itemId, {bool network = false}) async {
    final withNetwork = network && await _online();
    for (final extractor in _extractors.where((one) => withNetwork || !one.needsNetwork)) {
      for (final stale in await _stale(extractor, itemId: itemId, limit: 1)) {
        await _run(extractor, stale.id, stale.stamp);
      }
    }
  }

  /// Разобрать всё, что устарело, местными правилами. Идущий проход не дублируется.
  Future<void> sweep() => _sweeping ??= _sweepLocal().whenComplete(() => _sweeping = null);

  Future<void> _sweepLocal() async {
    for (final extractor in _extractors.where((one) => !one.needsNetwork)) {
      var done = 0;
      while (done < _sweepLimit) {
        final stale = await _stale(extractor, limit: _batch);
        if (stale.isEmpty) break;
        for (final one in stale) {
          await _run(extractor, one.id, one.stamp);
        }
        done += stale.length;
      }
    }
  }

  /// Сетевые правила: только при сети, неудачные ждут свою отсрочку.
  Future<void> sweepNetwork() async {
    final network = _extractors.where((one) => one.needsNetwork).toList();
    if (network.isEmpty || !await _online()) return;
    for (final extractor in network) {
      for (final one in await _stale(extractor, limit: _batch)) {
        await _run(extractor, one.id, one.stamp);
      }
    }
  }

  // вещи, которые правило должно разобрать: прогона нет, версия старая или отпечаток сменился
  Future<List<({String id, String? stamp})>> _stale(Extractor extractor, {String? itemId, required int limit}) async {
    final rows = await _db
        .customSelect(
          'SELECT items.id AS id, (${extractor.stampSql}) AS stamp FROM items '
          'LEFT JOIN extractor_runs AS runs ON runs.item_id = items.id AND runs.extractor = ? '
          'WHERE items.deleted_at IS NULL AND (${extractor.appliesSql}) '
          'AND (runs.item_id IS NULL OR runs.version <> ? OR runs.item_stamp IS NOT (${extractor.stampSql})) '
          'AND (runs.next_try IS NULL OR runs.next_try <= ? OR runs.version <> ?) '
          '${itemId == null ? '' : 'AND items.id = ? '}'
          'ORDER BY items.created_at DESC LIMIT ?',
          variables: [
            Variable.withString(extractor.name),
            Variable.withInt(extractor.version),
            Variable.withInt(_clock().millisecondsSinceEpoch),
            Variable.withInt(extractor.version),
            if (itemId != null) Variable.withString(itemId),
            Variable.withInt(limit),
          ],
          readsFrom: {_db.items, _db.extractorRuns, _db.attachments},
        )
        .get();
    return [for (final row in rows) (id: row.read<String>('id'), stamp: row.readNullable<String>('stamp'))];
  }

  Future<void> _run(Extractor extractor, String itemId, String? stamp) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null) return;
    final files = await (_db.select(_db.attachments)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    final previous = await (_db.select(_db.extractorRuns)..where((t) => t.itemId.equals(itemId) & t.extractor.equals(extractor.name))).getSingleOrNull();
    // упавший прежде прогон фактов не дал: для последствий это тоже первый раз
    final firstRun = previous == null || previous.error != null;
    final List<FactDraft> drafts;
    try {
      drafts = await extractor.extract(ExtractInput(item: item, files: files, filesRoot: _filesRoot));
    } catch (error) {
      await _failed(extractor, itemId, stamp, error);
      return;
    }
    final saved = await _db.transaction(() async {
      // вещь стёрли, пока правило работало: фактам негде жить
      final alive = await (_db.select(_db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
      if (alive == null) return false;
      await (_db.delete(_db.facts)..where((t) => t.itemId.equals(itemId) & t.extractor.equals(extractor.name))).go();
      for (final (position, draft) in drafts.indexed) {
        await _db
            .into(_db.facts)
            .insert(
              FactsCompanion.insert(
                id: const Uuid().v4(),
                itemId: itemId,
                extractor: extractor.name,
                kind: draft.kind,
                value: draft.value,
                detail: Value(draft.detail),
                number: Value(draft.number),
                at: Value(draft.at),
                position: Value(position),
              ),
            );
      }
      await _db.into(_db.extractorRuns).insertOnConflictUpdate(
        ExtractorRunsCompanion.insert(itemId: itemId, extractor: extractor.name, version: extractor.version, itemStamp: Value(stamp)),
      );
      await _refreshText(itemId);
      return true;
    });
    if (saved) await extractor.after(_db, item, drafts, firstRun: firstRun, now: _clock()).catchError((_) {});
  }

  // местное правило упало — не повторять, пока вещь не изменится; сетевое — повторить позже
  Future<void> _failed(Extractor extractor, String itemId, String? stamp, Object error) async {
    final previous = await (_db.select(_db.extractorRuns)..where((t) => t.itemId.equals(itemId) & t.extractor.equals(extractor.name))).getSingleOrNull();
    final attempts = (previous?.attempts ?? 0) + 1;
    final wait = Duration(minutes: min(5 * pow(2, attempts - 1).toInt(), 24 * 60));
    await _db.into(_db.extractorRuns).insertOnConflictUpdate(
      ExtractorRunsCompanion.insert(
        itemId: itemId,
        extractor: extractor.name,
        version: extractor.version,
        itemStamp: Value(extractor.needsNetwork ? null : stamp),
        attempts: Value(attempts),
        nextTry: Value(extractor.needsNetwork ? _clock().add(wait).millisecondsSinceEpoch : null),
        error: Value('$error'),
      ),
    );
  }

  Future<void> _refreshText(String itemId) => refreshFactsText(_db, itemId);
}

/// Текст фактов одной строкой для поиска; правка вещи от этого не считается.
/// Его же пересчитывает читатель хранилища, когда собирает базу из папки.
Future<void> refreshFactsText(AppDatabase db, String itemId) async {
  final facts = await (db.select(db.facts)
        ..where((t) => t.itemId.equals(itemId) & t.kind.isIn([for (final kind in searchableFacts) kind.name]))
        ..orderBy([(t) => OrderingTerm.asc(t.extractor), (t) => OrderingTerm.asc(t.position)]))
      .get();
  var text = facts.map((fact) => fact.value).join('\n');
  if (text.length > documentTextLimit) text = text.substring(0, documentTextLimit);
  await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(ItemsCompanion(factsText: Value(text)));
}
