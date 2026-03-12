import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:json_theme/json_theme.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

import 'screens/tracker_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SyApp()));
}

class SyApp extends StatefulWidget {
  const SyApp({super.key});

  @override
  State<SyApp> createState() => _SyAppState();
}

class _SyAppState extends State<SyApp> {
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    try {
      final themes = await Future.wait([
        _loadTheme('assets/light_theme.json'),
        _loadTheme('assets/dark_theme.json'),
      ]);

      if (mounted) {
        setState(() {
          _lightTheme = themes[0];
          _darkTheme = themes[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading themes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<ThemeData> _loadTheme(String path) async {
    final themeStr = await rootBundle.loadString(path);
    final themeJson = jsonDecode(themeStr);
    final base = ThemeDecoder.decodeThemeData(themeJson)!;
    return base.copyWith(
      textTheme: GoogleFonts.jetBrainsMonoTextTheme(base.textTheme),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Streak Tracker',
      theme: _lightTheme ?? ThemeData.light(),
      darkTheme: _darkTheme ?? ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const TrackerListScreen(),
    );
  }
}
