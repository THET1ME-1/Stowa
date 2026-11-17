import 'package:flutter/foundation.dart';

import 'vault_reader.dart';
import 'vault_writer.dart';

/// Один проход синхронизации хранилища: сперва забрать правки снаружи, потом записать свои.
/// В таком порядке правка с компьютера не затирается незаписанной правкой из приложения,
/// а при правке с двух сторон обе версии остаются.
class VaultSync {
  VaultSync({required this.reader, required this.writer, this.remote});

  final VaultReader reader;
  final VaultWriter writer;

  /// Проход синхронизации через сервер: пути файлов, которые он положил или удалил.
  final Future<List<String>> Function()? remote;

  /// С какого числа пришедших заметок главная показывает полоску: пара правок появится и так.
  static const showFrom = 50;

  /// Ход сверки «340 из 1000», пока снаружи пришло много заметок; null — полоски нет.
  final status = ValueNotifier<(int, int)?>(null);

  Future<void>? _running;
  bool _again = false;

  /// Новый вызов посреди прохода не теряется: проход повторится после текущего.
  Future<void> run() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    try {
      do {
        _again = false;
        await reader.reconcile(progress: _report);
        await writer.drain();
        // файл поправили, пока писатель писал соседние: забрать и дописать
        if (writer.sawExternalEdit) {
          await reader.reconcile(progress: _report);
          await writer.drain();
        }
        // свои правки уже в файлах: синхронизация отправляет их и кладёт чужие
        final sync = remote;
        final received = sync == null ? const <String>[] : await sync().catchError((_) => const <String>[]);
        if (received.isNotEmpty) {
          // метки, папки и правила с другого телефона — до заметок, история — после
          await reader.restoreSynced(received, meta: true);
          await reader.reconcile(progress: _report);
          await reader.restoreSynced(received, meta: false);
          await writer.drain();
        }
      } while (_again);
    } finally {
      status.value = null;
    }
  }

  void _report(int done, int total) {
    if (total >= showFrom) status.value = (done, total);
  }
}
