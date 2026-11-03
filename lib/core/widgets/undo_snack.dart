import 'package:flutter/material.dart';

/// Плашка с «Отменить». Во Flutter плашка с кнопкой по умолчанию висит, пока её
/// не нажмут, и закрывает строку ввода; здесь она уходит сама через [duration].
SnackBar undoSnackBar({required String message, required String label, required VoidCallback onUndo, Duration duration = const Duration(seconds: 5)}) {
  return SnackBar(
    persist: false,
    duration: duration,
    content: Text(message),
    action: SnackBarAction(label: label, onPressed: onUndo),
  );
}
