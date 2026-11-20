import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/search_query.dart';
import 'package:stowa/services/backup_service.dart';
import 'package:stowa/services/zip_stream.dart';

void main() {
  final now = DateTime(2026, 11, 3, 12);
  late AppDatabase source;
  late AppDatabase target;
  late Directory sourceFiles;
  late Directory targetFiles;
  late Directory out;

  setUp(() {
    source = AppDatabase.memory();
    target = AppDatabase.memory();
    sourceFiles = Directory.systemTemp.createTempSync('stowa_backup_from');
    targetFiles = Directory.systemTemp.createTempSync('stowa_backup_to');
    out = Directory.systemTemp.createTempSync('stowa_backup_out');
  });
  tearDown(() async {
    await source.close();
    await target.close();
    for (final dir in [sourceFiles, targetFiles, out]) {
      dir.deleteSync(recursive: true);
    }
  });

  Future<void> fill() async {
    await source.into(source.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Еда', icon: 'restaurant', shape: 'pill'));
    await source.into(source.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.image, title: 'Борщ', body: const Value('свёкла и капуста'), folderId: const Value('food'), createdAt: now, updatedAt: now));
    await source.into(source.items).insert(ItemsCompanion.insert(id: 'b', kind: ItemKind.note, title: 'Пампушки', createdAt: now, updatedAt: now));
    await source.into(source.attachments).insert(AttachmentsCompanion.insert(id: 'f', itemId: 'a', path: 'attachments/a/0_borsch.jpg', mime: 'image/jpeg', size: 3));
    File('${sourceFiles.path}/attachments/a/0_borsch.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync([7, 7, 7]);
    await source.into(source.tags).insert(TagsCompanion.insert(id: 't', name: 'рецепт', createdAt: now));
    await source.into(source.itemTags).insert(ItemTagsCompanion.insert(itemId: 'a', tagId: 't', source: TagSource.user));
    await source.into(source.rules).insert(
      RulesCompanion.insert(id: 'r', conditionKind: RuleConditionKind.hasTag, conditionValue: 'рецепт', actionKind: RuleActionKind.toFolder, actionValue: 'food'),
    );
    await source.into(source.links).insert(LinksCompanion.insert(fromId: 'a', toId: 'b', source: LinkSource.ai, reason: const Value('к борщу')));
  }

  test('копия, восстановленная в чистую Stowa, даёт те же вещи, теги, правила, связи и файлы', () async {
    await fill();
    final zip = await BackupService(source, filesRoot: sourceFiles, clock: () => now).export(out);
    // в новой Stowa уже что-то было: копия это заменяет
    await target.into(target.items).insert(ItemsCompanion.insert(id: 'x', kind: ItemKind.note, title: 'Лишнее', createdAt: now, updatedAt: now));

    final info = await BackupService.inspect(zip);
    expect(info.items, 2);
    expect(info.createdAt, now);

    await BackupService(target, filesRoot: targetFiles, clock: () => now).restore(zip);
    final items = await target.select(target.items).get();
    expect(items.map((item) => item.id), unorderedEquals(['a', 'b']));
    expect((await target.select(target.folders).getSingle()).name, 'Еда');
    expect((await target.select(target.itemTags).getSingle()).tagId, 't');
    expect((await target.select(target.rules).getSingle()).conditionValue, 'рецепт');
    expect((await target.select(target.links).getSingle()).reason, 'к борщу');
    expect(File('${targetFiles.path}/attachments/a/0_borsch.jpg').readAsBytesSync(), [7, 7, 7]);
    // поиск видит восстановленное
    final found = await ItemsRepository(target).search(query: parseSearch('свёкла', now), now: now);
    expect(found.results.single.card.id, 'a');
  });

  test('копия хранилища: все его файлы, кроме копий страниц и временных', () async {
    await fill();
    for (final path in ['Еда/Борщ.md', 'Еда/Борщ/борщ.jpg', '.stowa/tags.json', '.stowa/pages/a.html.gz', 'Еда/.Борщ.md.tmp', '.obsidian/app.json']) {
      File('${sourceFiles.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(path);
    }
    final zip = await BackupService(source, filesRoot: sourceFiles, vault: true, clock: () => now).export(out);
    final names = BackupService.entries(zip);
    expect(names, containsAll(['files/Еда/Борщ.md', 'files/Еда/Борщ/борщ.jpg', 'files/.stowa/tags.json', 'files/.obsidian/app.json', 'files/attachments/a/0_borsch.jpg']));
    expect(names, isNot(contains('files/.stowa/pages/a.html.gz')));
    expect(names, isNot(contains('files/Еда/.Борщ.md.tmp')));
  });

  test('восстановление в хранилище: файлы на месте, чужие файлы хранилища не тронуты, заметки ждут записи', () async {
    await fill();
    File('${sourceFiles.path}/Еда/Борщ/борщ.jpg')
      ..createSync(recursive: true)
      ..writeAsStringSync('jpeg');
    final zip = await BackupService(source, filesRoot: sourceFiles, vault: true, clock: () => now).export(out);
    File('${targetFiles.path}/Мои/список.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('своё');
    await BackupService(target, filesRoot: targetFiles, vault: true, clock: () => now).restore(zip);
    expect(File('${targetFiles.path}/Еда/Борщ/борщ.jpg').readAsStringSync(), 'jpeg');
    expect(File('${targetFiles.path}/Мои/список.md').readAsStringSync(), 'своё');
    expect(await target.select(target.vaultFiles).get(), isEmpty, reason: 'карта файлов прежнего телефона не годится');
    final queued = {for (final row in await target.select(target.vaultQueue).get()) row.target};
    expect(queued, containsAll(['item:a', 'item:b', 'meta:folders']));
  });

  test('в копии нет ключа ИИ и настроек: только база и файлы', () async {
    await fill();
    final zip = await BackupService(source, filesRoot: sourceFiles, clock: () => now).export(out);
    final names = BackupService.entries(zip);
    expect(names, contains('stowa.sqlite'));
    expect(names, contains('manifest.json'));
    expect(names.where((name) => !name.startsWith('files/') && name != 'stowa.sqlite' && name != 'manifest.json'), isEmpty);
  });

  group('копия без снимка базы — такую делает браузер', () {
    const borsch = '---\nid: a\nkind: note\n---\nсвёкла и капуста';

    /// Хранилище с заметками-файлами, собранное в архив куском за куском.
    Future<File> filesOnlyCopy() async {
      await fill();
      for (final (path, text) in [('Еда/Борщ.md', borsch), ('Еда/Борщ/борщ.jpg', 'jpeg'), ('.stowa/tags.json', '[]'), ('.stowa/pages/a.html.gz', 'страница'), ('Еда/.Борщ.md.tmp', 'недописано')]) {
        File('${sourceFiles.path}/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync(text);
      }
      final zip = File('${out.path}/Stowa-2026-11-03.zip');
      final sink = zip.openWrite();
      await BackupService(source, filesRoot: sourceFiles, vault: true, clock: () => now).exportFiles(ZipStreamWriter(sink.add));
      await sink.close();
      return zip;
    }

    test('в ней файлы хранилища и опись; базы, копий страниц и недописанного нет', () async {
      final names = BackupService.entries(await filesOnlyCopy());
      expect(names, containsAll(['manifest.json', 'files/Еда/Борщ.md', 'files/Еда/Борщ/борщ.jpg', 'files/.stowa/tags.json']));
      expect(names, isNot(contains('stowa.sqlite')));
      expect(names, isNot(contains('files/.stowa/pages/a.html.gz')));
      expect(names, isNot(contains('files/Еда/.Борщ.md.tmp')));
    });

    test('опись говорит: базы нет, заметок столько-то, сделана тогда-то', () async {
      final info = await BackupService.inspect(await filesOnlyCopy());
      expect(info.hasDatabase, isFalse);
      expect(info.items, 2);
      expect(info.createdAt, now);
    });

    test('у обычной копии телефона база есть', () async {
      await fill();
      final zip = await BackupService(source, filesRoot: sourceFiles, vault: true, clock: () => now).export(out);
      expect((await BackupService.inspect(zip)).hasDatabase, isTrue);
    });

    test('телефон восстанавливает её: файлы встают в хранилище, свои остаются, база ждёт пересборки из файлов', () async {
      final zip = await filesOnlyCopy();
      File('${targetFiles.path}/Мои/список.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('своё');
      await target.into(target.items).insert(ItemsCompanion.insert(id: 'x', kind: ItemKind.note, title: 'Своё', createdAt: now, updatedAt: now));
      final info = await BackupService(target, filesRoot: targetFiles, vault: true, clock: () => now).restore(zip);
      expect(info.hasDatabase, isFalse, reason: 'по этому экран зовёт пересборку указателя из файлов');
      expect(File('${targetFiles.path}/Еда/Борщ.md').readAsStringSync(), borsch);
      expect(File('${targetFiles.path}/Еда/Борщ/борщ.jpg').readAsStringSync(), 'jpeg');
      expect(File('${targetFiles.path}/Мои/список.md').readAsStringSync(), 'своё');
      expect((await target.select(target.items).get()).map((item) => item.id), ['x'], reason: 'базу копия без снимка не трогает');
    });

    test('из байтов, как её отдаёт браузер: файлы на месте', () async {
      final bytes = (await filesOnlyCopy()).readAsBytesSync();
      expect(BackupService.inspectBytes(bytes).items, 2);
      final info = await BackupService(target, filesRoot: targetFiles, vault: true, clock: () => now).restoreBytes(bytes);
      expect(info.hasDatabase, isFalse);
      expect(File('${targetFiles.path}/Еда/Борщ.md').readAsStringSync(), borsch);
    });

    test('копия телефона в браузере: снимок базы там не открыть, берутся только файлы', () async {
      await fill();
      File('${sourceFiles.path}/Еда/Борщ.md')
        ..createSync(recursive: true)
        ..writeAsStringSync(borsch);
      final zip = await BackupService(source, filesRoot: sourceFiles, vault: true, clock: () => now).export(out);
      final info = await BackupService(target, filesRoot: targetFiles, vault: true, clock: () => now).restoreBytes(zip.readAsBytesSync());
      expect(info.hasDatabase, isFalse, reason: 'базу не восстанавливали: указатель собирается из файлов');
      expect(File('${targetFiles.path}/Еда/Борщ.md').readAsStringSync(), borsch);
      expect(await target.select(target.items).get(), isEmpty);
    });

    test('файл с путём наружу из хранилища не пишется', () async {
      final evil = File('${out.path}/evil.zip');
      final sink = evil.openWrite();
      final zip = ZipStreamWriter(sink.add);
      await zip.add('manifest.json', '{"app":"stowa","schema":1,"createdAt":"2026-11-03T12:00:00.000","items":0,"database":false}'.codeUnits);
      await zip.add('files/../../снаружи.md', 'взлом'.codeUnits);
      await zip.add('files/Заметка.md', 'обычная'.codeUnits);
      await zip.close();
      await sink.close();
      await BackupService(target, filesRoot: targetFiles, vault: true, clock: () => now).restore(evil);
      expect(File('${targetFiles.path}/Заметка.md').existsSync(), isTrue);
      expect(File('${targetFiles.parent.path}/снаружи.md').existsSync(), isFalse);
      expect(Directory(targetFiles.parent.parent.path).listSync().whereType<File>().where((file) => file.path.endsWith('снаружи.md')), isEmpty);
    });
  });

  test('чужой архив не восстанавливается и ничего не трогает', () async {
    final stranger = File('${out.path}/other.zip')..writeAsBytesSync([80, 75, 5, 6, ...List.filled(18, 0)]);
    await target.into(target.items).insert(ItemsCompanion.insert(id: 'x', kind: ItemKind.note, title: 'Своё', createdAt: now, updatedAt: now));
    expect(() => BackupService.inspect(stranger), throwsA(isA<BackupError>()));
    await expectLater(BackupService(target, filesRoot: targetFiles, clock: () => now).restore(stranger), throwsA(isA<BackupError>()));
    expect(await target.select(target.items).get(), hasLength(1));
  });
}
