import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/theme_preferences_service.dart';
export '../services/shared_preferences_provider.dart'
    show sharedPreferencesProvider;

part 'theme_provider.g.dart';

enum AppThemeMode { light, dark, system, amoled }

@Riverpod(keepAlive: true)
class ThemeNotifier extends _$ThemeNotifier {
  @override
  AppThemeMode build() {
    final val = ref.watch(themePreferencesServiceProvider).loadThemeName();
    return AppThemeMode.values.firstWhere(
      (e) => e.name == val,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    await ref.read(themePreferencesServiceProvider).setThemeName(mode.name);
  }
}

@Riverpod(keepAlive: true)
class SeedColorNotifier extends _$SeedColorNotifier {
  @override
  Color? build() {
    return ref.watch(themePreferencesServiceProvider).loadSeedColor();
  }

  Future<void> setSeedColor(Color? color) async {
    state = color;
    await ref.read(themePreferencesServiceProvider).setSeedColor(color);
  }
}

@Riverpod(keepAlive: true)
class ReverseMonthOrderNotifier extends _$ReverseMonthOrderNotifier {
  @override
  bool build() {
    return ref.watch(themePreferencesServiceProvider).loadReverseMonthOrder();
  }

  Future<void> toggle() async {
    state = !state;
    await ref.read(themePreferencesServiceProvider).setReverseMonthOrder(state);
  }
}
