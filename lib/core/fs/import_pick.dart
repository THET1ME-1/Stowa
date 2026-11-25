/// Выгрузка для переноса, выбранная окном браузера. На телефоне папку выбирает системное
/// окно, и перенос читает её на месте, поэтому здесь только вид без устройства.
abstract class BrowserImport {
  /// Сколько файлов выбрано.
  int get count;

  /// Положить выбранное в личную папку сайта; путь выбранной папки или файла.
  Future<String> copy(void Function(int done, int total) progress);

  /// Стереть скопированное после переноса.
  Future<void> dispose();
}

/// Окно выбора браузера: папка выгрузки или, при [file], файл закладок. Отменили — null.
Future<BrowserImport?> chooseBrowserImport({required bool file}) async => null;
