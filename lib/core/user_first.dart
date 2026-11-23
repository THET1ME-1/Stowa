import 'platform.dart';

/// Человек важнее фона.
///
/// В браузере база одна и работает в одном потоке. После первой загрузки хранилища фон
/// часами разбирает заметки (факты, сверка файлов) и на каждую пишет в базу, а запросы
/// поиска и экранов стоят за ним в очереди секундами. Поэтому приложение отмечает каждое
/// нажатие и каждую букву ([touch]), а длинные фоновые проходы и пересчёты после правок
/// между шагами ждут, пока человек занят ([calm]).
///
/// На телефоне база в своём потоке, но пересчёты после правки идут в потоке экрана:
/// угадыватель папок, «вернуть сохранённое», «связанные», виджет. Пока выключено было,
/// каждая пауза набора в 0,7 с (автосохранение) запускала их посреди печати, и клавиатура
/// лагала (тестировщик 23.11; на эмуляторе с 1500 заметками — сотни миллисекунд на паузу).
class UserFirst {
  UserFirst({required this.enabled, DateTime Function()? clock, this.hold = const Duration(seconds: 2), this.poll = const Duration(milliseconds: 250)})
    : _clock = clock ?? DateTime.now;

  /// Выключено только в `flutter test`: там нет настоящего ожидания.
  final bool enabled;

  /// Сколько после нажатия человек считается занятым.
  final Duration hold;

  /// Как часто фон проверяет, освободился ли человек.
  final Duration poll;

  final DateTime Function() _clock;
  DateTime? _until;
  DateTime? _typingUntil;
  var _working = 0;

  /// Человек нажал клавишу, щёлкнул или прокрутил.
  void touch() {
    if (enabled) _until = _clock().add(hold);
  }

  /// Человек набрал букву в поле: он занят ([touch]) и ещё печатает ([typing]).
  void type() {
    if (!enabled) return;
    touch();
    _typingUntil = _clock().add(hold);
  }

  /// Набор идёт: буква была меньше [hold] назад.
  bool get typing {
    final until = _typingUntil;
    return until != null && _clock().isBefore(until);
  }

  /// Пересчёты после правки ждут конца набора, а не любого касания: на компьютере движение
  /// мыши — тоже касание, и списки не обновлялись бы, пока мышь двигается.
  Future<void> doneTyping() async {
    while (typing) {
      await Future<void>.delayed(poll);
    }
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

/// Один на приложение: его трогают корень приложения (касания, клавиши) и поля ввода (буквы:
/// касания по клавиатуре телефона приложению не видны), а спрашивают разбор фактов, сверка
/// хранилища, пересчёты после правок и виджет. Тест, которому нужно настоящее ожидание,
/// ставит свой (со своими часами) и возвращает прежний.
UserFirst userFirst = UserFirst(enabled: !inFlutterTest);
