import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/theme_provider.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Theme',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment(
                  value: AppThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
              ],
              selected: {
                currentTheme == AppThemeMode.amoled
                    ? AppThemeMode.dark
                    : currentTheme,
              },
              onSelectionChanged: (selection) {
                ref.read(themeProvider.notifier).setTheme(selection.first);
              },
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('AMOLED Dark'),
            subtitle: const Text(
              'Use pure black backgrounds to save battery on OLED screens.',
            ),
            secondary: const Icon(Icons.contrast),
            value: currentTheme == AppThemeMode.amoled,
            onChanged: (val) {
              if (val) {
                ref.read(themeProvider.notifier).setTheme(AppThemeMode.amoled);
              } else {
                ref.read(themeProvider.notifier).setTheme(AppThemeMode.dark);
              }
            },
          ),
        ],
      ),
    );
  }
}
