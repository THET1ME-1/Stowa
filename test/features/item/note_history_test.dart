import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/features/item/note_history.dart';
import 'package:stowa/services/sync/cloud_history.dart';
import 'package:stowa/services/sync/sync_crypto.dart';

import '../../services/sync/fakes.dart';

void main() {
  NoteVersion snapshot(String body, DateTime at) => NoteVersion(id: body, itemId: 'a', title: 'T', body: body, savedAt: at);
  HistoryEntry cloud(String body, DateTime at) => HistoryEntry(title: 'T', body: body, at: at);
  final t = DateTime(2026, 11, 23, 12);

  group('слияние облака и снимков', () {
    test('снимок с текстом из облака не повторяется, свой — остаётся', () {
      final rows = mergeHistory(
        title: 'T',
        body: 'сейчас',
        local: [snapshot('было', t.subtract(const Duration(hours: 2))), snapshot('без сети', t.subtract(const Duration(hours: 5)))],
        cloud: [cloud('было', t.subtract(const Duration(hours: 2, minutes: 1)))],
      );
      expect([for (final row in rows) (row.body, row.localOnly)], [('было', false), ('без сети', true)]);
    });

    test('подряд одинаковый текст — одна строка, самая ранняя; верх с нынешним — это «Сейчас»', () {
      final rows = mergeHistory(
        title: 'T',
        body: 'сейчас',
        local: const [],
        cloud: [
          cloud('сейчас', t),
          cloud('б', t.subtract(const Duration(hours: 1))),
          cloud('б', t.subtract(const Duration(hours: 2))),
          cloud('а', t.subtract(const Duration(hours: 3))),
        ],
      );
      expect([for (final row in rows) row.body], ['б', 'а']);
      expect(rows.first.at, t.subtract(const Duration(hours: 2)));
    });

    test('новые первыми по времени, снимки вперемешку с облаком', () {
      final rows = mergeHistory(
        title: 'T',
        body: 'сейчас',
        local: [snapshot('л', t.subtract(const Duration(hours: 2)))],
        cloud: [cloud('о1', t.subtract(const Duration(hours: 1))), cloud('о3', t.subtract(const Duration(hours: 3)))],
      );
      expect([for (final row in rows) row.body], ['о1', 'л', 'о3']);
    });
  });

  test('большая заметка: тексты грузятся до бюджета, дальше — «Показать раньше»', () async {
    final remote = FakeRemote();
    final key = VaultKey.generate();
    const path = 'Большая.md';
    final big = 'строка\n' * (64 * 1024);
    for (var i = 0; i < 6; i++) {
      final data = utf8.encode('---\nid: a\n---\nверсия $i\n$big');
      final box = await key.sealChunk(data);
      await remote.putBlob(sha256Hex(box), box);
      final file = key.fileId(path);
      final current = await remote.file(file);
      // по часу между правками: каждая — свой сеанс
      final at = DateTime(2026, 11, 23, i);
      remote.now = () => at.toUtc();
      await remote.commit(
        file,
        baseRev: current?.rev ?? 0,
        meta: await key.sealMeta(FileMeta(path: path, mtime: at.millisecondsSinceEpoch, size: data.length, hash: sha256Hex(data))),
        blobs: [sha256Hex(box)],
        size: data.length,
      );
    }
    var fetched = 0;
    remote.failWhen = (call) {
      if (call == 'getBlob') fetched++;
      return false;
    };
    final history = CloudHistory(remote: remote, key: key);
    // версия весит ~832 КБ (кириллица — два байта на букву): бюджет — на две с запасом
    final first = await loadCloudNoteHistory(history, path, budget: 1720 * 1024);
    expect(first.access, CloudAccess.on);
    expect(first.entries.length, 2);
    expect(first.more, true);
    expect(fetched, 2);
    // бюджет вдвое — уже открытые берутся из памяти
    final second = await loadCloudNoteHistory(history, path, budget: 3440 * 1024);
    expect(second.entries.length, 4);
    expect(fetched, 4);
    expect(second.entries.first.body, startsWith('версия 5'));
  });
}
