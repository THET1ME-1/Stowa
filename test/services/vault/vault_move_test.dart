import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/vault/vault_move.dart';
import 'package:stowa/services/vault/vault_reader.dart';

void main() {
  late AppDatabase db;
  late Directory old;
  late Directory target;
  late SettingsRepository settings;
  final now = DateTime(2026, 11, 6, 10);

  setUp(() async {
    db = AppDatabase.memory();
    old = Directory.systemTemp.createTempSync('stowa_old');
    target = Directory(p.join(Directory.systemTemp.createTempSync('stowa_phone').path, 'Stowa'));
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
    // старая установка: файлы в папке приложения, пути старого вида
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'f', name: 'Рецепты', icon: 'restaurant', shape: 'pill'));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.image, title: 'Борщ', folderId: const Value('f'), createdAt: now, updatedAt: now));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'l', kind: ItemKind.link, title: 'Карбонара', url: const Value('https://food.md/c'), coverPath: const Value('covers/l.jpg'), createdAt: now, updatedAt: now));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'd', kind: ItemKind.note, title: 'Старое', createdAt: now, updatedAt: now, deletedAt: Value(now)));
    await db.into(db.tags).insert(TagsCompanion.insert(id: 't', name: 'суп', createdAt: now, iconKind: const Value(TagIconKind.image), iconValue: const Value('tags/t.png')));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'p', itemId: 'a', path: 'attachments/a/0_борщ.jpg', mime: 'image/jpeg', size: 4));
    for (final (path, bytes) in [('attachments/a/0_борщ.jpg', 'борщ'), ('covers/l.jpg', 'обл'), ('tags/t.png', 'тег'), ('pages/l.html.gz', 'стр')]) {
      File(p.join(old.path, path))
        ..createSync(recursive: true)
        ..writeAsStringSync(bytes);
    }
  });
  tearDown(() async {
    await db.close();
    old.deleteSync(recursive: true);
    target.parent.deleteSync(recursive: true);
  });

  VaultMove move({Directory? from, bool insideApp = true, Future<void> Function(File source, File target)? copy}) =>
      VaultMove(db, settings: settings, from: from ?? old, fromInsideApp: insideApp, clock: () => now, copy: copy);
  File at(String relative) => File(p.join(target.path, relative));

  test('старая установка переезжает в новую раскладку: заметки, вложения, обложки, значки, копии страниц', () async {
    var steps = 0;
    final report = await move().moveTo(target, VaultMode.device, progress: (done, total) => steps++);
    expect(report.ok, isTrue, reason: report.missing.join(', '));
    expect(steps, greaterThan(0));
    expect(at('Рецепты/Борщ.md').existsSync(), isTrue);
    expect(at('Рецепты/Борщ/борщ.jpg').readAsStringSync(), 'борщ');
    expect(at('Карбонара.md').existsSync(), isTrue);
    expect(at('.trash/Старое.md').existsSync(), isTrue);
    expect(at('.stowa/covers/l.jpg').readAsStringSync(), 'обл');
    expect(at('.stowa/tag-icons/t.png').readAsStringSync(), 'тег');
    expect(at('.stowa/pages/l.html.gz').readAsStringSync(), 'стр');
    expect((await db.select(db.attachments).getSingle()).path, 'Рецепты/Борщ/борщ.jpg');
    expect((await (db.select(db.items)..where((t) => t.id.equals('l'))).getSingle()).coverPath, '.stowa/covers/l.jpg');
    expect((await db.select(db.tags).getSingle()).iconValue, '.stowa/tag-icons/t.png');
    expect(settings.vaultPath, target.path);
    expect(settings.vaultMode, VaultMode.device);
    expect(settings.vaultAsked, isTrue);
    // папка приложения освобождена от старых копий
    expect(Directory(p.join(old.path, 'attachments')).existsSync(), isFalse);
    expect(Directory(p.join(old.path, 'covers')).existsSync(), isFalse);
  });

  test('сверка не сошлась — старое на месте, пути в базе прежние, настройка не переключена', () async {
    final report = await move(
      copy: (source, destination) async {
        // копия обложки «не дописалась»
        if (source.path.endsWith('l.jpg')) return;
        await destination.parent.create(recursive: true);
        await source.copy(destination.path);
      },
    ).moveTo(target, VaultMode.device);
    expect(report.ok, isFalse);
    expect(report.missing, isNotEmpty);
    expect(settings.vaultPath, isNull);
    expect((await db.select(db.attachments).getSingle()).path, 'attachments/a/0_борщ.jpg');
    expect((await (db.select(db.items)..where((t) => t.id.equals('l'))).getSingle()).coverPath, 'covers/l.jpg');
    expect(File(p.join(old.path, 'attachments/a/0_борщ.jpg')).existsSync(), isTrue);
  });

  test('перенос из своей папки в другую: файлы на месте, старая папка человека не стирается', () async {
    await move().moveTo(target, VaultMode.device);
    final second = Directory(p.join(target.parent.path, 'Другая'));
    final report = await move(from: target, insideApp: false).moveTo(second, VaultMode.device);
    expect(report.ok, isTrue, reason: report.missing.join(', '));
    expect(File(p.join(second.path, 'Рецепты/Борщ/борщ.jpg')).readAsStringSync(), 'борщ');
    expect(settings.vaultPath, second.path);
    expect(at('Рецепты/Борщ.md').existsSync(), isTrue, reason: 'чужая для приложения папка остаётся как была');
  });

  test('открытие готового хранилища после переустановки не переписывает его заметки', () async {
    await move().moveTo(target, VaultMode.device);
    final before = {for (final file in target.listSync(recursive: true).whereType<File>()) if (file.path.endsWith('.md')) file.path: file.lastModifiedSync()};
    // переустановка: пустая база собирается из папки, хранилище внутри приложения пустое
    final fresh = AppDatabase.memory();
    addTearDown(fresh.close);
    final inside = Directory.systemTemp.createTempSync('stowa_inside');
    addTearDown(() => inside.deleteSync(recursive: true));
    await VaultReader(fresh, root: target, clock: () => now).rebuild();
    final report = await VaultMove(fresh, settings: settings, from: inside, fromInsideApp: true, clock: () => now).moveTo(target, VaultMode.device);
    expect(report.ok, isTrue, reason: report.missing.join(', '));
    final after = {for (final file in target.listSync(recursive: true).whereType<File>()) if (file.path.endsWith('.md')) file.path: file.lastModifiedSync()};
    expect(after, before);
  });

  test('«Пересобрать указатель» из папки даёт те же вещи, без дублей', () async {
    await move().moveTo(target, VaultMode.device);
    final before = (await db.select(db.items).get()).length;
    await VaultReader(db, root: target, clock: () => now).rebuild();
    expect((await db.select(db.items).get()).length, before);
  });
}
