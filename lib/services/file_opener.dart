import 'package:open_filex/open_filex.dart';

/// Открыть файл программой системы: PDF в просмотрщике, ролик в плеере. false — открыть
/// нечем или система отказала. На компьютере это запуск чужой программы, поэтому экраны
/// зовут открытие через `fileOpenerProvider`, а тесты его подменяют.
Future<bool> openWithSystem(String path, String mime) async {
  try {
    final result = await OpenFilex.open(path, type: mime);
    return result.type == ResultType.done;
  } on Object {
    // плагина нет или система бросила ошибку — для человека это то же «нечем открыть»
    return false;
  }
}
