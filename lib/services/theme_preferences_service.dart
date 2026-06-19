import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_provider.dart';

part 'theme_preferences_service.g.dart';

class ThemePreferencesService {
  ThemePreferencesService(this._prefs);

  final SharedPreferences _prefs;
  static const _themeKey = 'app_theme_mode';
  static const _seedColorKey = 'app_seed_color';
  static const _reverseMonthOrderKey = 'reverse_month_order';

  String? loadThemeName() {
    return _prefs.getString(_themeKey);
  }

  Future<void> setThemeName(String modeName) async {
    await _prefs.setString(_themeKey, modeName);
  }

  Color? loadSeedColor() {
    final value = _prefs.getInt(_seedColorKey);
    return value != null ? Color(value) : null;
  }

  Future<void> setSeedColor(Color? color) async {
    if (color == null) {
      await _prefs.remove(_seedColorKey);
    } else {
      await _prefs.setInt(_seedColorKey, color.toARGB32());
    }
  }

  bool loadReverseMonthOrder() {
    return _prefs.getBool(_reverseMonthOrderKey) ?? false;
  }

  Future<void> setReverseMonthOrder(bool value) async {
    await _prefs.setBool(_reverseMonthOrderKey, value);
  }
}

@Riverpod(keepAlive: true)
ThemePreferencesService themePreferencesService(Ref ref) {
  return ThemePreferencesService(ref.watch(sharedPreferencesProvider));
}
