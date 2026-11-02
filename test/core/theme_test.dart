import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kladovka/core/theme/app_theme.dart';
import 'package:kladovka/core/theme/tokens.dart';

void main() {
  test('фон и карточки берутся из токенов графита', () {
    final theme = buildAppTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF141517));
    expect(theme.colorScheme.surfaceContainerHigh, const Color(0xFF26272B));
    expect(theme.colorScheme.primary, const Color(0xFFF4F4F2));
    expect(theme.colorScheme.onPrimary, const Color(0xFF141517));
    expect(theme.colorScheme.secondaryContainer, Tokens.graphite);
    expect(theme.cardTheme.elevation, 0);
  });

  test('текст набран Onest, крупные заголовки Unbounded', () {
    final theme = buildAppTheme();
    expect(theme.textTheme.bodyLarge!.fontFamily, 'Onest');
    expect(theme.textTheme.labelLarge!.fontFamily, 'Onest');
    expect(theme.textTheme.headlineMedium!.fontFamily, 'Unbounded');
    expect(theme.textTheme.headlineMedium!.fontWeight, FontWeight.w700);
  });

  test('теней нет нигде, глубина ступенями поверхности', () {
    final theme = buildAppTheme();
    expect(theme.appBarTheme.elevation, 0);
    expect(theme.appBarTheme.scrolledUnderElevation, 0);
    expect(theme.bottomSheetTheme.elevation, 0);
    expect(theme.dialogTheme.elevation, 0);
    expect(theme.shadowColor, Colors.transparent);
  });

  test('кнопки пилюлей высотой 56, поля с заливкой без рамки', () {
    final theme = buildAppTheme();
    final filled = theme.filledButtonTheme.style!;
    expect(filled.minimumSize!.resolve({})!.height, 56);
    expect(filled.shape!.resolve({}), isA<StadiumBorder>());
    final input = theme.inputDecorationTheme;
    expect(input.filled, isTrue);
    expect((input.border as OutlineInputBorder).borderSide, BorderSide.none);
  });
}
