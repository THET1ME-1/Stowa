import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/capture_service.dart';
import 'package:stowa/services/file_keeper.dart';

void main() {
  late AppDatabase db;
  late Directory home;
  late Directory gallery;
  late Directory cache;
  var now = DateTime(2026, 11, 4, 12);

  FileKeeper keeper({String runner = 'main'}) => FileKeeper(db, filesRoot: home, movable: [cache], clock: () => now, runner: runner);

  setUp(() async {
    db = AppDatabase.memory();
    home = await Directory.systemTemp.createTemp('stowa_files');
    gallery = await Directory.systemTemp.createTemp('stowa_gallery');
    cache = await Directory(p.join(home.path, 'cache')).create();
    now = DateTime(2026, 11, 4, 12);
  });

  tearDown(() async {
    await db.close();
    await home.delete(recursive: true);
    await gallery.delete(recursive: true);
  });

  Future<String> item({String body = ''}) async {
    const id = 'v';
    await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.video, title: 'Ролик', body: Value(body), createdAt: now, updatedAt: now));
    return id;
  }

  Future<PickedFile> source(Directory folder, String name, {int bytes = 3 * 1024 * 1024}) async {
    final file = File(p.join(folder.path, name));
    await file.writeAsBytes(List.generate(bytes, (index) => index % 251));
    return PickedFile(path: file.path, mime: 'video/mp4', size: bytes);
  }

  Future<List<Attachment>> attachments() => db.select(db.attachments).get();
  Future<List<FileJob>> jobs() => db.select(db.fileJobs).get();

  test('задача пишется сразу, файл появляется во вложениях целиком после прохода', () async {
    final id = await item();
    final video = await source(gallery, 'clip.mp4');
    final files = keeper();
    await files.enqueue(id, [video]);
    expect(await jobs(), hasLength(1));
    expect(await attachments(), isEmpty);

    await files.drain();
    final stored = (await attachments()).single;
    expect(stored.position, 0);
    expect(File(p.join(home.path, stored.path)).readAsBytesSync(), File(video.path).readAsBytesSync());
    expect(await jobs(), isEmpty);
    // из галереи — копия: оригинал на месте
    expect(File(video.path).existsSync(), isTrue);
  });

  test('временный файл приложения переносится, а не копируется', () async {
    final id = await item();
    final voice = await source(cache, 'voice.m4a');
    final bytes = File(voice.path).readAsBytesSync();
    final files = keeper();
    await files.enqueue(id, [voice]);
    await files.drain();
    final stored = (await attachments()).single;
    expect(File(p.join(home.path, stored.path)).readAsBytesSync(), bytes);
    expect(File(voice.path).existsSync(), isFalse);
  });

  test('оборванное копирование продолжается с места обрыва', () async {
    final id = await item();
    final video = await source(gallery, 'clip.mp4');
    final files = keeper();
    await files.enqueue(id, [video]);
    // телефон выключился на середине: недописанный кусок лежит рядом с местом файла
    final job = (await jobs()).single;
    final part = File(p.join(home.path, '${job.target}.part'));
    await part.parent.create(recursive: true);
    await part.writeAsBytes(File(video.path).readAsBytesSync().sublist(0, 1024 * 1024));

    await keeper().drain();
    final stored = (await attachments()).single;
    expect(File(p.join(home.path, stored.path)).readAsBytesSync(), File(video.path).readAsBytesSync());
    expect(part.existsSync(), isFalse);
  });

  test('файл уже на месте, а база не успела записать — только запись, без второй копии', () async {
    final id = await item();
    final video = await source(gallery, 'clip.mp4');
    await keeper().enqueue(id, [video]);
    final job = (await jobs()).single;
    final target = File(p.join(home.path, job.target));
    await target.parent.create(recursive: true);
    await File(video.path).copy(target.path);
    await File(video.path).delete();

    await keeper().drain();
    expect((await attachments()).single.path, job.target);
    expect(await jobs(), isEmpty);
  });

  test('чужой живой исполнитель задачу держит, брошенную — забирают', () async {
    final id = await item();
    await keeper().enqueue(id, [await source(gallery, 'clip.mp4')]);
    await (db.update(db.fileJobs)).write(FileJobsCompanion(claimedBy: const Value('share'), claimedUntil: Value(now.add(const Duration(seconds: 10)).millisecondsSinceEpoch)));
    await keeper().drain();
    expect(await attachments(), isEmpty);

    now = now.add(const Duration(seconds: 30));
    await keeper().drain();
    expect(await attachments(), hasLength(1));
  });

  test('пропал источник: вещь без слов удаляется, со словами остаётся, об этом сообщают', () async {
    final id = await item();
    final files = keeper();
    final failures = <CopyFailure>[];
    final listening = files.failures.listen(failures.add);
    await files.enqueue(id, [const PickedFile(path: '/нет/такого.mp4', mime: 'video/mp4', size: 10)]);
    await files.drain();
    await Future<void>.delayed(Duration.zero);
    expect(failures.single.removed, isTrue);
    expect(await db.select(db.items).get(), isEmpty);
    expect(await jobs(), isEmpty);
    await listening.cancel();
  });

  test('нет места на диске — задача ждёт следующего прохода, а не теряется', () async {
    final id = await item(body: 'текст');
    final video = await source(gallery, 'clip.mp4');
    final files = FileKeeper(db, filesRoot: home, movable: [cache], clock: () => now, write: (from, part, offset, onWritten) => throw const FileSystemException('No space left on device', '', OSError('No space left on device', 28)));
    await files.enqueue(id, [video]);
    await files.drain();
    final job = (await jobs()).single;
    expect(job.attempts, 1);
    expect(await db.select(db.items).get(), hasLength(1));
  });

  test('вещь стёрли, пока копировалось: файла и записи не остаётся', () async {
    final id = await item();
    await keeper().enqueue(id, [await source(gallery, 'clip.mp4')]);
    await (db.delete(db.items)..where((t) => t.id.equals(id))).go();
    await keeper().drain();
    expect(await attachments(), isEmpty);
    expect(await jobs(), isEmpty);
  });

  test('ход копирования виден по вещи', () async {
    final id = await item();
    final files = keeper();
    final seen = <double>[];
    final listening = files.progress.listen((progress) {
      final value = progress[id];
      if (value != null) seen.add(value);
    });
    await files.enqueue(id, [await source(gallery, 'clip.mp4', bytes: 8 * 1024 * 1024)]);
    await files.drain();
    await Future<void>.delayed(Duration.zero);
    expect(seen, isNotEmpty);
    expect(seen.last, 1.0);
    await listening.cancel();
  });

  test('чужой ход виден по недописанному файлу', () async {
    final id = await item();
    final files = keeper();
    expect(await files.fractionOf(id), isNull);
    await files.enqueue(id, [await source(gallery, 'clip.mp4', bytes: 4 * 1024 * 1024)]);
    expect(await files.fractionOf(id), 0);
    // фон докопировал четверть
    final job = (await jobs()).single;
    final part = File(p.join(home.path, '${job.target}.part'));
    await part.parent.create(recursive: true);
    await part.writeAsBytes(List.filled(1024 * 1024, 1));
    expect(await files.fractionOf(id), closeTo(0.25, 0.001));
  });

  test('после прохода остались задачи — просит систему доделать в фоне', () async {
    final id = await item();
    var asked = 0;
    final files = FileKeeper(db, filesRoot: home, movable: [cache], clock: () => now, onLeftover: () async => asked++);
    await files.enqueue(id, [await source(gallery, 'clip.mp4')]);
    await (db.update(db.fileJobs)).write(FileJobsCompanion(claimedBy: const Value('share'), claimedUntil: Value(now.add(const Duration(seconds: 10)).millisecondsSinceEpoch)));
    await files.drain();
    // до прохода — страховка, после — ещё раз: задача так и не легла
    expect(asked, 2);
  });

  test('страховка заказывается до копирования, а пустая очередь систему не беспокоит', () async {
    final id = await item();
    var asked = 0;
    var copiedWhenAsked = true;
    final files = FileKeeper(
      db,
      filesRoot: home,
      movable: [cache],
      clock: () => now,
      onLeftover: () async {
        asked++;
        copiedWhenAsked = (await attachments()).isNotEmpty;
      },
    );
    await files.drain();
    expect(asked, 0);
    await files.enqueue(id, [await source(gallery, 'clip.mp4')]);
    await files.drain();
    expect(asked, 1);
    expect(copiedWhenAsked, isFalse);
  });
}
