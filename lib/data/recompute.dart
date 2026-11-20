import 'dart:async';

class _Nothing {
  const _Nothing();
}

/// Пересчёт по сигналу без очереди.
///
/// `asyncMap` считает каждый сигнал по порядку: сто записей в базу, пока шёл один тяжёлый
/// пересчёт, оставляли за ним сто таких же. Здесь сигналы, пришедшие за время пересчёта,
/// сливаются в один следующий: он уже видит всё, что успело поменяться.
///
/// [rest] — передышка после пересчёта по его ответу: пока она идёт, новый не начинается,
/// даже если сигналы есть. Так фон, который пишет в базу без остановки, не заставляет
/// считать без остановки. Нет [rest] или пустая — следующий пересчёт сразу.
///
/// Тот же самый ответ (тот же объект) второй раз подписчику не уходит: пересчёт вправе
/// вернуть прошлый, когда сигнал его не касался.
Stream<T> recomputeOn<T>(Stream<void> changes, Future<T> Function() compute, {Duration Function(T value)? rest}) {
  late final StreamController<T> out;
  StreamSubscription<void>? source;
  Timer? resting;
  var busy = false;
  var dirty = false;
  // подписчик ушёл: ответ идущего пересчёта уже никому не нужен
  var left = false;
  // последний отданный ответ; до первого — метка, которой ответ быть не может
  Object? sent = const _Nothing();

  Future<void> run() async {
    busy = true;
    dirty = false;
    var pause = Duration.zero;
    try {
      final value = await compute();
      if (left) return;
      if (!identical(value, sent)) out.add(value);
      sent = value;
      pause = rest?.call(value) ?? Duration.zero;
    } catch (error, stack) {
      if (left) return;
      out.addError(error, stack);
    } finally {
      busy = false;
    }
    if (pause > Duration.zero) {
      resting = Timer(pause, () {
        resting = null;
        if (dirty && !left) run();
      });
    } else if (dirty) {
      run();
    }
  }

  out = StreamController<T>(
    onListen: () {
      source = changes.listen(
        (_) {
          dirty = true;
          if (!busy && resting == null) run();
        },
        onError: out.addError,
        onDone: out.close,
      );
    },
    onCancel: () {
      left = true;
      resting?.cancel();
      resting = null;
      return source?.cancel();
    },
  );
  return out.stream;
}
