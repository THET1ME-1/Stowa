import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/services/privacy/seal_crypto.dart';
import 'package:stowa/services/privacy/sealed_store.dart';

void main() {
  const fast = KdfSettings(memoryKib: 256, passes: 1);
  late Directory root;
  late Directory vault;
  late Directory open;
  late SealKeys keys;
  late SealedStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sealed_store');
    vault = Directory(p.join(root.path, 'vault'))..createSync();
    open = Directory(p.join(root.path, 'open'))..createSync();
    keys = (await createLock('123456', kdf: fast)).$2;
    store = SealedStore(vault);
  });
  tearDown(() => root.delete(recursive: true));

  void put(Directory dir, String relative, String text, {DateTime? at}) {
    final file = File(p.join(dir.path, relative))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
    if (at != null) file.setLastModifiedSync(at);
  }

  Map<String, String> contents(Directory dir) => {
    for (final file in dir.listSync(recursive: true).whereType<File>()) p.relative(file.path, from: dir.path): file.readAsStringSync(),
  };

  List<String> sealedNames() => [for (final file in Directory(p.join(vault.path, '.stowa', 'sealed')).listSync().whereType<File>()) p.basename(file.path)]..sort();

  test('запечатанное лежит случайными именами без открытого текста и открывается тем же', () async {
    put(open, 'rows.json', '{"items": "План побега"}');
    put(open, 'files/1/фото.jpg', 'картинка', at: DateTime(2026, 5, 3, 10));
    await store.seal(open, keys.publicKey);

    for (final file in Directory(p.join(vault.path, '.stowa')).listSync(recursive: true).whereType<File>()) {
      final bytes = file.readAsBytesSync();
      expect(String.fromCharCodes(bytes).contains('План'), isFalse);
      expect(file.path.contains('фото'), isFalse);
    }

    final again = Directory(p.join(root.path, 'again'));
    final manifest = await store.unseal(again, keys);
    expect(manifest, isNotNull);
    expect(contents(again), contents(open));
    expect(File(p.join(again.path, 'files/1/фото.jpg')).lastModifiedSync(), DateTime(2026, 5, 3, 10));
  });

  test('повторное запечатывание: неизменённое — тем же блобом, изменённое — новым, стёртое уходит', () async {
    put(open, 'keep.txt', 'тот же', at: DateTime(2026, 1, 1));
    put(open, 'edit.txt', 'было', at: DateTime(2026, 1, 1));
    put(open, 'gone.txt', 'уйдёт', at: DateTime(2026, 1, 1));
    final first = await store.seal(open, keys.publicKey);

    put(open, 'edit.txt', 'стало', at: DateTime(2026, 2, 1));
    File(p.join(open.path, 'gone.txt')).deleteSync();
    final second = await store.seal(open, keys.publicKey, previous: first);

    expect(second.generation, first.generation + 1);
    expect(second.files['keep.txt']!.blob, first.files['keep.txt']!.blob);
    expect(second.files['edit.txt']!.blob, isNot(first.files['edit.txt']!.blob));
    expect(second.files.containsKey('gone.txt'), isFalse);
    // один список и по блобу на файл: старое подчищено
    expect(sealedNames().length, 3);

    final again = Directory(p.join(root.path, 'again'));
    await store.unseal(again, keys);
    expect(contents(again), {'keep.txt': 'тот же', 'edit.txt': 'стало'});
  });

  test('запечатали без прежнего списка (приложение убили) — верен новейший, старое стирается', () async {
    put(open, 'a.txt', 'первое');
    await store.seal(open, keys.publicKey);
    put(open, 'a.txt', 'второе');
    put(open, 'b.txt', 'новое');
    await store.seal(open, keys.publicKey);
    expect(sealedNames().length, 3);

    final again = Directory(p.join(root.path, 'again'));
    await store.unseal(again, keys);
    expect(contents(again), {'a.txt': 'второе', 'b.txt': 'новое'});
  });

  test('пустая папка запечатывается пустым списком, а без запечатанного открывать нечего', () async {
    expect(await store.hasSealed(), isFalse);
    expect(await store.unseal(Directory(p.join(root.path, 'x')), keys), isNull);
    await store.seal(open, keys.publicKey);
    expect(await store.hasSealed(), isTrue);
    final again = Directory(p.join(root.path, 'again'));
    expect((await store.unseal(again, keys))!.files, isEmpty);
  });

  test('чужой ключ не открывает, «забыл код» стирает всё', () async {
    put(open, 'a.txt', 'тайна');
    await store.seal(open, keys.publicKey);
    final other = (await createLock('999999', kdf: fast)).$2;
    await expectLater(store.unseal(Directory(p.join(root.path, 'x')), other), throwsA(isA<SealBroken>()));
    await store.wipe();
    expect(await store.hasSealed(), isFalse);
  });
}
