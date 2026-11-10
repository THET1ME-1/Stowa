import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';

/// Сколько цифр в коде Stowa.
const codeMinLength = 6;
const codeMaxLength = 12;

/// Ввод кода: точки, цифры, отпечаток. [onSubmit] отвечает ошибкой или null, если код подошёл.
/// Проверка идёт около секунды (ключ из кода считается честно), пока она идёт — кольцо.
class CodeEntry extends StatefulWidget {
  const CodeEntry({super.key, required this.title, this.subtitle, required this.onSubmit, this.onFingerprint, this.footer, this.waitUntil});

  final String title;
  final String? subtitle;
  final Future<String?> Function(String code) onSubmit;

  /// Кнопка отпечатка в углу клавиатуры; null — отпечатка нет.
  final VoidCallback? onFingerprint;

  /// Под клавиатурой: «Забыл код», «Отмена».
  final Widget? footer;

  /// Неверных кодов подряд было много: ввод закрыт до этого времени.
  final DateTime? waitUntil;

  @override
  State<CodeEntry> createState() => CodeEntryState();
}

class CodeEntryState extends State<CodeEntry> {
  String _code = '';
  String? _error;
  bool _busy = false;

  /// Новый шаг (повтор кода): поле пустое, ошибки нет.
  void reset({String? error}) => setState(() {
    _code = '';
    _error = error;
  });

  void _press(String digit) {
    if (_busy || _code.length >= codeMaxLength || _waiting) return;
    HapticFeedback.selectionClick();
    setState(() {
      _code += digit;
      _error = null;
    });
  }

  void _erase() {
    if (_busy || _code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  bool get _waiting => widget.waitUntil != null && widget.waitUntil!.isAfter(DateTime.now());

  Future<void> _submit() async {
    if (_busy || _code.length < codeMinLength || _waiting) return;
    setState(() => _busy = true);
    final error = await widget.onSubmit(_code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error != null) {
        _error = error;
        _code = '';
        HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final wait = widget.waitUntil;
    final message = _waiting ? l.codeWait(wait!.difference(DateTime.now()).inSeconds + 1) : _error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(symbolIcon('lock'), size: 36, color: Tokens.accent),
        const SizedBox(height: 16),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: text.headlineSmall!.copyWith(fontWeight: FontWeight.w600),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: text.bodyMedium!.copyWith(color: Tokens.muted, height: 1.4),
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 20,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < (_code.length < codeMinLength ? codeMinLength : _code.length); index++)
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _code.length ? Tokens.onSurface : Colors.transparent,
                          border: Border.all(color: index < _code.length ? Tokens.onSurface : Tokens.outline, width: 1.6),
                        ),
                      ),
                  ],
                ),
        ),
        SizedBox(
          height: 36,
          child: Center(
            child: message == null
                ? null
                : Text(
                    message,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium!.copyWith(color: Tokens.error),
                  ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final digit in row) _Key(label: digit, onTap: () => _press(digit))],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            widget.onFingerprint == null ? const _Key() : _Key(icon: 'fingerprint', tooltip: l.codeFingerprint, onTap: widget.onFingerprint),
            _Key(label: '0', onTap: () => _press('0')),
            _Key(icon: 'backspace', tooltip: l.codeErase, onTap: _erase, onLongPress: () => setState(() => _code = '')),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 240,
          height: 52,
          child: FilledButton(onPressed: _code.length >= codeMinLength && !_busy && !_waiting ? _submit : null, child: Text(l.codeDone)),
        ),
        if (widget.footer != null) ...[const SizedBox(height: 8), widget.footer!],
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, this.tooltip, this.onTap, this.onLongPress});

  final String? label;
  final String? icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final empty = label == null && icon == null;
    final key = SizedBox(
      width: 76,
      height: 76,
      child: empty
          ? null
          : Material(
              color: label == null ? Colors.transparent : Tokens.containerHigh,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Center(
                  child: label != null
                      ? Text(label!, style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w500))
                      : Icon(symbolIcon(icon!), size: 28, color: Tokens.onSurface),
                ),
              ),
            ),
    );
    // подсказка — только для чтения с экрана: замок стоит над навигатором, всплывашкам там негде жить
    return Padding(
      padding: const EdgeInsets.all(6),
      child: tooltip == null ? key : Semantics(button: true, label: tooltip, child: key),
    );
  }
}
