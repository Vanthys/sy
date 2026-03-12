import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system, amoled }

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier(this._prefs) : super(_loadTheme(_prefs));

  final SharedPreferences _prefs;
  static const _themeKey = 'app_theme_mode';

  static AppThemeMode _loadTheme(SharedPreferences prefs) {
    final val = prefs.getString(_themeKey);
    return AppThemeMode.values.firstWhere(
      (e) => e.name == val,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    await _prefs.setString(_themeKey, mode.name);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize shared_preferences before app start');
});

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});
