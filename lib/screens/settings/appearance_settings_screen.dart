import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/theme_provider.dart';
import '../../theme.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    final customSeed = ref.watch(seedColorProvider);

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
              ref
                  .read(themeProvider.notifier)
                  .setTheme(val ? AppThemeMode.amoled : AppThemeMode.dark);
            },
          ),
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Accent Color',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: CircleAvatar(
              radius: 14,
              backgroundColor:
                  customSeed ?? Theme.of(context).colorScheme.primary,
            ),
            title: Text(customSeed != null ? 'Custom color' : 'System default'),
            subtitle: Text(
              customSeed != null
                  ? 'Tap to change, or reset to use system color'
                  : 'Uses your device\'s wallpaper color on Android 12+',
            ),
            trailing: customSeed != null
                ? IconButton(
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Reset to system',
                    onPressed: () {
                      ref.read(seedColorProvider.notifier).setSeedColor(null);
                    },
                  )
                : null,
            onTap: () => _pickColor(context, ref, customSeed),
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor(
    BuildContext context,
    WidgetRef ref,
    Color? current,
  ) async {
    Color picked = current ?? kFallbackSeed;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accent Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (color) => picked = color,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(seedColorProvider.notifier).setSeedColor(picked);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
