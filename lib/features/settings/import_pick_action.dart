import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fs/import_pick.dart' if (dart.library.js_interop) '../../core/fs/import_pick_web.dart' show BrowserImport;
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../vault/vault_actions.dart';

/// Выгрузка выбрана, окно хода открыто: перенос пишет ход в [status] и в конце зовёт [close].
class PickedImport {
  PickedImport._(this.path, this.status, this._close);

  /// Папка выгрузки или файл закладок.
  final String path;
  final ValueNotifier<(String, double?)> status;
  final Future<void> Function() _close;

  /// Закрыть окно хода и стереть то, что сайт копировал к себе.
  Future<void> close() => _close();
}

/// Выбрать папку выгрузки (при [file] — файл закладок) и открыть окно хода. На телефоне —
/// системное окно выбора, перенос читает папку на месте. В браузере выбранное сперва ложится в
/// личную папку сайта, и ход копирования идёт в том же окне, где потом пойдёт перенос.
/// Отменили выбор или копия не вышла — null.
Future<PickedImport?> pickImport(BuildContext context, WidgetRef ref, {required bool file}) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  BrowserImport? browser;
  String? path;
  if (ref.read(storedInBrowserProvider)) {
    browser = await ref.read(browserImportPickerProvider)(file: file);
    if (browser == null) return null;
  } else {
    path = file ? await ref.read(bookmarksPickerProvider)() : await ref.read(vaultPickerProvider)();
    if (path == null) return null;
  }
  if (!context.mounted || !await ensureFileAccess(context, ref) || !context.mounted) {
    await browser?.dispose();
    return null;
  }

  final status = ValueNotifier<(String, double?)>((l.importProgress(0, 0), null));
  unawaited(showDialog<void>(context: context, barrierDismissible: false, builder: (context) => ProgressDialog(status: status)));
  Future<void> close() async {
    navigator.pop();
    status.dispose();
    await browser?.dispose().catchError((_) {});
  }

  if (browser != null) {
    try {
      path = await browser.copy((done, total) => status.value = (l.importReading(done, total), done / total));
    } on Object {
      // в браузере кончилось место или файл не прочитался: переносить нечего
      await close();
      showNote(messenger, l.importReadFailed);
      return null;
    }
  }
  return PickedImport._(path!, status, close);
}
