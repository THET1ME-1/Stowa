import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/share_intake.dart';
import '../privacy/privacy_gate.dart';
import 'share_receiver.dart';
import 'share_sheet.dart';

/// Переносит файлы из папки расширения в [into]; занятое имя получает номер.
/// Не перенёсся — остаётся как был.
Future<List<SharedPiece>> adoptShared(List<SharedPiece> pieces, Directory into) async {
  final adopted = <SharedPiece>[];
  for (final piece in pieces) {
    final words = piece.kind == SharedKind.text || piece.kind == SharedKind.url;
    adopted.add(words ? piece : await _adopt(piece, into));
  }
  return adopted;
}

Future<SharedPiece> _adopt(SharedPiece piece, Directory into) async {
  final from = File(piece.value);
  if (!from.existsSync()) return piece;
  try {
    await into.create(recursive: true);
    final target = _freePath(into, p.basename(from.path));
    try {
      await from.rename(target);
    } on FileSystemException {
      // другой том: переименование не проходит
      await from.copy(target);
      await from.delete();
    }
    return SharedPiece(value: target, kind: piece.kind, mime: piece.mime);
  } on FileSystemException {
    return piece;
  }
}

/// «фото.png» занято — «фото 2.png», потом «фото 3.png».
String _freePath(Directory folder, String name) {
  final base = p.basenameWithoutExtension(name);
  final extension = p.extension(name);
  var path = p.join(folder.path, name);
  for (var number = 2; File(path).existsSync(); number++) {
    path = p.join(folder.path, '$base $number$extension');
  }
  return path;
}

/// Сохраняет присланное и, когда замок открыт, показывает лист «Положил в …».
Future<void> receiveShared(BuildContext context, WidgetRef ref, List<SharedPiece> pieces) async {
  if (pieces.isEmpty) return;
  final l = L.of(context);
  final adopted = await adoptShared(pieces, Directory(p.join(ref.read(scratchRootProvider).path, 'tmp')));
  final id = await saveShared(ref, adopted, l: l);
  if (!context.mounted) return;
  // под замком заметка уже сохранена, а лист и плашка ждут кода
  await PrivacyGate.unlocked(context);
  if (!context.mounted) return;
  if (id == null) return showNote(ScaffoldMessenger.of(context), l.shareFailed, overDock: true);
  await showShareSheet(context, id);
}
