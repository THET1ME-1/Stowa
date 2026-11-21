import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../icons/icon_registry.dart';
import '../theme/tokens.dart';
import 'desk_mode.dart';

/// Калькулятор M3 для своего числа, как в Kadr: табло, цифры плитками, стирание и «Готово»
/// во всю ширину. Табло сначала пустое: старое число пришлось бы стирать перед новым.
/// Отдаёт число в [min]…[max] или null, если окно закрыли. На компьютере цифры, Backspace
/// и Enter — с клавиатуры.
Future<int?> showNumberPad(BuildContext context, {required String title, required int min, required int max, String unit = ''}) {
  return showStowaSheet<int>(context, maxHeightFactor: null, builder: (sheet) => _NumberPad(title: title, min: min, max: max, unit: unit));
}

class _NumberPad extends StatefulWidget {
  const _NumberPad({required this.title, required this.min, required this.max, required this.unit});

  final String title;
  final int min;
  final int max;
  final String unit;

  @override
  State<_NumberPad> createState() => _NumberPadState();
}

class _NumberPadState extends State<_NumberPad> {
  String _input = '';

  int? get _value => int.tryParse(_input);
  bool get _valid => _value != null && _value! >= widget.min && _value! <= widget.max;

  // клавиша «Numpad 7» и «7» с основного ряда — одна цифра
  static final _digitLabel = RegExp(r'^(?:Numpad )?(\d)$');

  /// Можно ли дописать цифру: без нуля впереди и не больше максимума.
  bool _canAppend(String digit) {
    if (_input.isEmpty && digit == '0') return widget.min <= 0;
    final next = int.tryParse(_input + digit);
    return next != null && next <= widget.max;
  }

  void _tap(String digit) {
    if (!_canAppend(digit)) return;
    HapticFeedback.selectionClick();
    setState(() => _input += digit);
  }

  void _backspace() {
    if (_input.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _confirm() {
    if (_valid) Navigator.pop(context, _value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_digitLabel.firstMatch(key.keyLabel)?.group(1) case final digit?) {
      _tap(digit);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _confirm();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _withUnit(int number) => widget.unit.isEmpty ? '$number' : '$number ${widget.unit}';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    // набрано, но вне границ — подсказка о границах краснеет
    final outside = _input.isNotEmpty && !_valid;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Center(
        heightFactor: 1,
        // на мониторе окно шире телефона: плитки не раздуваются
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            key: const ValueKey('number-pad'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.title, textAlign: TextAlign.center, style: text.titleSmall!.copyWith(color: Tokens.onSurfaceVariant)),
                const SizedBox(height: 6),
                // табло: набранное крупно, единица мельче рядом
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _input.isEmpty ? '—' : _input,
                        key: const ValueKey('pad-value'),
                        style: TextStyle(
                          fontFamily: 'Unbounded',
                          fontWeight: FontWeight.w700,
                          fontSize: 52,
                          height: 1.1,
                          color: _valid ? Tokens.onSurface : Tokens.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (widget.unit.isNotEmpty)
                        Text(' ${widget.unit}', style: TextStyle(fontFamily: 'Unbounded', fontWeight: FontWeight.w600, fontSize: 22, color: Tokens.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.numberPadRange('${widget.min}', _withUnit(widget.max)),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium!.copyWith(color: outside ? Tokens.error : Tokens.muted),
                ),
                const SizedBox(height: 18),
                for (final row in const [
                  ['7', '8', '9'],
                  ['4', '5', '6'],
                  ['1', '2', '3'],
                  ['', '0', 'b'],
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        for (final (index, key) in row.indexed) ...[
                          if (index > 0) const SizedBox(width: 10),
                          Expanded(child: _key(key)),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                FilledButton(
                  key: const ValueKey('pad-done'),
                  onPressed: _valid ? _confirm : null,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  child: Text(l.pickerApply, style: const TextStyle(fontFamily: 'Unbounded', fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Плитка: цифра, стирание («b») или пустое место слева от нуля. Цифра, которую
  /// дописать нельзя, гаснет.
  Widget _key(String key) {
    if (key.isEmpty) return const SizedBox.shrink();
    final back = key == 'b';
    final enabled = back ? _input.isNotEmpty : _canAppend(key);
    final ink = Tokens.onSurface.withValues(alpha: enabled ? 1 : 0.35);
    return AspectRatio(
      aspectRatio: 1.7,
      child: Material(
        key: ValueKey('pad-$key'),
        color: (back ? Tokens.containerHighest : Tokens.containerHigh).withValues(alpha: enabled ? 1 : 0.5),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? (back ? _backspace : () => _tap(key)) : null,
          child: Center(
            child: back
                ? Icon(symbolIcon('backspace'), size: 24, color: ink)
                : Text(key, style: TextStyle(fontFamily: 'Unbounded', fontWeight: FontWeight.w700, fontSize: 26, color: ink)),
          ),
        ),
      ),
    );
  }
}
