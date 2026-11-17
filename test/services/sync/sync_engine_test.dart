import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_engine.dart';

import 'fakes.dart';

var _now = 1700000000000;
int _clock() => _now += 1000;

class Device {
  Device(this.remote, this.key, {int chunk = 64}) {
    engine = SyncEngine(vault: vault, remote: remote, state: state, key: key, chunk: chunk, loser: (path, text) => losers.add((path, text)));
  }

  final FakeRemote remote;
  final VaultKey key;
  final vault = MemoryVault(_clock);
  final state = MemoryState();
  final losers = <(String, String)>[];
  late final SyncEngine engine;

  Future<SyncReport> sync() => engine.sync();
}

void main() {
  late FakeRemote remote;
  late VaultKey key;
  setUp(() {
    remote = FakeRemote();
    key = VaultKey.generate();
  });

  test('правка уходит и приходит', () async {
    final a = Device(remote, key), b = Device(remote, key);
    a.vault.putText('Заметка.md', 'привет\n');
    a.vault.put('Вложения/фото.jpg', List.generate(300, (i) => i % 256));
    expect((await a.sync()).pushed, 2);
    expect((await b.sync()).pulled, 2);
    expect(b.vault.text('Заметка.md'), 'привет\n');
    expect(b.vault.files['Вложения/фото.jpg']!.$1, a.vault.files['Вложения/фото.jpg']!.$1);
    // повторный проход ничего не гоняет
    final again = await a.sync();
    expect(again.pushed + again.pulled, 0);
  });

  test('удаление уходит и приходит, переименование — удаление и новый файл', () async {
    final a = Device(remote, key), b = Device(remote, key);
    a.vault.putText('a.md', 'a\n');
    a.vault.putText('b.md', 'b\n');
    await a.sync();
    await b.sync();
    a.vault.files.remove('a.md');
    a.vault.files['c.md'] = a.vault.files.remove('b.md')!;
    await a.sync();
    await b.sync();
    expect(b.vault.files.keys.toSet(), {'c.md'});
    expect(b.vault.text('c.md'), 'b\n');
  });

  test('одну заметку правили на двух телефонах — обе правки в файле', () async {
    final a = Device(remote, key), b = Device(remote, key);
    a.vault.putText('n.md', 'один\nдва\nтри\n');
    await a.sync();
    await b.sync();
    a.vault.putText('n.md', 'ОДИН\nдва\nтри\n');
    b.vault.putText('n.md', 'один\nдва\nТРИ\n');
    await a.sync();
    await b.sync();
    await a.sync();
    expect(a.vault.text('n.md'), 'ОДИН\nдва\nТРИ\n');
    expect(b.vault.text('n.md'), 'ОДИН\nдва\nТРИ\n');
    expect(a.losers.isEmpty && b.losers.isEmpty, isTrue);
  });

  test('одну строку правили оба — свежая в файле, другая в истории', () async {
    final a = Device(remote, key), b = Device(remote, key);
    a.vault.putText('n.md', 'строка\n');
    await a.sync();
    await b.sync();
    a.vault.putText('n.md', 'строка A\n');
    b.vault.putText('n.md', 'строка B\n');
    await a.sync();
    await b.sync();
    await a.sync();
    expect(a.vault.text('n.md'), 'строка B\n');
    expect(b.vault.text('n.md'), 'строка B\n');
    expect(b.losers, [('n.md', 'строка A\n')]);
  });

  test('второе непустое хранилище при первом проходе ничего не удаляет', () async {
    final a = Device(remote, key), b = Device(remote, key);
    a.vault.putText('a.md', 'из A\n');
    a.vault.putText('общая.md', 'общая\nиз A\n');
    await a.sync();
    b.vault.putText('b.md', 'из B\n');
    b.vault.putText('общая.md', 'общая\nиз B\n');
    await b.sync();
    await a.sync();
    for (final d in [a, b]) {
      expect(d.vault.files.keys.toSet(), {'a.md', 'b.md', 'общая.md'});
      expect(d.vault.text('общая.md'), allOf(contains('из A'), contains('из B')));
    }
  });

  test('правка побеждает удаление с другого телефона', () async {
    final a = Device(remote, key), b = Device(remote, key);
    a.vault.putText('n.md', 'x\n');
    await a.sync();
    await b.sync();
    a.vault.files.remove('n.md');
    b.vault.putText('n.md', 'x\nправка\n');
    await a.sync();
    await b.sync();
    await a.sync();
    expect(a.vault.text('n.md'), 'x\nправка\n');
    expect(b.vault.text('n.md'), 'x\nправка\n');
  });

  test('пропала треть файлов — удаления не уходят', () async {
    final a = Device(remote, key), b = Device(remote, key);
    for (var i = 0; i < 100; i++) {
      a.vault.putText('n$i.md', '$i\n');
    }
    await a.sync();
    await b.sync();
    for (var i = 0; i < 50; i++) {
      a.vault.files.remove('n$i.md');
    }
    final report = await a.sync();
    expect(report.error, SyncError.massDelete);
    await b.sync();
    expect(b.vault.files.length, 100);
  });

  test('обход папки упал — удалений нет', () async {
    final a = Device(remote, key), b = Device(remote, key);
    a.vault.putText('n.md', 'x\n');
    await a.sync();
    await b.sync();
    a.vault.listFails = true;
    final report = await a.sync();
    expect(report.error, SyncError.vaultUnreadable);
    await b.sync();
    expect(b.vault.text('n.md'), 'x\n');
  });

  test('служебное не синхронизируется', () async {
    final a = Device(remote, key), b = Device(remote, key);
    a.vault.putText('.stowa/covers/1.jpg', 'обложка');
    a.vault.putText('.stowa/incoming/x.md', 'входящее');
    a.vault.putText('.stowa/tags.json', '{"tags": []}');
    a.vault.putText('.obsidian/workspace.json', '{}');
    await a.sync();
    await b.sync();
    expect(b.vault.files.keys.toSet(), {'.stowa/tags.json'});
  });

  test('обрыв на третьей части — докачка без повторной отправки готовых', () async {
    final a = Device(remote, key, chunk: 1000), b = Device(remote, key, chunk: 1000);
    a.vault.put('видео.mp4', List.generate(4500, (i) => (i * 7) % 256));
    var puts = 0;
    remote.failWhen = (call) => call == 'putBlob' && ++puts == 3;
    expect((await a.sync()).error, SyncError.network);
    expect(remote.putCount, 2);
    remote.failWhen = null;
    await a.sync();
    expect(remote.putCount, 5);
    await b.sync();
    expect(b.vault.files['видео.mp4']!.$1, a.vault.files['видео.mp4']!.$1);
  });

  test('имя в другой записи кириллицы — тот же файл', () async {
    final a = Device(remote, key), b = Device(remote, key);
    a.vault.putText('Учёба.md', 'x\n');
    await a.sync();
    b.vault.putText('Учёба.md'.replaceAll('ё', 'ё'), 'x\n');
    await b.sync();
    expect(b.vault.files.length, 1);
  });

  for (var seed = 1; seed <= 25; seed++) {
    test('симуляция $seed: три телефона, правки, удаления, обрывы и падения', () => _simulate(seed));
  }
}

