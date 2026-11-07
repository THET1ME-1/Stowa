import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Свой цвет листом снизу: круг оттенков, ползунок яркости и HEX. Отмена — null.
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
  late Color _color = widget.initial;

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
              onColorChanged: (color) => setState(() => _color = color),
              enableAlpha: false,
              paletteType: PaletteType.hueWheel,
              labelTypes: const [],
              hexInputBar: true,
              portraitOnly: true,
              pickerAreaBorderRadius: BorderRadius.circular(Radii.photo),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, _color.withValues(alpha: 1)), child: Text(l.pickerApply))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
