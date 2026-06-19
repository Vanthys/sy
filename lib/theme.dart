import 'package:flutter/material.dart';

const Color kFallbackSeed = Color(0xFF515B92);

/// Replaces the surface hierarchy of [scheme] with surfaces generated from
/// [kFallbackSeed], guaranteeing visible tonal contrast regardless of how
/// saturated or neutral the accent seed is.
ColorScheme withStableSurfaces(ColorScheme scheme, Brightness brightness) {
  final surfaces = ColorScheme.fromSeed(
    seedColor: kFallbackSeed,
    brightness: brightness,
  );
  return scheme.copyWith(
    surface: surfaces.surface,
    surfaceContainerLowest: surfaces.surfaceContainerLowest,
    surfaceContainerLow: surfaces.surfaceContainerLow,
    surfaceContainer: surfaces.surfaceContainer,
    surfaceContainerHigh: surfaces.surfaceContainerHigh,
    surfaceContainerHighest: surfaces.surfaceContainerHighest,
  );
}

ThemeData buildTheme(ColorScheme colorScheme) {
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    fontFamily: 'JetBrainsMono',
    scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
    cardTheme: CardThemeData(color: colorScheme.surfaceContainerHigh),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surfaceContainerLowest,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

ThemeData buildAmoledTheme(ThemeData darkTheme) {
  return darkTheme.copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: darkTheme.colorScheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF111111),
      surfaceContainerHigh: const Color(0xFF1A1A1A),
      surfaceContainerHighest: const Color(0xFF222222),
    ),
    appBarTheme: darkTheme.appBarTheme.copyWith(
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: darkTheme.bottomSheetTheme.copyWith(
      backgroundColor: const Color(0xFF0A0A0A),
    ),
    dialogTheme: darkTheme.dialogTheme.copyWith(
      backgroundColor: const Color(0xFF0A0A0A),
    ),
  );
}