Future<void> _simulate(int seed) async {
  final remote = FakeRemote();
  final key = VaultKey.generate();
  final random = Random(seed);
  final devices = [for (var i = 0; i < 3; i++) Device(remote, key, chunk: 50)];
  final tokens = <String, String>{}; // строка → файл
  final deletedFiles = <String>{};
  var token = 0;
  for (var step = 0; step < 300; step++) {
    final d = devices[random.nextInt(3)];
    final roll = random.nextInt(10);
    final names = d.vault.files.keys.where((p) => p.endsWith('.md')).toList();
    if (roll < 4) {
      // дописать строку в заметку
      final name = names.isNotEmpty && random.nextBool() ? names[random.nextInt(names.length)] : 'n${random.nextInt(8)}.md';
      final line = 't${token++}';
      tokens[line] = name;
      final at = random.nextBool();
      final old = d.vault.text(name) ?? '';
      d.vault.putText(name, at ? '$line\n$old' : '$old$line\n');
    } else if (roll < 5 && names.isNotEmpty) {
      final name = names[random.nextInt(names.length)];
      deletedFiles.add(name);
      d.vault.files.remove(name);
    } else if (roll < 6) {
      d.vault.put('b${random.nextInt(4)}.bin', List.generate(random.nextInt(200), (_) => random.nextInt(256)));
    } else {
      remote.failWhen = random.nextInt(3) == 0 ? (_) => random.nextInt(6) == 0 : null;
      await d.sync();
      remote.failWhen = null;
    }
  }
  remote.failWhen = null;
  for (var round = 0; round < 4; round++) {
    for (final d in devices) {
      final report = await d.sync();
      expect(report.error, isNull);
    }
  }
  final first = devices.first.vault.files;
  Future<String> explain(Set<String> paths) async {
    final lines = <String>['сервер: последний seq ${remote.lastSeq}'];
    for (final path in paths) {
      final id = key.fileId(path);
      lines.add('$path: сервер ${remote.describe(id)}');
      for (var i = 0; i < devices.length; i++) {
        final s = (await devices[i].state.files())[id];
        lines.add(
          '  телефон $i: файл ${devices[i].vault.files.containsKey(path)}, помнит ${s == null ? 'нет' : 'rev ${s.rev} hash ${s.hash.isEmpty ? 'пусто' : 'есть'} size ${s.size}'}, курсор ${await devices[i].state.cursor()}',
        );
      }
    }
    return lines.join('\n');
  }

  for (final d in devices.skip(1)) {
    final diff = d.vault.files.keys.toSet().difference(first.keys.toSet()).union(first.keys.toSet().difference(d.vault.files.keys.toSet()));
    expect(d.vault.files.keys.toSet(), first.keys.toSet(), reason: await explain(diff));
    for (final path in first.keys) {
      expect(d.vault.files[path]!.$1, first[path]!.$1, reason: path);
    }
  }
  final losers = [for (final d in devices) ...d.losers.map((l) => l.$2)].join('\n');
  final all = [for (final p in first.keys.where((p) => p.endsWith('.md'))) devices.first.vault.text(p)].join('\n');
  for (final e in tokens.entries) {
    if (deletedFiles.contains(e.value)) continue;
    expect(all.contains('${e.key}\n') || losers.contains(e.key), isTrue, reason: 'пропала строка ${e.key} из ${e.value}');
  }
  for (final path in first.keys) {
    expect(path.startsWith('n') || path.startsWith('b'), isTrue);
  }
}
