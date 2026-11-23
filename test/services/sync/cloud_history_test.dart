import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/sync/cloud_history.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_engine.dart';
import 'package:stowa/services/sync/sync_ports.dart';

import 'fakes.dart';

var _now = 1763900000000;
int _clock() => _now += 60 * 1000;

void main() {
  late FakeRemote remote;
  late VaultKey key;
  late MemoryVault vault;
  late SyncEngine engine;
  late CloudHistory history;

  setUp(() {
    // часы сервера идут вместе с часами телефона
    remote = FakeRemote(now: () => DateTime.fromMillisecondsSinceEpoch(_now, isUtc: true));
    key = VaultKey.generate();
    vault = MemoryVault(_clock);
    engine = SyncEngine(vault: vault, remote: remote, state: MemoryState(), key: key);
    history = CloudHistory(remote: remote, key: key);
  });

  Future<void> save(String path, String text) async {
    vault.putText(path, text);
    await engine.sync();
  }

  Future<void> move(String from, String to) async {
    vault.files[to] = vault.files.remove(from)!;
    await engine.sync();
  }

  Future<List<String>> texts(String path) async => [for (final version in await history.versions(path)) await history.text(version)];

  test('версии файла новыми первыми: текст, путь, устройство, время правки', () async {
    await save('Заметка.md', 'один\n');
    await save('Заметка.md', 'два\n');
    await save('Заметка.md', 'три\n');
    final versions = await history.versions('Заметка.md');
    expect(await texts('Заметка.md'), ['три\n', 'два\n', 'один\n']);
    expect(versions.first.path, 'Заметка.md');
    expect(versions.first.device, 'тест');
    expect(versions.first.at, DateTime.fromMillisecondsSinceEpoch(vault.files['Заметка.md']!.$2));
    expect(versions.first.at.isAfter(versions.last.at), true);
  });

  test('цепочка переездов A → B → A целая и без петли', () async {
    await save('A.md', '---\nid: n1\n---\na1\n');
    await move('A.md', 'B.md');
    await save('B.md', '---\nid: n1\n---\nb1\n');
    await move('B.md', 'A.md');
    await save('A.md', '---\nid: n1\n---\na2\n');
    final shown = [for (final text in await texts('A.md')) text.split('\n')[3]];
    expect(shown, ['a2', 'b1', 'b1', 'a1', 'a1']);
    final paths = [for (final version in await history.versions('A.md')) version.path];
    expect(paths, ['A.md', 'A.md', 'B.md', 'B.md', 'A.md']);
  });

  test('без переезда новый файл на прежнем имени — та же история пути', () async {
    await save('a.md', 'первая жизнь\n');
    vault.files.remove('a.md');
    await engine.sync();
    await save('a.md', 'вторая жизнь\n');
    expect(await texts('a.md'), ['вторая жизнь\n', 'первая жизнь\n']);
  });

  test('сеансы: одно устройство, перерыв меньше 10 минут', () {
    CloudVersion v(int minute, String device) => CloudVersion(
      file: 'f',
      path: 'n.md',
      rev: minute,
      at: DateTime(2026, 11, 23, 14).add(Duration(minutes: minute)),
      sentAt: DateTime(2026, 11, 23, 14).add(Duration(minutes: minute)),
      size: 1,
      hash: '$minute',
      blobs: const [],
      device: device,
    );
    // новые первыми: 40 и 35 — один сеанс, 20 — после перерыва, 18 — с другого телефона
    final sessions = sessionsOf([v(40, 'Pixel'), v(35, 'Pixel'), v(20, 'Pixel'), v(18, 'Сайт'), v(17, 'Сайт')]);
    expect([for (final s in sessions) s.versions.length], [2, 1, 2]);
    expect(sessions.first.last.rev, 40);
    expect(sessions.first.from, DateTime(2026, 11, 23, 14, 35));
    expect(sessions.first.to, DateTime(2026, 11, 23, 14, 40));
    expect(sessions.last.last.device, 'Сайт');
  });

  test('удалённые: заметка и вложение есть, служебное и переезды — нет', () async {
    await save('Ушла.md', 'прощай\n');
    vault.put('Ушла/фото.jpg', [1, 2, 3]);
    await save('Переехала.md', '---\nid: n2\n---\nтекст\n');
    await save('.stowa/tags.json', '[]');
    vault.files.remove('Ушла.md');
    vault.files.remove('Ушла/фото.jpg');
    vault.files.remove('.stowa/tags.json');
    vault.files['Новое место.md'] = vault.files.remove('Переехала.md')!;
    await engine.sync();
    final deleted = await history.deleted();
    // вложение из папки заметки — при ней, отдельной строки нет
    expect([for (final file in deleted) file.path], ['Ушла.md']);
    final note = deleted.single;
    expect([for (final file in note.attachments) file.path], ['Ушла/фото.jpg']);
    expect(await history.text(note.last), 'прощай\n');
    expect(note.device, 'тест');
    expect(note.tomb, key.fileId('Ушла.md'));
  });

  test('удалённое в корзину — переезд, стёртое из корзины — под прежним именем', () async {
    await save('Дела.md', '---\nid: n5\n---\nсписок\n');
    await move('Дела.md', '.trash/Дела.md');
    expect(await history.deleted(), isEmpty);
    vault.files.remove('.trash/Дела.md');
    await engine.sync();
    final gone = (await history.deleted()).single;
    expect(gone.path, 'Дела.md');
    expect(gone.last.path, '.trash/Дела.md');
  });

  test('содержимое второй раз берётся из памяти', () async {
    await save('n.md', 'текст\n');
    var fetched = 0;
    remote.failWhen = (call) {
      if (call == 'getBlob') fetched++;
      return false;
    };
    final version = (await history.versions('n.md')).single;
    await history.text(version);
    await history.text(version);
    expect(fetched, 1);
  });

  test('битый заголовок — версия пропускается, остальные на месте', () async {
    await save('n.md', 'один\n');
    await save('n.md', 'два\n');
    await save('n.md', 'три\n');
    final old = remote.history[key.fileId('n.md')]!;
    final broken = old[1];
    old[1] = RemoteRevision(file: broken.file, rev: broken.rev, meta: 'не шифр', blobs: broken.blobs, size: broken.size, at: broken.at);
    expect(await texts('n.md'), ['три\n', 'один\n']);
  });

  test('журнал правок: что и откуда, без служебного и без надгробий переездов', () async {
    await save('a.md', '---\nid: n1\n---\nтекст\n');
    await save('.stowa/folders.json', '[]');
    await move('a.md', 'b.md');
    final (entries, next) = await history.log();
    expect(next, isNull);
    expect([for (final e in entries) e.version.path], ['b.md', 'a.md']);
  });

  test('стереть навсегда — история удалённого и его прежних путей, живого — нет', () async {
    await save('Старое.md', '---\nid: n1\n---\nтекст\n');
    await move('Старое.md', 'Новое.md');
    await save('Новое.md', '---\nid: n1\n---\nтекст 2\n');
    vault.files.remove('Новое.md');
    await engine.sync();
    // на прежнем пути живёт другой файл: его история остаётся
    await save('Старое.md', 'другой файл\n');
    await save('Старое.md', 'другой файл, правка\n');
    final gone = (await history.deleted()).single;
    expect(gone.last.path, 'Новое.md');
    await history.purge(gone);
    expect(await history.deleted(), isEmpty);
    expect(remote.history[key.fileId('Новое.md')], isNull);
    expect(remote.history[key.fileId('Старое.md')], isNotEmpty);
  });
}
