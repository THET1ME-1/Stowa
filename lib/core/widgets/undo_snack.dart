import 'package:flutter/material.dart';

/// Плашка с «Отменить» для последнего действия. Прежняя снимается сразу: иначе
/// плашки встают в очередь и «Отменить» вернёт не то. Во Flutter плашка с кнопкой
/// по умолчанию висит, пока её не нажмут; здесь она уходит сама через [duration].
void showUndo(
  ScaffoldMessengerState messenger, {
  required String message,
  required String label,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        duration: duration,
        content: Text(message),
        action: SnackBarAction(label: label, onPressed: onUndo),
      ),
    );
}
