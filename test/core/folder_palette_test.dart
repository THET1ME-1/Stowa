import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/folder_palette.dart';

void main() {
  test('цвет папки: ключ палитры, свой #RRGGBB с круга, без выбора — по месту', () {
    expect(FolderPalette.of('mint', 0), FolderPalette.colors['mint']);
    expect(FolderPalette.of('#3A7BD5', 0), const Color(0xFF3A7BD5));
    expect(FolderPalette.of('#3a7bd5', 0), const Color(0xFF3A7BD5));
    expect(FolderPalette.of(null, 1), FolderPalette.colors.values.elementAt(1));
    expect(FolderPalette.of('#zzz', 2), FolderPalette.colors.values.elementAt(2));
    expect(FolderPalette.keyOf(const Color(0xFF3A7BD5)), '#3A7BD5');
    expect(FolderPalette.keyOf(const Color(0x8000000F)), '#00000F');
  });
}
