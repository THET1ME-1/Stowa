import 'platform.dart';

/// Человек важнее фона.
///
/// В браузере база одна и работает в одном потоке. После первой загрузки хранилища фон
/// часами разбирает заметки (факты, сверка файлов) и на каждую пишет в базу, а запросы
/// поиска и экранов стоят за ним в очереди секундами. Поэтому приложение отмечает каждое
/// нажатие ([touch]), а длинные фоновые проходы между шагами ждут, пока человек занят ([calm]).
class UserFirst {
  UserFirst({required this.enabled, DateTime Function()? clock, this.hold = const Duration(seconds: 2), this.poll = const Duration(milliseconds: 250)})
    : _clock = clock ?? DateTime.now;

  /// На телефоне и компьютере база быстрая и фон ей не мешает: там выключено.
  final bool enabled;

  /// Сколько после нажатия человек считается занятым.
  final Duration hold;

  /// Как часто фон проверяет, освободился ли человек.
  final Duration poll;

  final DateTime Function() _clock;
  DateTime? _until;
  var _working = 0;

  /// Человек нажал клавишу, щёлкнул или прокрутил.
  void touch() {
    if (enabled) _until = _clock().add(hold);
  }

  /// [work] — то, чего человек ждёт прямо сейчас (поиск строки): пока оно идёт, он занят.
  Future<T> during<T>(Future<T> work) async {
    if (!enabled) return work;
    _working++;
    try {
      return await work;
    } finally {
      _working--;
      touch();
    }
  }

  bool get busy {
    if (_working > 0) return true;
    final until = _until;
    return until != null && _clock().isBefore(until);
  }

  /// Фоновый проход зовёт между шагами: человек не занят — возвращается сразу, без таймера.
  Future<void> calm() async {
    while (busy) {
      await Future<void>.delayed(poll);
    }
  }
}

/// Один на приложение: его трогает корень приложения, а спрашивают разбор фактов и сверка хранилища.
final userFirst = UserFirst(enabled: isWeb);
