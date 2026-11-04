import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/search_query.dart';
import 'package:stowa/services/backup_service.dart';

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

  test('в копии нет ключа ИИ и настроек: только база и файлы', () async {
    await fill();
    final zip = await BackupService(source, filesRoot: sourceFiles, clock: () => now).export(out);
    final names = BackupService.entries(zip);
    expect(names, contains('stowa.sqlite'));
    expect(names, contains('manifest.json'));
    expect(names.where((name) => !name.startsWith('files/') && name != 'stowa.sqlite' && name != 'manifest.json'), isEmpty);
  });

  test('чужой архив не восстанавливается и ничего не трогает', () async {
    final stranger = File('${out.path}/other.zip')..writeAsBytesSync([80, 75, 5, 6, ...List.filled(18, 0)]);
    await target.into(target.items).insert(ItemsCompanion.insert(id: 'x', kind: ItemKind.note, title: 'Своё', createdAt: now, updatedAt: now));
    expect(() => BackupService.inspect(stranger), throwsA(isA<BackupError>()));
    await expectLater(BackupService(target, filesRoot: targetFiles, clock: () => now).restore(stranger), throwsA(isA<BackupError>()));
    expect(await target.select(target.items).get(), hasLength(1));
  });
}
