import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sy3/logic/theme_provider.dart';

Future<ProviderContainer> _buildContainer(
  Map<String, Object> initialValues,
) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();

  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) => prefs),
    ],
  );
}

void main() {
  group('ThemeNotifier', () {
    test('defaults to system mode when no value is stored', () async {
      final container = await _buildContainer({});
      addTearDown(container.dispose);

      expect(container.read(themeProvider), AppThemeMode.system);
    });

    test('loads a previously stored theme mode', () async {
      final container = await _buildContainer({
        'app_theme_mode': AppThemeMode.dark.name,
      });
      addTearDown(container.dispose);

      expect(container.read(themeProvider), AppThemeMode.dark);
    });

    test('falls back to system mode when stored value is invalid', () async {
      final container = await _buildContainer({'app_theme_mode': 'invalid'});
      addTearDown(container.dispose);

      expect(container.read(themeProvider), AppThemeMode.system);
    });

    test('setTheme updates state and persists it', () async {
      final container = await _buildContainer({});
      addTearDown(container.dispose);

      await container.read(themeProvider.notifier).setTheme(AppThemeMode.amoled);

      expect(container.read(themeProvider), AppThemeMode.amoled);
      expect(
        container.read(sharedPreferencesProvider).getString('app_theme_mode'),
        AppThemeMode.amoled.name,
      );
    });
  });
}
