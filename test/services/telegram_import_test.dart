import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/capture_service.dart';
import 'package:stowa/services/telegram_import.dart';

void main() {
  late AppDatabase db;
  late Directory home;
  late Directory export;
  late CaptureService capture;
  late TelegramImport import;

  setUp(() async {
    db = AppDatabase.memory();
    home = await Directory.systemTemp.createTemp('stowa_home');
    export = await Directory.systemTemp.createTemp('stowa_export');
    capture = CaptureService(db, tags: TagsRepository(db), filesRoot: home, clock: () => DateTime(2026, 11, 6, 12));
    import = TelegramImport(db, capture);
  });

  tearDown(() async {
    await capture.settled();
    await db.close();
    await home.delete(recursive: true);
    await export.delete(recursive: true);
  });

  Future<void> exportWith(List<Map<String, Object?>> messages) async {
    await File(p.join(export.path, 'result.json')).writeAsString(jsonEncode({'name': 'Saved Messages', 'type': 'saved_messages', 'id': 1, 'messages': messages}));
  }

  Map<String, Object?> message(int id, int unix, String text, [Map<String, Object?> extra = const {}]) => {
    'id': id,
    'type': 'message',
    'date_unixtime': '$unix',
    'text': text,
    'text_entities': [if (text.isNotEmpty) {'type': 'plain', 'text': text}],
    ...extra,
  };

  test('сообщения становятся заметками с датой сообщения, файлы — вложениями', () async {
    await Directory(p.join(export.path, 'photos')).create();
    await File(p.join(export.path, 'photos', 'sea.jpg')).writeAsBytes(List.filled(2048, 1));
    await exportWith([
      message(1, 1683885600, 'Рецепт борща: свёкла, капуста'),
      message(2, 1683889200, 'Море', {'photo': 'photos/sea.jpg'}),
    ]);

    final steps = <(int, int)>[];
    final report = await import.run(export, progress: (done, total) => steps.add((done, total)));
    await capture.settled();

    expect((report.added, report.repeated, report.filesMissing), (2, 0, 0));
    expect(steps.last, (2, 2));
    final notes = await (db.select(db.items)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
    expect([for (final note in notes) note.createdAt], [DateTime.fromMillisecondsSinceEpoch(1683885600 * 1000), DateTime.fromMillisecondsSinceEpoch(1683889200 * 1000)]);
    expect(notes.first.body, 'Рецепт борща: свёкла, капуста');
    expect(notes.first.latitude, isNull);
    final files = await ItemsRepository(db).get(notes.last.id);
    expect(files!.attachments.single.mime, 'image/jpeg');
    expect(notes.last.kind, ItemKind.image);
  });

  test('дата в тексте сообщения напоминанием не становится', () async {
    await exportWith([message(1, 1683885600, 'Завтра в 10 стоматолог')]);
    await import.run(export);
    expect((await db.select(db.items).getSingle()).reminderAt, isNull);
  });

  test('повторный перенос той же выгрузки не двоит заметки', () async {
    await exportWith([message(1, 1683885600, 'Купить кофе'), message(2, 1683889200, 'Позвонить маме')]);
    await import.run(export);
    final again = await import.run(export);
    expect((again.added, again.repeated), (0, 2));
    expect(await db.select(db.items).get(), hasLength(2));
  });

  test('невыгруженный файл считается, сообщение с текстом остаётся', () async {
    await exportWith([message(1, 100, 'видео с концерта', {'file': '(File not included. Change data exporting settings to download.)', 'mime_type': 'video/mp4'})]);
    final report = await import.run(export);
    expect((report.added, report.filesMissing), (1, 1));
  });

  test('выгрузили заново с файлами — файл дописывается к уже перенесённой заметке, двойника нет', () async {
    const notIncluded = '(File not included. Change data exporting settings to download.)';
    await exportWith([message(1, 100, 'договор аренды', {'file': notIncluded, 'mime_type': 'application/pdf'})]);
    await import.run(export);

    await Directory(p.join(export.path, 'files')).create();
    await File(p.join(export.path, 'files', 'Договор.pdf')).writeAsBytes(List.filled(4096, 2));
    await exportWith([message(1, 100, 'договор аренды', {'file': 'files/Договор.pdf', 'mime_type': 'application/pdf'})]);
    final again = await import.run(export);
    await capture.settled();

    expect((again.added, again.repeated, again.filled), (0, 1, 1));
    final note = await db.select(db.items).getSingle();
    expect((await ItemsRepository(db).get(note.id))!.attachments.single.mime, 'application/pdf');

    // третий раз — файл уже на месте, второй не ложится
    final third = await import.run(export);
    await capture.settled();
    expect(third.filled, 0);
    expect(await db.select(db.attachments).get(), hasLength(1));
  });

  test('сообщение из одного невыгруженного файла заметкой не становится, но в счёт идёт', () async {
    await exportWith([
      message(1, 100, '', {'file': '(File not included. Change data exporting settings to download.)', 'mime_type': 'application/pdf'}),
      message(2, 200, 'с подписью', {'file': '(File not included. Change data exporting settings to download.)', 'mime_type': 'video/mp4'}),
    ]);
    final report = await import.run(export);
    expect((report.added, report.filesMissing), (1, 2));
  });

  test('файла нет на месте — сообщение переносится без него', () async {
    await exportWith([message(1, 100, 'договор', {'file': 'files/нет.pdf', 'mime_type': 'application/pdf'})]);
    final report = await import.run(export);
    await capture.settled();
    expect((report.added, report.filesMissing), (1, 1));
    expect((await db.select(db.attachments).get()), isEmpty);
  });

  test('сотни сообщений переносятся пачками: все на месте, ход по пачкам до конца', () async {
    await exportWith([for (var id = 1; id <= 120; id++) message(id, 1683885600 + id * 60, 'Заметка номер $id')]);
    final steps = <(int, int)>[];
    final report = await import.run(export, progress: (done, total) => steps.add((done, total)));
    expect(report.added, 120);
    expect(await db.select(db.items).get(), hasLength(120));
    expect(steps, [(0, 120), (50, 120), (100, 120), (120, 120)]);
  });

  test('выгрузка в HTML: страницы по номерам, фото на месте', () async {
    String page(String body) => '<html><body><div class="history">$body</div></body></html>';
    String message(String date, String text, [String media = '']) =>
        '<div class="message default clearfix"><div class="body"><div class="pull_right date details" title="$date">x</div>'
        '${media.isEmpty ? '' : '<div class="media_wrap clearfix">$media</div>'}<div class="text">$text</div></div></div>';
    await Directory(p.join(export.path, 'photos')).create();
    await File(p.join(export.path, 'photos', 'sea.jpg')).writeAsBytes(List.filled(2048, 1));
    // вторая страница называется messages2, десятая — messages10: порядок по номеру, а не по алфавиту
    await File(p.join(export.path, 'messages.html')).writeAsString(page(message('12.05.2023 10:00:00 GMT+02:00', 'первая')));
    await File(p.join(export.path, 'messages2.html')).writeAsString(page(message('13.05.2023 10:00:00 GMT+02:00', 'Море', '<a class="photo_wrap clearfix pull_left" href="photos/sea.jpg"></a>')));
    await File(p.join(export.path, 'messages10.html')).writeAsString(page(message('14.05.2023 10:00:00 GMT+02:00', 'десятая')));

    final report = await import.run(export);
    await capture.settled();
    expect(report.added, 3);
    final notes = await (db.select(db.items)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
    expect(notes.map((note) => note.body), ['первая', 'Море', 'десятая']);
    expect((await ItemsRepository(db).get(notes[1].id))!.attachments.single.mime, 'image/jpeg');
  });

  test('в папке нет result.json — понятная ошибка', () async {
    expect(() => import.run(export), throwsA(isA<TelegramImportError>()));
  });
}
