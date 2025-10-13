import 'package:flutter/material.dart';
import 'package:json_theme/json_theme.dart';
import 'package:flutter/services.dart'; 
import 'dart:convert';

import 'data/database.dart';
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

  runApp(SyApp(
    lightTheme: lightTheme,
    darkTheme: darkTheme,
  ));
}

class SyApp extends StatefulWidget {
  final ThemeData lightTheme;
  final ThemeData darkTheme;

  const SyApp({
    super.key,
    required this.lightTheme,
    required this.darkTheme,
  });

  @override
  State<SyApp> createState() => _SyAppState();
}

class _SyAppState extends State<SyApp> {
  late final AppDatabase _database;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Streak Tracker',
      theme: widget.lightTheme,
      darkTheme: widget.darkTheme,
      themeMode: ThemeMode.system, // Automatically switches
      home: TrackerListScreen(database: _database),
    );
  }
}
