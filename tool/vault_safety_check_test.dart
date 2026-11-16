// Проверка безопасности хранилища на копии настоящей папки Obsidian: Stowa не должна
// переносить, переименовывать и менять чужие файлы ни при чтении, ни при правке заметок.
//
//   VAULT_COPY=~/Projects/College TMPDIR=~/.cache/flutter-tmp flutter test tool/vault_safety_check_test.dart
//
// Папка копируется во временную, сама папка не трогается. Печатаются только числа и до
// десяти путей с изменениями: содержимое заметок не выводится.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_writer.dart';

void main() {
  final source = Platform.environment['VAULT_COPY'];

  // у заметки не считается строка «id: …» в шапке: по ней Stowa узнаёт свою заметку (так с 06.11)
  final idLine = RegExp(r'^id: [0-9a-f-]{36}\n', multiLine: true);
  // строка, которую дописывает шаг правки; без неё заметка должна совпасть с исходной
  const marker = '\nпроверка';
  var withoutMarker = false;
  List<int> comparable(File file) {
    final bytes = file.readAsBytesSync();
    if (!file.path.endsWith('.md')) return bytes;
    // конец файла без перевода строки — тоже не правка: запись всегда ставит один «\n»
    var text = utf8.decode(bytes, allowMalformed: true).replaceFirst(idLine, '');
    if (withoutMarker) {
      // правленую заметку Stowa подписывает своими свойствами (вид, даты, кто разложил) — так с
      // 06.11; сравнивается всё остальное: текст, чужие свойства, вставки
      text = text.replaceFirst(marker, '').replaceAll(RegExp(r'^(kind|created|updated|sorted_by): .*\n', multiLine: true), '');
    }
    text = text.replaceFirst(RegExp(r'^---\n---\n'), '');
    return utf8.encode(text.trimRight());
  }

  // путь от корня → md5; служебное Stowa и git не считаются
  Map<String, String> snapshot(Directory root) => {
    for (final file in root.listSync(recursive: true, followLinks: false).whereType<File>())
      if (!p.relative(file.path, from: root.path).startsWith('.stowa') && !p.relative(file.path, from: root.path).startsWith('.git/'))
        p.relative(file.path, from: root.path): md5.convert(comparable(file)).toString(),
  };

  void report(String step, Map<String, String> before, Map<String, String> after, {bool notesMayChange = false}) {
    final gone = [for (final path in before.keys) if (!after.containsKey(path)) path];
    final added = [for (final path in after.keys) if (!before.containsKey(path)) path];
    final changed = [for (final MapEntry(:key, :value) in before.entries) if (after[key] case final now? when now != value) key];
    final changedFiles = [for (final path in changed) if (!path.endsWith('.md')) path];
    // ignore: avoid_print
    print('$step: всего ${before.length}, пропало ${gone.length}, добавлено ${added.length}, изменено ${changed.length} (не заметок ${changedFiles.length})');
    for (final path in [...gone.take(10), ...added.take(10), ...changedFiles.take(10)]) {
      // ignore: avoid_print
      print('  $path');
    }
    expect(gone, isEmpty, reason: '$step: файлы пропали или переехали');
    expect(added, isEmpty, reason: '$step: появились новые файлы');
    expect(changedFiles, isEmpty, reason: '$step: изменились картинки или документы');
    if (!notesMayChange) expect(changed, isEmpty, reason: '$step: чтение переписало заметки');
  }

  test('копия хранилища: чтение и правка ничего не переносят', () async {
    final from = Directory(source!.replaceFirst('~', Platform.environment['HOME']!));
    final work = Directory.systemTemp.createTempSync('stowa_safety');
    final root = Directory(p.join(work.path, 'vault'));
    final copy = await Process.run('cp', ['-a', from.path, root.path]);
    expect(copy.exitCode, 0, reason: '${copy.stderr}');
    final db = AppDatabase.memory();
    addTearDown(() async {
      await db.close();
      // KEEP=1 — оставить копию, чтобы посмотреть разницу руками
      if (Platform.environment['KEEP'] == null) work.deleteSync(recursive: true);
    });
    // ignore: avoid_print
    print('копия: ${root.path}');
    final now = DateTime.now();
    final reader = VaultReader(db, root: root, clock: () => now);
    final writer = VaultWriter(db, root: root, clock: () => now, attachmentsDefault: () => 'Вложения');

    // 1. открыли папку: сверка и запись очереди
    final start = snapshot(root);
    await reader.reconcile();
    while (await writer.drain() > 0) {}
    final items = await db.select(db.items).get();
    // ignore: avoid_print
    print('заметок ${items.length}, вложений ${(await db.select(db.attachments).get()).length}');
    report('чтение', start, snapshot(root));

    // 2. поправили каждую заметку с текстом: дописали строку
    final opened = snapshot(root);
    // тот же снимок с той же чисткой своих строк, что и после правки
    withoutMarker = true;
    final openedPlain = snapshot(root);
    withoutMarker = false;
    final notes =[for (final item in items) if (item.kind == ItemKind.note && item.deletedAt == null && item.body.trim().isNotEmpty) item];
    for (final item in notes) {
      await (db.update(db.items)..where((t) => t.id.equals(item.id))).write(ItemsCompanion(body: Value('${item.body}\nпроверка'), updatedAt: Value(now)));
    }
    while (await writer.drain() > 0) {}
    // ignore: avoid_print
    print('поправлено заметок ${notes.length}');
    report('правка', opened, snapshot(root), notesMayChange: true);
    // без дописанной строки каждая заметка — как была: ни вставок, ни переписанной шапки
    withoutMarker = true;
    report('правка без своей строки', openedPlain, snapshot(root));
    withoutMarker = false;

    // 3. ещё одна сверка после правки — без новых заметок и переездов
    final edited = snapshot(root);
    await reader.reconcile();
    while (await writer.drain() > 0) {}
    report('повторная сверка', edited, snapshot(root));
    expect((await db.select(db.items).get()).length, items.length);

    // 4. переименовали в Stowa заметку, на которую ссылаются чаще всего: старое имя не
    // остаётся ни в одной ссылке, переименован ровно один файл
    final files = await db.select(db.vaultFiles).get();
    final stems = {for (final row in files) if (row.path.endsWith('.md')) p.posix.basenameWithoutExtension(row.path): row};
    final linked = <String, int>{};
    for (final item in await db.select(db.items).get()) {
      for (final match in RegExp(r'\[\[([^\]|#\n]+)').allMatches(item.body)) {
        final target = match.group(1)!.split('/').last.replaceFirst(RegExp(r'\.md$'), '');
        if (stems.containsKey(target)) linked[target] = (linked[target] ?? 0) + 1;
      }
    }
    final busiest = (linked.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
    final row = stems[busiest.key]!;
    final before = snapshot(root);
    await (db.update(db.items)..where((t) => t.id.equals(row.itemId))).write(ItemsCompanion(title: Value('${busiest.key} (новое)')));
    while (await writer.drain() > 0) {}
    final after = snapshot(root);
    final gone = [for (final path in before.keys) if (!after.containsKey(path)) path];
    final added = [for (final path in after.keys) if (!before.containsKey(path)) path];
    final changed = [for (final MapEntry(:key, :value) in before.entries) if (after[key] case final now? when now != value) key];
    // ignore: avoid_print
    print('переименование: ссылок ${busiest.value}, пропало ${gone.length}, добавлено ${added.length}, изменено заметок ${changed.length}');
    expect(gone, [row.path]);
    expect(added, hasLength(1));
    final stale = <String>[];
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.md') && !file.path.endsWith('.canvas')) continue;
      final text = file.readAsStringSync();
      final left = RegExp('\\[\\[([^\\]|#\\n]*/)?${RegExp.escape(busiest.key)}(\\.md)?[\\]|#]').hasMatch(text);
      if (left) stale.add(p.relative(file.path, from: root.path));
    }
    expect(stale, isEmpty, reason: 'старое имя осталось в ссылках');
  }, skip: source == null ? 'нужна VAULT_COPY' : false, timeout: const Timeout(Duration(minutes: 20)));
}
