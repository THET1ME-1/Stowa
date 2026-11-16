import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Свой цвет листом снизу: круг оттенков, ползунок яркости, HEX и R, G, B числами. Отмена — null.
Future<Color?> showColorPickerSheet(BuildContext context, {required Color initial, required String title}) {
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ColorPickerSheet(initial: initial, title: title),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initial, required this.title});

  final Color initial;
  final String title;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late Color _color = widget.initial.withValues(alpha: 1);

  // поля HEX и R, G, B: правка в любом двигает круг, круг переписывает поля
  late final _hex = TextEditingController(text: _hexOf(_color));
  late final _channels = [for (final value in _rgbOf(_color)) TextEditingController(text: '$value')];
  final _focus = [for (var i = 0; i < 4; i++) FocusNode()];

  @override
  void dispose() {
    _hex.dispose();
    for (final one in _channels) {
      one.dispose();
    }
    for (final one in _focus) {
      one.dispose();
    }
    super.dispose();
  }

  static String _hexOf(Color color) => (color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  static List<int> _rgbOf(Color color) {
    final value = color.toARGB32();
    return [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
  }

  /// Новый цвет; поля, которые человек сейчас не набирает, переписываются под него.
  void _set(Color color) {
    setState(() => _color = color.withValues(alpha: 1));
    if (!_focus[0].hasFocus) _hex.text = _hexOf(_color);
    final rgb = _rgbOf(_color);
    for (var i = 0; i < 3; i++) {
      if (!_focus[i + 1].hasFocus) _channels[i].text = '${rgb[i]}';
    }
  }

  void _fromHex(String text) {
    final clean = text.replaceAll('#', '').trim();
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(clean)) return;
    _set(Color(0xFF000000 | int.parse(clean, radix: 16)));
  }

  void _fromChannels() {
    final rgb = [for (final one in _channels) (int.tryParse(one.text) ?? 0).clamp(0, 255)];
    _set(Color.fromARGB(255, rgb[0], rgb[1], rgb[2]));
  }

  Widget _field({required String label, required TextEditingController controller, required FocusNode focus, required ValueChanged<String> onChanged, required bool hex, Key? key}) {
    return Column(
      // подпись канала над числом по центру, как само число; HEX — слева, как его текст
      crossAxisAlignment: hex ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.only(left: hex ? 12 : 0, bottom: 4),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Tokens.muted)),
        ),
        TextField(
          key: key,
          controller: controller,
          focusNode: focus,
          textAlign: hex ? TextAlign.start : TextAlign.center,
          keyboardType: hex ? TextInputType.visiblePassword : TextInputType.number,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            hex ? FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')) : FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(hex ? 7 : 3),
          ],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
          decoration: InputDecoration(
            isDense: true,
            prefixText: hex ? '# ' : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(width: 28, height: 28, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.title, style: text.titleLarge)),
              ],
            ),
            const SizedBox(height: 12),
            ColorPicker(
              pickerColor: _color,
              onColorChanged: _set,
              enableAlpha: false,
              paletteType: PaletteType.hueWheel,
              labelTypes: const [],
              hexInputBar: false,
              portraitOnly: true,
              pickerAreaBorderRadius: BorderRadius.circular(Radii.photo),
            ),
            // HEX и три канала одной строкой: место под ползунком больше не пустует
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 5,
                  child: _field(key: const ValueKey('color-hex'), label: 'HEX', controller: _hex, focus: _focus[0], hex: true, onChanged: _fromHex),
                ),
                for (final (i, label) in ['R', 'G', 'B'].indexed) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _field(key: ValueKey('color-$label'), label: label, controller: _channels[i], focus: _focus[i + 1], hex: false, onChanged: (_) => _fromChannels()),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, _color), child: Text(l.pickerApply))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
