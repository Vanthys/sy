// lib/theme.dart
import 'package:flutter/material.dart';

/// Core color palette (intensity theme)
const Color kPrimary = Color(0xFF9B2FAE); // deep purple-magenta
const Color kSecondary = Color.fromARGB(255, 53, 144, 229); // intense red accent
const Color kSurfaceDark = Color(0xFF121212); // very dark surface background
const Color kSurfaceDarkElevated = Color(0xFF333333);

const Color kSurfaceLight = Color(0xFFFDFDFD); // soft light background
const Color kSurfaceLightElevated = Color(0xFFAAAAAA);


/// Light theme
final ColorScheme lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: kPrimary,
  onPrimary: Colors.white,
  secondary: kSecondary,
  onSecondary: Colors.white,
  surface: kSurfaceLight,
  surfaceBright: kSurfaceLightElevated,
  onSurface: Colors.black,
  error: Colors.red.shade700,
  onError: Colors.white,
  primaryContainer: kPrimary.withAlpha(30),
  onPrimaryContainer: kPrimary,
  secondaryContainer: kSecondary.withAlpha(30),
  onSecondaryContainer: kSecondary,
  outline: Colors.grey.shade400,
);

// Dark color scheme (intense + moody)
final ColorScheme darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: kPrimary,
  onPrimary: Colors.white,
  secondary: kSecondary,
  onSecondary: Colors.white,
  surface: kSurfaceDark,
  surfaceBright: kSurfaceDarkElevated,
  onSurface: Colors.white,
  error: Colors.red.shade400,
  onError: Colors.black,
  primaryContainer: kPrimary.withAlpha(50),
  onPrimaryContainer: Colors.white,
  secondaryContainer: kSecondary.withAlpha(50),
  onSecondaryContainer: Colors.white,
  outline: Colors.grey.shade700,
);


final ThemeData lightTheme = ThemeData(
  colorScheme: lightColorScheme,
  useMaterial3: true,
  scaffoldBackgroundColor: lightColorScheme.surface,
  appBarTheme: AppBarTheme(
    backgroundColor: lightColorScheme.surface,
    foregroundColor: lightColorScheme.onSurface,
    elevation: 0,
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: lightColorScheme.primary,
    foregroundColor: lightColorScheme.onPrimary,
  ),
);

final ThemeData darkTheme = ThemeData(
  colorScheme: darkColorScheme,
  useMaterial3: true,
  scaffoldBackgroundColor: darkColorScheme.surface,
  appBarTheme: AppBarTheme(
    backgroundColor: darkColorScheme.surface,
    foregroundColor: darkColorScheme.onSurface,
    elevation: 0,
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: darkColorScheme.primary,
    foregroundColor: darkColorScheme.onPrimary,
  ),
);