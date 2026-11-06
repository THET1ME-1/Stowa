import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/telegram_import.dart';
import '../vault/vault_actions.dart';

/// «Из Telegram»: человек выбирает папку выгрузки, сообщения становятся заметками,
/// итог — плашкой: сколько перенесено и сколько уже было.
Future<void> importTelegram(BuildContext context, WidgetRef ref) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final picked = await ref.read(vaultPickerProvider)();
  if (picked == null || !context.mounted) return;
  if (!await ensureFileAccess(context, ref) || !context.mounted) return;

  final status = ValueNotifier<(String, double?)>((l.importProgress(0, 0), null));
  unawaited(showDialog<void>(context: context, barrierDismissible: false, builder: (context) => ProgressDialog(status: status)));
  try {
    final import = TelegramImport(ref.read(databaseProvider), ref.read(captureServiceProvider));
    final report = await import.run(Directory(picked), progress: (done, total) => status.value = (l.importProgress(done, total), total == 0 ? null : done / total));
    final done = [l.importDone(report.added), if (report.repeated > 0) l.importRepeated(report.repeated)].join(', ');
    showNote(messenger, report.filesMissing > 0 ? '$done. ${l.importMissing(report.filesMissing)}' : done);
  } on TelegramImportError {
    showNote(messenger, l.importNotTelegram);
  } finally {
    navigator.pop();
    status.dispose();
  }
}
