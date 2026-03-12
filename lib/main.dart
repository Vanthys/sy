import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:json_theme/json_theme.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'screens/tracker_list_screen.dart';
import 'logic/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SyApp(),
    ),
  );
}

class SyApp extends ConsumerStatefulWidget {
  const SyApp({super.key});

  @override
  ConsumerState<SyApp> createState() => _SyAppState();
}

class _SyAppState extends ConsumerState<SyApp> {
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;
  ThemeData? _amoledTheme;
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
          _amoledTheme = _generateAmoledTheme(themes[1]);
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

  ThemeData _generateAmoledTheme(ThemeData baseDark) {
    return baseDark.copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: baseDark.colorScheme.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF111111),
        surfaceContainerHigh: const Color(0xFF1A1A1A),
        surfaceContainerHighest: const Color(0xFF222222),
      ),
      appBarTheme: baseDark.appBarTheme.copyWith(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: baseDark.bottomSheetTheme.copyWith(
        backgroundColor: const Color(0xFF0A0A0A),
      ),
      dialogTheme: baseDark.dialogTheme.copyWith(
        backgroundColor: const Color(0xFF0A0A0A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final themeMode = ref.watch(themeProvider);

    ThemeData? activeDarkTheme = _darkTheme ?? ThemeData.dark();
    if (themeMode == AppThemeMode.amoled) {
      activeDarkTheme = _amoledTheme;
    }

    ThemeMode activeThemeMode;
    switch (themeMode) {
      case AppThemeMode.light:
        activeThemeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
        activeThemeMode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        activeThemeMode = ThemeMode.system;
        break;
    }

    return MaterialApp(
      title: 'Streak Tracker',
      theme: _lightTheme ?? ThemeData.light(),
      darkTheme: activeDarkTheme,
      themeMode: activeThemeMode,
      home: const TrackerListScreen(),
    );
  }
}
