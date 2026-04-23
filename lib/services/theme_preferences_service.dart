import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_provider.dart';

part 'theme_preferences_service.g.dart';

class ThemePreferencesService {
  ThemePreferencesService(this._prefs);

  final SharedPreferences _prefs;
  static const _themeKey = 'app_theme_mode';

  String? loadThemeName() {
    return _prefs.getString(_themeKey);
  }

  Future<void> setThemeName(String modeName) async {
    await _prefs.setString(_themeKey, modeName);
  }
}

@Riverpod(keepAlive: true)
ThemePreferencesService themePreferencesService(Ref ref) {
  return ThemePreferencesService(ref.watch(sharedPreferencesProvider));
}
