import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:json_theme/json_theme.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'screens/tracker_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load light theme
  final lightThemeStr = await rootBundle.loadString('assets/light_theme.json');
  final lightThemeJson = jsonDecode(lightThemeStr);
  final lightTheme = ThemeDecoder.decodeThemeData(lightThemeJson)!;

  // Load dark theme
  final darkThemeStr = await rootBundle.loadString('assets/dark_theme.json');
  final darkThemeJson = jsonDecode(darkThemeStr);
  final darkTheme = ThemeDecoder.decodeThemeData(darkThemeJson)!;

  runApp(
    ProviderScope(
      child: SyApp(lightTheme: lightTheme, darkTheme: darkTheme),
    ),
  );
}

class SyApp extends StatelessWidget {
  final ThemeData lightTheme;
  final ThemeData darkTheme;

  const SyApp({super.key, required this.lightTheme, required this.darkTheme});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Streak Tracker',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system, // Automatically switches
      home: const TrackerListScreen(),
    );
  }
}
