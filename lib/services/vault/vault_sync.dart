import 'vault_reader.dart';
import 'vault_writer.dart';

/// Один проход синхронизации хранилища: сперва забрать правки снаружи, потом записать свои.
/// В таком порядке правка с компьютера не затирается незаписанной правкой из приложения,
/// а при правке с двух сторон обе версии остаются.
class VaultSync {
  VaultSync({required this.reader, required this.writer});

  final VaultReader reader;
  final VaultWriter writer;

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
    do {
      _again = false;
      await reader.reconcile();
      await writer.drain();
      // файл поправили, пока писатель писал соседние: забрать и дописать
      if (writer.sawExternalEdit) {
        await reader.reconcile();
        await writer.drain();
      }
    } while (_again);
  }
}
