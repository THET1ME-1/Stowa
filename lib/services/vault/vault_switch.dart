import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/db/database.dart';
import '../../domain/known_vaults.dart';
import 'vault_layout.dart';
import 'vault_location.dart';
import 'vault_reader.dart';

/// В папке есть заметки `.md`, служебное `.stowa`, `.obsidian` и корзина не в счёт.
Future<bool> folderHasNotes(Directory root) async {
  if (!await root.exists()) return false;
  return root.list(recursive: true, followLinks: false).any((entity) {
    if (entity is! File || !entity.path.endsWith('.md')) return false;
    return !isServicePath(p.relative(entity.path, from: root.path).split(p.separator).join('/'));
  });
}

/// Открыть базу хранилища [target]. Пустая база при заметках в папке собирается из папки:
/// так открывается Obsidian или прежнее хранилище после переустановки. Знакомая база
/// открывается как есть — свежие правки снаружи подтянет сверка при открытии.
Future<AppDatabase> prepareVaultDatabase(
  KnownVault target, {
  required AppDatabase Function(String name) open,
  required DateTime Function() clock,
  void Function(int done, int total)? progress,
}) async {
  final db = open(target.db);
  try {
    final root = Directory(target.path);
    if (!await hasSavedItems(db) && await folderHasNotes(root)) {
      await VaultReader(db, root: root, clock: clock).rebuild(progress: progress);
    }
    return db;
  } catch (_) {
    await db.close();
    rethrow;
  }
}
