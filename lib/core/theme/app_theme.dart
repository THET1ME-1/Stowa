import 'package:flutter/material.dart';

import 'tokens.dart';

const displayFont = 'Unbounded';
const bodyFont = 'Onest';

/// Схема M3 из токенов графита. Сид нужен только для ролей, которых в макете
/// нет (tertiary, fixed), всё видимое задано руками.
ColorScheme buildColorScheme() {
  return ColorScheme.fromSeed(
    seedColor: Tokens.accent,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
  ).copyWith(
    surface: Tokens.background,
    surfaceDim: Tokens.background,
    surfaceBright: Tokens.containerHighest,
    surfaceContainerLowest: Tokens.containerLowest,
    surfaceContainerLow: Tokens.containerLow,
    surfaceContainer: Tokens.container,
    surfaceContainerHigh: Tokens.containerHigh,
    surfaceContainerHighest: Tokens.containerHighest,
    onSurface: Tokens.onSurface,
    onSurfaceVariant: Tokens.onSurfaceVariant,
    primary: Tokens.accent,
    onPrimary: Tokens.onAccent,
    primaryContainer: Tokens.accent,
    onPrimaryContainer: Tokens.onAccent,
    secondary: Tokens.onSurfaceVariant,
    onSecondary: Tokens.onAccent,
    secondaryContainer: Tokens.graphite,
    onSecondaryContainer: Tokens.onSurface,
    tertiary: Tokens.muted,
    onTertiary: Tokens.onAccent,
    tertiaryContainer: Tokens.containerHighest,
    onTertiaryContainer: Tokens.onSurface,
    outline: Tokens.muted,
    outlineVariant: Tokens.outline,
    inverseSurface: Tokens.accent,
    onInverseSurface: Tokens.onAccent,
    inversePrimary: Tokens.graphite,
    error: Tokens.error,
    onError: Tokens.onError,
    shadow: Colors.transparent,
    scrim: const Color(0xB80C0D0E),
  );
}

TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
  TextStyle display(TextStyle? style, double size) => style!.copyWith(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      );
  final body = base.apply(fontFamily: bodyFont, bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  return body.copyWith(
    displayLarge: display(body.displayLarge, 48),
    displayMedium: display(body.displayMedium, 40),
    displaySmall: display(body.displaySmall, 32),
    headlineLarge: display(body.headlineLarge, 28),
    headlineMedium: display(body.headlineMedium, 24),
    headlineSmall: display(body.headlineSmall, 20),
    titleLarge: body.titleLarge!.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
    titleMedium: body.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall: body.titleSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    bodyLarge: body.bodyLarge!.copyWith(fontSize: 16, height: 1.45),
    bodyMedium: body.bodyMedium!.copyWith(fontSize: 15, height: 1.4),
    bodySmall: body.bodySmall!.copyWith(fontSize: 13, color: scheme.onSurfaceVariant),
    labelLarge: body.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    labelMedium: body.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
    labelSmall: body.labelSmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
  );
}

/// Тема Кладовки: тёмный матовый графит и белый, M3 Expressive по ДНК
/// Togetherly. Теней нет, листы снизу, кнопки пилюлей.
ThemeData buildAppTheme() {
  final scheme = buildColorScheme();
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  final text = _textTheme(base.textTheme, scheme);
  const pill = StadiumBorder();
  final buttonText = text.labelLarge!.copyWith(fontSize: 16);

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    shadowColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.headlineSmall,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: pill,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: pill, textStyle: text.labelLarge),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44), shape: const CircleBorder()),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primary,
      labelStyle: text.labelLarge!.copyWith(fontSize: 14),
      side: BorderSide.none,
      shape: pill,
      elevation: 0,
      pressElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      hintStyle: text.bodyLarge!.copyWith(color: Tokens.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.card), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.card), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.card), borderSide: BorderSide.none),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      modalElevation: 0,
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.outlineVariant,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card))),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
    ),
    snackBarTheme: SnackBarThemeData(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium!.copyWith(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.outlineVariant,
      // ignore: deprecated_member_use
      year2023: false,
    ),
  );
}
