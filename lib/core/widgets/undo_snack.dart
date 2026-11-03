import 'package:flutter/material.dart';

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
