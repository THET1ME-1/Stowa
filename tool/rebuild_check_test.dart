// Пересборка указателя по папке, как после восстановления копии без базы: сколько заметок
// получилось, сколько из них — файлы без своей заметки, и сколько заняла каждая часть.
//
//   VAULT_COPY=~/.cache/stowa-restore-check/vault TMPDIR=~/.cache/flutter-tmp flutter test tool/rebuild_check_test.dart
//
// Папка читается на месте: заметкам без id пересборка его допишет. Печатаются только числа
// и до десяти путей: содержимое заметок не выводится.
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/services/vault/vault_reader.dart';

void main() {
  final source = Platform.environment['VAULT_COPY'];

  test('пересборка указателя по копии', () async {
    final root = Directory(source!);
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final reader = VaultReader(db, root: root, clock: DateTime.now);
    final watch = Stopwatch()..start();
    var lastDone = -1;
    Duration? notesRead;
    await reader.rebuild(
      progress: (done, total) {
        if (done == total && total > 0 && done != lastDone) notesRead = watch.elapsed;
        lastDone = done;
      },
    );
    final all = watch.elapsed;

    final kinds = await db.customSelect('SELECT kind, count(*) AS n FROM items WHERE deleted_at IS NULL GROUP BY kind ORDER BY n DESC').get();
    // заметка-файл: её вложение — сам файл из карты файлов
    final loose = await db
        .customSelect(
          'SELECT attachments.path AS path FROM items JOIN attachments ON attachments.item_id = items.id JOIN vault_files ON vault_files.item_id = items.id AND vault_files.path = attachments.path WHERE items.deleted_at IS NULL',
        )
        .get();
    final paths = [for (final row in loose) row.read<String>('path')];
    final byTop = <String, int>{};
    for (final path in paths) {
      final top = path.contains('/') ? path.split('/').first : '(корень)';
      byTop[top] = (byTop[top] ?? 0) + 1;
    }
    // упомянута ли заметка-файл именем в тексте какой-нибудь заметки
    var mentioned = 0;
    final examples = <String>[];
    for (final path in paths) {
      final name = p.posix.basename(path);
      final hit = await db.customSelect('SELECT 1 FROM items WHERE instr(body, ?1) > 0 OR instr(coalesce(document, \'\'), ?1) > 0 LIMIT 1', variables: [Variable.withString(name)]).getSingleOrNull();
      if (hit != null) {
        mentioned++;
        if (examples.length < 10) examples.add(path);
      }
    }
    final attachments = await db.customSelect('SELECT count(*) AS n FROM attachments').getSingle();

    // ignore: avoid_print
    print('заметки прочитаны за ${notesRead?.inSeconds} с, всё — за ${all.inSeconds} с');
    // ignore: avoid_print
    print('по видам: ${[for (final row in kinds) '${row.read<String>('kind')} ${row.read<int>('n')}'].join(', ')}');
    // ignore: avoid_print
    print('вложений ${attachments.read<int>('n')}, заметок-файлов ${paths.length}, из них имя есть в тексте заметок: $mentioned');
    // ignore: avoid_print
    print('заметки-файлы по папкам: ${(byTop.entries.toList()..sort((a, b) => b.value - a.value)).take(8).map((e) => '${e.key} ${e.value}').join(', ')}');
    for (final path in examples) {
      // ignore: avoid_print
      print('  упомянута, но стала заметкой: $path');
    }
  }, skip: source == null ? 'нужна VAULT_COPY' : false, timeout: const Timeout(Duration(minutes: 30)));
}
