import 'package:flutter/material.dart';

/// Плашка на мониторе: рабочее пространство показывает её пилюлей по центру над общей
/// строкой, как в макете веба (`design/web/stowa-web-workspace.html`, `.toast`), а не
/// полосой во всю ширину окна.
class DeskToast {
  DeskToast({required this.message, this.label, this.onTap, required this.duration});

  final String message;
  final String? label;
  final VoidCallback? onTap;
  final Duration duration;
}

/// Куда уходят плашки, пока на экране рабочее пространство (`DeskToastHost`). Оно одно,
/// поэтому объект общий. Нет его — плашки идут обычными `SnackBar`, как на телефоне.
class DeskToasts extends ValueNotifier<DeskToast?> {
  DeskToasts() : super(null);

  int _hosts = 0;

  /// Показывать ли плашки пилюлей: рабочее пространство на экране.
  bool get hosted => _hosts > 0;

  void attach() => _hosts++;

  void detach() {
    _hosts--;
    if (_hosts == 0) value = null;
  }

  /// Убрать плашку; с [only] — только если на экране всё ещё она.
  void hide([DeskToast? only]) {
    if (only == null || identical(value, only)) value = null;
  }
}

final deskToasts = DeskToasts();

/// Плашка с «Отменить» для последнего действия. Прежняя снимается сразу: иначе
/// плашки встают в очередь и «Отменить» вернёт не то. Во Flutter плашка с кнопкой
/// по умолчанию висит, пока её не нажмут; здесь она уходит сама через [duration].
/// [overDock] — на экране со строкой ввода внизу: плашка встаёт над ней, а не на её кнопки.
void showUndo(
  ScaffoldMessengerState messenger, {
  required String message,
  required String label,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
  bool overDock = false,
}) {
  if (deskToasts.hosted) {
    messenger.hideCurrentSnackBar();
    deskToasts.value = DeskToast(message: message, label: label, onTap: onUndo, duration: duration);
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        duration: duration,
        // свёрнутая строка ввода занимает снизу около 120 точек с отступами
        margin: overDock ? const EdgeInsets.fromLTRB(16, 0, 16, 128) : null,
        content: Text(message),
        action: SnackBarAction(label: label, onPressed: onUndo),
      ),
    );
}

/// Короткое сообщение без кнопки. Прежняя плашка снимается, как у [showUndo].
/// [overDock] — над плавающей панелью внизу экрана.
void showNote(ScaffoldMessengerState messenger, String message, {bool overDock = false}) {
  if (deskToasts.hosted) {
    messenger.hideCurrentSnackBar();
    deskToasts.value = DeskToast(message: message, duration: const Duration(seconds: 3));
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        duration: const Duration(seconds: 3),
        margin: overDock ? const EdgeInsets.fromLTRB(16, 0, 16, 112) : null,
        content: Text(message),
      ),
    );
}
